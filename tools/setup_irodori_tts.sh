#!/bin/bash
# 公式Irodori-TTSをプロジェクトローカルへ導入する。
# 既存のcloneは上書きせず、依存関係だけを公式のmacOS/CPU手順で同期する。
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel)"
MODEL="Aratako/Irodori-TTS-v4.1-Small"
DEFAULT_DIR="$PROJECT_ROOT/.local/Irodori-TTS"
case "${1:-}" in
  "") ;;
  --large) DEFAULT_DIR="$DEFAULT_DIR-large"; MODEL="Aratako/Irodori-TTS-v4-Large" ;;
  *) echo "Usage: $0 [--large]" >&2; exit 1 ;;
esac
TTS_DIR="${IRODORI_TTS_DIR:-$DEFAULT_DIR}"
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
# scipy 1.15.3 macOS wheel has invalid Mach-O thread_bss; use the verified wheel.
if [ "$(uname -s)" = Darwin ]; then
  uv pip install --python "$TTS_DIR/.venv/bin/python" 'scipy==1.14.1'
fi
"$TTS_DIR/.venv/bin/python" -c 'from transformers import AutoModel, AutoTokenizer'


REVISION="$(git -C "$TTS_DIR" rev-parse HEAD)"
echo "OK: Irodori-TTSを準備しました"
echo "  path: $TTS_DIR"
echo "  revision: $REVISION"
echo "  checkpoint: ${MODEL}（初回生成時に取得）"
