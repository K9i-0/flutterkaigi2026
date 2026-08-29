#!/usr/bin/env python3
"""Create reproducible low/high anonymous-news voice audio from an approved WAV."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import re
import secrets
import shutil
import subprocess
import tempfile


TARGET_SAMPLE_RATE = 48_000
TARGET_CHANNELS = 1
TARGET_LUFS = -16.5
DURATION_TOLERANCE_SECONDS = 0.005

PRESETS = {
    "low": {
        "pitch_ratio": 0.66,
        "filter": (
            "rubberband=tempo=1.0:pitch=0.66:transients=smooth:detector=soft:"
            "phase=laminar:window=long:smoothing=on:formant=shifted:pitchq=quality,"
            "highpass=f=75,lowpass=f=3000,equalizer=f=180:t=q:w=1:g=3,"
            "acompressor=threshold=0.10:ratio=4:attack=8:release=160:makeup=1.3,"
            "alimiter=limit=0.85:level=false"
        ),
    },
    "high": {
        "pitch_ratio": 1.48,
        "filter": (
            "rubberband=tempo=1.0:pitch=1.48:transients=smooth:detector=soft:"
            "phase=laminar:window=long:smoothing=on:formant=shifted:pitchq=quality,"
            "highpass=f=180,lowpass=f=4300,equalizer=f=2200:t=q:w=1:g=2,"
            "acompressor=threshold=0.10:ratio=4:attack=8:release=130:makeup=1.25,"
            "alimiter=limit=0.85:level=false"
        ),
    },
}


def run(command: list[str]) -> subprocess.CompletedProcess[str]:
    result = subprocess.run(command, capture_output=True, text=True)
    if result.returncode != 0:
        detail = result.stderr.strip() or result.stdout.strip()
        raise RuntimeError(f"command failed: {command[0]}: {detail}")
    return result


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def probe(path: Path) -> dict[str, float | int | str]:
    result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration:stream=codec_name,sample_rate,channels",
            "-of",
            "json",
            str(path),
        ]
    )
    data = json.loads(result.stdout)
    stream = data["streams"][0]
    return {
        "duration_seconds": float(data["format"]["duration"]),
        "codec_name": stream["codec_name"],
        "sample_rate": int(stream["sample_rate"]),
        "channels": int(stream["channels"]),
    }


def measure_loudness(path: Path) -> tuple[float, float]:
    result = subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-i",
            str(path),
            "-filter_complex",
            "ebur128=peak=true",
            "-f",
            "null",
            "-",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        raise RuntimeError(f"loudness measurement failed: {result.stderr.strip()}")
    integrated = re.findall(r"I:\s+(-?\d+(?:\.\d+)?) LUFS", result.stderr)
    peaks = re.findall(r"Peak:\s+(-?\d+(?:\.\d+)?) dBFS", result.stderr)
    if not integrated or not peaks:
        raise RuntimeError("could not parse ebur128 summary")
    return float(integrated[-1]), float(peaks[-1])


def require_tools() -> None:
    for command in ("ffmpeg", "ffprobe"):
        if shutil.which(command) is None:
            raise RuntimeError(f"required command not found: {command}")
    filters = run(["ffmpeg", "-hide_banner", "-filters"]).stdout
    if "rubberband" not in filters:
        raise RuntimeError("FFmpeg rubberband filter is required")


def select_mode(requested: str, seed: int | None) -> tuple[str, int | None]:
    if requested in PRESETS:
        return requested, None
    selected_seed = seed if seed is not None else secrets.randbits(64)
    return random.Random(selected_seed).choice(["low", "high"]), selected_seed


def render_processed(source: Path, destination: Path, filter_chain: str) -> None:
    run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-y",
            "-i",
            str(source),
            "-af",
            filter_chain,
            "-ar",
            str(TARGET_SAMPLE_RATE),
            "-ac",
            str(TARGET_CHANNELS),
            "-c:a",
            "pcm_s16le",
            str(destination),
        ]
    )


def normalize_to_target(source: Path, destination: Path, target_lufs: float) -> None:
    current = source
    for iteration in range(3):
        measured_lufs, _ = measure_loudness(current)
        if abs(measured_lufs - target_lufs) <= 0.1:
            if current != destination:
                shutil.copyfile(current, destination)
                if current != source:
                    current.unlink(missing_ok=True)
            return
        gain = target_lufs - measured_lufs
        next_path = destination if iteration == 2 else destination.with_name(
            f"{destination.stem}.normalize-{iteration}{destination.suffix}"
        )
        render_processed(
            current,
            next_path,
            f"volume={gain:.2f}dB,alimiter=limit=0.85:level=false",
        )
        if current != source and current != destination:
            current.unlink(missing_ok=True)
        current = next_path
    if current != destination:
        shutil.copyfile(current, destination)
        current.unlink(missing_ok=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Apply the Madogiwa strong low/high anonymous-news voice preset."
    )
    parser.add_argument("input", type=Path, help="approved source audio")
    parser.add_argument("output", type=Path, help="output WAV")
    parser.add_argument(
        "--mode",
        choices=("low", "high", "random"),
        default="random",
        help="default: random (50/50 low or high)",
    )
    parser.add_argument("--seed", type=int, help="reproducible seed for random mode")
    parser.add_argument("--target-lufs", type=float, default=TARGET_LUFS)
    parser.add_argument(
        "--metadata",
        type=Path,
        help="sidecar JSON path; default: <output>.anonymous-voice.json",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    require_tools()

    source = args.input.expanduser().resolve()
    output = args.output.expanduser().resolve()
    metadata_path = (
        args.metadata.expanduser().resolve()
        if args.metadata
        else output.with_name(f"{output.stem}.anonymous-voice.json")
    )
    if not source.is_file():
        raise FileNotFoundError(f"input not found: {source}")
    if output == source:
        raise ValueError("output must not overwrite input")
    if output.suffix.lower() != ".wav":
        raise ValueError("output must use the .wav extension")

    output.parent.mkdir(parents=True, exist_ok=True)
    metadata_path.parent.mkdir(parents=True, exist_ok=True)
    selected_mode, random_seed = select_mode(args.mode, args.seed)
    preset = PRESETS[selected_mode]
    input_probe = probe(source)

    with tempfile.TemporaryDirectory(prefix="anonymous-voice-") as temp_dir:
        processed = Path(temp_dir) / "processed.wav"
        render_processed(source, processed, str(preset["filter"]))
        normalize_to_target(processed, output, args.target_lufs)

    output_probe = probe(output)
    duration_delta = abs(
        float(output_probe["duration_seconds"]) - float(input_probe["duration_seconds"])
    )
    if duration_delta > DURATION_TOLERANCE_SECONDS:
        output.unlink(missing_ok=True)
        raise RuntimeError(
            f"duration changed by {duration_delta:.6f}s; anonymous audio rejected"
        )
    if (
        output_probe["sample_rate"] != TARGET_SAMPLE_RATE
        or output_probe["channels"] != TARGET_CHANNELS
        or output_probe["codec_name"] != "pcm_s16le"
    ):
        output.unlink(missing_ok=True)
        raise RuntimeError("output must be 48 kHz mono PCM 16-bit WAV")

    integrated_lufs, true_peak_dbfs = measure_loudness(output)
    if abs(integrated_lufs - args.target_lufs) > 0.2:
        output.unlink(missing_ok=True)
        raise RuntimeError(
            f"loudness is {integrated_lufs:.1f} LUFS; target is {args.target_lufs:.1f} LUFS"
        )
    if true_peak_dbfs > -0.5:
        output.unlink(missing_ok=True)
        raise RuntimeError(f"true peak is too high: {true_peak_dbfs:.1f} dBFS")
    pitch_ratio = float(preset["pitch_ratio"])
    output_sha256 = sha256(output)
    metadata = {
        "schema": "madogiwa.anonymous_voice.v1",
        "requested_mode": args.mode,
        "selected_mode": selected_mode,
        "random_seed": random_seed,
        "preset": {
            "pitch_ratio": pitch_ratio,
            "pitch_semitones": round(12 * math.log2(pitch_ratio), 3),
            "filter_chain": preset["filter"],
        },
        "input": {
            "path": str(source),
            "sha256": sha256(source),
            **input_probe,
        },
        "output": {
            "path": str(output),
            "sha256": output_sha256,
            **output_probe,
            "integrated_lufs": integrated_lufs,
            "true_peak_dbfs": true_peak_dbfs,
        },
        "target_lufs": args.target_lufs,
        "privacy_notice": "This is a broadcast effect, not an identity-protection guarantee.",
    }
    metadata_path.write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )
    print(
        f"OK: {output} (selected_mode={selected_mode}, "
        f"random_seed={random_seed}, "
        f"duration={output_probe['duration_seconds']:.6f}s, "
        f"loudness={integrated_lufs:.1f} LUFS, "
        f"true_peak={true_peak_dbfs:.1f} dBFS, "
        f"sha256={output_sha256}, metadata={metadata_path})"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
