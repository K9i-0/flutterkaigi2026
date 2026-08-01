#!/usr/bin/env python3
"""Create lightweight visual timing artifacts for a generated Seedance video."""

from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path


def require_tool(name: str) -> None:
    if shutil.which(name) is None:
        raise SystemExit(f"Required command not found: {name}")


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def contact_sheet_filter(fps: int) -> str:
    timestamp = (
        "drawtext=text='%{pts\\:hms}':x=5:y=5:fontsize=18:"
        "fontcolor=yellow:box=1:boxcolor=black@0.65"
    )
    return f"fps={fps},scale=320:-2,{timestamp},tile=5x6:padding=2:margin=2"


def create_contact_sheet(
    video: Path,
    output: Path,
    *,
    fps: int,
    start: float | None = None,
    duration: float | None = None,
) -> None:
    command = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y"]
    if start is not None:
        command.extend(["-ss", f"{start:.3f}"])
    command.extend(["-i", str(video)])
    if duration is not None:
        command.extend(["-t", f"{duration:.3f}"])
    command.extend(
        [
            "-vf",
            contact_sheet_filter(fps),
            "-frames:v",
            "1",
            str(output),
        ]
    )
    run(command)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Inspect a generated Seedance video with ffprobe, contact sheets, and "
            "scene-change candidates. Audio content still requires human listening."
        )
    )
    parser.add_argument("video", type=Path)
    parser.add_argument(
        "--output",
        type=Path,
        help="Audit directory (default: <video_stem>_audit beside the video)",
    )
    parser.add_argument("--action-start", type=float)
    parser.add_argument("--action-end", type=float)
    parser.add_argument("--scene-threshold", type=float, default=0.24)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    video = args.video.resolve()
    if not video.is_file():
        raise SystemExit(f"Video not found: {video}")
    if (args.action_start is None) != (args.action_end is None):
        raise SystemExit("Provide both --action-start and --action-end")
    if args.action_start is not None and args.action_end <= args.action_start:
        raise SystemExit("--action-end must be greater than --action-start")
    if not 0 < args.scene_threshold < 1:
        raise SystemExit("--scene-threshold must be between 0 and 1")

    require_tool("ffmpeg")
    require_tool("ffprobe")

    output = (args.output or video.with_name(f"{video.stem}_audit")).resolve()
    output.mkdir(parents=True, exist_ok=True)

    metadata_result = run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration,size:stream=index,codec_type,codec_name,width,height,r_frame_rate,sample_rate,channels",
            "-of",
            "json",
            str(video),
        ],
        capture=True,
    )
    metadata = json.loads(metadata_result.stdout)
    (output / "metadata.json").write_text(
        json.dumps(metadata, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    create_contact_sheet(video, output / "full_1fps.png", fps=1)
    if args.action_start is not None:
        create_contact_sheet(
            video,
            output / "action_2fps.png",
            fps=2,
            start=args.action_start,
            duration=args.action_end - args.action_start,
        )

    scene_result = run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "info",
            "-i",
            str(video),
            "-vf",
            f"select=gt(scene\\,{args.scene_threshold}),showinfo",
            "-an",
            "-f",
            "null",
            "-",
        ],
        capture=True,
    )
    cuts = [float(value) for value in re.findall(r"pts_time:([0-9.]+)", scene_result.stderr)]
    cut_lines = [f"threshold={args.scene_threshold:.3f}"]
    cut_lines.extend(f"{value:.6f}" for value in cuts)
    (output / "scene_cuts.txt").write_text("\n".join(cut_lines) + "\n", encoding="utf-8")

    duration = float(metadata.get("format", {}).get("duration", 0.0))
    print(f"Video: {video}")
    print(f"Duration: {duration:.3f}s")
    print(f"Scene-change candidates: {len(cuts)}")
    print(f"Audit artifacts: {output}")
    print("Listen manually for exact words, pronunciation, speaker, count, and masking.")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except subprocess.CalledProcessError as error:
        if error.stderr:
            print(error.stderr, file=sys.stderr)
        raise
