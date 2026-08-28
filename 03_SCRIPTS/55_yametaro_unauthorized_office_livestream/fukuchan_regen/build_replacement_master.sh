#!/bin/bash
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
EPISODE_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
OUT="$SCRIPT_DIR/dialogue_master_fukuchan_regen_31_6s.wav"

ffmpeg -y -v error \
  -i "$EPISODE_DIR/audio/dialogue_master_31_6s.wav" \
  -i "$SCRIPT_DIR/wan3_fukuchan_regen_seed550031_480p.mp4" \
  -i "$EPISODE_DIR/fukuchan_pov_regen/wan3_fukuchan_pov_seed550032_480p.mp4" \
  -i "$SCRIPT_DIR/fukuchan_stop_camera_seed100.wav" \
  -i "$SCRIPT_DIR/yametaro_keep_pestering_seed100.wav" \
  -filter_complex "[0:a]atrim=duration=17.6,asetpts=PTS-STARTPTS[front];[1:a]atrim=start=0:end=1.2,asetpts=PTS-STARTPTS,volume=0.58,adelay=17600:all=1[old_intro];[2:a]atrim=start=1.2:end=4.2,asetpts=PTS-STARTPTS,atempo=0.8,volume=0.58,adelay=18800:all=1[pov_warn];[1:a]atrim=start=4.966667:end=8.5,asetpts=PTS-STARTPTS,volume=0.58,adelay=22567:all=1[old_middle];[2:a]atrim=start=4.5:end=10.0,asetpts=PTS-STARTPTS,volume=0.64,adelay=26100:all=1[pov_monitor];[3:a]loudnorm=I=-16:TP=-2:LRA=7,adelay=18800:all=1[fuku];[4:a]loudnorm=I=-17:TP=-2:LRA=7,adelay=22600:all=1[yame];[front][old_intro][pov_warn][old_middle][pov_monitor][fuku][yame]amix=inputs=7:duration=longest:normalize=0,alimiter=limit=0.95,atrim=duration=31.6,aresample=48000[a]" \
  -map "[a]" -ac 2 -ar 48000 -c:a pcm_s16le "$OUT"

ffprobe -v error -show_entries format=duration:stream=sample_rate,channels -of json "$OUT"
