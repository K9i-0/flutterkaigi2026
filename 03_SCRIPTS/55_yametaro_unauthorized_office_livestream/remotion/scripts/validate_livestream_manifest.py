#!/usr/bin/env python3
"""Validate the Yame Channel livestream-specific frame ranges and text."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / "src" / "edit-manifest.json"


def frame_range(item: dict, name: str, duration: int) -> tuple[int, int]:
    start = item.get("startFrame")
    end = item.get("endFrame")
    if not isinstance(start, int) or not isinstance(end, int):
        raise ValueError(f"{name} frame values must be integers")
    if not 0 <= start < end <= duration:
        raise ValueError(f"{name} must fit inside 0..{duration}")
    return start, end


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    duration = manifest["composition"]["durationInFrames"]
    if duration != 948:
        raise ValueError("dialogue-repaired livestream master must be exactly 948 frames")
    if manifest["composition"]["fps"] != 30:
        raise ValueError("livestream master must be 30 fps")
    if manifest["channel"]["name"] != "やめチャンネル":
        raise ValueError("channel name must be やめチャンネル")

    platform = manifest.get("platform")
    if not isinstance(platform, dict) or platform.get("name") != "YumeTube Live":
        raise ValueError("platform name must be YumeTube Live")
    for key in ("logoBlack", "logoWhite"):
        value = platform.get(key)
        if not isinstance(value, str) or not value.endswith(".png"):
            raise ValueError(f"platform.{key} must be a PNG path")
        if not (ROOT / "public" / value).is_file():
            raise ValueError(f"platform.{key} does not exist in public: {value}")

    replacement_video = manifest.get("replacementVideo")
    if not isinstance(replacement_video, dict):
        raise ValueError("replacementVideo is required")
    replacement_path = replacement_video.get("path")
    if not isinstance(replacement_path, str) or not (ROOT / "public" / replacement_path).is_file():
        raise ValueError("replacementVideo.path must exist in public")
    if replacement_video.get("startFrame") != 528:
        raise ValueError("Fukuchan replacement must start at frame 528")
    if replacement_video.get("sourceCutFrame") != 501:
        raise ValueError("original Wan source must cut at frame 501")

    video_inserts = manifest.get("videoInserts")
    if not isinstance(video_inserts, list) or len(video_inserts) != 2:
        raise ValueError("exactly two smartphone POV video inserts are required")
    expected_inserts = [(564, 677, 36), (783, 948, 135)]
    for index, (item, expected) in enumerate(zip(video_inserts, expected_inserts)):
        start, end = frame_range(item, f"videoInserts[{index}]", duration)
        if (start, end, item.get("sourceStartFrame")) != expected:
            raise ValueError(f"videoInserts[{index}] has unexpected splice timing")
        path = item.get("path")
        if not isinstance(path, str) or not (ROOT / "public" / path).is_file():
            raise ValueError(f"videoInserts[{index}].path must exist in public")

    live_ranges = [
        frame_range(item, f"liveSegments[{index}]", duration)
        for index, item in enumerate(manifest["liveSegments"])
    ]
    for previous, current in zip(live_ranges, live_ranges[1:]):
        if current[0] < previous[1]:
            raise ValueError("liveSegments must not overlap")
    for index, item in enumerate(manifest["liveSegments"]):
        if item.get("logoVariant") not in {"black", "white"}:
            raise ValueError(
                f"liveSegments[{index}].logoVariant must be black or white"
            )
    if live_ranges[-1][1] != duration:
        raise ValueError("final livestream segment must continue through the last frame")
    if live_ranges[2] != (564, 677) or live_ranges[3] != (783, 948):
        raise ValueError("Fukuchan live UI must appear only over true smartphone POV inserts")

    for index, item in enumerate(manifest["comments"]):
        start, end = frame_range(item, f"comments[{index}]", duration)
        if not any(start >= live_start and end <= live_end for live_start, live_end in live_ranges):
            raise ValueError(f"comments[{index}] must be fully inside one live segment")

    if "confidential" in manifest:
        raise ValueError("fixed confidential card is obsolete; use monitorScreen tracking")
    monitor_screen = manifest["monitorScreen"]
    if frame_range(monitor_screen, "monitorScreen", duration) != (798, 858):
        raise ValueError("tracked monitor replacement must occupy frames 798..858")
    if monitor_screen["text"] != "社外秘":
        raise ValueError("monitorScreen text must be 社外秘")
    baked_video = monitor_screen.get("bakedVideo")
    if not isinstance(baked_video, str) or not baked_video.endswith(".mp4"):
        raise ValueError("monitorScreen.bakedVideo must be an MP4 path")
    track_path = ROOT / "src" / monitor_screen.get("trackData", "")
    if not track_path.is_file():
        raise ValueError("monitorScreen.trackData must exist in src")
    track = json.loads(track_path.read_text(encoding="utf-8"))
    if track.get("compositionStartFrame") != 798 or track.get("compositionEndFrame") != 858:
        raise ValueError("monitor tracking frame range must match monitorScreen")
    track_frames = track.get("frames")
    if not isinstance(track_frames, list) or len(track_frames) != 60:
        raise ValueError("monitor tracking must contain exactly 60 frames")
    expected_frames = list(range(798, 858))
    if [item.get("frame") for item in track_frames] != expected_frames:
        raise ValueError("monitor tracking frames must be contiguous")
    if any(item.get("fallback") for item in track_frames):
        raise ValueError("monitor tracking contains an optical-flow fallback")

    refined_track_path = ROOT / "src" / monitor_screen.get("refinedTrackData", "")
    if not refined_track_path.is_file():
        raise ValueError("monitorScreen.refinedTrackData must exist in src")
    refined_track = json.loads(refined_track_path.read_text(encoding="utf-8"))
    refined_frames = refined_track.get("frames")
    if (
        refined_track.get("compositionStartFrame") != 798
        or refined_track.get("compositionEndFrame") != 858
        or not isinstance(refined_frames, list)
        or len(refined_frames) != 60
    ):
        raise ValueError("refined monitor tracking must contain frames 798..857")
    expected_keyframes = [150, 160, 170, 180, 190, 200, 205, 209]
    actual_keyframes = [
        item.get("sourceFrame") for item in refined_frames if item.get("manualKeyframe")
    ]
    if actual_keyframes != expected_keyframes:
        raise ValueError("refined monitor tracking has unexpected manual keyframes")
    if refined_track.get("smoothingRadius") != 0:
        raise ValueError("refined monitor tracking must not use temporal smoothing")
    keyframes_path = ROOT / "src" / monitor_screen.get("keyframes", "")
    if not keyframes_path.is_file():
        raise ValueError("monitorScreen.keyframes must exist in src")

    green_test = manifest.get("greenMonitorTest")
    if not isinstance(green_test, dict):
        raise ValueError("greenMonitorTest is required")
    expected_green_inserts = {
        "insert": (783, 888, 0),
        "returnInsert": (888, 948, 240),
    }
    for key, expected in expected_green_inserts.items():
        item = green_test.get(key)
        if not isinstance(item, dict):
            raise ValueError(f"greenMonitorTest.{key} is required")
        start, end = frame_range(item, f"greenMonitorTest.{key}", duration)
        if (start, end, item.get("sourceStartFrame")) != expected:
            raise ValueError(f"greenMonitorTest.{key} has unexpected splice timing")
        path = item.get("path")
        if not isinstance(path, str) or not (ROOT / "public" / path).is_file():
            raise ValueError(f"greenMonitorTest.{key}.path must exist in public")
    return_lens_cover = green_test["returnInsert"].get("lensCover")
    if not isinstance(return_lens_cover, dict):
        raise ValueError("greenMonitorTest.returnInsert must retain the lens cover")
    if (
        return_lens_cover.get("startFrame"),
        return_lens_cover.get("endFrame"),
        return_lens_cover.get("scale"),
    ) != (888, 930, 7.5):
        raise ValueError("green monitor return lens cover has unexpected timing")

    if "interruption" in manifest:
        raise ValueError("interruption card is forbidden; end on Fukuchan's hand over the lens")

    caption_text = "\n".join(item["text"] for item in manifest["captions"])
    for forbidden in (
        "ノンアル",
        "麦茶",
        "最近のお茶って",
        "配信が中断されました",
        "やでー",
    ):
        if forbidden in caption_text:
            raise ValueError(f"obsolete caption text remains: {forbidden}")
    if "かんぱーい！" not in caption_text:
        raise ValueError("Sobaya's required toast caption is missing")
    if "普通の会社は\n酒ダメなん？" not in caption_text:
        raise ValueError("Yametaro's clueless workplace-alcohol caption is missing")
    for required in (
        "配信するやで！",
        "カメラ止めろって！",
        "何見てるん？ 見せてや！",
    ):
        if required not in caption_text:
            raise ValueError(f"Yametaro's crisp ending is missing: {required}")

    required_comments = {
        "見てるぞー",
        "やめさん働いてたの？",
        "許可とか取ってるのかな？",
        "👆やめ太郎が取ってるわけないだろ",
        "驚いております！",
        "大変驚いております！",
        "ヤバい仮面の男キター",
        "え、仕事中にビール？",
        "🍺🍺🍺🍺🍺",
        "認めてて草",
        "乾杯すな",
        "冗談じゃないの怖",
        "常識どこに置いてきた",
        "会社以前の問題だろ",
        "こいつマジもんや",
        "社外秘全画面は終わった",
        "情報漏えいRTA世界新",
    }
    actual_comments = {item["text"] for item in manifest["comments"]}
    missing = sorted(required_comments - actual_comments)
    if missing:
        raise ValueError(f"required comments missing: {missing}")

    obsolete_opening_comments = {
        "勝手に入ってて草",
        "無職に入館証渡した奴だれだよ",
        "これ生配信でええんか？",
    }
    remaining_obsolete = sorted(obsolete_opening_comments & actual_comments)
    if remaining_obsolete:
        raise ValueError(f"obsolete opening comments remain: {remaining_obsolete}")

    okayaman_comments = [
        item for item in manifest["comments"] if item.get("author") == "okayaman"
    ]
    if len(okayaman_comments) != 3:
        raise ValueError("exactly three Okayaman comments are required")
    for item in okayaman_comments:
        if "おかやまん" in item["text"]:
            raise ValueError("Okayaman must be identified by icon, not by name in comment text")

    print(
        "Valid livestream manifest: "
        f"{len(live_ranges)} live segment(s), "
        f"{len(manifest['comments'])} comment(s), "
        f"{len(manifest['captions'])} caption(s)"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
