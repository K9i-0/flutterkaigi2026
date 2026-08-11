#!/usr/bin/env python3
"""Validate a PNG movie poster and optionally render centered SNS previews."""

from __future__ import annotations

import argparse
import shutil
import struct
import subprocess
import sys
from pathlib import Path


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
TARGET_SIZE = (1024, 1536)
TARGET_RATIO = 2 / 3
RATIO_TOLERANCE = 0.002
COLOR_MODES = {2: "RGB", 6: "RGBA"}


def read_png_header(path: Path) -> tuple[int, int, int, str]:
    with path.open("rb") as stream:
        signature = stream.read(8)
        length_bytes = stream.read(4)
        chunk_type = stream.read(4)
        if signature != PNG_SIGNATURE or len(length_bytes) != 4 or chunk_type != b"IHDR":
            raise ValueError("not a valid PNG with an IHDR header")
        length = struct.unpack(">I", length_bytes)[0]
        if length != 13:
            raise ValueError(f"unexpected IHDR length: {length}")
        data = stream.read(13)
        if len(data) != 13:
            raise ValueError("truncated IHDR header")
    width, height, bit_depth, color_type, _, _, _ = struct.unpack(">IIBBBBB", data)
    return width, height, bit_depth, COLOR_MODES.get(color_type, f"PNG color type {color_type}")


def run_ffmpeg(source: Path, output: Path, filter_graph: str) -> None:
    command = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-y",
        "-i", str(source), "-vf", filter_graph, "-frames:v", "1", str(output),
    ]
    subprocess.run(command, check=True)


def render_previews(source: Path, output_dir: Path) -> list[Path]:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError("ffmpeg is required only when --preview-dir is used")
    output_dir.mkdir(parents=True, exist_ok=True)
    stem = source.stem
    jobs = [
        (
            output_dir / f"{stem}__safe-guides.png",
            "drawbox=x=2:y=(ih-iw*5/4)/2+2:w=iw-4:h=iw*5/4-4:color=0x00FF88:t=6,"
            "drawbox=x=2:y=(ih-iw)/2+2:w=iw-4:h=iw-4:color=0xFFD400:t=4",
        ),
        (output_dir / f"{stem}__crop-4x5.png", "crop=iw:iw*5/4:0:(ih-iw*5/4)/2"),
        (output_dir / f"{stem}__crop-1x1.png", "crop=iw:iw:0:(ih-iw)/2"),
    ]
    for output, filter_graph in jobs:
        run_ffmpeg(source, output, filter_graph)
    return [output for output, _ in jobs]


def audit(path: Path, preview_dir: Path | None) -> bool:
    errors: list[str] = []
    warnings: list[str] = []
    try:
        width, height, bit_depth, mode = read_png_header(path)
    except Exception as exc:
        print(f"FAIL {path}: {exc}")
        return False

    ratio = width / height
    if abs(ratio - TARGET_RATIO) > RATIO_TOLERANCE:
        errors.append(f"aspect ratio is {width}:{height} ({ratio:.5f}), expected 2:3")
    if (width, height) != TARGET_SIZE:
        warnings.append(f"size is {width}x{height}; production master should be 1024x1536")
    if mode not in {"RGB", "RGBA"}:
        warnings.append(f"color mode is {mode}, expected RGB or RGBA")
    if bit_depth != 8:
        warnings.append(f"bit depth is {bit_depth}, expected 8")

    status = "PASS" if not errors else "FAIL"
    print(f"{status} {path}: {width}x{height}, mode={mode}, bit_depth={bit_depth}, format=PNG")
    for message in errors:
        print(f"  ERROR: {message}")
    for message in warnings:
        print(f"  WARNING: {message}")

    if preview_dir is not None:
        try:
            for preview in render_previews(path, preview_dir):
                print(f"  PREVIEW: {preview}")
        except Exception as exc:
            print(f"  ERROR: could not render previews: {exc}")
            return False
    return not errors


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("images", nargs="+", type=Path)
    parser.add_argument("--preview-dir", type=Path)
    args = parser.parse_args()

    passed = True
    for path in args.images:
        if not path.is_file():
            print(f"FAIL {path}: file not found")
            passed = False
            continue
        passed = audit(path, args.preview_dir) and passed
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
