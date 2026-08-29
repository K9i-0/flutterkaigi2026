#!/usr/bin/env bash
set -euo pipefail

remotion_dir="$(cd "$(dirname "$0")/.." && pwd)"
repo_dir="$(git -C "$remotion_dir" rev-parse --show-toplevel)"
python_bin="$repo_dir/.local/screen-replacement-venv/bin/python"

if [[ ! -x "$python_bin" ]]; then
  echo "OpenCV environment not found: $python_bin" >&2
  exit 1
fi

cd "$remotion_dir"
mkdir -p out

"$python_bin" scripts/track_monitor.py public/fukuchan-pov.mp4 \
  --source-start 150 --source-end 209 --composition-start 798 \
  --corners '126,91;655,99;648,382;141,438' \
  --canonical-width 1000 --canonical-height 600 --smoothing-radius 0 \
  --output out/monitor-track-raw.json \
  --preview out/monitor-track-raw-preview.mp4

"$python_bin" scripts/refine_monitor_track.py out/monitor-track-raw.json \
  --keyframes src/monitor-track-keyframes.json \
  --output src/monitor-track-refined.json \
  --input-video public/fukuchan-pov.mp4 \
  --reference-track src/monitor-track.json \
  --preview out/monitor-track-refined-preview.mp4

npx remotion still src/index.ts MonitorScreenSource out/monitor-screen-source.png --frame=0 --overwrite

"$python_bin" scripts/composite_tracked_screen.py \
  public/fukuchan-pov.mp4 \
  --screen out/monitor-screen-source.png \
  --track-json src/monitor-track-refined.json \
  --output public/fukuchan-pov-opencv-refined.mp4 \
  --edge-inset 2 \
  --feather 1.2 \
  --overwrite

npx remotion render src/index.ts YameChannelLiveOpenCV out/livestream_opencv_refined_comparison.mp4 \
  --codec=h264 --crf=18 --audio-codec=aac --overwrite

ffmpeg -hide_banner -loglevel error -y \
  -i ../final_remotion_livestream.mp4 \
  -i out/livestream_opencv_refined_comparison.mp4 \
  -filter_complex \
  "[0:v]trim=start_frame=783:end_frame=870,setpts=PTS-STARTPTS,drawtext=text='OLD SMOOTHED':fontcolor=white:fontsize=20:x=18:y=18:box=1:boxcolor=black@0.72:boxborderw=8[left];[1:v]trim=start_frame=783:end_frame=870,setpts=PTS-STARTPTS,drawtext=text='REFINED TRACK':fontcolor=white:fontsize=20:x=18:y=18:box=1:boxcolor=black@0.72:boxborderw=8[right];[left][right]hstack=inputs=2[v]" \
  -map "[v]" -an -c:v libx264 -crf 18 -pix_fmt yuv420p \
  out/monitor_refined_comparison.mp4

ffmpeg -hide_banner -loglevel error -y \
  -i out/monitor_refined_comparison.mp4 \
  -vf "select=eq(n\,74)" -frames:v 1 out/monitor_refined_comparison_end.png

echo "Refined tracking preview: $remotion_dir/out/monitor-track-refined-preview.mp4"
echo "Refined full comparison: $remotion_dir/out/livestream_opencv_refined_comparison.mp4"
echo "Old/refined side-by-side: $remotion_dir/out/monitor_refined_comparison.mp4"
echo "End-motion still: $remotion_dir/out/monitor_refined_comparison_end.png"
