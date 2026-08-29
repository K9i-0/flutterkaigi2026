#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
EPISODE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
REMOTION_DIR="$EPISODE_DIR/remotion"
TEST_DIR="$EPISODE_DIR/monitor_green_test"
PYTHON="$REPO_DIR/.local/screen-replacement-venv/bin/python"

"$PYTHON" "$SCRIPT_DIR/track_green_monitor.py" \
  "$TEST_DIR/wan3_monitor_green_seed550033_480p.mp4" \
  --output-json "$TEST_DIR/monitor-green-track.json" \
  --preview "$TEST_DIR/monitor-green-track-preview.mp4"

"$PYTHON" "$SCRIPT_DIR/composite_tracked_screen.py" \
  "$TEST_DIR/wan3_monitor_green_seed550033_480p.mp4" \
  --screen "$REMOTION_DIR/out/monitor-screen-source.png" \
  --track-json "$TEST_DIR/monitor-green-track.json" \
  --output "$TEST_DIR/monitor-green-replaced-video-only.mp4" \
  --edge-inset 0 \
  --feather 0.8 \
  --fade-in 0 \
  --fade-out 0 \
  --overwrite

ffmpeg -y -hide_banner -loglevel error \
  -i "$TEST_DIR/monitor-green-replaced-video-only.mp4" \
  -i "$TEST_DIR/wan3_monitor_green_seed550033_480p.mp4" \
  -map 0:v:0 -map '1:a:0?' \
  -c:v copy -c:a aac -b:a 192k -t 4 \
  "$TEST_DIR/monitor-green-replaced.mp4"

ffmpeg -y -hide_banner -loglevel error \
  -i "$TEST_DIR/wan3_monitor_green_seed550033_480p.mp4" \
  -i "$TEST_DIR/monitor-green-replaced.mp4" \
  -filter_complex "[0:v]scale=624:360,drawbox=x=0:y=0:w=iw:h=34:color=black@0.72:t=fill,drawtext=text='WAN GREEN INPUT':x=14:y=8:fontsize=20:fontcolor=white[left];[1:v]scale=624:360,drawbox=x=0:y=0:w=iw:h=34:color=black@0.72:t=fill,drawtext=text='TRACKED REPLACEMENT':x=14:y=8:fontsize=20:fontcolor=white[right];[left][right]hstack=inputs=2[v]" \
  -map '[v]' -map '1:a:0?' \
  -c:v libx264 -crf 18 -preset medium -c:a aac -b:a 192k -t 4 \
  "$TEST_DIR/monitor-green-comparison.mp4"
