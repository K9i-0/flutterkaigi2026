#!/usr/bin/env python3
"""Export the shipped game's text plus its runtime story structure, without deps."""
from __future__ import annotations

import argparse
import collections
import hashlib
import json
from pathlib import Path
import re
import subprocess
import sys

LAB = Path(__file__).resolve().parents[1]
ROOT = LAB.parent
OUTPUT = LAB / "scenario/game_text.json"
EXCLUDED = {
    "game_automation.dart", "game_benchmark.dart", "game_debug_probe.dart",
    "game_native_audit.dart", "campaign_audit.dart",
}
JAPANESE = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def repo_path(path: Path) -> str:
    return str(path.relative_to(ROOT))


def decode_dart(value: str) -> str:
    escapes = {"n": "\n", "r": "\r", "t": "\t", "b": "\b", "f": "\f", "v": "\v"}
    def replace(match):
        code = match.group(1)
        if code.startswith("u{"):
            return chr(int(code[2:-1], 16))
        if code[0] in ("u", "x") and len(code) > 1:
            return chr(int(code[1:], 16))
        return escapes.get(code, code)
    return re.sub(r"\\(u\{[0-9a-fA-F]+\}|u[0-9a-fA-F]{4}|x[0-9a-fA-F]{2}|.)", replace, value)


class DartStrings:
    """A lexical scanner, including nested ${... 'string' ...} and comments.

    This is deliberately NOT a Dart evaluator. Templates retain exact Dart
    expressions; event/dialogue semantics come from the actual Dart runtime.
    """
    def __init__(self, text: str):
        self.text = text
        self.rows = []

    def skip_comment(self, i):
        s = self.text
        if s.startswith("//", i):
            end = s.find("\n", i)
            return len(s) if end < 0 else end
        if s.startswith("/*", i):
            depth, j = 1, i + 2
            while j < len(s) and depth:
                if s.startswith("/*", j): depth, j = depth + 1, j + 2
                elif s.startswith("*/", j): depth, j = depth - 1, j + 2
                else: j += 1
            if depth: raise ValueError("Unclosed Dart comment")
            return j
        return None

    def scan_string(self, start, nested=False):
        s, i = self.text, start
        raw = s[i] == 'r'
        if raw: i += 1
        quote = s[i]
        delimiter = quote * (3 if s.startswith(quote * 3, i) else 1)
        content_start = i + len(delimiter)
        i, template = content_start, False
        while i < len(s):
            if s.startswith(delimiter, i):
                end = i + len(delimiter)
                value = s[content_start:i]
                self.rows.append({
                    "start": start, "end": end, "raw": s[start:end],
                    "text": value if raw else decode_dart(value),
                    "template": template, "nestedInterpolation": nested,
                })
                return end
            if not raw and s[i] == "\\":
                i += 2
                continue
            if not raw and s.startswith("${", i):
                template = True
                i = self.scan_expression(i + 2)
                continue
            if not raw and s[i] == "$" and i + 1 < len(s) and re.match(r"[A-Za-z_]", s[i + 1]):
                template = True
            i += 1
        raise ValueError(f"Unclosed Dart string at {start}")

    def scan_expression(self, i):
        s, depth = self.text, 1
        while i < len(s):
            comment = self.skip_comment(i)
            if comment is not None: i = comment; continue
            if s[i] in "\"'" or (s[i] == 'r' and i + 1 < len(s) and s[i + 1] in "\"'"):
                i = self.scan_string(i, nested=True); continue
            if s[i] == '{': depth += 1
            if s[i] == '}':
                depth -= 1
                if not depth: return i + 1
            i += 1
        raise ValueError("Unclosed Dart interpolation")

    def scan(self):
        s, i = self.text, 0
        while i < len(s):
            comment = self.skip_comment(i)
            if comment is not None: i = comment; continue
            if s[i] in "\"'" or (s[i] == 'r' and i + 1 < len(s) and s[i + 1] in "\"'"):
                i = self.scan_string(i); continue
            i += 1
        rows = sorted(self.rows, key=lambda r: r["start"])
        # Dart's adjacent literals are one string, even across comments/newlines.
        result = []
        for row in rows:
            if result and not row["nestedInterpolation"] and not result[-1]["nestedInterpolation"]:
                previous = result[-1]
                between = s[previous["end"]:row["start"]]
                between = re.sub(r"/\*.*?\*/|//[^\n]*", "", between, flags=re.S)
                if not between.strip():
                    previous["end"] = row["end"]
                    previous["raw"] += row["raw"]
                    previous["text"] += row["text"]
                    previous["template"] |= row["template"]
                    continue
            result.append(row)
        return result


def anchors(source):
    pattern = re.compile(
        r"^(?:  )?(?:const\s+|(?:static\s+)?(?:late\s+)?(?:final\s+)?"
        r"(?:Widget|String\??|void|bool|double|int|Future(?:<[^\n]+?>)?|"
        r"List<[^\n]+?>|Map<[^\n]+?>|DialogueLine|EventCut\??)\s+)"
        r"(?:get\s+)?([A-Za-z_]\w*)\b", re.M)
    return [(m.start(), m.group(1)) for m in pattern.finditer(source)]


def inventory(path):
    source = path.read_text()
    rows = DartStrings(source).scan()
    points = anchors(source)
    counts = collections.Counter()
    for row in rows:
        before = source[:row["start"]]
        candidates = [name for offset, name in points if offset <= row["start"]]
        owner = candidates[-1] if candidates else "module"
        counts[owner] += 1
        row.update({
            "id": f"source:{path.stem}:{owner}:{counts[owner]}",
            "source": {"path": repo_path(path), "line": before.count("\n") + 1},
            "owner": owner,
            "context": "\n".join(source[:row["start"]].splitlines()[-3:])[-260:],
        })
        text = row["text"]
        context = row["context"]
        if not text:
            kind = "technical"
        elif JAPANESE.search(text):
            kind = "player_text"
        elif row["template"] and not re.match(r"(?:assets/|event:|dialogue:|bag-|collection-|journal-|rocket-)", text):
            kind = "dynamic_template_candidate"
        elif re.search(r"(?:Text|SelectableText|tooltip|semanticLabel|text|label|title)\s*[:(]\s*$", context):
            kind = "player_text"
        elif re.fullmatch(r"[A-Z][A-Z0-9 /\u2026.-]*", text):
            kind = "player_text_candidate"
        elif re.search(r"(?:throw|Exception|Error)\s*\(?[^\n]*$", context):
            kind = "internal_error_potentially_displayed"
        else:
            kind = "technical"
        row["kind"] = kind
    return rows


def add_sources(value, by_text):
    if isinstance(value, list):
        for child in value: add_sources(child, by_text)
    if isinstance(value, dict):
        for child in list(value.values()): add_sources(child, by_text)
        if isinstance(value.get("text"), str):
            matches = by_text.get(value["text"], [])
            if matches: value["sources"] = matches


def documents(rows):
    selected = [r for r in rows if r["owner"] == "cinematicDocuments"]
    result = []
    if len(selected) % 4:
        raise ValueError("cinematicDocuments no longer consists of key + title/body/footer string tuples; update exporter")
    for start in range(0, len(selected), 4):
        key, title, body, footer = selected[start:start + 4]
        result.append({
            "id": f"document:{key['text']}", "key": key["text"],
            "title": title["text"], "body": body["text"], "footer": footer["text"],
            "source": key["source"],
        })
    return result


def image_transcripts(images, previous, force=False):
    cache = {r["asset"]: r for r in previous.get("imageText", [])}
    result, pending = [], []
    for image in images:
        row = dict(image)
        row["sha256"] = digest(ROOT / row["source"])
        old = cache.get(row["asset"])
        if old and old.get("sha256") == row["sha256"] and not force:
            row.update({k: old[k] for k in ("ocrLines", "ocrStatus")})
        else:
            pending.append(row)
        result.append(row)
    if pending:
        command = ["swift", str(LAB / "tool/export_hazard_text_ocr.swift")]
        command += [str(ROOT / row["source"]) for row in pending]
        process = subprocess.run(command, text=True, capture_output=True, check=True)
        recognized = json.loads(process.stdout)
        for row, transcript in zip(pending, recognized, strict=True):
            if "error" in transcript:
                raise RuntimeError(f"OCR failed for {row['asset']}: {transcript['error']}")
            row["ocrLines"] = transcript["lines"]
            row["ocrStatus"] = "machine_transcription_unverified"
    return result


def build(previous, force_ocr):
    files = sorted(p for p in (LAB / "lib/game").glob("*.dart") if p.name not in EXCLUDED)
    files.append(LAB / "lib/game_main.dart")
    rows_by_file = {path.name: inventory(path) for path in files}
    rows = [row for group in rows_by_file.values() for row in group]
    by_text = collections.defaultdict(list)
    for row in rows:
        by_text[row["text"]].append(row["source"])
    process = subprocess.run(
        ["mise", "exec", "--", "dart", "run", "tool/export_hazard_text_runtime.dart"],
        cwd=LAB, text=True, capture_output=True, check=True)
    runtime = json.loads(process.stdout)
    declared_tables = set(re.findall(
        r"const\s+(\w+)\s*=\s*<String,\s*List<DialogueLine>>",
        (LAB / "lib/game/game_dialogue.dart").read_text()))
    registered_tables = set(runtime["dialogueTableSourceNames"])
    if declared_tables != registered_tables:
        raise ValueError(f"Dialogue tables changed; update runtime exporter: added={sorted(declared_tables - registered_tables)}, removed={sorted(registered_tables - declared_tables)}")
    declared_special = set(re.findall(
        r"const\s+(\w+)\s*=\s*DialogueLine\(",
        (LAB / "lib/game/game_dialogue.dart").read_text()))
    exported_special = {name for name in runtime["specialDialogue"] if not name.startswith("purchase:")}
    if declared_special != exported_special:
        raise ValueError(f"Conditional lines changed; update runtime exporter: added={sorted(declared_special - exported_special)}, removed={sorted(exported_special - declared_special)}")
    add_sources(runtime, by_text)
    # Explicit semantic IDs survive wording edits; list indices preserve order.
    for owner, topics in runtime["dialogueTrees"].items():
        for topic, lines in topics.items():
            for i, line in enumerate(lines):
                line.update({"id": f"dialogue:{owner}:{topic}:{i}", "order": i})
    variant_counts = collections.Counter()
    for variant in runtime["resolvedDialogueVariants"]:
        key = f"{variant['owner']}:{variant['topic']}"
        index = variant_counts[key]
        variant_counts[key] += 1
        variant["id"] = f"resolved-dialogue:{key}:{index}"
        for i, line in enumerate(variant["lines"]):
            line.update({"id": f"{variant['id']}:{i}", "order": i})
    for event in runtime["events"]:
        for shot in event["shots"]:
            shot["condition"] = (
                {"read": f"foundMemos contains {shot['readMemo']}",
                 "unread": f"foundMemos does not contain {shot['readMemo']}"}
                if shot["readMemo"] else {"branch": "unconditional within event"})
            if shot.get("unreadText"):
                shot["unreadSources"] = by_text[shot["unreadText"]]
    maps, images, json_sources = [], [], []
    for region in ["village", "farm", "mountain"]:
        path = LAB / f"assets/{region}.json"
        data = json.loads(path.read_text())
        json_sources.append(path)
        maps.append({
            "id": region, "label": data["label"], "subtitle": data["subtitle"],
            "source": repo_path(path.resolve()),
            "npcs": data.get("npcs", []), "exits": data.get("exits", []),
            "posters": [{"id": p["id"], "title": p["title"], "source": p["source"]}
                        for p in data.get("collection", [])],
        })
        for poster in data.get("collection", []):
            images.append({
                "id": f"image:poster:{poster['id']}", "asset": f"assets/collection/{poster['id']}.png",
                "source": repo_path((LAB / f"assets/collection/{poster['id']}.png").resolve()),
                "title": poster["title"], "usage": "collected poster full-resolution viewer",
            })
    for path in sorted((LAB / "assets/cinematics").glob("*.png")):
        images.append({"id": f"image:cinematic:{path.stem}",
                       "asset": f"assets/cinematics/{path.name}",
                       "source": repo_path(path.resolve()),
                       "usage": "cinematic illustration or title logo"})
    player_rows, technical_count = [], 0
    for row in rows:
        if row["kind"] == "technical":
            technical_count += 1
            continue
        player_rows.append({
            "id": row["id"], "text": row["text"],
            "usage": row["kind"], "scope": row["owner"],
            "source": row["source"],
            "condition": {"status": "inferred_from_source_context", "context": row["context"]},
            **({"templateSyntax": "Dart interpolation; $variable and ${expression} are unevaluated",
                "dartLiteral": row["raw"]} if row["template"] else {}),
            **({"nestedInterpolationBranch": True} if row["nestedInterpolation"] else {}),
        })
    template_only = [r for r in player_rows if "templateSyntax" in r]
    snapshot_sources = files + json_sources + [
        LAB / "tool/export_hazard_text.py", LAB / "tool/export_hazard_text_runtime.dart",
        LAB / "tool/export_hazard_text_ocr.swift",
    ]
    return {
        "schemaVersion": 1,
        "title": "そば屋ハザード・ゲーム内テキストレビュー集",
        "scope": {
            "authoritativeText": "Dart台詞・分岐・資料・メモ・ポスター裏面・UI・操作文・通知・マップの文字列。runtimeStoryは実際のDart定数/getterから評価。sourceTextは本編ソースの網羅的な文字列候補抽出。",
            "readOrder": ["runtimeStory.events", "runtimeStory.dialogueTrees", "runtimeStory.dialogueStarts", "runtimeStory.resolvedDialogueVariants",
                          "runtimeStory.memos", "runtimeStory.posterEvidence", "cinematicDocuments", "maps", "sourceText", "imageText"],
            "branchNotes": "bossAliveはキャンペーン全体の巨大そば屋の生存状態。falseではgiant_defeatedを設定する。移動フラグrefuge_readyは標準のボス撃破／最高難度の全員撃破で設定し、家解放まで農場の商人を残す。evacuationStartedを各contexts/objectiveExamples/dialogueStarts.contextへ明示。resolvedDialogueVariantsのcontextsはgetterの評価入力で、npcPresent=falseの旧会話も比較用に収録するが実プレイでは開始不可。topicUnlockedByDialogueStateは会話getterの解禁状態、topicSelectableはNPCの存在も満たした選択肢表示可否（intro/greetingは自動会話なのでfalse）。dialogueStartsは初回/再訪/撃破後再会をstartDialogueで実行した結果。閉鎖中の家は玄関外からの拒否例を含む。旧reunion既読と新refuge_reportを区別する。未受領/受領、各メモ単独所持、全イベント既視聴などの完全な状態空間は列挙していない。解禁・発火条件はconditionSourcesを参照。",
            "imageText": "ポスター原本とカットシーン画像・ロゴの焼き込み文字をApple Visionで転記。座標・confidence付き。OCRは未校正で、装飾文字や細字の欠落・誤読・読む順の誤りがあり得る。画像の全文を完全に保証する正本ではなく、レビュー補助。ゲーム側の題名と裏書きは別途正確に収録。",
            "excluded": ["vendor/flutter_sceneおよびFlutter/OS自体の文言", "旧モデル検証ラボなどlib/game以外のUI（game_main.dartのみ含む）",
                         "自動化・ベンチマーク専用のエラー/検証用シナリオ", "ソースコメント、保存キー、内部ID、アセットパスだけの文字列",
                         "実行環境・プラグインが動的に生成する例外の全文（本編での表示テンプレートと本編定義の例外候補は収録）"],
            "stableIds": "会話はowner/topic/index、イベントはevent/index、メモ/画像/資料は既存キー。sourceTextはファイル/宣言名/文字列順で、文言の修正や無関係な行の追加では変わらない。同じ宣言への文字列挿入は後続番号を変える。",
            "templateCount": len(template_only),
            "technicalLiteralsExcluded": technical_count,
            "excludedGameFiles": sorted(EXCLUDED),
        },
        "runtimeStory": runtime,
        "cinematicDocuments": documents(rows_by_file["game_cinematic_insert.dart"]),
        "maps": maps,
        "conditionSources": condition_sources(),
        "sourceText": player_rows,
        "imageText": image_transcripts(images, previous, force_ocr),
        "sourceManifest": [{"path": repo_path(path), "sha256": digest(path)} for path in snapshot_sources],
    }


def condition_sources():
    """Full source excerpts make inferred trigger notes auditable, not invented."""
    result = []
    targets = {
        "game_state.dart": ["get knowsEngine", "get hasStoryEvidence", "get npcs", "get postBossReunion", "get evacuationStarted", "get dialogueLines", "get availableDialogueTopics", "String dialogueTopicLabel", "get visibleTradeOffers", "int stockRemaining", "void startDialogue", "void chooseDialogue", "void buySupplies", "void endDialogue"],
        "game_refuge.dart": ["get refugeUnlocked", "get insideRefuge", "get refugeReports", "get refugeComplete", "void _rememberRefugeReport", "void normalizeRefugeOccupants"],
        "game_controller.dart": ["void _finishEvent", "void startEvent", "bool transitionRegion"],
        "game_page.dart": ["Widget dialogue"],
    }
    for filename, markers in targets.items():
        path = LAB / "lib/game" / filename
        source = path.read_text()
        for marker in markers:
            start = source.find(marker)
            if start < 0: continue
            line_start = source.rfind("\n", 0, start) + 1
            match = re.search(r"\n  (?:[A-Za-z@]|///)", source[start + len(marker):])
            end = start + len(marker) + match.start() if match else len(source)
            result.append({"id": f"condition:{path.stem}:{marker.replace(' ', '_')}",
                           "source": {"path": repo_path(path), "line": source[:line_start].count("\n") + 1},
                           "code": source[line_start:end].strip()})
        if filename == "game_controller.dart":
            lines = source.splitlines()
            occurrences = collections.Counter()
            for i, code in enumerate(lines):
                event = re.search(r"startEvent\(['\"]([^'\"]+)", code)
                if event:
                    event_id = event.group(1)
                    occurrences[event_id] += 1
                    first, last = max(0, i - 7), min(len(lines), i + 5)
                    result.append({"id": f"condition:{path.stem}:event_trigger:{event_id}:{occurrences[event_id]}",
                                   "source": {"path": repo_path(path), "line": first + 1},
                                   "code": "\n".join(lines[first:last])})
    return result


def self_check():
    test = r"""// 'comment'
const x = '前${flag ? '売切' : '残${count}'}後';
const y = '一行\n' '二行';
const z = r'\nそのまま'; /* 'skip' */
"""
    rows = DartStrings(test).scan()
    assert [r["text"] for r in rows] == ["前${flag ? '売切' : '残${count}'}後", "売切", "残${count}", "一行\n二行", r"\nそのまま"]
    assert rows[0]["template"] and rows[1]["nestedInterpolation"]
    assert not rows[-1]["template"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Fail if the committed export differs from current source")
    parser.add_argument("--refresh-ocr", action="store_true", help="Rerun image OCR even if image hash is unchanged")
    args = parser.parse_args()
    self_check()
    previous = json.loads(OUTPUT.read_text()) if OUTPUT.exists() else {}
    current = build(previous, args.refresh_ocr)
    rendered = json.dumps(current, ensure_ascii=False, indent=2) + "\n"
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text() != rendered:
            print("game_text.json is stale; run python3 tool/export_hazard_text.py", file=sys.stderr)
            return 1
        print("game_text.json matches current game source and image hashes")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(rendered)
    print(f"Exported {len(current['sourceText'])} source text entries, {len(current['runtimeStory']['events'])} events, "
          f"{len(current['imageText'])} image transcripts -> {OUTPUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
