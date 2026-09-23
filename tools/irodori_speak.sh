#!/bin/bash
# Irodori-TTSで正典参照音声からセリフのボイスサンプルWAVを生成する。
# Usage: IRODORI_TTS_DIR=/path/to/Irodori-TTS irodori_speak.sh TEXT OUT.wav REF.wav [SEED] [CAPTION]
# 既定は自動尺。明示的な語尾修復ではIRODORI_DURATION_SCALEで生成尺を補正できる。
set -eu

[ "$#" -le 5 ] || {
  echo "ERROR: 引数が多すぎます。固定秒数と話速倍率は廃止しました。第5引数にはcaptionだけを指定してください。" >&2
  exit 1
}

TEXT="${1:?セリフ本文を指定してください}"
OUT="${2:?出力WAVを指定してください}"
REF="${3:?正典参照WAVを指定してください}"
SEED="${4:-}"
CAPTION="${5:-}"
SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null || true)"
DEFAULT_TTS_DIR="${PROJECT_ROOT:+$PROJECT_ROOT/.local/Irodori-TTS}"
TTS_DIR="${IRODORI_TTS_DIR:-$DEFAULT_TTS_DIR}"
CHECKPOINT="${IRODORI_TTS_CHECKPOINT:-Aratako/Irodori-TTS-v4.1-Small}"

[ -f "$REF" ] || { echo "ERROR: 参照WAVが見つかりません: $REF" >&2; exit 1; }
[ -n "$TTS_DIR" ] || { echo "ERROR: IRODORI_TTS_DIRを指定してください" >&2; exit 1; }
[ -f "$TTS_DIR/infer.py" ] || { echo "ERROR: Irodori-TTSのinfer.pyが見つかりません: $TTS_DIR（tools/setup_irodori_tts.shを実行するか、IRODORI_TTS_DIRを指定してください）" >&2; exit 1; }
command -v uv >/dev/null || { echo "ERROR: uvが必要です" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpegが必要です" >&2; exit 1; }
command -v ffprobe >/dev/null || { echo "ERROR: ffprobeが必要です" >&2; exit 1; }

case "$OUT" in
  /*) ;;
  *) OUT="$PWD/$OUT" ;;
esac
case "$REF" in
  /*) ;;
  *) REF="$PWD/$REF" ;;
esac

SEED_ARGS=()
[ -n "$SEED" ] && SEED_ARGS=(--seed "$SEED")

CAPTION_ARGS=()
[ -n "$CAPTION" ] && CAPTION_ARGS=(--caption "$CAPTION")

# 比較・未加工納品用。既存の呼び出しは従来の動作を維持する。
INFERENCE_ARGS=()
case "${IRODORI_UNCUT:-0}" in
  0) ;;
  1) INFERENCE_ARGS+=(--no-trim-tail) ;;
  *) echo "ERROR: IRODORI_UNCUTは0か1を指定してください" >&2; exit 1 ;;
esac
[ -z "${IRODORI_CFG_SCALE_TEXT:-}" ] || INFERENCE_ARGS+=(--cfg-scale-text "$IRODORI_CFG_SCALE_TEXT")
if [ -n "${IRODORI_DURATION_SCALE:-}" ]; then
  awk -v value="$IRODORI_DURATION_SCALE" 'BEGIN { exit !(value ~ /^[0-9]+([.][0-9]+)?$/ && value > 0) }' || {
    echo "ERROR: IRODORI_DURATION_SCALEは0より大きい小数で指定してください" >&2
    exit 1
  }
  INFERENCE_ARGS+=(--duration-scale "$IRODORI_DURATION_SCALE")
fi

(cd "$TTS_DIR" && uv run --no-sync python infer.py \
  --hf-checkpoint "$CHECKPOINT" \
  --text "$TEXT" \
  --ref-wav "$REF" \
  --output-wav "$OUT" \
  ${SEED_ARGS[@]+"${SEED_ARGS[@]}"} \
  ${CAPTION_ARGS[@]+"${CAPTION_ARGS[@]}"} \
  ${INFERENCE_ARGS[@]+"${INFERENCE_ARGS[@]}"} >&2)

[ "$(head -c 4 "$OUT")" = "RIFF" ] || { echo "ERROR: RIFF/WAVを生成できませんでした: $OUT" >&2; exit 1; }

if [ "${IRODORI_UNCUT:-0}" != 1 ]; then
TRIMMED="${OUT%.wav}.trim.wav"
ffmpeg -y -v error -i "$OUT" \
  -af "silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.1,areverse,silenceremove=start_periods=1:start_threshold=-40dB:start_silence=0.2,areverse" \
  "$TRIMMED"
[ "$(head -c 4 "$TRIMMED")" = "RIFF" ] || { echo "ERROR: 無音トリムに失敗しました: $TRIMMED" >&2; exit 1; }
mv "$TRIMMED" "$OUT"
fi

DURATION="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUT")"
echo "OK: $OUT (${DURATION}s, checkpoint=$CHECKPOINT, ref=$(basename "$REF")${SEED:+, seed=$SEED}${CAPTION:+, caption=yes}, duration=auto, duration_scale=${IRODORI_DURATION_SCALE:-1.0}, uncut=${IRODORI_UNCUT:-0}, text_cfg=${IRODORI_CFG_SCALE_TEXT:-3.0})"
