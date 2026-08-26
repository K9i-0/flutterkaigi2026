#!/usr/bin/env python3
"""Validate or submit a Qwen Cloud Wan 3.0 video configuration.

Dry-run is the default. A paid API call happens only with --submit.
"""

from __future__ import annotations

import argparse
import base64
import json
import mimetypes
import os
from pathlib import Path
import sys
import time
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


SUBMIT_URL = (
    "https://dashscope-intl.aliyuncs.com/api/v1/services/"
    "aigc/video-generation/video-synthesis"
)
QUERY_URL = "https://dashscope-intl.aliyuncs.com/api/v1/tasks/{task_id}"
ALLOWED_MEDIA_TYPES = {
    "first_frame",
    "last_frame",
    "reference_image",
    "reference_video",
    "reference_audio",
    "file",
    "link",
}
ALLOWED_RESOLUTIONS = {"480P", "720P", "1080P"}
ALLOWED_RATIOS = {"adaptive", "16:9", "4:3", "1:1", "3:4", "9:16"}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("config", type=Path, help="Path to wan3_config.json")
    parser.add_argument(
        "--submit",
        action="store_true",
        help="Make the paid API call. Without this flag, only validate inputs.",
    )
    parser.add_argument("--poll-interval", type=int, default=10)
    return parser.parse_args()


def load_config(path: Path) -> tuple[dict[str, Any], Path]:
    resolved = path.resolve()
    with resolved.open(encoding="utf-8") as handle:
        config = json.load(handle)
    if not isinstance(config, dict):
        raise ValueError("Config root must be an object")
    return config, resolved.parent


def resolve_inside(base: Path, value: str) -> Path:
    path = Path(value)
    return path if path.is_absolute() else (base / path).resolve()


def validate(config: dict[str, Any], base: Path) -> tuple[str, list[tuple[str, Path]], dict[str, Any], Path]:
    if config.get("model") != "wan3.0-video":
        raise ValueError('model must be "wan3.0-video"')

    prompt_path = resolve_inside(base, str(config.get("prompt_file", "")))
    if not prompt_path.is_file():
        raise ValueError(f"Prompt file not found: {prompt_path}")
    prompt = prompt_path.read_text(encoding="utf-8").strip()
    if not prompt:
        raise ValueError("Prompt is empty")
    if len(prompt) > 20_000:
        raise ValueError(f"Prompt exceeds 20,000 characters: {len(prompt):,}")

    raw_media = config.get("media", [])
    if not isinstance(raw_media, list):
        raise ValueError("media must be an array")
    media: list[tuple[str, Path]] = []
    types: set[str] = set()
    for index, item in enumerate(raw_media, 1):
        if not isinstance(item, dict):
            raise ValueError(f"media[{index}] must be an object")
        kind = item.get("type")
        if kind not in ALLOWED_MEDIA_TYPES:
            raise ValueError(f"Unsupported media type at index {index}: {kind}")
        if kind in {"link", "file"} and str(item.get("path", "")).startswith(("http://", "https://")):
            raise ValueError("Use local paths only; public URLs must not be persisted by this helper")
        media_path = resolve_inside(base, str(item.get("path", "")))
        if not media_path.is_file():
            raise ValueError(f"Media file not found: {media_path}")
        types.add(kind)
        media.append((kind, media_path))

    has_reference = bool(types & {"reference_image", "reference_video", "reference_audio", "file", "link"})
    has_frames = bool(types & {"first_frame", "last_frame"})
    if has_reference and has_frames:
        raise ValueError("reference media and first/last frames cannot be mixed")
    if "last_frame" in types and "first_frame" not in types:
        raise ValueError("last_frame requires first_frame")

    parameters = config.get("parameters")
    if not isinstance(parameters, dict):
        raise ValueError("parameters must be an object")
    resolution = parameters.get("resolution")
    ratio = parameters.get("ratio")
    duration = parameters.get("duration")
    seed = parameters.get("seed")
    if resolution not in ALLOWED_RESOLUTIONS:
        raise ValueError(f"Invalid resolution: {resolution}")
    if ratio not in ALLOWED_RATIOS:
        raise ValueError(f"Invalid ratio: {ratio}")
    if not isinstance(duration, int) or not 2 <= duration <= 30:
        raise ValueError("duration must be an integer from 2 to 30")
    if not isinstance(seed, int) or not 0 <= seed <= 2_147_483_647:
        raise ValueError("seed must be an integer from 0 to 2147483647")
    for key in ("audio", "watermark", "prompt_extend"):
        if not isinstance(parameters.get(key), bool):
            raise ValueError(f"parameters.{key} must be boolean")

    output = resolve_inside(base, str(config.get("output", "")))
    if not output.name.lower().endswith(".mp4"):
        raise ValueError("output must end in .mp4")
    return prompt, media, parameters, output


def data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def build_payload(prompt: str, media: list[tuple[str, Path]], parameters: dict[str, Any]) -> dict[str, Any]:
    return {
        "model": "wan3.0-video",
        "input": {
            "prompt": prompt,
            "media": [{"type": kind, "url": data_uri(path)} for kind, path in media],
        },
        "parameters": parameters,
    }


def api_json(url: str, api_key: str, method: str = "GET", payload: Any = None) -> Any:
    headers = {"Authorization": f"Bearer {api_key}"}
    data = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers["Content-Type"] = "application/json"
        headers["X-DashScope-Async"] = "enable"
    request = Request(url, data=data, headers=headers, method=method)
    try:
        with urlopen(request, timeout=180) as response:
            return json.load(response)
    except HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        try:
            error = json.loads(body)
        except json.JSONDecodeError:
            error = {}
        code = error.get("code")
        if code == "AccessDenied.Unpurchased":
            raise RuntimeError(
                "Qwen Cloud billing is not activated for pay-as-you-go calls. "
                "Complete billing information and add a payment method at "
                "https://home.qwencloud.com/billing/overview?target=payment, then retry. "
                "The task was not created, so this failed request is not charged."
            ) from exc
        if code == "AllocationQuota.FreeTierOnly":
            raise RuntimeError(
                "Qwen Cloud Free quota only mode blocked this paid call. Disable "
                "Free quota only in the Qwen Cloud console, then retry. "
                "The task was not created, so this failed request is not charged."
            ) from exc
        raise RuntimeError(f"HTTP {exc.code}: {body}") from exc
    except URLError as exc:
        raise RuntimeError(f"Network error: {exc.reason}") from exc


def main() -> int:
    args = parse_args()
    try:
        config, base = load_config(args.config)
        prompt, media, parameters, output = validate(config, base)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print(f"Validation error: {exc}", file=sys.stderr)
        return 2

    total_bytes = sum(path.stat().st_size for _, path in media)
    counts = {kind: sum(1 for current, _ in media if current == kind) for kind, _ in media}
    print(f"Prompt: {len(prompt):,} characters")
    print(f"Media: {counts} ({total_bytes / 1024 / 1024:.1f} MiB raw)")
    print(
        f"Request: wan3.0-video, {parameters['duration']} s, "
        f"{parameters['resolution']}, {parameters['ratio']}, audio={parameters['audio']}"
    )
    print(
        f"Seed: {parameters['seed']}; prompt_extend={parameters['prompt_extend']}; "
        f"watermark={parameters['watermark']}"
    )
    print(f"Output: {output}")

    if not args.submit:
        print("Dry-run complete. Add --submit to make the paid request.")
        return 0

    api_key = os.environ.get("DASHSCOPE_API_KEY")
    if not api_key:
        print("DASHSCOPE_API_KEY is not set.", file=sys.stderr)
        return 2

    try:
        payload = build_payload(prompt, media, parameters)
        created = api_json(SUBMIT_URL, api_key, method="POST", payload=payload)
        task_id = created.get("output", {}).get("task_id")
        if not task_id:
            raise RuntimeError(f"No task_id in response: {json.dumps(created, ensure_ascii=False)}")
        print(f"Task submitted: {task_id}")

        while True:
            result = api_json(QUERY_URL.format(task_id=task_id), api_key)
            status = result.get("output", {}).get("task_status", "UNKNOWN")
            print(f"Status: {status}")
            if status == "SUCCEEDED":
                break
            if status in {"FAILED", "CANCELED", "UNKNOWN"}:
                raise RuntimeError(json.dumps(result, ensure_ascii=False))
            time.sleep(max(2, min(args.poll_interval, 60)))

        video_url = result.get("output", {}).get("video_url")
        if not isinstance(video_url, str) or not video_url.startswith(("http://", "https://")):
            raise RuntimeError(f"No video URL in result: {json.dumps(result, ensure_ascii=False)}")
        output.parent.mkdir(parents=True, exist_ok=True)
        with urlopen(video_url, timeout=180) as response, output.open("wb") as handle:
            while chunk := response.read(1024 * 1024):
                handle.write(chunk)
        print(f"Downloaded: {output}")
        return 0
    except RuntimeError as exc:
        print(f"API error: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
