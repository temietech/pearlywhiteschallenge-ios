// PearlyToothbrushScanner - Godot iOS plugin
// Rear camera (AVFoundation) + TensorFlow Lite C API toothbrush detection.
//
// Model: efficientdet_lite0.tflite (COCO, 90 classes, "toothbrush" = class index 89).
// The bundled model is the raw (no NMS) variant:
//   input  [1, 320, 320, 3] float32, normalised (pixel - 127.5) / 127.5
//   output [1, 19206, 90]   class scores (logits) per anchor
//   output [1, 19206, 4]    box regressions (not needed here)
// The code below inspects the tensors at load time, so it also works with the
// post-processed (4-output) and uint8 variants of the same model.

#import "PearlyToothbrushScanner.h"
#include "core/object/message_queue.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <Accelerate/Accelerate.h>
#include <TensorFlowLiteC/TensorFlowLiteC.h>

#include <atomic>
#include <cmath>
#include <cstdlib>
#include <cstring>

// ---- Tunables ---------------------------------------------------------------
static const int kToothbrushClassIndex = 89;   // COCO label map index (0-based, 90 classes)
static const float kVerifyThreshold = 0.52f;   // probability needed on a frame (filters 2D screen noise)
static const int kRequiredConsecutiveHits = 4; // frames in a row above threshold for physical presence
static const int kPreviewWidth = 240;          // preview image sent to Godot
static const double kDetectedSignalInterval = 0.2; // seconds between toothbrush_detected signals

// Convert a 0-1 probability into the 0-100 value the game UI uses.
// The UI treats 65 as "locked", so the verify threshold is mapped onto 65.
static float ui_confidence(float probability) {
	float v = probability / kVerifyThreshold * 65.0f;
	if (v < 0.0f) v = 0.0f;
	if (v > 99.0f) v = 99.0f;
	return v;
}

static float sigmoidf_(float x) { return 1.0f / (1.0f + expf(-x)); }

enum PearlyModelMode {
	PEARLY_MODEL_RAW = 0,  // [1, anchors, classes] scores
	PEARLY_MODEL_POST = 1, // boxes / classes / scores / count
};

// ============================================================================
@interface PearlyCameraDelegate : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
- (BOOL)setupTFLiteModel;
- (void)startCamera;
- (void)stopCamera;
- (void)cleanupTFLite;
- (void)previewDelivered;
- (void)shutdown;
@end

@implementation PearlyCameraDelegate {
	AVCaptureSession *_session;
	dispatch_queue_t _sessionQueue;
	dispatch_queue_t _videoQueue;
	dispatch_queue_t _inferenceQueue;

	TfLiteModel *_model;
	TfLiteInterpreter *_interpreter;
	int _inW, _inH, _inC;
	TfLiteType _inType;
	PearlyModelMode _mode;
	int _numClasses;

	std::atomic<bool> _running;      // frames are being processed
	std::atomic<bool> _wantRunning;  // startCamera requested and not stopped since
	std::atomic<bool> _inferenceBusy;
	std::atomic<int> _pendingPreviews;
	int _consecutiveHits;
	uint64_t _frameCounter;
	CFAbsoluteTime _lastDetectedEmit;
}

- (instancetype)init {
	self = [super init];
	if (self) {
		_sessionQueue = dispatch_queue_create("com.pearlywhites.scanner.session", DISPATCH_QUEUE_SERIAL);
		_videoQueue = dispatch_queue_create("com.pearlywhites.scanner.video", DISPATCH_QUEUE_SERIAL);
		_inferenceQueue = dispatch_queue_create("com.pearlywhites.scanner.inference", DISPATCH_QUEUE_SERIAL);
		_model = NULL;
		_interpreter = NULL;
		_running = false;
		_wantRunning = false;
		_inferenceBusy = false;
		_pendingPreviews = 0;
		_consecutiveHits = 0;
		_frameCounter = 0;
		_lastDetectedEmit = 0;
	}
	return self;
}

static void pearly_error(const char *msg) {
	NSLog(@"[PearlyScanner] %s", msg);
	if (PearlyToothbrushScanner::get_singleton()) {
		PearlyToothbrushScanner::get_singleton()->emit_scanner_error(String(msg));
	}
}

// Called on the inference queue only.
- (BOOL)setupTFLiteModel {
	if (_interpreter) {
		return YES;
	}
	NSString *modelPath = [[NSBundle mainBundle] pathForResource:@"efficientdet_lite0" ofType:@"tflite"];
	if (!modelPath) {
		pearly_error("efficientdet_lite0.tflite was not found in the app bundle.");
		return NO;
	}

	_model = TfLiteModelCreateFromFile([modelPath UTF8String]);
	if (!_model) {
		pearly_error("Could not load the toothbrush model.");
		return NO;
	}

	TfLiteInterpreterOptions *options = TfLiteInterpreterOptionsCreate();
	TfLiteInterpreterOptionsSetNumThreads(options, 2);
	_interpreter = TfLiteInterpreterCreate(_model, options);
	TfLiteInterpreterOptionsDelete(options);
	if (!_interpreter || TfLiteInterpreterAllocateTensors(_interpreter) != kTfLiteOk) {
		pearly_error("Could not start the toothbrush model.");
		[self cleanupTFLite];
		return NO;
	}

	// ---- Input description ----
	const TfLiteTensor *input = TfLiteInterpreterGetInputTensor(_interpreter, 0);
	if (!input || TfLiteTensorNumDims(input) != 4) {
		pearly_error("Unexpected model input shape.");
		[self cleanupTFLite];
		return NO;
	}
	_inH = TfLiteTensorDim(input, 1);
	_inW = TfLiteTensorDim(input, 2);
	_inC = TfLiteTensorDim(input, 3);
	_inType = TfLiteTensorType(input);
	if (_inC != 3 || (_inType != kTfLiteFloat32 && _inType != kTfLiteUInt8)) {
		pearly_error("Unsupported model input format.");
		[self cleanupTFLite];
		return NO;
	}

	// ---- Output description ----
	int outCount = TfLiteInterpreterGetOutputTensorCount(_interpreter);
	_mode = PEARLY_MODEL_RAW;
	_numClasses = 0;
	if (outCount >= 3) {
		_mode = PEARLY_MODEL_POST;
	} else {
		for (int i = 0; i < outCount; i++) {
			const TfLiteTensor *t = TfLiteInterpreterGetOutputTensor(_interpreter, i);
			if (TfLiteTensorNumDims(t) == 3 && TfLiteTensorDim(t, 2) > 4) {
				_numClasses = TfLiteTensorDim(t, 2);
			}
		}
		if (_numClasses <= kToothbrushClassIndex) {
			pearly_error("Model output does not contain the toothbrush class.");
			[self cleanupTFLite];
			return NO;
		}
	}

	NSLog(@"[PearlyScanner] Model ready: input %dx%dx%d (%s), mode %s",
			_inW, _inH, _inC, _inType == kTfLiteFloat32 ? "float32" : "uint8",
			_mode == PEARLY_MODEL_RAW ? "raw" : "post-processed");
	return YES;
}

// ---------------------------------------------------------------------------
// Camera
- (void)startCamera {
	if (_wantRunning) {
		return;
	}
	_wantRunning = true;
	_consecutiveHits = 0;
	_frameCounter = 0;

	// Load the model in the background (first start only).
	dispatch_async(_inferenceQueue, ^{
		[self setupTFLiteModel];
	});

	dispatch_async(_sessionQueue, ^{
		if (!self->_wantRunning) {
			return; // stopped again before the camera opened
		}
		if (self->_session) {
			[self->_session stopRunning];
			self->_session = nil;
		}

		AVCaptureSession *session = [[AVCaptureSession alloc] init];
		[session beginConfiguration];
		if ([session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
			session.sessionPreset = AVCaptureSessionPreset640x480;
		}

		AVCaptureDevice *camera = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
																	 mediaType:AVMediaTypeVideo
																	  position:AVCaptureDevicePositionBack];
		if (!camera) {
			camera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
		}
		if (!camera) {
			[session commitConfiguration];
			self->_wantRunning = false;
			pearly_error("No camera was found on this device.");
			return;
		}

		NSError *error = nil;
		AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:camera error:&error];
		if (!input || error || ![session canAddInput:input]) {
			[session commitConfiguration];
			self->_wantRunning = false;
			pearly_error("Could not open the rear camera.");
			return;
		}
		[session addInput:input];

		AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
		output.alwaysDiscardsLateVideoFrames = YES;
		output.videoSettings = @{ (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA) };
		[output setSampleBufferDelegate:self queue:self->_videoQueue];
		if (![session canAddOutput:output]) {
			[session commitConfiguration];
			self->_wantRunning = false;
			pearly_error("Could not read frames from the camera.");
			return;
		}
		[session addOutput:output];

		// Deliver frames upright for a phone held in portrait.
		AVCaptureConnection *conn = [output connectionWithMediaType:AVMediaTypeVideo];
		if (conn) {
			if (@available(iOS 17.0, *)) {
				if ([conn isVideoRotationAngleSupported:90.0]) {
					conn.videoRotationAngle = 90.0;
				}
			} else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
				if (conn.isVideoOrientationSupported) {
					conn.videoOrientation = AVCaptureVideoOrientationPortrait;
				}
#pragma clang diagnostic pop
			}
		}

		[session commitConfiguration];
		if (!self->_wantRunning) {
			return;
		}
		self->_session = session;
		self->_running = true;
		[session startRunning];
		NSLog(@"[PearlyScanner] Rear camera started.");
	});
}

- (void)stopCamera {
	_wantRunning = false;
	_running = false;
	dispatch_async(_sessionQueue, ^{
		if (self->_session) {
			[self->_session stopRunning];
			self->_session = nil;
			NSLog(@"[PearlyScanner] Camera stopped.");
		}
	});
}

// ---------------------------------------------------------------------------
// Frames (video queue)
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
	if (!_running) {
		return;
	}
	CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
	if (!pixelBuffer) {
		return;
	}
	_frameCounter++;

	CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
	const size_t w = CVPixelBufferGetWidth(pixelBuffer);
	const size_t h = CVPixelBufferGetHeight(pixelBuffer);
	const size_t rowBytes = CVPixelBufferGetBytesPerRow(pixelBuffer);
	uint8_t *base = (uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);

	vImage_Buffer src = { base, (vImagePixelCount)h, (vImagePixelCount)w, rowBytes };

	// 1) Live preview for the game UI (~15 fps, skipped if the game is behind).
	if ((_frameCounter % 2) == 0 && _pendingPreviews.load() < 2) {
		const int pw = kPreviewWidth;
		const int ph = (int)llround((double)kPreviewWidth * (double)h / (double)w);
		PackedByteArray rgba;
		if (ph > 0 && rgba.resize(pw * ph * 4) == OK) {
			vImage_Buffer dst = { rgba.ptrw(), (vImagePixelCount)ph, (vImagePixelCount)pw, (size_t)pw * 4 };
			if (vImageScale_ARGB8888(&src, &dst, NULL, kvImageNoFlags) == kvImageNoError) {
				const uint8_t bgraToRgba[4] = { 2, 1, 0, 3 };
				vImagePermuteChannels_ARGB8888(&dst, &dst, bgraToRgba, kvImageNoFlags);
				_pendingPreviews++;
				if (PearlyToothbrushScanner::get_singleton()) {
					PearlyToothbrushScanner::get_singleton()->emit_preview_frame(rgba, pw, ph);
				}
			}
		}
	}

	// 2) Model input: centre square crop, scaled to the model size (only when idle).
	if (_interpreter && !_inferenceBusy.load()) {
		const size_t side = w < h ? w : h;
		const size_t x0 = (w - side) / 2;
		const size_t y0 = (h - side) / 2;
		vImage_Buffer crop = { base + y0 * rowBytes + x0 * 4, (vImagePixelCount)side, (vImagePixelCount)side, rowBytes };

		const int mw = _inW, mh = _inH;
		uint8_t *scaled = (uint8_t *)malloc((size_t)mw * mh * 4);
		if (scaled) {
			vImage_Buffer dst = { scaled, (vImagePixelCount)mh, (vImagePixelCount)mw, (size_t)mw * 4 };
			if (vImageScale_ARGB8888(&crop, &dst, NULL, kvImageNoFlags) == kvImageNoError) {
				_inferenceBusy = true;
				dispatch_async(_inferenceQueue, ^{
					[self runInference:scaled];
					free(scaled);
					self->_inferenceBusy = false;
				});
			} else {
				free(scaled);
			}
		}
	}

	CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
}

- (void)previewDelivered {
	if (_pendingPreviews.load() > 0) {
		_pendingPreviews--;
	}
}

// ---------------------------------------------------------------------------
// Inference (inference queue). `bgra` is _inW x _inH BGRA.
- (void)runInference:(const uint8_t *)bgra {
	if (!_running || !_interpreter) {
		return;
	}

	TfLiteTensor *input = TfLiteInterpreterGetInputTensor(_interpreter, 0);
	const int pixels = _inW * _inH;
	if (_inType == kTfLiteFloat32) {
		float *dst = (float *)TfLiteTensorData(input);
		for (int i = 0; i < pixels; i++) {
			dst[i * 3 + 0] = ((float)bgra[i * 4 + 2] - 127.5f) / 127.5f; // R
			dst[i * 3 + 1] = ((float)bgra[i * 4 + 1] - 127.5f) / 127.5f; // G
			dst[i * 3 + 2] = ((float)bgra[i * 4 + 0] - 127.5f) / 127.5f; // B
		}
	} else {
		uint8_t *dst = (uint8_t *)TfLiteTensorData(input);
		for (int i = 0; i < pixels; i++) {
			dst[i * 3 + 0] = bgra[i * 4 + 2];
			dst[i * 3 + 1] = bgra[i * 4 + 1];
			dst[i * 3 + 2] = bgra[i * 4 + 0];
		}
	}

	if (TfLiteInterpreterInvoke(_interpreter) != kTfLiteOk) {
		return;
	}

	const float probability = (_mode == PEARLY_MODEL_RAW) ? [self toothbrushProbabilityRaw] : [self toothbrushProbabilityPost];
	if (!_running) {
		return;
	}

	PearlyToothbrushScanner *scanner = PearlyToothbrushScanner::get_singleton();
	if (!scanner) {
		return;
	}

	if (probability >= kVerifyThreshold) {
		_consecutiveHits++;
	} else {
		_consecutiveHits = 0;
	}

	if (_consecutiveHits >= kRequiredConsecutiveHits) {
		NSLog(@"[PearlyScanner] Toothbrush verified (p=%.2f)", probability);
		[self stopCamera];
		float conf = ui_confidence(probability);
		if (conf < 65.0f) conf = 65.0f;
		scanner->emit_toothbrush_detected(conf, String("toothbrush"));
		scanner->emit_toothbrush_verified(conf);
		return;
	}

	CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
	if (now - _lastDetectedEmit >= kDetectedSignalInterval) {
		_lastDetectedEmit = now;
		scanner->emit_toothbrush_detected(ui_confidence(probability), String(probability > 0.15f ? "toothbrush" : "searching"));
	}
}

// Reads one value of an output tensor as float (handles float32 and uint8).
static float pearly_read(const TfLiteTensor *t, size_t index) {
	if (TfLiteTensorType(t) == kTfLiteFloat32) {
		return ((const float *)TfLiteTensorData(t))[index];
	}
	if (TfLiteTensorType(t) == kTfLiteUInt8) {
		TfLiteQuantizationParams q = TfLiteTensorQuantizationParams(t);
		return ((float)((const uint8_t *)TfLiteTensorData(t))[index] - (float)q.zero_point) * q.scale;
	}
	return 0.0f;
}

// Raw model: max toothbrush score over all anchors, then sigmoid if the values are logits.
- (float)toothbrushProbabilityRaw {
	int outCount = TfLiteInterpreterGetOutputTensorCount(_interpreter);
	for (int i = 0; i < outCount; i++) {
		const TfLiteTensor *t = TfLiteInterpreterGetOutputTensor(_interpreter, i);
		if (TfLiteTensorNumDims(t) != 3 || TfLiteTensorDim(t, 2) != _numClasses) {
			continue;
		}
		const int anchors = TfLiteTensorDim(t, 1);
		float best = -INFINITY;
		float lowest = INFINITY;
		for (int a = 0; a < anchors; a++) {
			float v = pearly_read(t, (size_t)a * _numClasses + kToothbrushClassIndex);
			if (v > best) best = v;
			if (v < lowest) lowest = v;
		}
		// Logits contain negative values; probabilities never do.
		return (lowest < 0.0f || best > 1.0f) ? sigmoidf_(best) : best;
	}
	return 0.0f;
}

// Post-processed model: find the classes and scores tensors ([1, N]) and look for class 89.
- (float)toothbrushProbabilityPost {
	int outCount = TfLiteInterpreterGetOutputTensorCount(_interpreter);
	const TfLiteTensor *classes = NULL;
	const TfLiteTensor *scores = NULL;
	for (int i = 0; i < outCount; i++) {
		const TfLiteTensor *t = TfLiteInterpreterGetOutputTensor(_interpreter, i);
		if (TfLiteTensorNumDims(t) != 2 || TfLiteTensorDim(t, 1) < 2) {
			continue;
		}
		// The classes tensor holds whole numbers above 1; scores are between 0 and 1.
		bool wholeNumbers = true;
		bool aboveOne = false;
		const int n = TfLiteTensorDim(t, 1);
		for (int k = 0; k < n; k++) {
			float v = pearly_read(t, k);
			if (fabsf(v - roundf(v)) > 1e-3f) wholeNumbers = false;
			if (v > 1.0f) aboveOne = true;
		}
		if (wholeNumbers && aboveOne && !classes) {
			classes = t;
		} else if (!scores) {
			scores = t;
		}
	}
	if (!classes || !scores) {
		return 0.0f;
	}
	const int n = TfLiteTensorDim(scores, 1);
	float best = 0.0f;
	for (int k = 0; k < n; k++) {
		if ((int)lroundf(pearly_read(classes, k)) == kToothbrushClassIndex) {
			float s = pearly_read(scores, k);
			if (s > best) best = s;
		}
	}
	return best;
}

- (void)cleanupTFLite {
	if (_interpreter) {
		TfLiteInterpreterDelete(_interpreter);
		_interpreter = NULL;
	}
	if (_model) {
		TfLiteModelDelete(_model);
		_model = NULL;
	}
}

- (void)shutdown {
	[self stopCamera];
	dispatch_sync(_inferenceQueue, ^{
		[self cleanupTFLite];
	});
}

@end

// ============================================================================
// Godot singleton

PearlyToothbrushScanner *PearlyToothbrushScanner::instance = nullptr;

PearlyToothbrushScanner *PearlyToothbrushScanner::get_singleton() {
	return instance;
}

PearlyToothbrushScanner::PearlyToothbrushScanner() {
	instance = this;
	is_scanning = false;
	camera_delegate = [[PearlyCameraDelegate alloc] init];
}

PearlyToothbrushScanner::~PearlyToothbrushScanner() {
	if (instance == this) {
		instance = nullptr;
	}
	if (camera_delegate) {
		[(PearlyCameraDelegate *)camera_delegate shutdown];
		camera_delegate = nil;
	}
}

void PearlyToothbrushScanner::_bind_methods() {
	ClassDB::bind_method(D_METHOD("startScanner"), &PearlyToothbrushScanner::startScanner);
	ClassDB::bind_method(D_METHOD("stopScanner"), &PearlyToothbrushScanner::stopScanner);
	ClassDB::bind_method(D_METHOD("isScannerRunning"), &PearlyToothbrushScanner::isScannerRunning);
	ClassDB::bind_method(D_METHOD("hasCameraPermission"), &PearlyToothbrushScanner::hasCameraPermission);
	ClassDB::bind_method(D_METHOD("requestCameraPermission"), &PearlyToothbrushScanner::requestCameraPermission);
	ClassDB::bind_method(D_METHOD("_deliver_preview", "rgba", "width", "height"), &PearlyToothbrushScanner::_deliver_preview);

	ADD_SIGNAL(MethodInfo("toothbrush_verified", PropertyInfo(Variant::FLOAT, "confidence")));
	ADD_SIGNAL(MethodInfo("toothbrush_detected", PropertyInfo(Variant::FLOAT, "confidence"), PropertyInfo(Variant::STRING, "label")));
	ADD_SIGNAL(MethodInfo("scanner_error", PropertyInfo(Variant::STRING, "error_message")));
	ADD_SIGNAL(MethodInfo("permission_result", PropertyInfo(Variant::BOOL, "granted")));
	ADD_SIGNAL(MethodInfo("preview_frame", PropertyInfo(Variant::PACKED_BYTE_ARRAY, "rgba"), PropertyInfo(Variant::INT, "width"), PropertyInfo(Variant::INT, "height")));
}

bool PearlyToothbrushScanner::hasCameraPermission() {
	return [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo] == AVAuthorizationStatusAuthorized;
}

void PearlyToothbrushScanner::requestCameraPermission() {
	AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
	if (status == AVAuthorizationStatusAuthorized) {
		emit_permission_result(true);
		return;
	}
	if (status == AVAuthorizationStatusDenied || status == AVAuthorizationStatusRestricted) {
		emit_permission_result(false);
		emit_scanner_error("Camera access is turned off. A parent can turn it on in Settings.");
		return;
	}
	[AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
							 completionHandler:^(BOOL granted) {
								 dispatch_async(dispatch_get_main_queue(), ^{
									 PearlyToothbrushScanner *self_ = PearlyToothbrushScanner::get_singleton();
									 if (!self_) {
										 return;
									 }
									 self_->emit_permission_result(granted);
									 if (granted) {
										 if (self_->is_scanning) {
											 [(PearlyCameraDelegate *)self_->camera_delegate startCamera];
										 }
									 } else {
										 self_->emit_scanner_error("Camera access was not allowed.");
									 }
								 });
							 }];
}

void PearlyToothbrushScanner::startScanner() {
	is_scanning = true;
	if (!hasCameraPermission()) {
		requestCameraPermission();
		return;
	}
	[(PearlyCameraDelegate *)camera_delegate startCamera];
}

void PearlyToothbrushScanner::stopScanner() {
	is_scanning = false;
	[(PearlyCameraDelegate *)camera_delegate stopCamera];
}

bool PearlyToothbrushScanner::isScannerRunning() {
	return is_scanning;
}

// All emits are deferred to the main thread (they are called from camera / model threads).
void PearlyToothbrushScanner::emit_toothbrush_verified(float confidence) {
	call_deferred(SNAME("emit_signal"), SNAME("toothbrush_verified"), confidence);
}

void PearlyToothbrushScanner::emit_toothbrush_detected(float confidence, const String &label) {
	call_deferred(SNAME("emit_signal"), SNAME("toothbrush_detected"), confidence, label);
}

void PearlyToothbrushScanner::emit_scanner_error(const String &error_message) {
	call_deferred(SNAME("emit_signal"), SNAME("scanner_error"), error_message);
}

void PearlyToothbrushScanner::emit_permission_result(bool granted) {
	call_deferred(SNAME("emit_signal"), SNAME("permission_result"), granted);
}

void PearlyToothbrushScanner::emit_preview_frame(const PackedByteArray &rgba, int width, int height) {
	call_deferred(SNAME("_deliver_preview"), rgba, width, height);
}

void PearlyToothbrushScanner::_deliver_preview(const PackedByteArray &rgba, int width, int height) {
	if (camera_delegate) {
		[(PearlyCameraDelegate *)camera_delegate previewDelivered];
	}
	if (is_scanning) {
		emit_signal(SNAME("preview_frame"), rgba, width, height);
	}
}

// ============================================================================
// Engine entry points (names must match PearlyToothbrushScanner.gdip)

void pearly_toothbrush_scanner_init() {
	if (!PearlyToothbrushScanner::get_singleton()) {
		PearlyToothbrushScanner *scanner = memnew(PearlyToothbrushScanner);
		Engine::get_singleton()->add_singleton(Engine::Singleton("PearlyToothbrushScanner", scanner));
	}
}

void pearly_toothbrush_scanner_deinit() {
	if (PearlyToothbrushScanner::get_singleton()) {
		memdelete(PearlyToothbrushScanner::get_singleton());
	}
}
