#!/usr/bin/env python3
"""Generate separate transparent PNG caption overlays for Episode 60."""

from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

SCRIPT_DIR = Path(__file__).resolve().parent
OUT_DIR = SCRIPT_DIR / "captions"
OUT_DIR.mkdir(exist_ok=True)

# Font selection: Hiragino Mincho ProN W6 or BIZ UDMincho
FONT_PATH = "/System/Library/Fonts/ヒラギノ明朝 ProN.ttc"
GOTHIC_PATH = "/System/Library/Fonts/ヒラギノ角ゴシック W8.ttc"

CAPTIONS = [
    {
        "id": "caption_01_yametaro",
        "parent": "無職も",
        "ruby": "やめ太郎",
        "ruby_start": 0,
        "ruby_end": 2, # covers "無職"
    },
    {
        "id": "caption_02_fukuchan",
        "parent": "福ちゃんも",
        "ruby": "ギュン",
        "ruby_start": 0,
        "ruby_end": 3, # covers "福ちゃん"
    },
    {
        "id": "caption_03_tokun",
        "parent": "象徴社長も",
        "ruby": "とーくん",
        "ruby_start": 0,
        "ruby_end": 4, # covers "象徴社長"
    },
    {
        "id": "caption_04_ina",
        "parent": "否",
        "ruby": "いな",
        "ruby_start": 0,
        "ruby_end": 1,
    },
    {
        "id": "caption_05_okayaman",
        "parent": "窓際王でさえも",
        "ruby": "おかやまん",
        "ruby_start": 0,
        "ruby_end": 3, # covers "窓際王"
    },
    {
        "id": "caption_06_orega",
        "parent": "俺が",
        "ruby": "おれ",
        "ruby_start": 0,
        "ruby_end": 1,
    },
    {
        "id": "caption_07_mamoraneba",
        "parent": "守護らねば",
        "ruby": "まも",
        "ruby_start": 0,
        "ruby_end": 2, # covers "守護"
    },
    {
        "id": "caption_08_naranu",
        "parent": "ならぬ",
        "ruby": None,
        "ruby_start": 0,
        "ruby_end": 0,
    },
    {
        "id": "caption_09_title",
        "parent": "窓際族物語",
        "ruby": None,
        "ruby_start": 0,
        "ruby_end": 0,
        "is_title": True,
    }
]


def render_caption(item: dict, base_font_size: int = 72) -> Image.Image:
    parent_text = item["parent"]
    ruby_text = item.get("ruby")
    is_title = item.get("is_title", False)

    font_path = GOTHIC_PATH if is_title else FONT_PATH
    main_font = ImageFont.truetype(font_path, base_font_size, index=1 if font_path == FONT_PATH else 0)
    ruby_size = int(base_font_size * 0.45)
    ruby_font = ImageFont.truetype(font_path, ruby_size, index=1 if font_path == FONT_PATH else 0)

    # Vertical layout calculation
    char_spacing = int(base_font_size * 0.15)
    total_main_height = len(parent_text) * base_font_size + (len(parent_text) - 1) * char_spacing
    
    # Width: main column + ruby column + padding
    ruby_col_width = int(ruby_size * 1.4) if ruby_text else 0
    main_col_width = int(base_font_size * 1.3)
    stroke_width = max(4, int(base_font_size * 0.08))
    
    pad = stroke_width * 3 + 20
    img_w = main_col_width + ruby_col_width + pad * 2
    img_h = total_main_height + pad * 2
    
    img = Image.new("RGBA", (img_w, img_h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Main text is on the left if there's ruby on the right
    main_x = pad + (ruby_col_width if False else 0)
    # Actually, Japanese vertical text has ruby on the RIGHT side of the main text!
    # So: Left = Main text, Right = Ruby
    main_col_x = pad
    ruby_col_x = main_col_x + main_col_width

    # Draw main text vertically
    y = pad
    for char in parent_text:
        # Handle special vertical characters if needed
        disp_char = char
        if char == "ー":
            disp_char = "丨" # vertical bar
        
        # Center in column
        bbox = draw.textbbox((0, 0), disp_char, font=main_font)
        cw = bbox[2] - bbox[0]
        cx = main_col_x + (main_col_width - cw) // 2
        
        draw.text(
            (cx, y),
            disp_char,
            font=main_font,
            fill=(255, 255, 255, 255),
            stroke_width=stroke_width,
            stroke_fill=(0, 0, 0, 255),
        )
        y += base_font_size + char_spacing

    # Draw ruby if present
    if ruby_text:
        r_start = item["ruby_start"]
        r_end = item["ruby_end"]
        # Calculate target Y span for the ruby
        target_top_y = pad + r_start * (base_font_size + char_spacing)
        target_bottom_y = pad + r_end * (base_font_size + char_spacing) - char_spacing
        target_span = target_bottom_y - target_top_y

        ruby_char_spacing = int(ruby_size * 0.1)
        ruby_total_h = len(ruby_text) * ruby_size + (len(ruby_text) - 1) * ruby_char_spacing
        
        # Center ruby alongside the target parent characters
        ry_start = target_top_y + max(0, (target_span - ruby_total_h) // 2)
        ry = ry_start
        ruby_stroke = max(2, int(stroke_width * 0.55))

        for r_char in ruby_text:
            disp_r = r_char
            if r_char == "ー":
                disp_r = "丨"
            r_bbox = draw.textbbox((0, 0), disp_r, font=ruby_font)
            rcw = r_bbox[2] - r_bbox[0]
            rcx = ruby_col_x + (ruby_col_width - rcw) // 2
            draw.text(
                (rcx, ry),
                disp_r,
                font=ruby_font,
                fill=(255, 255, 255, 255),
                stroke_width=ruby_stroke,
                stroke_fill=(0, 0, 0, 255),
            )
            ry += ruby_size + ruby_char_spacing

    # Crop to actual bounding box
    bbox = img.getbbox()
    if bbox:
        # Add small margin
        m = 4
        crop_box = (
            max(0, bbox[0] - m),
            max(0, bbox[1] - m),
            min(img_w, bbox[2] + m),
            min(img_h, bbox[3] + m),
        )
        img = img.crop(crop_box)

    return img


def main():
    print("Generating Baki-style typography captions...")
    for item in CAPTIONS:
        img = render_caption(item, base_font_size=80)
        out_path = OUT_DIR / f"{item['id']}.png"
        img.save(out_path)
        print(f"Saved: {out_path.name} ({img.width}x{img.height})")
    print("Done!")

if __name__ == "__main__":
    main()
