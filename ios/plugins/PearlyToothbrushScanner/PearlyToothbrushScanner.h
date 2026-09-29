#ifndef PEARLY_TOOTHBRUSH_SCANNER_H
#define PEARLY_TOOTHBRUSH_SCANNER_H

#include "core/object/class_db.h"
#include "core/config/engine.h"

#ifdef __OBJC__
@class PearlyCameraDelegate;
#else
typedef void PearlyCameraDelegate;
#endif

// Godot singleton "PearlyToothbrushScanner" (same API as the Android plugin).
//
// Methods:  startScanner(), stopScanner(), isScannerRunning(),
//           hasCameraPermission(), requestCameraPermission()
// Signals:  toothbrush_verified(confidence: float)            0-100
//           toothbrush_detected(confidence: float, label: String)  0-100, ~5x per second
//           scanner_error(error_message: String)
//           permission_result(granted: bool)
//           preview_frame(rgba: PackedByteArray, width: int, height: int)   live camera image
class PearlyToothbrushScanner : public Object {
	GDCLASS(PearlyToothbrushScanner, Object);

	static PearlyToothbrushScanner *instance;

	PearlyCameraDelegate *camera_delegate = nullptr;
	bool is_scanning = false;

protected:
	static void _bind_methods();

public:
	static PearlyToothbrushScanner *get_singleton();

	void startScanner();
	void stopScanner();
	bool isScannerRunning();
	bool hasCameraPermission();
	void requestCameraPermission();

	// Thread-safe: may be called from any thread, the signal is emitted on the main thread.
	void emit_toothbrush_verified(float confidence);
	void emit_toothbrush_detected(float confidence, const String &label);
	void emit_scanner_error(const String &error_message);
	void emit_permission_result(bool granted);
	void emit_preview_frame(const PackedByteArray &rgba, int width, int height);
	void _deliver_preview(const PackedByteArray &rgba, int width, int height);

	PearlyToothbrushScanner();
	~PearlyToothbrushScanner();
};

void pearly_toothbrush_scanner_init();
void pearly_toothbrush_scanner_deinit();

#endif // PEARLY_TOOTHBRUSH_SCANNER_H
