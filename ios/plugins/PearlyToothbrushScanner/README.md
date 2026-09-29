# PearlyToothbrushScanner – iOS plugin

Rear camera + TensorFlow Lite check that a toothbrush is in view before brushing.
Same Godot API as the Android plugin (`Engine.get_singleton("PearlyToothbrushScanner")`),
plus a `preview_frame` signal that feeds the live camera image to `brush_check_screen.gd`.

## Build (on a Mac with Xcode)

```bash
bash ios/plugins/PearlyToothbrushScanner/build_ios_plugin.sh 4.7-stable
```

Use the Godot version your editor is built on (Help > About). The script:

1. downloads the matching Godot source (for headers and exact compiler flags),
2. downloads TensorFlowLiteC 2.14.0,
3. compiles `PearlyToothbrushScanner.debug.a` / `.release.a` into `ios/plugins/`,
4. copies `TensorFlowLiteC.xcframework` into `ios/plugins/`.

Everything temporary goes in `~/pearly_ios_build`, outside the project.

## Files

| File | Purpose |
|---|---|
| `../PearlyToothbrushScanner.gdip` | Plugin config read by the iOS exporter |
| `PearlyToothbrushScanner.h/.mm` | Plugin source |
| `build_ios_plugin.sh` | One-command build |
| `res://models/efficientdet_lite0.tflite` | COCO model, copied into the app bundle via the gdip `files` entry |

## Model notes

`efficientdet_lite0.tflite` is the raw (no NMS) float model: input `[1,320,320,3]` float32
normalised to −1…1, output `[1,19206,90]` class logits. Toothbrush is class index **89**.
The plugin takes the highest toothbrush score across all anchors, applies a sigmoid and
verifies after 2 frames in a row at ≥ 0.40. Tune `kVerifyThreshold` /
`kRequiredConsecutiveHits` at the top of the `.mm` file.
