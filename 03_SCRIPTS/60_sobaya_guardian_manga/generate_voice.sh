#!/bin/bash
set -eu

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
AUDIO_DIR="$SCRIPT_DIR/audio"
REF="$ROOT_DIR/02_CHARACTERS/Sobaya_voice.wav"
SEED="42"
CAPTION="低く重厚な声。静かに確固たる覚悟を込めて話す。"
SPEAK_SH="$ROOT_DIR/.claude/skills/seedance/scripts/irodori_speak.sh"
MONSTER_SH="$ROOT_DIR/.claude/skills/seedance/scripts/sobaya_monsterize.sh"

# Baki style: speak the RUBY readings!
LINES=(
  "01_yametaro:やめ太郎も"
  "02_fukuchan:ギュンも"
  "03_tokun:とーくんも"
  "04_ina:いな"
  "05_okayaman:おかやまんでさえも"
  "06_orega:おれが"
  "07_mamoraneba:まもらねば"
  "08_naranu:ならぬ"
)

for item in "${LINES[@]}"; do
  KEY="${item%%:*}"
  TEXT="${item#*:}"
  RAW_WAV="$AUDIO_DIR/raw_${KEY}.wav"
  MONSTER_WAV="$AUDIO_DIR/sobaya_${KEY}.wav"
  
  echo "Generating: $KEY -> '$TEXT'"
  bash "$SPEAK_SH" "$TEXT" "$RAW_WAV" "$REF" "$SEED" "$CAPTION"
  bash "$MONSTER_SH" "$RAW_WAV" "$MONSTER_WAV"
  echo "Processed: $MONSTER_WAV"
done

echo "All ruby-voice files generated successfully!"
