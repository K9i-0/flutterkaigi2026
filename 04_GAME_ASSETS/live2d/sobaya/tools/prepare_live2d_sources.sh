#!/bin/zsh

set -euo pipefail

script_dir="${0:A:h}"
asset_dir="${script_dir:h}"
canvas="1254x1254"

master_key="${asset_dir}/source/sobaya_live2d_master_key.png"
body_key="${asset_dir}/source/sobaya_body_plate_key.png"
head_key="${asset_dir}/parts/sobaya_head_unit_key.png"
mug_key="${asset_dir}/parts/sobaya_mug_hand_key.png"

for source_image in "$master_key" "$body_key" "$head_key" "$mug_key"; do
  if [[ ! -f "$source_image" ]]; then
    print -u2 "Missing source image: $source_image"
    exit 1
  fi
done

remove_green_key() {
  local input_path="$1"
  local output_path="$2"

  magick "$input_path" \
    -alpha set \
    -channel A -fx '1-clamp((g-max(r,b)-0.04)/0.5)' \
    -channel G -fx 'a<0.99?min(g,max(r,b)):g' \
    "$output_path"
}

remove_green_key "$master_key" "${asset_dir}/source/sobaya_live2d_master.png"
remove_green_key "$body_key" "${asset_dir}/source/sobaya_body_plate.png"
remove_green_key "$head_key" "${asset_dir}/parts/sobaya_head_unit_raw.png"
remove_green_key "$mug_key" "${asset_dir}/parts/sobaya_mug_hand_raw.png"

# Align the generated head to the master's two circular eye openings.
# Source eye centers: (534.8,336.3), (708.9,336.5)
# Master eye centers: (555.7,286.4), (699.9,286.5)
# Scale = 144.2 / 174.1 = 82.83%; translation after scale = (+113,+8).
magick -size "$canvas" canvas:none \
  \( "${asset_dir}/parts/sobaya_head_unit_raw.png" -resize 82.83% \) \
  -geometry +113+8 -composite \
  "${asset_dir}/parts/sobaya_head_unit.png"

# Align the mug by the amber beer body.
# Source beer bbox: 205x256+580+735; master bbox: 193x240+474+900.
# Scale = 94%; translation after scale = (-71,+209).
magick -size "$canvas" canvas:none \
  \( "${asset_dir}/parts/sobaya_mug_hand_raw.png" -resize 94% \) \
  -geometry -71+209 -composite \
  "${asset_dir}/parts/sobaya_mug_hand.png"

magick -size "$canvas" canvas:none \
  "${asset_dir}/source/sobaya_body_plate.png" -composite \
  "${asset_dir}/parts/sobaya_head_unit.png" -composite \
  "${asset_dir}/parts/sobaya_mug_hand.png" -composite \
  "${asset_dir}/preview/sobaya_live2d_composite.png"

magick \
  \( "${asset_dir}/preview/sobaya_live2d_composite.png" -depth 8 -set label CompositePreview \) \
  \( "${asset_dir}/source/sobaya_body_plate.png" -depth 8 -set label BodyPlate \) \
  \( "${asset_dir}/parts/sobaya_head_unit.png" -depth 8 -set label HeadUnit \) \
  \( "${asset_dir}/parts/sobaya_mug_hand.png" -depth 8 -set label MugHand \) \
  -depth 8 -compress RLE \
  "${asset_dir}/cubism/sobaya_live2d_source.psd"

magick montage \
  "${asset_dir}/source/sobaya_live2d_master_key.png" \
  "${asset_dir}/source/sobaya_body_plate_key.png" \
  "${asset_dir}/parts/sobaya_head_unit_key.png" \
  "${asset_dir}/parts/sobaya_mug_hand_key.png" \
  "${asset_dir}/preview/sobaya_live2d_composite.png" \
  -thumbnail 500x500 -tile 3x2 -geometry +12+12 -background '#202020' \
  "${asset_dir}/preview/sobaya_live2d_source_contact_sheet.png"

magick identify \
  "${asset_dir}/source/sobaya_live2d_master.png" \
  "${asset_dir}/source/sobaya_body_plate.png" \
  "${asset_dir}/parts/sobaya_head_unit.png" \
  "${asset_dir}/parts/sobaya_mug_hand.png" \
  "${asset_dir}/cubism/sobaya_live2d_source.psd"
