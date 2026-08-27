#!/usr/bin/env python3
"""Create an episode-local Remotion post-production project from the skill template."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import sys


VERSION_RE = re.compile(r"^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("episode_dir", type=Path)
    parser.add_argument("--input-video", required=True, type=Path)
    parser.add_argument("--remotion-version", required=True)
    parser.add_argument("--width", required=True, type=int)
    parser.add_argument("--height", required=True, type=int)
    parser.add_argument("--fps", required=True, type=int)
    parser.add_argument("--duration-seconds", required=True, type=float)
    parser.add_argument("--composition-id", default="MadogiwaEdit")
    return parser.parse_args()


def fail(message: str) -> int:
    print(f"Error: {message}", file=sys.stderr)
    return 2


def main() -> int:
    args = parse_args()
    episode_dir = args.episode_dir.resolve()
    source_video = args.input_video.resolve()
    if not episode_dir.is_dir():
        return fail(f"Episode directory not found: {episode_dir}")
    if not source_video.is_file():
        return fail(f"Input video not found: {source_video}")
    if not VERSION_RE.fullmatch(args.remotion_version):
        return fail("--remotion-version must be an exact semver such as 4.0.518")
    if args.width <= 0 or args.height <= 0 or args.fps <= 0:
        return fail("width, height, and fps must be positive integers")
    if args.duration_seconds <= 0:
        return fail("duration must be positive")
    if not re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", args.composition_id):
        return fail("composition ID must start with a letter and use letters, digits, _ or -")

    destination = episode_dir / "remotion"
    if destination.exists():
        return fail(f"Refusing to overwrite existing project: {destination}")

    template = Path(__file__).resolve().parent.parent / "assets" / "project-template"
    if not template.is_dir():
        return fail(f"Template directory not found: {template}")

    shutil.copytree(template, destination)
    package_path = destination / "package.json"
    package_text = package_path.read_text(encoding="utf-8")
    package_text = package_text.replace("__REMOTION_VERSION__", args.remotion_version)
    package_text = package_text.replace("__COMPOSITION_ID__", args.composition_id)
    package_path.write_text(package_text, encoding="utf-8")

    manifest_path = destination / "src" / "edit-manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    manifest["composition"] = {
        "id": args.composition_id,
        "width": args.width,
        "height": args.height,
        "fps": args.fps,
        "durationInFrames": round(args.duration_seconds * args.fps),
    }
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )

    public_dir = destination / "public"
    public_dir.mkdir(parents=True, exist_ok=True)
    input_asset = public_dir / "input.mp4"
    try:
        input_asset.hardlink_to(source_video)
        asset_mode = "hardlink"
    except OSError:
        shutil.copy2(source_video, input_asset)
        asset_mode = "copy"

    print(f"Created: {destination}")
    print(f"Input asset: {input_asset} ({asset_mode} of {source_video})")
    print(f"Composition: {args.composition_id}; {args.width}x{args.height}; {args.fps} fps")
    print(f"Duration: {manifest['composition']['durationInFrames']} frames")
    print("Next: edit src/edit-manifest.json, run npm install, then npm run typecheck")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
