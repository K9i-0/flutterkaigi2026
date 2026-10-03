#!/bin/bash
# User-requested source-performance to Sobaya-timbre conversion.
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
out="$root/.local/chuagostini-20261003"
ffmpeg -v error -y -ss 36.20 -i "$out/source.mp4" -vn -ac 1 -ar 44100 "$out/source_call.wav"
cd "$root/.local/seed-vc"
PYTORCH_ENABLE_MPS_FALLBACK=1 .venv/bin/python inference.py \
  --source "$out/source_call.wav" \
  --target "$root/02_CHARACTERS/Sobaya_voice.wav" \
  --output "$out/seedvc-output" \
  --diffusion-steps 50 --length-adjust 1.0 --inference-cfg-rate 0.7 \
  --f0-condition True --auto-f0-adjust False --semi-tone-shift 0 --fp16 False
