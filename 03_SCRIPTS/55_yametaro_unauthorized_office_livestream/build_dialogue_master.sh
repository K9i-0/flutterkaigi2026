#!/bin/bash
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
SOURCE_VIDEO="$SCRIPT_DIR/wan3_result_seed550030_480p_lipsync.mp4"
OUT="$SCRIPT_DIR/audio/dialogue_master_31_6s.wav"

ffmpeg -y -v error \
  -i "$SOURCE_VIDEO" \
  -i "$SCRIPT_DIR/audio/yametaro_01_start_seed100.wav" \
  -i "$SCRIPT_DIR/audio/yametaro_02_sobaya_intro_seed100.wav" \
  -i "$SCRIPT_DIR/audio/sobaya_01_kanpai_seed42_monster.wav" \
  -i "$SCRIPT_DIR/audio/yametaro_03_office_alcohol_question_seed100.wav" \
  -i "$SCRIPT_DIR/audio/yametaro_04_fukuchan_greeting_seed100.wav" \
  -i "$SCRIPT_DIR/audio/fukuchan_01_stop_seed100.wav" \
  -filter_complex "[0:a]atrim=start=20.8:end=23.1,asetpts=PTS-STARTPTS,volume=0.12,aloop=loop=-1:size=101430,atrim=duration=31.6[amb];[1:a]loudnorm=I=-17:TP=-2:LRA=7,adelay=1000:all=1[y1];[2:a]loudnorm=I=-17:TP=-2:LRA=7,adelay=4850:all=1[y2];[3:a]loudnorm=I=-16:TP=-2:LRA=7,adelay=12300:all=1[s1];[4:a]loudnorm=I=-17:TP=-2:LRA=7,adelay=13750:all=1[y3];[5:a]loudnorm=I=-17:TP=-2:LRA=7,adelay=17650:all=1[y4];[6:a]loudnorm=I=-16:TP=-2:LRA=7,adelay=27500:all=1[f1];[amb][y1][y2][s1][y3][y4][f1]amix=inputs=7:duration=longest:normalize=0,alimiter=limit=0.95,atrim=duration=31.6,aresample=48000[a]" \
  -map "[a]" -ac 2 -ar 48000 -c:a pcm_s16le "$OUT"

ffprobe -v error -show_entries format=duration:stream=sample_rate,channels -of json "$OUT"
