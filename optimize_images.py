#!/usr/bin/env python3
"""
Pearly Whites Challenge - image optimiser

Shrinks the PNG / JPG files under assets/ so the project and the app are smaller.

    python optimize_images.py              # optimise (originals are backed up first)
    python optimize_images.py --dry-run    # only report what would change
    python optimize_images.py --max-size 1536
    python optimize_images.py --max-size-models 2048   # keep 3D model textures at full size

What it does, per image:
  * scales it down if its longest side is bigger than --max-size (default 2048 px);
    3D model textures (assets/candy_crusade/models) use --max-size-models (default 1024),
  * PNG: removes an alpha channel that is fully opaque, then saves with max compression,
  * JPG: re-saves at quality --jpeg-quality (default 85; normal maps 92),
  * keeps the new file only if it is smaller than the original.

File names, formats and folders never change, so nothing in the game needs updating.
Nine-patch panels (whose borders are set in pixels) are never scaled, only recompressed.
Every file that is changed is first copied to a backup folder next to the project:
    "<project folder> - image originals"

Order matters for the 3D models: open the project in Summer Engine once first so it
finishes importing, close it, then run this script. (On a first import Godot pulls the
textures out of the .glb files again and would overwrite the optimised ones.)
Needs Python 3.8+ and Pillow:  python -m pip install pillow
"""

import argparse
import io
import os
import shutil
import sys
import time
from concurrent.futures import ProcessPoolExecutor

try:
    from PIL import Image
except ImportError:
    print("Pillow is not installed. Run this first:\n\n    python -m pip install pillow\n")
    sys.exit(1)

Image.MAX_IMAGE_PIXELS = None  # large textures are expected

PROJECT = os.path.dirname(os.path.abspath(__file__))
SCAN_DIRS = ["assets"]
EXTENSIONS = (".png", ".jpg", ".jpeg")
PROPS_DIR = os.path.join("assets", "candy_crusade", "models")
MIN_BYTES = 30 * 1024  # smaller files aren't worth touching

# Used as NinePatchRect textures with pixel margins in the scripts: never resize these.
NO_RESIZE = {
    "game_blue_window_tall.png",
    "itembackpanel.png",
    "transparent_panel.png",
    "itemwindow.png",
}


def human(n):
    for unit in ("B", "KB", "MB", "GB"):
        if abs(n) < 1024 or unit == "GB":
            return f"{n:.0f} {unit}" if unit == "B" else f"{n:.1f} {unit}"
        n /= 1024.0


def optimise_one(job):
    """Returns (relpath, old_size, new_size, note) - new bytes are written by the caller."""
    path, rel, max_size, jpeg_quality = job
    if "normal" in os.path.basename(rel).lower():
        jpeg_quality = max(jpeg_quality, 92)  # normal maps show JPEG artefacts as lighting bumps
    old_size = os.path.getsize(path)
    try:
        with Image.open(path) as im:
            im.load()
            fmt = (im.format or "").upper()
            original_mode = im.mode
            w, h = im.size
            notes = []

            # 1) scale down
            resized = False
            if max(w, h) > max_size and os.path.basename(rel).lower() not in NO_RESIZE:
                scale = max_size / float(max(w, h))
                new_w, new_h = max(1, round(w * scale)), max(1, round(h * scale))
                if im.mode == "P":
                    im = im.convert("RGBA")
                elif im.mode not in ("RGB", "RGBA", "L", "LA"):
                    im = im.convert("RGBA" if "A" in im.mode else "RGB")
                im = im.resize((new_w, new_h), Image.LANCZOS)
                resized = True
                notes.append(f"{w}x{h} -> {new_w}x{new_h}")

            out = io.BytesIO()
            if fmt == "PNG":
                # 2) drop alpha that is 100% opaque
                if im.mode == "RGBA" and im.getchannel("A").getextrema() == (255, 255):
                    im = im.convert("RGB")
                    if original_mode != "P":
                        notes.append("removed unused transparency")
                elif im.mode == "LA" and im.getchannel("A").getextrema() == (255, 255):
                    im = im.convert("L")
                if original_mode == "P" and im.mode != "P":
                    # was a 256-colour image before scaling: keep it 256-colour
                    im = im.quantize(256, method=Image.Quantize.FASTOCTREE if im.mode == "RGBA" else Image.Quantize.MEDIANCUT)
                im.save(out, "PNG", optimize=True)
            elif fmt in ("JPEG", "MPO"):
                if im.mode not in ("RGB", "L"):
                    im = im.convert("RGB")
                im.save(out, "JPEG", quality=jpeg_quality, optimize=True, progressive=False)
            else:
                return (rel, old_size, old_size, f"skipped ({fmt or 'unknown'} format)", None)

            data = out.getvalue()
            # require a real gain, so running the script twice doesn't re-compress JPEGs again
            if len(data) < old_size * 0.97:
                return (rel, old_size, len(data), ", ".join(notes) or "recompressed", data)
            return (rel, old_size, old_size, "already optimal", None)
    except Exception as e:  # corrupt / unsupported file: leave it alone
        return (rel, old_size, old_size, f"skipped ({e})", None)


def main():
    ap = argparse.ArgumentParser(description="Optimise game images under assets/.")
    ap.add_argument("--dry-run", action="store_true", help="report only, change nothing")
    ap.add_argument("--max-size", type=int, default=2048, help="longest side in pixels (default 2048)")
    ap.add_argument("--max-size-models", type=int, default=1024,
                    help="longest side for 3D model textures in assets/candy_crusade/models (default 1024)")
    ap.add_argument("--force", action="store_true", help="run even if the project has not been imported yet")
    ap.add_argument("--jpeg-quality", type=int, default=85, help="JPEG quality 1-95 (default 85)")
    args = ap.parse_args()

    imported = os.path.join(PROJECT, ".godot", "imported")
    if not args.force and not args.dry_run and (not os.path.isdir(imported) or len(os.listdir(imported)) < 50):
        print("The project hasn't been imported by the editor yet.\n"
              "Open it in Summer Engine, wait for the import to finish, close it, then run this again.\n"
              "(Otherwise the editor re-extracts the 3D model textures and overwrites the optimised ones.)\n"
              "Use --force to run anyway.")
        sys.exit(1)

    backup_root = os.path.join(os.path.dirname(PROJECT), os.path.basename(PROJECT) + " - image originals")

    jobs = []
    for d in SCAN_DIRS:
        for root, dirs, files in os.walk(os.path.join(PROJECT, d)):
            dirs[:] = [x for x in dirs if not x.startswith(".")]
            for f in files:
                if f.lower().endswith(EXTENSIONS):
                    p = os.path.join(root, f)
                    if os.path.getsize(p) >= MIN_BYTES:
                        rel = os.path.relpath(p, PROJECT)
                        limit = args.max_size_models if rel.startswith(PROPS_DIR + os.sep) else args.max_size
                        jobs.append((p, rel, limit, args.jpeg_quality))

    if not jobs:
        print("No images found under", ", ".join(SCAN_DIRS))
        return

    print(f"Checking {len(jobs)} images (max {args.max_size}px, 3D models {args.max_size_models}px, "
          f"JPEG quality {args.jpeg_quality})"
          + ("  [DRY RUN - nothing will be changed]" if args.dry_run else ""))
    start = time.time()
    total_old = total_new = changed = 0
    results = []
    with ProcessPoolExecutor() as pool:
        for rel, old, new, note, data in pool.map(optimise_one, jobs, chunksize=4):
            total_old += old
            if data is None:
                total_new += old
                if note.startswith("skipped"):
                    results.append((0, rel, note))
                continue
            total_new += new
            changed += 1
            results.append((old - new, rel, f"{human(old)} -> {human(new)}  ({note})"))
            if not args.dry_run:
                src = os.path.join(PROJECT, rel)
                bak = os.path.join(backup_root, rel)
                if not os.path.exists(bak):  # keep the very first original
                    os.makedirs(os.path.dirname(bak), exist_ok=True)
                    shutil.copy2(src, bak)
                tmp = src + ".tmp_opt"
                with open(tmp, "wb") as fh:
                    fh.write(data)
                os.replace(tmp, src)

    for saved, rel, line in sorted(results, reverse=True)[:25]:
        print(f"  {rel}: {line}")
    if len(results) > 25:
        print(f"  ... and {len(results) - 25} more")

    print()
    print(f"{'Would change' if args.dry_run else 'Changed'} {changed} of {len(jobs)} images "
          f"in {time.time() - start:.0f}s")
    print(f"Images: {human(total_old)} -> {human(total_new)}  (saves {human(total_old - total_new)})")
    if not args.dry_run and changed:
        print(f"Originals backed up to: {backup_root}")
        print("Open the project in Summer Engine to re-import, then check the screens look right.")


if __name__ == "__main__":
    main()
