package com.pearlywhites.toothbrushdetector

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Matrix
import android.util.Log
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.LifecycleOwner
import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.SignalInfo
import org.godotengine.godot.plugin.UsedByGodot
import org.tensorflow.lite.support.image.TensorImage
import org.tensorflow.lite.task.core.BaseOptions
import org.tensorflow.lite.task.vision.detector.ObjectDetector
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class ToothbrushDetectorPlugin(godot: Godot) : GodotPlugin(godot) {

    companion object {
        private const val TAG = "PearlyToothbrushScanner"
        private const val CAMERA_PERMISSION_REQUEST_CODE = 2001
        private const val MODEL_ASSET_NAME = "efficientdet_lite0.tflite"
        private const val VERIFICATION_SCORE_THRESHOLD = 0.65f // 65% confidence threshold
    }

    private var cameraExecutor: ExecutorService = Executors.newSingleThreadExecutor()
    private var cameraProvider: ProcessCameraProvider? = null
    private var objectDetector: ObjectDetector? = null
    private var isScanning = false
    private var lastEmittedTime = 0L

    override fun getPluginName(): String {
        return "PearlyToothbrushScanner"
    }

    override fun getPluginSignals(): Set<SignalInfo> {
        return setOf(
            SignalInfo("toothbrush_verified", java.lang.Float::class.java),
            SignalInfo("toothbrush_detected", java.lang.Float::class.java, String::class.java),
            SignalInfo("scanner_error", String::class.java),
            SignalInfo("permission_result", java.lang.Boolean::class.java)
        )
    }

    @UsedByGodot
    fun hasCameraPermission(): Boolean {
        val activity = activity ?: return false
        return ContextCompat.checkSelfPermission(
            activity,
            Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED
    }

    @UsedByGodot
    fun requestCameraPermission() {
        val activity = activity ?: return
        if (hasCameraPermission()) {
            emitSignal("permission_result", true)
            return
        }
        ActivityCompat.requestPermissions(
            activity,
            arrayOf(Manifest.permission.CAMERA),
            CAMERA_PERMISSION_REQUEST_CODE
        )
    }

    @UsedByGodot
    fun startScanner() {
        val activity = activity ?: run {
            emitSignal("scanner_error", "Activity is null")
            return
        }

        if (isScanning) {
            Log.d(TAG, "Scanner is already running.")
            return
        }

        if (!hasCameraPermission()) {
            Log.d(TAG, "Camera permission not granted. Requesting...")
            requestCameraPermission()
            return
        }

        activity.runOnUiThread {
            try {
                initObjectDetector()
                startCameraX()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to start scanner: ${e.message}", e)
                emitSignal("scanner_error", "Failed to start scanner: ${e.localizedMessage}")
            }
        }
    }

    @UsedByGodot
    fun stopScanner() {
        val activity = activity ?: return
        activity.runOnUiThread {
            try {
                isScanning = false
                cameraProvider?.unbindAll()
                objectDetector?.close()
                objectDetector = null
                Log.d(TAG, "CameraX scanner stopped.")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping scanner: ${e.message}", e)
            }
        }
    }

    @UsedByGodot
    fun isScannerRunning(): Boolean {
        return isScanning
    }

    private fun initObjectDetector() {
        val context = activity ?: return
        if (objectDetector != null) return

        try {
            val baseOptionsBuilder = BaseOptions.builder().setNumThreads(2)
            try {
                baseOptionsBuilder.useGpu()
            } catch (e: Exception) {
                Log.w(TAG, "GPU delegate unavailable, falling back to CPU: ${e.message}")
            }

            val options = ObjectDetector.ObjectDetectorOptions.builder()
                .setBaseOptions(baseOptionsBuilder.build())
                .setMaxResults(5)
                .setScoreThreshold(0.30f) // Minimum threshold to receive candidate detections
                .build()

            objectDetector = ObjectDetector.createFromFileAndOptions(context, MODEL_ASSET_NAME, options)
            Log.d(TAG, "TensorFlow Lite ObjectDetector initialized with $MODEL_ASSET_NAME")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to initialize ObjectDetector: ${e.message}", e)
            emitSignal("scanner_error", "Model load error: ${e.localizedMessage}")
        }
    }

    private fun startCameraX() {
        val activity = activity ?: return
        val lifecycleOwner = activity as? LifecycleOwner ?: run {
            emitSignal("scanner_error", "Activity does not implement LifecycleOwner")
            return
        }

        val cameraProviderFuture = ProcessCameraProvider.getInstance(activity)
        cameraProviderFuture.addListener({
            try {
                cameraProvider = cameraProviderFuture.get()

                // Rear-facing camera selector
                val cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA

                val imageAnalysis = ImageAnalysis.Builder()
                    .setOutputImageFormat(ImageAnalysis.OUTPUT_IMAGE_FORMAT_RGBA_8888)
                    .setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST)
                    .build()

                imageAnalysis.setAnalyzer(cameraExecutor) { imageProxy ->
                    processImageProxy(imageProxy)
                }

                cameraProvider?.unbindAll()
                cameraProvider?.bindToLifecycle(
                    lifecycleOwner,
                    cameraSelector,
                    imageAnalysis
                )

                isScanning = true
                Log.d(TAG, "CameraX rear camera bound and active.")
            } catch (e: Exception) {
                Log.e(TAG, "Camera binding failed: ${e.message}", e)
                emitSignal("scanner_error", "Camera binding failed: ${e.localizedMessage}")
            }
        }, ContextCompat.getMainExecutor(activity))
    }

    private fun processImageProxy(imageProxy: ImageProxy) {
        if (!isScanning) {
            imageProxy.close()
            return
        }

        val detector = objectDetector ?: run {
            imageProxy.close()
            return
        }

        try {
            val bitmap = imageProxy.toBitmap()
            val rotationDegrees = imageProxy.imageInfo.rotationDegrees

            val rotatedBitmap = if (rotationDegrees != 0) {
                val matrix = Matrix().apply { postRotate(rotationDegrees.toFloat()) }
                Bitmap.createBitmap(bitmap, 0, 0, bitmap.width, bitmap.height, matrix, true)
            } else {
                bitmap
            }

            val tensorImage = TensorImage.fromBitmap(rotatedBitmap)
            val results = detector.detect(tensorImage)

            var verified = false
            var bestScore = 0.0f
            var bestLabel = "none"

            for (detection in results) {
                for (category in detection.categories) {
                    val label = category.label.lowercase()
                    val score = category.score
                    val index = category.index

                    // Check COCO dataset Toothbrush Class (ID 90 or 80) or label name
                    val isToothbrush = (index == 90 || index == 80 || label.contains("toothbrush") || label.contains("brush"))

                    if (score > bestScore) {
                        bestScore = score
                        bestLabel = category.label
                    }

                    if (isToothbrush && score >= VERIFICATION_SCORE_THRESHOLD) {
                        verified = true
                        bestScore = score
                        bestLabel = "toothbrush"
                        break
                    }
                }
                if (verified) break
            }

            val now = System.currentTimeMillis()
            if (verified) {
                isScanning = false
                activity?.runOnUiThread {
                    Log.d(TAG, "Toothbrush VERIFIED! Score: $bestScore")
                    emitSignal("toothbrush_verified", bestScore * 100.0f)
                    stopScanner()
                }
            } else if (now - lastEmittedTime > 200) { // Throttle live feedback signal to ~5fps
                lastEmittedTime = now
                activity?.runOnUiThread {
                    emitSignal("toothbrush_detected", bestScore * 100.0f, bestLabel)
                }
            }

        } catch (e: Exception) {
            Log.e(TAG, "Error analyzing image frame: ${e.message}", e)
        } finally {
            imageProxy.close()
        }
    }

    override fun onMainRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onMainRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == CAMERA_PERMISSION_REQUEST_CODE) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            emitSignal("permission_result", granted)
            if (granted) {
                startScanner()
            } else {
                emitSignal("scanner_error", "Camera permission was denied.")
            }
        }
    }

    override fun onMainDestroy() {
        super.onMainDestroy()
        stopScanner()
        cameraExecutor.shutdown()
    }
}
