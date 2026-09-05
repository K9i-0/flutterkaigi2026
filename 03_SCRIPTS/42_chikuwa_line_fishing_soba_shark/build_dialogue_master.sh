#!/bin/bash
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
NO_VOCALS_AUDIO="$SCRIPT_DIR/audio/no_vocals.wav"
OUT="$SCRIPT_DIR/audio/dialogue_master_30s.wav"

LINE1="$SCRIPT_DIR/audio/line01_yotan_omoi.wav"
LINE2="$SCRIPT_DIR/audio/line02_fukuchan_maite_subtle.wav"
LINE3="$SCRIPT_DIR/audio/line03_fukuchan_daichikuwa_subtle.wav"
LINE4="$SCRIPT_DIR/audio/line04_fukuchan_samedayo_subtle.wav"
LINE5="$SCRIPT_DIR/audio/line05_yotan_nandakoitsu.wav"
LINE6="$SCRIPT_DIR/audio/line06_fukuchan_biiru_subtle.wav"
LINE7="$SCRIPT_DIR/audio/line07_sobaya_kanpai.wav"

ffmpeg -y -v error \
  -i "$NO_VOCALS_AUDIO" \
  -i "$LINE1" \
  -i "$LINE2" \
  -i "$LINE3" \
  -i "$LINE4" \
  -i "$LINE5" \
  -i "$LINE6" \
  -i "$LINE7" \
  -filter_complex "
    [0:a]volume='if(between(t,0.3,5.1)+between(t,6.0,9.6)+between(t,12.2,15.1)+between(t,16.5,19.2)+between(t,22.5,24.8)+between(t,26.0,28.15), 0.0, 1.0)':eval=frame[bg];
    [1:a]loudnorm=I=-14:TP=-1.5:LRA=7,adelay=300:all=1[v1];
    [2:a]loudnorm=I=-13.5:TP=-1.5:LRA=7,adelay=2000:all=1[v2];
    [3:a]loudnorm=I=-13.5:TP=-1.5:LRA=7,adelay=6000:all=1[v3];
    [4:a]loudnorm=I=-13:TP=-1.5:LRA=7,adelay=12200:all=1[v4];
    [5:a]loudnorm=I=-13.5:TP=-1.5:LRA=7,adelay=16500:all=1[v5];
    [6:a]loudnorm=I=-14:TP=-1.5:LRA=7,adelay=22500:all=1[v6];
    [7:a]loudnorm=I=-13:TP=-1.5:LRA=7,adelay=26800:all=1[v7];
    [bg][v1][v2][v3][v4][v5][v6][v7]amix=inputs=8:duration=first:dropout_transition=0:normalize=0,alimiter=limit=0.95,atrim=duration=30.02,aresample=44100[a]
  " \
  -map "[a]" -ac 2 -ar 44100 -c:a pcm_s16le "$OUT"

echo "=== Master Audio Built with Tuned Cast ==="
ffprobe -v error -show_entries format=duration:stream=sample_rate,channels -of json "$OUT"
