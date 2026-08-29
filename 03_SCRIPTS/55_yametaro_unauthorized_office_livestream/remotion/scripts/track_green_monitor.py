#!/usr/bin/env python3
"""Track a chroma-green monitor surface as a perspective quadrilateral."""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import cv2
import numpy as np


def order_corners(points: np.ndarray) -> np.ndarray:
    points = np.asarray(points, dtype=np.float32).reshape(4, 2)
    ordered = np.empty((4, 2), dtype=np.float32)
    sums = points.sum(axis=1)
    diffs = np.diff(points, axis=1).ravel()
    ordered[0] = points[np.argmin(sums)]  # top-left
    ordered[2] = points[np.argmax(sums)]  # bottom-right
    ordered[1] = points[np.argmin(diffs)]  # top-right
    ordered[3] = points[np.argmax(diffs)]  # bottom-left
    return ordered


def contour_quad(contour: np.ndarray) -> np.ndarray | None:
    hull = cv2.convexHull(contour)
    perimeter = cv2.arcLength(hull, True)
    for ratio in np.linspace(0.005, 0.06, 56):
        approx = cv2.approxPolyDP(hull, ratio * perimeter, True)
        if len(approx) == 4:
            return order_corners(approx[:, 0, :])
    return None


def median_smooth(corners: list[np.ndarray], radius: int) -> list[np.ndarray]:
    if radius <= 0:
        return corners
    result: list[np.ndarray] = []
    for index in range(len(corners)):
        start = max(0, index - radius)
        end = min(len(corners), index + radius + 1)
        result.append(np.median(np.stack(corners[start:end]), axis=0).astype(np.float32))
    return result


def polynomial_smooth(
    corners: list[np.ndarray], radius: int, degree: int
) -> list[np.ndarray]:
    """Centered local polynomial smoothing without causal tracking lag."""
    if radius <= 0:
        return corners
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


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("--output-json", type=Path, required=True)
    parser.add_argument("--preview", type=Path)
    parser.add_argument("--canonical-width", type=int, default=1000)
    parser.add_argument("--canonical-height", type=int, default=600)
    parser.add_argument(
        "--smoothing-mode",
        choices=("median", "polynomial"),
        default="polynomial",
    )
    parser.add_argument("--smooth-radius", type=int, default=9)
    parser.add_argument("--poly-degree", type=int, default=2)
    parser.add_argument("--expand-pixels", type=float, default=7.0)
    parser.add_argument("--min-area-ratio", type=float, default=0.08)
    args = parser.parse_args()

    capture = cv2.VideoCapture(str(args.input))
    if not capture.isOpened():
        raise RuntimeError(f"cannot open input video: {args.input}")
    width = int(capture.get(cv2.CAP_PROP_FRAME_WIDTH))
    height = int(capture.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = float(capture.get(cv2.CAP_PROP_FPS))
    frame_count = int(capture.get(cv2.CAP_PROP_FRAME_COUNT))
    minimum_area = width * height * args.min_area_ratio

    frames: list[np.ndarray] = []
    masks: list[np.ndarray] = []
    raw_corners: list[np.ndarray] = []
    areas: list[float] = []
    frame_index = 0

    while True:
        ok, frame = capture.read()
        if not ok:
            break
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        # Wan's generated display is green with mild illumination variation.
        # A moderately high saturation floor excludes plants and beige office
        # objects that can otherwise join the large screen component.
        mask = cv2.inRange(hsv, np.array([32, 80, 35]), np.array([92, 255, 255]))
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, np.ones((7, 7), np.uint8))
        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))

        contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        candidates = [(cv2.contourArea(contour), contour) for contour in contours]
        candidates = [candidate for candidate in candidates if candidate[0] >= minimum_area]
        if not candidates:
            raise RuntimeError(f"no monitor-sized green region at frame {frame_index}")
        area, contour = max(candidates, key=lambda item: item[0])
        quad = contour_quad(contour)
        if quad is None:
            raise RuntimeError(f"green contour is not a quadrilateral at frame {frame_index}")

        frames.append(frame)
        masks.append(mask)
        raw_corners.append(quad)
        areas.append(float(area))
        frame_index += 1

    capture.release()
    if not frames:
        raise RuntimeError("input contains no decodable video frames")
    if frame_count > 0 and len(frames) != frame_count:
        raise RuntimeError(f"decoded {len(frames)} frames; expected {frame_count}")

    if args.smoothing_mode == "polynomial":
        smoothed_corners = polynomial_smooth(
            raw_corners, args.smooth_radius, args.poly_degree
        )
    else:
        smoothed_corners = median_smooth(raw_corners, args.smooth_radius)
    corners = [expand_quad(quad, args.expand_pixels) for quad in smoothed_corners]
    canonical = np.array(
        [
            [0, 0],
            [args.canonical_width - 1, 0],
            [args.canonical_width - 1, args.canonical_height - 1],
            [0, args.canonical_height - 1],
        ],
        dtype=np.float32,
    )
    tracking_frames = []
    for index, quad in enumerate(corners):
        homography = cv2.getPerspectiveTransform(canonical, quad)
        tracking_frames.append(
            {
                "frame": index,
                "sourceFrame": index,
                "corners": np.round(quad, 3).tolist(),
                "homography": np.round(homography.reshape(-1), 9).tolist(),
                "features": 0,
                "inliers": 4,
                "fallback": False,
                "detection": "hsv-green-contour",
                "greenArea": round(areas[index], 1),
            }
        )

    payload = {
        "sourceVideo": args.input.name,
        "sourceStartFrame": 0,
        "sourceEndFrame": len(frames) - 1,
        "compositionStartFrame": 0,
        "compositionEndFrame": len(frames) - 1,
        "canonicalWidth": args.canonical_width,
        "canonicalHeight": args.canonical_height,
        "frameWidth": width,
        "frameHeight": height,
        "fps": fps,
        "smoothingRadius": args.smooth_radius,
        "smoothingMode": args.smoothing_mode,
        "polynomialDegree": (
            args.poly_degree if args.smoothing_mode == "polynomial" else None
        ),
        "detector": {
            "method": "HSV mask + largest contour + convex quadrilateral",
            "hsvLower": [32, 80, 35],
            "hsvUpper": [92, 255, 255],
            "detectedFrames": len(frames),
            "minimumGreenAreaRatio": round(min(areas) / (width * height), 6),
            "maximumGreenAreaRatio": round(max(areas) / (width * height), 6),
            "quadExpansionPixels": args.expand_pixels,
        },
        "frames": tracking_frames,
    }
    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    args.output_json.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    if args.preview:
        args.preview.parent.mkdir(parents=True, exist_ok=True)
        writer = cv2.VideoWriter(
            str(args.preview),
            cv2.VideoWriter_fourcc(*"mp4v"),
            fps,
            (width, height),
        )
        if not writer.isOpened():
            raise RuntimeError(f"cannot open preview output: {args.preview}")
        for frame, mask, quad in zip(frames, masks, corners):
            preview = frame.copy()
            tint = np.zeros_like(preview)
            tint[:, :, 2] = mask
            preview = cv2.addWeighted(preview, 0.82, tint, 0.18, 0)
            cv2.polylines(preview, [np.round(quad).astype(np.int32)], True, (0, 255, 255), 2, cv2.LINE_AA)
            for corner_index, point in enumerate(quad):
                x, y = np.round(point).astype(int)
                cv2.circle(preview, (x, y), 5, (255, 0, 255), -1, cv2.LINE_AA)
                cv2.putText(
                    preview,
                    str(corner_index),
                    (x + 7, y - 7),
                    cv2.FONT_HERSHEY_SIMPLEX,
                    0.45,
                    (255, 255, 255),
                    1,
                    cv2.LINE_AA,
                )
            writer.write(preview)
        writer.release()

    print(
        f"frames={len(frames)} detected={len(corners)} size={width}x{height} fps={fps:g} "
        f"area_ratio={min(areas)/(width*height):.3f}-{max(areas)/(width*height):.3f} "
        f"json={args.output_json} preview={args.preview or '-'}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
