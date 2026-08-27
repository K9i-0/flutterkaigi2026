#!/usr/bin/env python3
"""Validate episode 54's restrained TV-shopping edit manifest."""

from __future__ import annotations

import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
MANIFEST_PATH = ROOT / "src" / "edit-manifest.json"
PUBLIC = ROOT / "public"


def fail(message: str) -> None:
    raise ValueError(message)


def duration(path: Path) -> float:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration",
            "-of",
            "default=noprint_wrappers=1:nokey=1",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return float(result.stdout.strip())


def main() -> int:
    try:
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        total = manifest["composition"]["durationInFrames"]
        fps = manifest["composition"]["fps"]
        if (total, fps) != (900, 30):
            fail("shopping v1 must remain exactly 900 frames at 30 fps")

        for key in ("inputVideo", "replacementAudio"):
            asset = PUBLIC / manifest[key]
            if not asset.is_file():
                fail(f"missing public asset: {key}={asset}")

        audio_duration = duration(PUBLIC / manifest["replacementAudio"])
        if abs(audio_duration - total / fps) > 0.001:
            fail(f"replacement audio must be 30.000 seconds, got {audio_duration:.6f}")
        if manifest["replacementAudio"] != "shopping_irodori_instrumental_master_30s.wav":
            fail(
                "v1 final must use the Irodori plus Demucs no-vocals master; "
                "raw Wan audio is forbidden"
            )

        required_product = {
            "name",
            "claims",
            "height",
            "weight",
            "regularPrice",
            "todayPrice",
            "stock",
            "matchRate",
            "disclaimer",
            "presidentTitle",
        }
        missing_product = sorted(required_product - set(manifest["product"]))
        if missing_product:
            fail(f"missing product fields: {', '.join(missing_product)}")

        cue_names = (
            "intro",
            "features",
            "president",
            "priceReveal",
            "comparison",
            "disclaimer",
            "punchline",
            "final",
        )
        cues = manifest["cues"]
        for name in cue_names:
            cue = cues.get(name)
            if not isinstance(cue, dict):
                fail(f"missing cue: {name}")
            start = cue.get("startFrame")
            end = cue.get("endFrame")
            if not isinstance(start, int) or not isinstance(end, int):
                fail(f"cue {name} must use integer frames")
            if not 0 <= start < end <= total:
                fail(f"cue {name} has invalid range {start}-{end}")

        captions = manifest["captions"]
        forbidden_cues = {"mouthCoverRight", "mouthCoverLeft"}
        if forbidden_cues & set(cues):
            fail("natural edit must not contain mouth-cover panel cues")

        expected_lines = [
            "本日ご紹介するのは、等身大そば屋フィギュア！",
            "職人が細部まで仕上げた、驚きの再現度です！",
            "とーくん社長、こちら、おいくらですか？",
            "そして、ご本人にも来ていただきました！",
            "うわ、どっちが本物かわからないぎゅん！",
            "わかるやろ。",
        ]
        actual_lines = [caption["text"] for caption in captions]
        if actual_lines != expected_lines:
            fail("caption dialogue no longer matches the approved six-line script")
    except (KeyError, OSError, ValueError, subprocess.CalledProcessError) as exc:
        print(f"Validation error: {exc}", file=sys.stderr)
        return 2

    print("Valid shopping manifest: 900 frames; six canonical lines; no mouth-cover panels")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
