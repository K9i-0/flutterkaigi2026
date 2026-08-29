#!/usr/bin/env python3
"""Track a planar monitor surface and export Remotion-ready homographies."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np


def parse_corners(value: str) -> np.ndarray:
    points = []
    for pair in value.split(";"):
        x, y = pair.split(",")
        points.append([float(x), float(y)])
    if len(points) != 4:
        raise argparse.ArgumentTypeError("corners must contain TL;TR;BR;BL")
    return np.asarray(points, dtype=np.float32)


def polygon_mask(shape: tuple[int, int], corners: np.ndarray) -> np.ndarray:
    center = corners.mean(axis=0)
    inner = center + (corners - center) * 0.94
    mask = np.zeros(shape, dtype=np.uint8)
    cv2.fillConvexPoly(mask, np.round(inner).astype(np.int32), 255)
    return mask


def detect_features(gray: np.ndarray, corners: np.ndarray) -> np.ndarray:
    points = cv2.goodFeaturesToTrack(
        gray,
        mask=polygon_mask(gray.shape, corners),
        maxCorners=320,
        qualityLevel=0.003,
        minDistance=3,
        blockSize=5,
        useHarrisDetector=False,
    )
    if points is None:
        return np.empty((0, 1, 2), dtype=np.float32)
    return points.astype(np.float32)


def smooth_tracks(corners: list[np.ndarray], radius: int = 2) -> list[np.ndarray]:
    stack = np.stack(corners)
    result = []
    for index in range(len(stack)):
        start = max(0, index - radius)
        end = min(len(stack), index + radius + 1)
        result.append(np.median(stack[start:end], axis=0).astype(np.float32))
    return result


def valid_quad(previous: np.ndarray, candidate: np.ndarray) -> bool:
    if not np.isfinite(candidate).all():
        return False
    previous_area = abs(cv2.contourArea(previous.astype(np.float32)))
    candidate_area = abs(cv2.contourArea(candidate.astype(np.float32)))
    if previous_area <= 1 or not 0.55 <= candidate_area / previous_area <= 1.8:
        return False
    return bool(cv2.isContourConvex(np.round(candidate).astype(np.int32)))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--source-start", type=int, required=True)
    parser.add_argument("--source-end", type=int, required=True)
    parser.add_argument("--composition-start", type=int, required=True)
    parser.add_argument("--corners", type=parse_corners, required=True)
    parser.add_argument("--canonical-width", type=int, default=1000)
    parser.add_argument("--canonical-height", type=int, default=600)
    parser.add_argument("--smoothing-radius", type=int, default=2)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--preview", type=Path, required=True)
    args = parser.parse_args()

    capture = cv2.VideoCapture(str(args.input))
    if not capture.isOpened():
        raise RuntimeError(f"cannot open {args.input}")
    fps = capture.get(cv2.CAP_PROP_FPS)
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    capture.set(cv2.CAP_PROP_POS_FRAMES, args.source_start)

    ok, first = capture.read()
    if not ok:
        raise RuntimeError("cannot read first tracking frame")
    previous_gray = cv2.cvtColor(first, cv2.COLOR_BGR2GRAY)
    current_corners = args.corners.copy()
    tracked_corners = [current_corners.copy()]
    diagnostics = [{"features": 0, "inliers": 0, "fallback": False}]

    previous_points = detect_features(previous_gray, current_corners)
    lk = dict(
        winSize=(31, 31),
        maxLevel=4,
        criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 40, 0.01),
    )

    frames = [first]
    for _source_frame in range(args.source_start + 1, args.source_end + 1):
        ok, frame = capture.read()
        if not ok:
            raise RuntimeError(f"video ended before frame {_source_frame}")
        current_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        fallback = False
        inlier_count = 0

        if len(previous_points) >= 8:
            forward, status_forward, _ = cv2.calcOpticalFlowPyrLK(
                previous_gray, current_gray, previous_points, None, **lk
            )
            backward, status_backward, _ = cv2.calcOpticalFlowPyrLK(
                current_gray, previous_gray, forward, None, **lk
            )
            forward_backward_error = np.linalg.norm(previous_points - backward, axis=2)
            valid = (
                status_forward.reshape(-1).astype(bool)
                & status_backward.reshape(-1).astype(bool)
                & (forward_backward_error.reshape(-1) < 2.2)
            )
            old_points = previous_points.reshape(-1, 2)[valid]
            new_points = forward.reshape(-1, 2)[valid]
        else:
            old_points = np.empty((0, 2), dtype=np.float32)
            new_points = np.empty((0, 2), dtype=np.float32)

        if len(old_points) >= 8:
            homography, inlier_mask = cv2.findHomography(
                old_points, new_points, cv2.RANSAC, 2.8
            )
            inlier_count = int(inlier_mask.sum()) if inlier_mask is not None else 0
        else:
            homography = None

        if homography is not None and inlier_count >= 6:
            candidate = cv2.perspectiveTransform(
                current_corners.reshape(1, 4, 2), homography
            ).reshape(4, 2)
            if valid_quad(current_corners, candidate):
                current_corners = candidate.astype(np.float32)
            else:
                fallback = True
        else:
            fallback = True

        tracked_corners.append(current_corners.copy())
        diagnostics.append(
            {
                "features": int(len(old_points)),
                "inliers": inlier_count,
                "fallback": fallback,
            }
        )
        frames.append(frame)
        previous_gray = current_gray
        previous_points = detect_features(previous_gray, current_corners)

    capture.release()
    if args.smoothing_radius < 0:
        raise ValueError("smoothing radius must be zero or greater")
    smoothed = (
        smooth_tracks(tracked_corners, radius=args.smoothing_radius)
        if args.smoothing_radius > 0
        else tracked_corners
    )
    canonical = np.asarray(
        [
            [0, 0],
            [args.canonical_width, 0],
            [args.canonical_width, args.canonical_height],
            [0, args.canonical_height],
        ],
        dtype=np.float32,
    )

    output_frames = []
    for index, corners in enumerate(smoothed):
        homography = cv2.getPerspectiveTransform(canonical, corners)
        homography /= homography[2, 2]
        output_frames.append(
            {
                "frame": args.composition_start + index,
                "sourceFrame": args.source_start + index,
                "corners": [[round(float(x), 3), round(float(y), 3)] for x, y in corners],
                "homography": [round(float(value), 9) for value in homography.reshape(-1)],
                **diagnostics[index],
            }
        )

    payload = {
        "sourceVideo": args.input.name,
        "sourceStartFrame": args.source_start,
        "sourceEndFrame": args.source_end,
        "compositionStartFrame": args.composition_start,
        "compositionEndFrame": args.composition_start + len(output_frames),
        "canonicalWidth": args.canonical_width,
        "canonicalHeight": args.canonical_height,
        "frameWidth": width,
        "frameHeight": height,
        "fps": fps,
        "smoothingRadius": args.smoothing_radius,
        "frames": output_frames,
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n")

    args.preview.parent.mkdir(parents=True, exist_ok=True)
    writer = cv2.VideoWriter(
        str(args.preview), cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height)
    )
    if not writer.isOpened():
        raise RuntimeError("cannot create preview video")
    for frame, corners, info in zip(frames, smoothed, diagnostics):
        debug = frame.copy()
        polygon = np.round(corners).astype(np.int32)
        overlay = debug.copy()
        cv2.fillConvexPoly(overlay, polygon, (0, 0, 255))
        debug = cv2.addWeighted(overlay, 0.16, debug, 0.84, 0)
        cv2.polylines(debug, [polygon], True, (0, 0, 255), 3, cv2.LINE_AA)
        for point in polygon:
            cv2.circle(debug, tuple(point), 6, (0, 255, 255), -1, cv2.LINE_AA)
        cv2.putText(
            debug,
            f"features={info['features']} inliers={info['inliers']} fallback={info['fallback']}",
            (18, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.58,
            (20, 20, 20),
            3,
            cv2.LINE_AA,
        )
        cv2.putText(
            debug,
            f"features={info['features']} inliers={info['inliers']} fallback={info['fallback']}",
            (18, 30),
            cv2.FONT_HERSHEY_SIMPLEX,
            0.58,
            (255, 255, 255),
            1,
            cv2.LINE_AA,
        )
        writer.write(debug)
    writer.release()

    fallback_count = sum(1 for item in diagnostics if item["fallback"])
    minimum_inliers = min((item["inliers"] for item in diagnostics[1:]), default=0)
    print(
        f"tracked={len(output_frames)} fallback={fallback_count} "
        f"minimum_inliers={minimum_inliers} output={args.output} preview={args.preview}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
