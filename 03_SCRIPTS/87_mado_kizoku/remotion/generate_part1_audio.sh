#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
mkdir -p .local/mado-kizoku-part1
IRODORI_TTS_CHECKPOINT=Aratako/Irodori-TTS-v4-Large IRODORI_CFG_SCALE_TEXT=5 tools/irodori_speak.sh 'やはり、労働をサボっていただくおビールは格別ですわね。' .local/mado-kizoku-part1/sobaya_raw.wav 02_CHARACTERS/Sobaya_voice.wav 42 '優雅なお嬢様口調。くつろいで、満足そうに話す。'
tools/sobaya_monsterize.sh .local/mado-kizoku-part1/sobaya_raw.wav .local/mado-kizoku-part1/sobaya.wav
IRODORI_TTS_CHECKPOINT=Aratako/Irodori-TTS-v4.1-Small IRODORI_CFG_SCALE_TEXT=5 IRODORI_UNCUT=1 IRODORI_DURATION_SCALE=0.65 tools/irodori_speak.sh 'こちらのお菓子もギュンですわ。' .local/mado-kizoku-part1/fukuchan_fit.wav 02_CHARACTERS/Fukuchan_voice.wav 100
IRODORI_TTS_CHECKPOINT=Aratako/Irodori-TTS-v4.1-Small IRODORI_CFG_SCALE_TEXT=5 IRODORI_UNCUT=1 IRODORI_DURATION_SCALE=0.35 tools/irodori_speak.sh '来客用ですわ。' .local/mado-kizoku-part1/yametaro_fit.wav 02_CHARACTERS/Yametaro_voice.wav 7
