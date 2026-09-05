#!/usr/bin/env python3
"""Validate the Mushoku Abel livestream UI manifest."""

from __future__ import annotations

import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT / "src" / "edit-manifest.json"
PUBLIC = ROOT / "public"


def main() -> None:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    composition = manifest["composition"]
    duration = composition["durationInFrames"]
    assert composition == {
        "id": "MushokuAbelDebut",
        "width": 832,
        "height": 480,
        "fps": 30,
        "durationInFrames": 540,
    }
    assert manifest["stream"]["title"] == "窓際コンサル系VTuber 無職アベル"
    assert manifest["stream"]["tag"] == "初配信"
    assert manifest["stream"]["liveLabel"] == "LIVE"

    expected = {
        "okayaman": ("おかやまん", "見てるぞー", "avatar_okayaman.jpg"),
        "sobaya": ("そば屋", "ちゃんと聞こえてるで", "avatar_sobaya.jpg"),
        "fukuchan": ("福ちゃん", "デビューおめでとぎゅん！", "avatar_fukuchan.jpg"),
        "takosan": ("たこさん", "窓際から世界へ", "avatar_takosan.png"),
        "viewer_shoken": ("初見の社畜", "えっ、上司！？", "viewer_avatar_necktie.svg"),
        "viewer_madobe_cat": ("窓辺の猫", "上司から1万円飛んできたw", "viewer_avatar_cat.svg"),
        "viewer_teiji_dash": ("定時ダッシュ", "初配信から監視つきで草", "viewer_avatar_coffee.svg"),
        "yotan": ("よーたん", "部長、巡回お疲れさまです", "avatar_yotan.jpg"),
    }
    comments = manifest["comments"]
    assert len(comments) == len(expected)
    for comment in comments:
        author = comment["author"]
        assert author in expected
        display_name, text, avatar = expected[author]
        assert comment["displayName"] == display_name
        assert comment["text"] == text
        assert comment["avatar"] == avatar
        assert 0 <= comment["startFrame"] < comment["endFrame"] <= duration
        assert (PUBLIC / avatar).is_file(), f"missing avatar: {avatar}"

    featured = [comment for comment in comments if comment.get("featured")]
    assert len(featured) == 1
    assert featured[0]["author"] == "okayaman"
    assert featured[0]["endFrame"] == duration
    assert featured[0]["kind"] == "superchat"
    assert featured[0]["amount"] == "¥10,000"

    member_authors = {"okayaman", "sobaya", "fukuchan", "takosan", "yotan"}
    surprised = {"viewer_shoken", "viewer_madobe_cat", "viewer_teiji_dash"}
    assert surprised.isdisjoint(member_authors)
    for comment in comments:
        if comment["author"] in surprised:
            assert comment["startFrame"] >= 276
    assert "上司" not in next(c["text"] for c in comments if c["author"] == "yotan")

    print(f"Valid Mushoku Abel livestream manifest: {duration} frames, {len(comments)} viewer comments")


if __name__ == "__main__":
    main()
