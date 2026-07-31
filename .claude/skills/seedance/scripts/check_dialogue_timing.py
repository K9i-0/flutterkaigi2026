#!/usr/bin/env python3
"""Estimate a safe Seedance scene window for one Japanese dialogue line."""

from __future__ import annotations

import argparse
import math
import re
import sys
import unicodedata


RATES = {
    "slow": 3.5,
    "normal": 4.5,
    "shout": 4.0,
    "fast": 5.5,
}

SMALL_KANA = set("ぁぃぅぇぉゃゅょゎァィゥェォャュョヮヵヶ")
KANJI_RE = re.compile(r"[\u3400-\u4dbf\u4e00-\u9fff々]")

PAUSE_SECONDS = {
    "、": 0.25,
    ",": 0.25,
    "，": 0.25,
    "。": 0.45,
    "！": 0.45,
    "？": 0.45,
    "!": 0.45,
    "?": 0.45,
    "・": 0.15,
    "…": 0.35,
    ":": 0.30,
    "：": 0.30,
    ";": 0.30,
    "；": 0.30,
}


def is_kana(char: str) -> bool:
    name = unicodedata.name(char, "")
    return name.startswith("HIRAGANA LETTER") or name.startswith("KATAKANA LETTER")


def count_mora(reading: str) -> int:
    count = 0
    for char in reading:
        if char in SMALL_KANA:
            continue
        if char == "ー" or is_kana(char):
            count += 1
    return count


def round_up_tenth(value: float) -> float:
    return math.ceil((value - 1e-9) * 10) / 10


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Estimate minimum Japanese speech time and the recommended Seedance beat "
            "window, including lead-in and settle time."
        )
    )
    parser.add_argument("--text", required=True, help="Exact Japanese line to be spoken")
    parser.add_argument(
        "--reading",
        help="Kana reading used for mora counting; required when --text contains kanji",
    )
    parser.add_argument(
        "--style",
        choices=sorted(RATES),
        default="normal",
        help="Delivery preset (default: normal)",
    )
    parser.add_argument(
        "--rate",
        type=float,
        help="Override the delivery rate in mora per second",
    )
    parser.add_argument(
        "--window",
        type=float,
        help="Available beat duration in seconds; exits 1 when insufficient",
    )
    parser.add_argument("--lead", type=float, default=0.4)
    parser.add_argument("--settle", type=float, default=0.4)
    return parser


def main() -> int:
    args = build_parser().parse_args()

    if args.rate is not None and args.rate <= 0:
        raise SystemExit("--rate must be greater than zero")
    if args.window is not None and args.window <= 0:
        raise SystemExit("--window must be greater than zero")
    if args.lead < 0 or args.settle < 0:
        raise SystemExit("--lead and --settle cannot be negative")
    if KANJI_RE.search(args.text) and not args.reading:
        raise SystemExit("--reading is required because --text contains kanji")

    reading = args.reading or args.text
    mora = count_mora(reading)
    if mora == 0:
        raise SystemExit("No Japanese mora found; provide a kana --reading")

    rate = args.rate or RATES[args.style]
    pause = sum(PAUSE_SECONDS.get(char, 0.0) for char in args.text)
    speech = round_up_tenth(mora / rate + pause)
    recommended = round_up_tenth(speech + args.lead + args.settle)

    print(f"Exact text: {args.text}")
    print(f"Timing reading: {reading}")
    print(f"Delivery: {args.style} ({rate:.2f} mora/s)")
    print(f"Mora count: {mora}")
    print(f"Punctuation pauses: {pause:.2f}s")
    print(f"Minimum speech time: {speech:.1f}s")
    print(
        f"Recommended beat window: {recommended:.1f}s "
        f"(lead {args.lead:.1f}s + speech + settle {args.settle:.1f}s)"
    )

    if args.window is not None:
        margin = args.window - recommended
        if margin < -1e-9:
            print(
                f"FAIL: assigned {args.window:.1f}s is short by {-margin:.1f}s",
                file=sys.stderr,
            )
            return 1
        print(f"PASS: assigned {args.window:.1f}s leaves {margin:.1f}s margin")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
