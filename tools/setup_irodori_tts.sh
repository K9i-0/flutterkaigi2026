#!/bin/bash
# 公式Irodori-TTSをプロジェクトローカルへ導入する。
# 既存のcloneは上書きせず、依存関係だけを公式のmacOS/CPU手順で同期する。
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
TTS_DIR="${IRODORI_TTS_DIR:-$PROJECT_ROOT/.local/Irodori-TTS}"
EXPECTED_ORIGIN="https://github.com/Aratako/Irodori-TTS.git"

command -v git >/dev/null || { echo "ERROR: gitが必要です" >&2; exit 1; }
command -v uv >/dev/null || { echo "ERROR: uvが必要です" >&2; exit 1; }

if [ -e "$TTS_DIR" ]; then
  [ -d "$TTS_DIR/.git" ] || {
    echo "ERROR: 導入先は既に存在しますがIrodori-TTSのcloneではありません: $TTS_DIR" >&2
    exit 1
  }
  ACTUAL_ORIGIN="$(git -C "$TTS_DIR" remote get-url origin)"
  [ "$ACTUAL_ORIGIN" = "$EXPECTED_ORIGIN" ] || {
    echo "ERROR: originが公式リポジトリではありません: $ACTUAL_ORIGIN" >&2
    exit 1
  }
else
  mkdir -p "$(dirname -- "$TTS_DIR")"
  git clone "$EXPECTED_ORIGIN" "$TTS_DIR"
fi

(cd "$TTS_DIR" && uv sync --extra cpu)

REVISION="$(git -C "$TTS_DIR" rev-parse HEAD)"
echo "OK: Irodori-TTSを準備しました"
echo "  path: $TTS_DIR"
echo "  revision: $REVISION"
echo "  checkpoint: Aratako/Irodori-TTS-v4.1-Small（初回生成時に取得）"
