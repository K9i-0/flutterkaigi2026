#!/usr/bin/env python3
"""Track a planar display with chroma segmentation or optical flow."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np


def parse_corners(value: str) -> np.ndarray:
    try:
        points = [[float(v) for v in pair.split(",")] for pair in value.split(";")]
    except ValueError as error:
        raise argparse.ArgumentTypeError("corners must be TLx,TLy;TRx,TRy;BRx,BRy;BLx,BLy") from error
    if len(points) != 4 or any(len(point) != 2 for point in points):
        raise argparse.ArgumentTypeError("corners must contain TL;TR;BR;BL")
    return np.asarray(points, dtype=np.float32)


def order_corners(points: np.ndarray) -> np.ndarray:
    points = np.asarray(points, dtype=np.float32).reshape(4, 2)
    ordered = np.empty((4, 2), dtype=np.float32)
    sums = points.sum(axis=1)
    diffs = np.diff(points, axis=1).ravel()
    ordered[0] = points[np.argmin(sums)]
    ordered[2] = points[np.argmax(sums)]
    ordered[1] = points[np.argmin(diffs)]
    ordered[3] = points[np.argmax(diffs)]
    return ordered


def contour_quad(contour: np.ndarray) -> np.ndarray | None:
    hull = cv2.convexHull(contour)
    perimeter = cv2.arcLength(hull, True)
    for ratio in np.linspace(0.005, 0.06, 56):
        approximation = cv2.approxPolyDP(hull, ratio * perimeter, True)
        if len(approximation) == 4:
            return order_corners(approximation[:, 0, :])
    return None


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


def valid_quad(
    previous: np.ndarray, candidate: np.ndarray, max_corner_step: float
) -> bool:
    if not np.isfinite(candidate).all():
        return False
    previous_area = abs(cv2.contourArea(previous.astype(np.float32)))
    candidate_area = abs(cv2.contourArea(candidate.astype(np.float32)))
    if previous_area <= 1 or not 0.55 <= candidate_area / previous_area <= 1.8:
        return False
    corner_steps = np.linalg.norm(candidate - previous, axis=1)
    if float(np.max(corner_steps)) > max_corner_step:
        return False
    return bool(cv2.isContourConvex(np.round(candidate).astype(np.int32)))


def median_smooth(corners: list[np.ndarray], radius: int) -> list[np.ndarray]:
    values = np.stack(corners)
    result = []
    for index in range(len(values)):
        start = max(0, index - radius)
        end = min(len(values), index + radius + 1)
        result.append(np.median(values[start:end], axis=0).astype(np.float32))
    return result


def polynomial_smooth(
    corners: list[np.ndarray], radius: int, degree: int
) -> list[np.ndarray]:
    values = np.stack(corners).astype(np.float64)
    result = np.empty_like(values)
    for index in range(len(values)):
        start = max(0, index - radius)
        end = min(len(values), index + radius + 1)
        x = np.arange(start, end, dtype=np.float64) - index
        local_degree = min(degree, len(x) - 1)
        for corner_index in range(4):
            for axis in range(2):
                coefficients = np.polyfit(
                    x, values[start:end, corner_index, axis], local_degree
                )
                result[index, corner_index, axis] = coefficients[-1]
    return [frame.astype(np.float32) for frame in result]


def expand_quad(corners: np.ndarray, pixels: float) -> np.ndarray:
    if pixels <= 0:
        return corners
    center = corners.mean(axis=0)
    directions = corners - center
    lengths = np.linalg.norm(directions, axis=1, keepdims=True)
    return corners + directions / np.maximum(lengths, 1e-6) * pixels


def track_green(
    frames: list[np.ndarray], args: argparse.Namespace
) -> tuple[list[np.ndarray], list[dict], list[np.ndarray]]:
    height, width = frames[0].shape[:2]
    minimum_area = width * height * args.min_area_ratio
    corners: list[np.ndarray] = []
    diagnostics: list[dict] = []
    masks: list[np.ndarray] = []
    lower = np.array([args.hue_min, args.sat_min, args.val_min])
    upper = np.array([args.hue_max, 255, 255])
    for index, frame in enumerate(frames):
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        mask = cv2.inRange(hsv, lower, upper)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))
        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        candidates = [contour for contour in contours if cv2.contourArea(contour) >= minimum_area]
        if not candidates:
            raise RuntimeError(f"no screen-sized green region at local frame {index}")
        contour = max(candidates, key=cv2.contourArea)
        quad = contour_quad(contour)
        if quad is None:
            raise RuntimeError(f"green contour is not a quadrilateral at local frame {index}")
        area = float(cv2.contourArea(contour))
        corners.append(quad)
        masks.append(mask)
        diagnostics.append(
            {
                "features": 0,
                "inliers": 4,
                "fallback": False,
                "greenArea": round(area, 1),
                "greenAreaRatio": round(area / (width * height), 6),
            }
        )
    return corners, diagnostics, masks


def track_planar(
    frames: list[np.ndarray], initial: np.ndarray, max_corner_step: float
) -> tuple[list[np.ndarray], list[dict], list[np.ndarray]]:
    previous_gray = cv2.cvtColor(frames[0], cv2.COLOR_BGR2GRAY)
    current_corners = initial.copy()
    corners = [current_corners.copy()]
    diagnostics = [{"features": 0, "inliers": 0, "fallback": False}]
    previous_points = detect_features(previous_gray, current_corners)
    lk = {
        "winSize": (31, 31),
        "maxLevel": 4,
        "criteria": (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 40, 0.01),
    }
    for frame in frames[1:]:
        current_gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        fallback = False
        inlier_count = 0
        old_points = np.empty((0, 2), dtype=np.float32)
        new_points = np.empty((0, 2), dtype=np.float32)
        if len(previous_points) >= 8:
            forward, status_forward, _ = cv2.calcOpticalFlowPyrLK(
                previous_gray, current_gray, previous_points, None, **lk
            )
            backward, status_backward, _ = cv2.calcOpticalFlowPyrLK(
                current_gray, previous_gray, forward, None, **lk
            )
            error = np.linalg.norm(previous_points - backward, axis=2)
            valid = (
                status_forward.reshape(-1).astype(bool)
                & status_backward.reshape(-1).astype(bool)
                & (error.reshape(-1) < 2.2)
            )
            old_points = previous_points.reshape(-1, 2)[valid]
            new_points = forward.reshape(-1, 2)[valid]
        homography = None
        if len(old_points) >= 8:
            homography, inlier_mask = cv2.findHomography(
                old_points, new_points, cv2.RANSAC, 2.8
            )
            inlier_count = int(inlier_mask.sum()) if inlier_mask is not None else 0
        if homography is not None and inlier_count >= 6:
            candidate = cv2.perspectiveTransform(
                current_corners.reshape(1, 4, 2), homography
            ).reshape(4, 2)
            if valid_quad(current_corners, candidate, max_corner_step):
                current_corners = candidate.astype(np.float32)
            else:
                fallback = True
        else:
            fallback = True
        corners.append(current_corners.copy())
        diagnostics.append(
            {
                "features": int(len(old_points)),
                "inliers": inlier_count,
                "fallback": fallback,
            }
        )
        previous_gray = current_gray
        previous_points = detect_features(previous_gray, current_corners)
    return corners, diagnostics, [np.zeros(frames[0].shape[:2], np.uint8) for _ in frames]


def read_frames(
    path: Path, source_start: int, source_end: int | None
) -> tuple[list[np.ndarray], float, int, int, int]:
    capture = cv2.VideoCapture(str(path))
    if not capture.isOpened():
        raise RuntimeError(f"cannot open input video: {path}")
    fps = float(capture.get(cv2.CAP_PROP_FPS))
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    total = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    end = total - 1 if source_end is None else source_end
    if not 0 <= source_start <= end < total:
        raise ValueError(f"tracking range must fit 0..{total - 1}")
    capture.set(cv2.CAP_PROP_POS_FRAMES, source_start)
    frames = []
    for source_frame in range(source_start, end + 1):
        ok, frame = capture.read()
        if not ok:
            raise RuntimeError(f"video ended before source frame {source_frame}")
        frames.append(frame)
    capture.release()
    return frames, fps, width, height, end


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--mode", choices=("green", "planar"), required=True)
    parser.add_argument("--source-start", type=int, default=0)
    parser.add_argument("--source-end", type=int)
    parser.add_argument("--composition-start", type=int, default=0)
    parser.add_argument("--corners", type=parse_corners)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--canonical-width", type=int, default=1000)
    parser.add_argument("--canonical-height", type=int, default=600)
    parser.add_argument(
        "--smoothing-mode",
        choices=("auto", "none", "median", "polynomial"),
        default="auto",
    )
    parser.add_argument("--smooth-radius", type=int, default=9)
    parser.add_argument("--poly-degree", type=int, default=2)
    parser.add_argument("--expand-pixels", type=float)
    parser.add_argument("--hue-min", type=int, default=32)
    parser.add_argument("--hue-max", type=int, default=92)
    parser.add_argument("--sat-min", type=int, default=80)
    parser.add_argument("--val-min", type=int, default=35)
    parser.add_argument("--min-area-ratio", type=float, default=0.08)
    parser.add_argument("--max-corner-step", type=float, default=40.0)
    args = parser.parse_args()

    if args.mode == "planar" and args.corners is None:
        parser.error("--corners is required for planar mode")
    if args.smooth_radius < 0 or args.poly_degree < 0:
        parser.error("smoothing values must be zero or greater")

    frames, fps, width, height, source_end = read_frames(
        args.input, args.source_start, args.source_end
    )
    if args.mode == "green":
        raw_corners, diagnostics, masks = track_green(frames, args)
    else:
        assert args.corners is not None
        raw_corners, diagnostics, masks = track_planar(
            frames, args.corners, args.max_corner_step
        )

    smoothing_mode = args.smoothing_mode
    if smoothing_mode == "auto":
        smoothing_mode = "polynomial" if args.mode == "green" else "none"
    if smoothing_mode == "polynomial":
        smoothed = polynomial_smooth(raw_corners, args.smooth_radius, args.poly_degree)
    elif smoothing_mode == "median":
        smoothed = median_smooth(raw_corners, args.smooth_radius)
    else:
        smoothed = raw_corners

    expansion = args.expand_pixels
    if expansion is None:
        expansion = 7.0 if args.mode == "green" else 0.0
    corners = [expand_quad(frame, expansion) for frame in smoothed]
    canonical = np.asarray(
        [
            [0, 0],
            [args.canonical_width - 1, 0],
            [args.canonical_width - 1, args.canonical_height - 1],
            [0, args.canonical_height - 1],
        ],
        dtype=np.float32,
    )

    output_frames = []
    for index, (quad, diagnostic) in enumerate(zip(corners, diagnostics)):
        homography = cv2.getPerspectiveTransform(canonical, quad)
        homography /= homography[2, 2]
        output_frames.append(
            {
                "frame": args.composition_start + index,
                "sourceFrame": args.source_start + index,
                "corners": np.round(quad, 3).tolist(),
                "homography": np.round(homography.reshape(-1), 9).tolist(),
                **diagnostic,
            }
        )

    values = np.stack(corners).astype(np.float64)
    velocity = np.linalg.norm(np.diff(values, axis=0), axis=2).max(axis=1)
    acceleration = np.linalg.norm(
        values[2:] - 2 * values[1:-1] + values[:-2], axis=2
    ).max(axis=1)
    payload = {
        "sourceVideo": args.input.name,
        "sourceStartFrame": args.source_start,
        "sourceEndFrame": source_end,
        "compositionStartFrame": args.composition_start,
        "compositionEndFrame": args.composition_start + len(frames),
        "canonicalWidth": args.canonical_width,
        "canonicalHeight": args.canonical_height,
        "frameWidth": width,
        "frameHeight": height,
        "fps": fps,
        "mode": args.mode,
        "smoothingMode": smoothing_mode,
        "smoothingRadius": args.smooth_radius if smoothing_mode != "none" else 0,
        "polynomialDegree": args.poly_degree if smoothing_mode == "polynomial" else None,
        "quadExpansionPixels": expansion,
        "motion": {
            "velocityMedian": round(float(np.median(velocity)), 6) if len(velocity) else 0,
            "velocityMaximum": round(float(np.max(velocity)), 6) if len(velocity) else 0,
            "accelerationMedian": round(float(np.median(acceleration)), 6) if len(acceleration) else 0,
            "accelerationMaximum": round(float(np.max(acceleration)), 6) if len(acceleration) else 0,
        },
        "greenThreshold": (
            {
                "hsvLower": [args.hue_min, args.sat_min, args.val_min],
                "hsvUpper": [args.hue_max, 255, 255],
                "minimumAreaRatio": args.min_area_ratio,
            }
            if args.mode == "green"
            else None
        ),
        "frames": output_frames,
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
    )

    if args.preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        writer = cv2.VideoWriter(
            str(args.preview), cv2.VideoWriter_fourcc(*"mp4v"), fps, (width, height)
        )
        if not writer.isOpened():
            raise RuntimeError(f"cannot create preview: {args.preview}")
        for frame, mask, quad, diagnostic in zip(frames, masks, corners, diagnostics):
            preview = frame.copy()
            if args.mode == "green":
                tint = np.zeros_like(preview)
                tint[:, :, 2] = mask
                preview = cv2.addWeighted(preview, 0.84, tint, 0.16, 0)
            polygon = np.round(quad).astype(np.int32)
            cv2.polylines(preview, [polygon], True, (0, 255, 255), 2, cv2.LINE_AA)
            for corner_index, point in enumerate(polygon):
                cv2.circle(preview, tuple(point), 5, (255, 0, 255), -1, cv2.LINE_AA)
                cv2.putText(
                    preview,
                    str(corner_index),
                    tuple(point + np.array([7, -7])),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.45,
                    (255, 255, 255),
                    1,
                    cv2.LINE_AA,
                )
            label = f"mode={args.mode} inliers={diagnostic['inliers']} fallback={diagnostic['fallback']}"
            cv2.putText(preview, label, (14, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.52, (0, 0, 0), 3, cv2.LINE_AA)
            cv2.putText(preview, label, (14, 26), cv2.FONT_HERSHEY_SIMPLEX, 0.52, (255, 255, 255), 1, cv2.LINE_AA)
            writer.write(preview)
        writer.release()

    fallback_count = sum(1 for item in diagnostics if item["fallback"])
    print(
        f"mode={args.mode} frames={len(frames)} fallback={fallback_count} "
        f"velocity={payload['motion']['velocityMedian']:.3f}/{payload['motion']['velocityMaximum']:.3f} "
        f"acceleration={payload['motion']['accelerationMedian']:.3f}/{payload['motion']['accelerationMaximum']:.3f} "
        f"json={args.output_json} preview={args.preview or '-'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
