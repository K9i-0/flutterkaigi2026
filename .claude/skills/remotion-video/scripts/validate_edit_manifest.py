#!/usr/bin/env python3
"""Validate the reusable Remotion edit manifest before preview or render."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys
from typing import Any


OVERLAY_TYPES = {"station-bug", "news-lower-third", "ticker"}
STATION_POSITIONS = {"top-left", "top-right"}
STATION_VARIANTS = {"plain", "brand", "clock"}
LOWER_THIRD_PLACEMENTS = {"top-left", "bottom-left", "bottom"}
LOWER_THIRD_VARIANTS = {"compact", "full"}
COLOR_RE = re.compile(r"^#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?$")
CLOCK_RE = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--public-dir", type=Path)
    return parser.parse_args()


def require_int(value: Any, name: str, minimum: int = 0) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value < minimum:
        raise ValueError(f"{name} must be an integer >= {minimum}")
    return value


def require_text(value: Any, name: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{name} must be non-empty text")
    return value


def validate_range(item: dict[str, Any], name: str, duration: int) -> tuple[int, int]:
    start = require_int(item.get("startFrame"), f"{name}.startFrame")
    end = require_int(item.get("endFrame"), f"{name}.endFrame")
    if not start < end <= duration:
        raise ValueError(f"{name} must satisfy 0 <= startFrame < endFrame <= {duration}")
    return start, end


def validate_asset(public_dir: Path | None, value: str, name: str) -> None:
    if public_dir is None:
        return
    asset = (public_dir / value).resolve()
    if not asset.is_file():
        raise ValueError(f"{name} not found under public dir: {asset}")


def validate(manifest: dict[str, Any], public_dir: Path | None) -> list[str]:
    warnings: list[str] = []
    composition = manifest.get("composition")
    if not isinstance(composition, dict):
        raise ValueError("composition must be an object")
    require_text(composition.get("id"), "composition.id")
    require_int(composition.get("width"), "composition.width", 1)
    require_int(composition.get("height"), "composition.height", 1)
    require_int(composition.get("fps"), "composition.fps", 1)
    duration = require_int(
        composition.get("durationInFrames"), "composition.durationInFrames", 1
    )

    input_video = require_text(manifest.get("inputVideo"), "inputVideo")
    validate_asset(public_dir, input_video, "inputVideo")
    volume = manifest.get("inputVideoVolume", 1)
    if not isinstance(volume, (int, float)) or isinstance(volume, bool) or not 0 <= volume <= 1:
        raise ValueError("inputVideoVolume must be a number from 0 to 1")
    replacement_audio = manifest.get("replacementAudio")
    if replacement_audio is not None:
        replacement_audio = require_text(replacement_audio, "replacementAudio")
        validate_asset(public_dir, replacement_audio, "replacementAudio")
        if volume != 0:
            warnings.append(
                "replacementAudio is set; input video will be muted by the template "
                "regardless of inputVideoVolume"
            )

    overlays = manifest.get("overlays", [])
    if not isinstance(overlays, list):
        raise ValueError("overlays must be an array")
    for index, overlay in enumerate(overlays):
        name = f"overlays[{index}]"
        if not isinstance(overlay, dict):
            raise ValueError(f"{name} must be an object")
        kind = overlay.get("type")
        if kind not in OVERLAY_TYPES:
            raise ValueError(f"{name}.type must be one of: {', '.join(sorted(OVERLAY_TYPES))}")
        validate_range(overlay, name, duration)
        accent = overlay.get("accentColor")
        if accent is not None and (not isinstance(accent, str) or not COLOR_RE.fullmatch(accent)):
            raise ValueError(f"{name}.accentColor must be #RRGGBB or #RRGGBBAA")
        if kind == "station-bug":
            text = overlay.get("text")
            image = overlay.get("image")
            if not (isinstance(text, str) and text.strip()) and not (
                isinstance(image, str) and image.strip()
            ):
                raise ValueError(f"{name} requires text or image")
            if isinstance(image, str) and image.strip():
                validate_asset(public_dir, image, f"{name}.image")
            position = overlay.get("position")
            if position is not None and position not in STATION_POSITIONS:
                raise ValueError(
                    f"{name}.position must be one of: "
                    f"{', '.join(sorted(STATION_POSITIONS))}"
                )
            variant = overlay.get("variant")
            if variant is not None and variant not in STATION_VARIANTS:
                raise ValueError(
                    f"{name}.variant must be one of: "
                    f"{', '.join(sorted(STATION_VARIANTS))}"
                )
            if variant == "clock" and (
                not isinstance(text, str) or not CLOCK_RE.fullmatch(text)
            ):
                raise ValueError(f"{name}.text must be a fixed HH:MM time for clock variant")
        elif kind == "news-lower-third":
            require_text(overlay.get("kicker"), f"{name}.kicker")
            headline = require_text(overlay.get("headline"), f"{name}.headline")
            if headline.count("\n") > 1:
                raise ValueError(f"{name}.headline must be at most two lines")
            placement = overlay.get("placement")
            if placement is not None and placement not in LOWER_THIRD_PLACEMENTS:
                raise ValueError(
                    f"{name}.placement must be one of: "
                    f"{', '.join(sorted(LOWER_THIRD_PLACEMENTS))}"
                )
            variant = overlay.get("variant")
            if variant is not None and variant not in LOWER_THIRD_VARIANTS:
                raise ValueError(
                    f"{name}.variant must be one of: "
                    f"{', '.join(sorted(LOWER_THIRD_VARIANTS))}"
                )
            width = overlay.get("widthPercent")
            if width is not None and (
                not isinstance(width, (int, float))
                or isinstance(width, bool)
                or not 28 <= width <= 90
            ):
                raise ValueError(f"{name}.widthPercent must be a number from 28 to 90")
        elif kind == "ticker":
            require_text(overlay.get("label"), f"{name}.label")
            require_text(overlay.get("text"), f"{name}.text")

    captions = manifest.get("captions", [])
    if not isinstance(captions, list):
        raise ValueError("captions must be an array")
    previous_end = 0
    for index, caption in enumerate(captions):
        name = f"captions[{index}]"
        if not isinstance(caption, dict):
            raise ValueError(f"{name} must be an object")
        start, end = validate_range(caption, name, duration)
        text = require_text(caption.get("text"), f"{name}.text")
        if text.count("\n") > 1:
            raise ValueError(f"{name}.text must be at most two lines")
        if start < previous_end:
            raise ValueError(f"{name} overlaps the previous caption")
        previous_end = end
        if len(max(text.splitlines(), key=len)) > 42:
            warnings.append(f"{name} has a line over 42 characters; inspect fit manually")
    return warnings


def main() -> int:
    args = parse_args()
    try:
        manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
        if not isinstance(manifest, dict):
            raise ValueError("manifest root must be an object")
        public_dir = args.public_dir.resolve() if args.public_dir else None
        warnings = validate(manifest, public_dir)
    except (OSError, json.JSONDecodeError, ValueError) as exc:
        print(f"Validation error: {exc}", file=sys.stderr)
        return 2
    for warning in warnings:
        print(f"Warning: {warning}")
    composition = manifest["composition"]
    print(
        "Valid manifest: "
        f"{composition['id']}; {composition['width']}x{composition['height']}; "
        f"{composition['fps']} fps; {composition['durationInFrames']} frames; "
        f"{len(manifest.get('overlays', []))} overlay(s); "
        f"{len(manifest.get('captions', []))} caption(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
