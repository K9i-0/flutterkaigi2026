#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
asset_dir="${script_dir:h}"
expected_geometry="1254x1254"

png_files=(
  "${asset_dir}/source/sobaya_live2d_master.png"
  "${asset_dir}/source/sobaya_body_plate.png"
  "${asset_dir}/parts/sobaya_head_unit.png"
  "${asset_dir}/parts/sobaya_eye_lid_l.png"
  "${asset_dir}/parts/sobaya_eye_lid_r.png"
  "${asset_dir}/parts/sobaya_mouth_slot.png"
  "${asset_dir}/parts/sobaya_mug_hand.png"
  "${asset_dir}/preview/sobaya_live2d_composite.png"
)
psd_path="${asset_dir}/cubism/sobaya_live2d_source.psd"

for image_path in "${png_files[@]}"; do
  if [[ ! -f "$image_path" ]]; then
    print -u2 "Missing image: $image_path"
    exit 1
  fi

  geometry="$(magick identify -format '%wx%h' "$image_path")"
  if [[ "$geometry" != "$expected_geometry" ]]; then
    print -u2 "Unexpected geometry: $image_path ($geometry)"
    exit 1
  fi
done

if [[ ! -f "$psd_path" ]]; then
  print -u2 "Missing PSD: $psd_path"
  exit 1
fi

psd_geometry="$(magick identify -format '%wx%h' "${psd_path}[0]")"
psd_depth="$(magick identify -format '%z' "${psd_path}[0]")"
psd_colorspace="$(magick identify -format '%[colorspace]' "${psd_path}[0]")"

if [[ "$psd_geometry" != "$expected_geometry" ]]; then
  print -u2 "Unexpected PSD geometry: $psd_geometry"
  exit 1
fi
if [[ "$psd_depth" != "8" ]]; then
  print -u2 "Cubism requires an 8-bit PSD; got ${psd_depth}-bit"
  exit 1
fi
if [[ "$psd_colorspace" != "sRGB" && "$psd_colorspace" != "RGB" ]]; then
  print -u2 "Cubism requires RGB PSD data; got $psd_colorspace"
  exit 1
fi

expected_labels=(BodyPlate HeadUnit EyeLidL EyeLidR MouthSlot MugHand)
for layer_number in 1 2 3 4 5 6; do
  actual_label="$(magick identify -format '%[label]' "${psd_path}[${layer_number}]")"
  expected_label="${expected_labels[$layer_number]}"
  if [[ "$actual_label" != "$expected_label" ]]; then
    print -u2 "Unexpected PSD layer ${layer_number}: $actual_label (expected $expected_label)"
    exit 1
  fi
done

scene_count="$(magick identify -format '%s\n' "$psd_path" | wc -l | tr -d ' ')"
if [[ "$scene_count" != "7" ]]; then
  print -u2 "Expected one PSD composite and six layers; got $scene_count scenes"
  exit 1
fi

print "Live2D source validation passed"
print "  canvas: ${expected_geometry}"
print "  PSD: RGB, 8-bit, 6 Cubism layers"
print "  layers: ${expected_labels[*]}"
