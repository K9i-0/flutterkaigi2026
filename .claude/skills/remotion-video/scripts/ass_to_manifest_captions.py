#!/usr/bin/env python3
"""Convert ASS dialogue events into Remotion manifest caption objects."""

from __future__ import annotations

import argparse
import json
import math
from pathlib import Path
import re
import sys


TIME_RE = re.compile(r"^(\d+):(\d{2}):(\d{2})(?:[.](\d{1,3}))?$")
TAG_RE = re.compile(r"\{[^}]*\}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--fps", required=True, type=int)
    parser.add_argument("--output", required=True, type=Path)
    return parser.parse_args()


def parse_time(value: str) -> float:
    match = TIME_RE.fullmatch(value.strip())
    if not match:
        raise ValueError(f"Invalid ASS timestamp: {value}")
    hours, minutes, seconds, fraction = match.groups()
    fraction_seconds = float(f"0.{fraction}") if fraction else 0.0
    return int(hours) * 3600 + int(minutes) * 60 + int(seconds) + fraction_seconds


def clean_text(value: str) -> str:
    text = TAG_RE.sub("", value)
    text = text.replace(r"\N", "\n").replace(r"\n", "\n").replace(r"\h", " ")
    return text.strip()


def main() -> int:
    args = parse_args()
    if args.fps <= 0:
        print("Error: --fps must be positive", file=sys.stderr)
        return 2
    if not args.input.is_file():
        print(f"Error: input not found: {args.input}", file=sys.stderr)
        return 2

    in_events = False
    fields: list[str] | None = None
    captions: list[dict[str, int | str]] = []
    for raw_line in args.input.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if line.startswith("[") and line.endswith("]"):
            in_events = line.casefold() == "[events]"
            continue
        if not in_events:
            continue
        if line.casefold().startswith("format:"):
            fields = [part.strip().casefold() for part in line.split(":", 1)[1].split(",")]
            continue
        if not line.casefold().startswith("dialogue:"):
            continue
        if not fields:
            raise ValueError("ASS [Events] section has Dialogue before Format")
        values = [part.strip() for part in line.split(":", 1)[1].split(",", len(fields) - 1)]
        if len(values) != len(fields):
            raise ValueError(f"Dialogue field count mismatch: {raw_line}")
        event = dict(zip(fields, values, strict=True))
        start = parse_time(event["start"])
        end = parse_time(event["end"])
        text = clean_text(event["text"])
        if not text or end <= start:
            continue
        captions.append(
            {
                "startFrame": math.floor(start * args.fps + 1e-9),
                "endFrame": math.ceil(end * args.fps - 1e-9),
                "text": text,
            }
        )

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(
        json.dumps(captions, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"Converted {len(captions)} caption(s) at {args.fps} fps: {args.output}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except ValueError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        raise SystemExit(2) from exc
