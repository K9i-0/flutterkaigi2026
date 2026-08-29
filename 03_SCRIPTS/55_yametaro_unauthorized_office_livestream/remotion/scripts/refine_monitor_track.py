#!/usr/bin/env python3
"""Anchor a raw monitor track to manually reviewed corner keyframes."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np


def frame_map(track: dict) -> dict[int, dict]:
    return {int(item["sourceFrame"]): item for item in track["frames"]}


def interpolate_correction(
    source_frame: int,
    keyframe_numbers: list[int],
    corrections: dict[int, np.ndarray],
) -> np.ndarray:
    if source_frame <= keyframe_numbers[0]:
        return corrections[keyframe_numbers[0]]
    if source_frame >= keyframe_numbers[-1]:
        return corrections[keyframe_numbers[-1]]
    for left, right in zip(keyframe_numbers, keyframe_numbers[1:]):
        if left <= source_frame <= right:
            amount = (source_frame - left) / (right - left)
            return corrections[left] * (1.0 - amount) + corrections[right] * amount
    raise RuntimeError(f"cannot interpolate source frame {source_frame}")


def draw_polygon(frame: np.ndarray, corners: np.ndarray, color: tuple[int, int, int]) -> None:
    polygon = np.rint(corners).astype(np.int32)
    cv2.polylines(frame, [polygon], True, color, 3, cv2.LINE_AA)
    for point in polygon:
        cv2.circle(frame, tuple(point), 5, color, -1, cv2.LINE_AA)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("base_track", type=Path)
    parser.add_argument("--keyframes", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--input-video", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    parser.add_argument("--reference-track", type=Path)
    args = parser.parse_args()

    base = json.loads(args.base_track.read_text(encoding="utf-8"))
    base_frames = frame_map(base)
    keyframe_payload = json.loads(args.keyframes.read_text(encoding="utf-8"))
    manual = {
        int(item["sourceFrame"]): np.asarray(item["corners"], dtype=np.float32)
        for item in keyframe_payload["keyframes"]
    }
    keyframe_numbers = sorted(manual)
    if keyframe_numbers[0] != int(base["sourceStartFrame"]):
        raise ValueError("first keyframe must match sourceStartFrame")
    if keyframe_numbers[-1] != int(base["sourceEndFrame"]):
        raise ValueError("last keyframe must match sourceEndFrame")
    if any(frame not in base_frames for frame in keyframe_numbers):
        raise ValueError("all keyframes must exist in the base track")

    corrections = {
        frame: manual[frame] - np.asarray(base_frames[frame]["corners"], dtype=np.float32)
        for frame in keyframe_numbers
    }
    canonical = np.asarray(
        [
            [0, 0],
            [base["canonicalWidth"], 0],
            [base["canonicalWidth"], base["canonicalHeight"]],
            [0, base["canonicalHeight"]],
        ],
        dtype=np.float32,
    )

    refined_frames = []
    refined_by_source: dict[int, np.ndarray] = {}
    for item in base["frames"]:
        source_frame = int(item["sourceFrame"])
        base_corners = np.asarray(item["corners"], dtype=np.float32)
        corners = base_corners + interpolate_correction(
            source_frame, keyframe_numbers, corrections
        )
        homography = cv2.getPerspectiveTransform(canonical, corners)
        homography /= homography[2, 2]
        refined_by_source[source_frame] = corners
        refined_frames.append(
            {
                **item,
                "corners": [
                    [round(float(x), 3), round(float(y), 3)] for x, y in corners
                ],
                "homography": [
                    round(float(value), 9) for value in homography.reshape(-1)
                ],
                "manualKeyframe": source_frame in manual,
            }
        )

    payload = {
        **base,
        "frames": refined_frames,
        "refinement": {
            "method": "raw optical flow plus interpolated manual keyframe correction",
            "keyframes": args.keyframes.name,
            "keyframeSourceFrames": keyframe_numbers,
        },
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")

    reference_by_source = None
    if args.reference_track:
        reference_by_source = frame_map(
            json.loads(args.reference_track.read_text(encoding="utf-8"))
        )

    capture = cv2.VideoCapture(str(args.input_video))
    if not capture.isOpened():
        raise RuntimeError(f"cannot open input video: {args.input_video}")
    fps = float(capture.get(cv2.CAP_PROP_FPS))
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    capture.set(cv2.CAP_PROP_POS_FRAMES, int(base["sourceStartFrame"]))
    args.preview.parent.mkdir(parents=True, exist_ok=True)
    writer = cv2.VideoWriter(
        str(args.preview), cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height)
    )
    if not writer.isOpened():
        raise RuntimeError("cannot create refined tracking preview")

    for source_frame in range(int(base["sourceStartFrame"]), int(base["sourceEndFrame"]) + 1):
        ok, frame = capture.read()
        if not ok:
            raise RuntimeError(f"video ended before source frame {source_frame}")
        if reference_by_source is not None:
            reference = np.asarray(
                reference_by_source[source_frame]["corners"], dtype=np.float32
            )
            draw_polygon(frame, reference, (0, 0, 255))
        draw_polygon(frame, refined_by_source[source_frame], (70, 235, 70))
        label = "KEYFRAME" if source_frame in manual else "INTERPOLATED"
        cv2.putText(
            frame,
            f"red=old smoothed  green=refined  source={source_frame} {label}",
            (16, 28),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.56,
            (15, 15, 15),
            3,
            cv2.LINE_AA,
        )
        cv2.putText(
            frame,
            f"red=old smoothed  green=refined  source={source_frame} {label}",
            (16, 28),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.56,
            (255, 255, 255),
            1,
            cv2.LINE_AA,
        )
        writer.write(frame)

    capture.release()
    writer.release()
    print(
        f"refined={len(refined_frames)} keyframes={len(keyframe_numbers)} "
        f"output={args.output} preview={args.preview}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
