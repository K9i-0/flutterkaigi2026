#!/usr/bin/env python3
"""Submit episode 30 to Qwen Cloud Wan 3.0 and download the result.

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


EPISODE_DIR = Path(__file__).resolve().parent
SUBMIT_URL = (
    "https://dashscope-intl.aliyuncs.com/api/v1/services/"
    "aigc/video-generation/video-synthesis"
)
QUERY_URL = "https://dashscope-intl.aliyuncs.com/api/v1/tasks/{task_id}"

MEDIA = [
    ("reference_image", EPISODE_DIR / "character_sobaya_basic_sheet.png"),
    ("reference_image", EPISODE_DIR / "logo_yumemi_master.png"),
    ("reference_image", EPISODE_DIR / "scene_00_sobaya_m202_front_start_production.png"),
    (
        "reference_image",
        EPISODE_DIR / "scene_01_yumemi_office_start_production_pose_fixed_v2.png",
    ),
    ("reference_image", EPISODE_DIR / "vfx_yumemi_office_blast_production.png"),
    ("reference_image", EPISODE_DIR / "scene_02_sobaya_drinking_final_production.png"),
]


def data_uri(path: Path) -> str:
    mime = mimetypes.guess_type(path.name)[0] or "application/octet-stream"
    encoded = base64.b64encode(path.read_bytes()).decode("ascii")
    return f"data:{mime};base64,{encoded}"


def build_payload(resolution: str, seed: int) -> dict[str, Any]:
    prompt = (EPISODE_DIR / "prompt_wan3.txt").read_text(encoding="utf-8").strip()
    media = [{"type": kind, "url": data_uri(path)} for kind, path in MEDIA]
    return {
        "model": "wan3.0-video",
        "input": {"prompt": prompt, "media": media},
        "parameters": {
            "resolution": resolution,
            "ratio": "16:9",
            "duration": 15,
            "audio": True,
            "seed": seed,
            "watermark": False,
            "prompt_extend": False,
        },
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
        raise RuntimeError(f"HTTP {exc.code}: {body}") from exc
    except URLError as exc:
        raise RuntimeError(f"Network error: {exc.reason}") from exc


def find_video_url(value: Any) -> str | None:
    if isinstance(value, str) and value.startswith(("http://", "https://")):
        if ".mp4" in value.lower():
            return value
    if isinstance(value, dict):
        for key in ("video_url", "url"):
            candidate = value.get(key)
            if isinstance(candidate, str) and candidate.startswith(("http://", "https://")):
                return candidate
        for child in value.values():
            found = find_video_url(child)
            if found:
                return found
    if isinstance(value, list):
        for child in value:
            found = find_video_url(child)
            if found:
                return found
    return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--submit",
        action="store_true",
        help="Make the paid API call. Without this flag, only validate inputs.",
    )
    parser.add_argument("--resolution", choices=("480P", "720P", "1080P"), default="480P")
    parser.add_argument("--seed", type=int, default=300030)
    parser.add_argument("--poll-interval", type=int, default=10)
    parser.add_argument(
        "--output",
        type=Path,
        default=EPISODE_DIR / "wan3_episode30_seed300030_480p.mp4",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    missing = [str(path) for _, path in MEDIA if not path.is_file()]
    prompt_path = EPISODE_DIR / "prompt_wan3.txt"
    if not prompt_path.is_file():
        missing.append(str(prompt_path))
    if missing:
        print("Missing inputs:\n- " + "\n- ".join(missing), file=sys.stderr)
        return 2

    prompt_length = len(prompt_path.read_text(encoding="utf-8"))
    total_media_bytes = sum(path.stat().st_size for _, path in MEDIA)
    image_count = sum(kind == "reference_image" for kind, _ in MEDIA)
    audio_count = sum(kind == "reference_audio" for kind, _ in MEDIA)
    print(f"Prompt: {prompt_length:,} characters")
    print(
        f"References: {image_count} images + {audio_count} audio "
        f"({total_media_bytes / 1024 / 1024:.1f} MiB raw)"
    )
    print(f"Request: wan3.0-video, 15 s, {args.resolution}, 16:9, audio on")
    print(f"Seed: {args.seed}; prompt_extend: false; watermark: false")

    if not args.submit:
        print("Dry-run complete. Add --submit to make the paid request.")
        return 0

    api_key = os.environ.get("DASHSCOPE_API_KEY")
    if not api_key:
        print("DASHSCOPE_API_KEY is not set.", file=sys.stderr)
        return 2

    payload = build_payload(args.resolution, args.seed)
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

    video_url = find_video_url(result)
    if not video_url:
        raise RuntimeError(f"No video URL in result: {json.dumps(result, ensure_ascii=False)}")
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with urlopen(video_url, timeout=180) as response, args.output.open("wb") as output:
        while chunk := response.read(1024 * 1024):
            output.write(chunk)
    print(f"Downloaded: {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
