#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
input="${1:-$script_dir/wan3_raw_seed260826_480p.mp4}"
output="${2:-$script_dir/sobaya_hazard_trailer_30s_seed260826_480p.mp4}"

if [[ ! -f "$input" ]]; then
  echo "Input video not found: $input" >&2
  exit 2
fi

cd "$script_dir"

ffmpeg -nostdin -y \
  -i "$input" \
  -loop 1 -i logo_sobaya_hazard_master.png \
  -filter_complex "[0:v]subtitles=subtitles_ja.ass:fontsdir=/System/Library/Fonts,split[ref][base];[1:v][ref]scale=w=rw:h=rh:flags=lanczos[logo];[base][logo]overlay=0:0:enable='gte(t,27.2)'[outv]" \
  -map "[outv]" -map 0:a? \
  -c:v libx264 -preset slow -crf 16 -pix_fmt yuv420p \
  -c:a aac -b:a 192k -t 30 \
  "$output"

ffprobe -v error \
  -show_entries format=duration:stream=index,codec_type,codec_name,width,height,avg_frame_rate \
  -of json "$output"
