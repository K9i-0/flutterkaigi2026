#!/bin/bash
# そば屋のIrodori-TTS出力へ正典のモンスターボイス加工を適用する。
# Usage: sobaya_monsterize.sh INPUT.wav OUTPUT.wav
set -eu

INPUT="${1:?入力WAVを指定してください}"
OUTPUT="${2:?出力WAVを指定してください。入力とは別のパスにしてください}"

[ -f "$INPUT" ] || { echo "ERROR: 入力WAVが見つかりません: $INPUT" >&2; exit 1; }
[ "$INPUT" != "$OUTPUT" ] || { echo "ERROR: 入力を保護するため別の出力パスを指定してください" >&2; exit 1; }
command -v ffmpeg >/dev/null || { echo "ERROR: ffmpegが必要です" >&2; exit 1; }
command -v ffprobe >/dev/null || { echo "ERROR: ffprobeが必要です" >&2; exit 1; }

SAMPLE_RATE="$(ffprobe -v error -select_streams a:0 -show_entries stream=sample_rate -of csv=p=0 "$INPUT")"
[ -n "$SAMPLE_RATE" ] && [ "$SAMPLE_RATE" -gt 0 ] || { echo "ERROR: サンプルレートを取得できません: $INPUT" >&2; exit 1; }

ffmpeg -y -v error -i "$INPUT" \
  -af "asetrate=${SAMPLE_RATE}*0.7492,aresample=${SAMPLE_RATE},atempo=1.3348,tremolo=f=70:d=0.5,dynaudnorm" \
  -sample_fmt s16 "$OUTPUT"

[ "$(head -c 4 "$OUTPUT")" = "RIFF" ] || { echo "ERROR: 加工後WAVを生成できませんでした: $OUTPUT" >&2; exit 1; }
DURATION="$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 "$OUTPUT")"
echo "OK: $OUTPUT (${DURATION}s, pitch=-5 semitones, tremolo=70Hz)"
