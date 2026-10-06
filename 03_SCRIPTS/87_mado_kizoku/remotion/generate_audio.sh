#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../../.."
mkdir -p .local/mado-kizoku-audio
export IRODORI_TTS_CHECKPOINT=Aratako/Irodori-TTS-v4-Large
export IRODORI_CFG_SCALE_TEXT=5
tools/irodori_speak.sh '今度のプロジェクト、おコードがクソでしたわ。ペットのおさるにでも書かせたのかしら？' .local/mado-kizoku-audio/sobaya_insult_raw.wav 02_CHARACTERS/Sobaya_voice.wav 42 '優雅なお嬢様口調で、平然と毒舌を言う。自然な会話。'
tools/sobaya_monsterize.sh .local/mado-kizoku-audio/sobaya_insult_raw.wav .local/mado-kizoku-audio/sobaya_insult.wav
tools/irodori_speak.sh 'えーあいには出せない、人のぬくもりを感じましたわ。' .local/mado-kizoku-audio/sobaya_praise_raw.wav 02_CHARACTERS/Sobaya_voice.wav 42 '一瞬ためらい、丁寧なお嬢様口調で取り繕う。'
tools/sobaya_monsterize.sh .local/mado-kizoku-audio/sobaya_praise_raw.wav .local/mado-kizoku-audio/sobaya_praise.wav
IRODORI_TTS_CHECKPOINT=Aratako/Irodori-TTS-v4.1-Small IRODORI_UNCUT=1 tools/irodori_speak.sh 'ほんばんも、おもえになってますわ。' .local/mado-kizoku-audio/takosan_small.wav 02_CHARACTERS/Takosan_voice.wav 43
IRODORI_UNCUT=1 IRODORI_DURATION_SCALE=1 tools/irodori_speak.sh 'あのコードなら、ぜんぶワイが、かいてましてよ。' .local/mado-kizoku-audio/yametaro_kana.wav 02_CHARACTERS/Yametaro_voice.wav 7 '淡々と静かな圧をかける。自慢しない。'
