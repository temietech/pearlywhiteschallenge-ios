#!/bin/bash
# ---------------------------------------------------------------------------
# Builds the PearlyToothbrushScanner iOS plugin for Godot.
#
# Run on a Mac with Xcode installed, from anywhere:
#     bash build_ios_plugin.sh 4.7-stable
#
# The argument is the Godot version your editor is based on (Summer Engine:
# Help > About). Default: 4.7-stable.
#
# Output (written next to PearlyToothbrushScanner.gdip in ios/plugins/):
#     PearlyToothbrushScanner.debug.a
#     PearlyToothbrushScanner.release.a
#     TensorFlowLiteC.xcframework
# ---------------------------------------------------------------------------
set -euo pipefail

GODOT_TAG="${1:-4.7-stable}"
TFLITE_VERSION="2.14.0"
TFLITE_URL="https://dl.google.com/tflite-release/ios/prod/tensorflow/lite/release/ios/release/30/20231002-210715/TensorFlowLiteC/2.14.0/883c6fc838e0354b/TensorFlowLiteC-2.14.0.tar.gz"
MIN_IOS="14.0"

SRC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"   # ios/plugins/PearlyToothbrushScanner
PLUGINS_DIR="$(dirname "$SRC_DIR")"                        # ios/plugins
WORK="$HOME/pearly_ios_build"                               # kept outside the Godot project
GODOT_DIR="$WORK/godot-$GODOT_TAG"
JOBS="$(sysctl -n hw.ncpu 2>/dev/null || echo 4)"

step() { printf "\n\033[1;34m==> %s\033[0m\n" "$*"; }
fail() { printf "\n\033[1;31mERROR: %s\033[0m\n" "$*"; exit 1; }

# ---------------------------------------------------------------------------
step "Checking tools"
command -v xcrun >/dev/null || fail "Xcode is not installed. Install Xcode from the App Store, open it once, then run: sudo xcode-select -s /Applications/Xcode.app"
xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1 || fail "The iOS SDK was not found. Open Xcode once and accept the licence, then try again."
command -v git >/dev/null || fail "git is missing (it comes with Xcode command line tools: xcode-select --install)"
command -v python3 >/dev/null || fail "python3 is missing (it comes with Xcode command line tools: xcode-select --install)"
if ! python3 -m SCons --version >/dev/null 2>&1; then
	echo "Installing SCons (Godot's build tool)..."
	python3 -m pip install --user scons || python3 -m pip install --user --break-system-packages scons
fi
SCONS=(python3 -m SCons)
SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
mkdir -p "$WORK"

# ---------------------------------------------------------------------------
step "Getting Godot $GODOT_TAG source (headers only are used)"
if [ ! -d "$GODOT_DIR/.git" ]; then
	git clone --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git "$GODOT_DIR" \
		|| fail "Could not download Godot '$GODOT_TAG'. Check the version name (for example 4.7-stable or 4.7.1-stable)."
fi

# Starts a Godot iOS build just long enough to (1) generate the *.gen.h headers
# and (2) record the exact compiler flags Godot uses for this target, then stops it.
capture_flags() {
	local target="$1" extra_wait="$2"
	local log="$WORK/scons_${target}.log"
	echo "Preparing Godot headers for $target (this takes a minute or two)..."
	( cd "$GODOT_DIR" && "${SCONS[@]}" platform=ios arch=arm64 target="$target" verbose=yes -j"$JOBS" >"$log" 2>&1 ) &
	local pid=$! waited=0
	# wait for the first compile of an engine core file
	until grep -qE -- ' -c .*core/[^ ]+\.cpp' "$log" 2>/dev/null; do
		sleep 2; waited=$((waited + 2))
		if ! kill -0 "$pid" 2>/dev/null; then tail -n 30 "$log"; fail "Godot's build stopped early (see messages above)."; fi
		[ "$waited" -gt 900 ] && { kill -INT "$pid" 2>/dev/null || true; fail "Timed out preparing Godot headers."; }
	done
	sleep "$extra_wait"
	pkill -INT -P "$pid" 2>/dev/null || true
	kill -INT "$pid" 2>/dev/null || true
	wait "$pid" 2>/dev/null || true
	python3 - "$log" "$GODOT_DIR" >"$WORK/flags_${target}.txt" <<'PY'
import re, shlex, sys, os
log, root = sys.argv[1], sys.argv[2]
line = next(l for l in open(log, errors="replace") if re.search(r" -c .*core/\S+\.cpp", l))
keep = []
toks = shlex.split(line)
i = 0
while i < len(toks):
    t = toks[i]
    if t == "-D" and i + 1 < len(toks):
        keep.append("-D" + toks[i + 1]); i += 1
    elif t.startswith("-D") or t.startswith("-std="):
        keep.append(t)
    elif t.startswith("-I") and len(t) > 2:
        p = t[2:]
        keep.append("-I" + (p if os.path.isabs(p) else os.path.join(root, p)))
    elif t == "-I" and i + 1 < len(toks):
        p = toks[i + 1]; i += 1
        keep.append("-I" + (p if os.path.isabs(p) else os.path.join(root, p)))
    i += 1
print("\n".join(keep))
PY
	echo "Captured $(wc -l <"$WORK/flags_${target}.txt" | tr -d ' ') compiler flags for $target."
}

# ---------------------------------------------------------------------------
step "Getting TensorFlow Lite $TFLITE_VERSION for iOS"
TFL_DIR="$WORK/tflite-$TFLITE_VERSION"
if [ ! -d "$TFL_DIR/Frameworks/TensorFlowLiteC.xcframework" ]; then
	mkdir -p "$TFL_DIR"
	curl -fL "$TFLITE_URL" -o "$TFL_DIR/tflite.tar.gz" || fail "Could not download TensorFlow Lite."
	tar -xzf "$TFL_DIR/tflite.tar.gz" -C "$TFL_DIR"
fi
XCF="$(find "$TFL_DIR" -type d -name 'TensorFlowLiteC.xcframework' | head -n 1)"
[ -n "$XCF" ] || fail "TensorFlowLiteC.xcframework not found in the download."
SLICE="$(find "$XCF" -maxdepth 1 -type d -name 'ios-arm64' | head -n 1)"
[ -n "$SLICE" ] || SLICE="$(find "$XCF" -maxdepth 1 -type d -name 'ios-arm64*' ! -name '*simulator*' | head -n 1)"
[ -n "$SLICE" ] || fail "No iPhone (arm64) slice inside TensorFlowLiteC.xcframework."

# ---------------------------------------------------------------------------
build_target() {
	local target="$1" suffix="$2"
	local obj="$WORK/PearlyToothbrushScanner.$suffix.o"
	local out="$PLUGINS_DIR/PearlyToothbrushScanner.$suffix.a"
	local attempt
	for attempt in 1 2 3; do
		if [ ! -s "$WORK/flags_${target}.txt" ] || [ "$attempt" -gt 1 ]; then
			capture_flags "$target" $((20 * attempt))
		fi
		FLAGS=()
		while IFS= read -r f; do [ -n "$f" ] && FLAGS+=("$f"); done <"$WORK/flags_${target}.txt"
		echo "Compiling plugin ($suffix)..."
		if xcrun --sdk iphoneos clang++ -x objective-c++ -c "$SRC_DIR/PearlyToothbrushScanner.mm" -o "$obj" \
			-arch arm64 -isysroot "$SDK" -miphoneos-version-min="$MIN_IOS" \
			-fobjc-arc -fno-exceptions -fvisibility=hidden -O2 \
			"${FLAGS[@]}" -I"$SRC_DIR" -I"$GODOT_DIR" -F"$SLICE" \
			2>"$WORK/compile_$suffix.log"; then
			break
		fi
		if grep -q "gen\.h\|gen\.inc" "$WORK/compile_$suffix.log" && [ "$attempt" -lt 3 ]; then
			echo "Some generated Godot headers were not ready yet, trying again..."
			continue
		fi
		cat "$WORK/compile_$suffix.log"
		fail "The plugin did not compile ($suffix). Send the messages above to Claude."
	done
	rm -f "$out"
	xcrun libtool -static -o "$out" "$obj"
	echo "Created $(basename "$out")"
}

step "Building the plugin"
build_target template_release release
build_target template_debug debug

step "Installing TensorFlow Lite next to the plugin"
rm -rf "$PLUGINS_DIR/TensorFlowLiteC.xcframework"
cp -R "$XCF" "$PLUGINS_DIR/TensorFlowLiteC.xcframework"

step "Done"
echo "ios/plugins now contains:"
ls -1 "$PLUGINS_DIR"
echo
echo "Next: open the project in the editor on this Mac, Project > Export > iOS,"
echo "check that 'Pearly Toothbrush Scanner' is ticked under Plugins, then export."
