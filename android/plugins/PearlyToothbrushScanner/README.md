# PearlyToothbrushScanner - Godot 4 Android Plugin

This plugin runs native Android CameraX and TensorFlow Lite object detection entirely offline on mobile hardware.

## Folder Structure

- `build.gradle`: Android library gradle setup including CameraX, TensorFlow Lite Task Vision, and Godot dependencies.
- `src/main/AndroidManifest.xml`: Declares Camera permissions and features.
- `src/main/java/com/pearlywhites/toothbrushdetector/ToothbrushDetectorPlugin.kt`: GodotPlugin native Android bridge.
- `src/main/assets/efficientdet_lite0.tflite`: The TFLite model file placed in the Android assets.

## Building the .aar

Run in terminal from the plugin folder or root:
```bash
./gradlew :PearlyToothbrushScanner:assembleRelease
```
Copy `build/outputs/aar/PearlyToothbrushScanner-release.aar` into `res://android/plugins/`.

## Signals Emitted to GDScript

1. `toothbrush_verified(confidence: float)`: Emitted when a toothbrush is detected with score > 0.65.
2. `toothbrush_detected(confidence: float, label: string)`: Emitted periodically with live detection stats.
3. `scanner_error(message: string)`: Emitted if camera or model fails.
4. `permission_result(granted: bool)`: Emitted with camera permission status.

## Methods Callable from GDScript

- `startScanner()`
- `stopScanner()`
- `isScannerRunning() -> bool`
- `hasCameraPermission() -> bool`
- `requestCameraPermission()`
