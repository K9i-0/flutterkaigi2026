#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
out=.local/chuagostini-20261003
mkdir -p "$out"
caption='Sing a short, catchy commercial brand jingle.'
for variant in word syllables; do
  case "$variant" in
    word) text='Chuagostini.' ;;
    syllables) text='Chua-go-stee-nee.' ;;
  esac
  tools/irodori_speak.sh "$text" "$out/english_${variant}_raw.wav" \
    02_CHARACTERS/Sobaya_voice.wav 42 "$caption"
  tools/sobaya_monsterize.sh "$out/english_${variant}_raw.wav" \
    "$out/english_${variant}_sobaya.wav"
done
