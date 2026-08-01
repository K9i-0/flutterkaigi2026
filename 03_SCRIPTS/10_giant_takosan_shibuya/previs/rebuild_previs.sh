#!/usr/bin/env bash
set -euo pipefail

PREVIS_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREVIS_BLENDER_BIN="${PREVIS_BLENDER_BIN:-/opt/homebrew/bin/blender}"
PREVIS_FFMPEG_BIN="${PREVIS_FFMPEG_BIN:-ffmpeg}"
PREVIS_MAGICK_BIN="${PREVIS_MAGICK_BIN:-magick}"
PREVIS_TMP_ROOT="${TMPDIR:-/tmp}"
PREVIS_TMP_DIR="$(mktemp -d "${PREVIS_TMP_ROOT%/}/giant_takosan_previs.XXXXXX")"

cleanup_previs_tmp() {
  case "${PREVIS_TMP_DIR}" in
    */giant_takosan_previs.*) rm -rf -- "${PREVIS_TMP_DIR}" ;;
    *) printf 'Unsafe temporary path; retained: %s\n' "${PREVIS_TMP_DIR}" >&2 ;;
  esac
}
trap cleanup_previs_tmp EXIT

"${PREVIS_BLENDER_BIN}" --background --python "${PREVIS_SCRIPT_DIR}/build_previs.py"

"${PREVIS_BLENDER_BIN}" \
  --background "${PREVIS_SCRIPT_DIR}/giant_takosan_battle_previs.blend" \
  -o "${PREVIS_TMP_DIR}/frame_" \
  -F PNG \
  -s 1 \
  -e 176 \
  -a

"${PREVIS_FFMPEG_BIN}" \
  -y \
  -framerate 24 \
  -start_number 1 \
  -i "${PREVIS_TMP_DIR}/frame_%04d.png" \
  -c:v libx264 \
  -pix_fmt yuv420p \
  -movflags +faststart \
  "${PREVIS_SCRIPT_DIR}/giant_takosan_battle_previs.mp4"

"${PREVIS_MAGICK_BIN}" montage \
  -background '#121722' \
  -fill white \
  -pointsize 16 \
  -label '%t' \
  "${PREVIS_SCRIPT_DIR}"/storyboard_frames/0[1-4]_*.png \
  -thumbnail 427x240 \
  -tile 4x1 \
  -geometry 427x240+14+34 \
  "${PREVIS_TMP_DIR}/storyboard_top.png"

"${PREVIS_MAGICK_BIN}" montage \
  -background '#121722' \
  -fill white \
  -pointsize 16 \
  -label '%t' \
  "${PREVIS_SCRIPT_DIR}"/storyboard_frames/0[5-8]_*.png \
  -thumbnail 427x240 \
  -tile 4x1 \
  -geometry 427x240+14+34 \
  "${PREVIS_TMP_DIR}/storyboard_bottom.png"

"${PREVIS_MAGICK_BIN}" \
  "${PREVIS_TMP_DIR}/storyboard_top.png" \
  "${PREVIS_TMP_DIR}/storyboard_bottom.png" \
  -append \
  "${PREVIS_SCRIPT_DIR}/giant_takosan_battle_storyboard.png"

printf 'Rebuilt: %s\n' "${PREVIS_SCRIPT_DIR}/giant_takosan_battle_previs.mp4"
printf 'Rebuilt: %s\n' "${PREVIS_SCRIPT_DIR}/giant_takosan_battle_storyboard.png"

