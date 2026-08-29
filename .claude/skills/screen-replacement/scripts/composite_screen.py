#!/usr/bin/env python3
"""Perspective-warp an image or video into a tracked planar display."""

from __future__ import annotations

import argparse
import json
import subprocess
from pathlib import Path

import cv2
import numpy as np


IMAGE_SUFFIXES = {".bmp", ".jpeg", ".jpg", ".png", ".tif", ".tiff", ".webp"}


def opacity_for_frame(frame: int, start: int, end: int, fade_in: int, fade_out: int) -> float:
    enter = 1.0 if fade_in <= 0 else np.clip((frame - start) / fade_in, 0.0, 1.0)
    exit_ = 1.0 if fade_out <= 0 else np.clip((end - frame) / fade_out, 0.0, 1.0)
    return float(min(enter, exit_))


def prepare_screen(frame: np.ndarray, width: int, height: int) -> tuple[np.ndarray, np.ndarray]:
    if frame.shape[:2] != (height, width):
        frame = cv2.resize(frame, (width, height), interpolation=cv2.INTER_LANCZOS4)
    if frame.ndim == 2:
        return cv2.cvtColor(frame, cv2.COLOR_GRAY2BGR), np.full((height, width), 255, np.uint8)
    if frame.shape[2] == 4:
        return frame[:, :, :3], frame[:, :, 3]
    return frame[:, :, :3], np.full((height, width), 255, np.uint8)


class ScreenSource:
    def __init__(self, path: Path, width: int, height: int) -> None:
        self.width = width
        self.height = height
        self.static: tuple[np.ndarray, np.ndarray] | None = None
        self.capture: cv2.VideoCapture | None = None
        if path.suffix.lower() in IMAGE_SUFFIXES:
            image = cv2.imread(str(path), cv2.IMREAD_UNCHANGED)
            if image is None:
                raise RuntimeError(f"cannot read screen image: {path}")
            self.static = prepare_screen(image, width, height)
        else:
            capture = cv2.VideoCapture(str(path))
            if not capture.isOpened():
                raise RuntimeError(f"cannot read screen video: {path}")
            self.capture = capture

    def frame(self, index: int) -> tuple[np.ndarray, np.ndarray]:
        if self.static is not None:
            return self.static
        assert self.capture is not None
        self.capture.set(cv2.CAP_PROP_POS_FRAMES, index)
        ok, frame = self.capture.read()
        if not ok:
            self.capture.set(cv2.CAP_PROP_POS_FRAMES, 0)
            ok, frame = self.capture.read()
        if not ok:
            raise RuntimeError(f"cannot read inserted screen frame {index}")
        return prepare_screen(frame, self.width, self.height)

    def close(self) -> None:
        if self.capture is not None:
            self.capture.release()


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="base video containing the display")
    parser.add_argument("--screen", type=Path, required=True, help="image or video to insert")
    parser.add_argument("--track-json", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--ffmpeg", default="ffmpeg")
    parser.add_argument("--crf", type=int, default=16)
    parser.add_argument("--edge-inset", type=int, default=0)
    parser.add_argument("--feather", type=float, default=1.0)
    parser.add_argument("--fade-in", type=int, default=0)
    parser.add_argument("--fade-out", type=int, default=0)
    parser.add_argument("--preserve-audio", action="store_true")
    parser.add_argument("--overwrite", action="store_true")
    args = parser.parse_args()

    if args.output.exists() and not args.overwrite:
        raise FileExistsError(f"output exists; pass --overwrite: {args.output}")

    track = json.loads(args.track_json.read_text(encoding="utf-8"))
    canonical_width = int(track["canonicalWidth"])
    canonical_height = int(track["canonicalHeight"])
    tracked_by_source_frame = {int(item["sourceFrame"]): item for item in track["frames"]}
    source_start = int(track["sourceStartFrame"])
    composition_start = int(track["compositionStartFrame"])
    composition_end = int(track["compositionEndFrame"])

    capture = cv2.VideoCapture(str(args.input))
    if not capture.isOpened():
        raise RuntimeError(f"cannot open input video: {args.input}")
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = float(capture.get(cv2.CAP_PROP_FPS))
    total_frames = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    if width != int(track["frameWidth"]) or height != int(track["frameHeight"]):
        raise ValueError("tracking dimensions do not match input video")

    screen = ScreenSource(args.screen, canonical_width, canonical_height)
    inset = max(0, args.edge_inset)
    inset_mask = np.zeros((canonical_height, canonical_width), dtype=np.float32)
    inset_mask[
        inset : canonical_height - inset if inset else canonical_height,
        inset : canonical_width - inset if inset else canonical_width,
    ] = 1.0
    if args.feather > 0:
        inset_mask = cv2.GaussianBlur(inset_mask, (0, 0), args.feather)

    args.output.parent.mkdir(parents=True, exist_ok=True)
    ffmpeg_command = [
        args.ffmpeg,
        "-hide_banner",
        "-loglevel",
        "error",
        "-y" if args.overwrite else "-n",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "bgr24",
        "-s:v",
        f"{width}x{height}",
        "-r",
        f"{fps:.9f}",
        "-i",
        "pipe:0",
    ]
    if args.preserve_audio:
        ffmpeg_command.extend(["-i", str(args.input), "-map", "0:v:0", "-map", "1:a:0?"])
    else:
        ffmpeg_command.extend(["-map", "0:v:0", "-an"])
    ffmpeg_command.extend(
        [
            "-c:v",
            "libx264",
            "-preset",
            "medium",
            "-crf",
            str(args.crf),
            "-pix_fmt",
            "yuv420p",
        ]
    )
    if args.preserve_audio:
        ffmpeg_command.extend(["-c:a", "aac", "-b:a", "192k"])
    if total_frames > 0 and fps > 0:
        ffmpeg_command.extend(["-t", f"{total_frames / fps:.9f}"])
    ffmpeg_command.extend(["-movflags", "+faststart", str(args.output)])
    encoder = subprocess.Popen(ffmpeg_command, stdin=subprocess.PIPE)
    assert encoder.stdin is not None

    frame_number = 0
    composited = 0
    try:
        while True:
            ok, base = capture.read()
            if not ok:
                break
            tracked = tracked_by_source_frame.get(frame_number)
            if tracked is not None:
                screen_index = frame_number - source_start
                screen_bgr, screen_alpha = screen.frame(screen_index)
                homography = np.asarray(tracked["homography"], dtype=np.float64).reshape(3, 3)
                warped_screen = cv2.warpPerspective(
                    screen_bgr,
                    homography,
                    (width, height),
                    flags=cv2.INTER_LANCZOS4,
                    borderMode=cv2.BORDER_CONSTANT,
                )
                source_alpha = (screen_alpha.astype(np.float32) / 255.0) * inset_mask
                warped_alpha = cv2.warpPerspective(
                    source_alpha,
                    homography,
                    (width, height),
                    flags=cv2.INTER_LINEAR,
                    borderMode=cv2.BORDER_CONSTANT,
                )
                composition_frame = int(tracked["frame"])
                opacity = opacity_for_frame(
                    composition_frame,
                    composition_start,
                    composition_end,
                    args.fade_in,
                    args.fade_out,
                )
                alpha = np.clip(warped_alpha * opacity, 0.0, 1.0)[:, :, None]
                base = np.clip(
                    base.astype(np.float32) * (1.0 - alpha)
                    + warped_screen.astype(np.float32) * alpha,
                    0,
                    255,
                ).astype(np.uint8)
                composited += 1
            encoder.stdin.write(base.tobytes())
            frame_number += 1
    finally:
        capture.release()
        screen.close()
        encoder.stdin.close()

    return_code = encoder.wait()
    if return_code != 0:
        raise RuntimeError(f"ffmpeg encoder failed with exit code {return_code}")
    if composited != len(track["frames"]):
        raise RuntimeError(
            f"composited {composited} frames but tracking contains {len(track['frames'])}"
        )
    print(
        f"frames={frame_number} composited={composited} size={width}x{height} "
        f"fps={fps:g} audio={'preserved' if args.preserve_audio else 'none'} output={args.output}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
