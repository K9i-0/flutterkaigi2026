"""Android adaptive launcher icon from the adopted square icon art.

The art becomes the full-bleed background layer (108dp); the foreground is a
transparent drawable. The 108dp canvas is centred on Yumemin, so the 72dp mask
area keeps the ears and tail, and the missing top strip is filled by blurring
the replicated edge (it only shows outside the mask, e.g. during parallax).

usage: python3 tool/build_android_icon.py  (Pillow)
"""
from pathlib import Path

from PIL import Image, ImageFilter

app = Path(__file__).resolve().parents[1]
src = Image.open(app / 'design/title_icon_candidates/icon-b-mascot.png').convert('RGB')
res = app / 'android/app/src/main/res'

w, h = src.size
# Yumemin centre and canvas side, as fractions of the source (canvas 1.16x so
# the mask circle, 2/3 of the canvas, reaches the ear tips and the tail).
cx, cy, side = .505 * w, .41 * h, round(1.16 * w)
left, top = round(cx - side / 2), round(cy - side / 2)
pad = max(0, -left), max(0, -top), max(0, left + side - w), max(0, top + side - h)
canvas = Image.new('RGB', (w + pad[0] + pad[2], h + pad[1] + pad[3]))
canvas.paste(src, (pad[0], pad[1]))
# Replicate edges into the padding, then blur only the padded strips.
for x in range(pad[0]):
    canvas.paste(src.crop((0, 0, 1, h)), (x, pad[1]))
for x in range(pad[2]):
    canvas.paste(src.crop((w - 1, 0, w, h)), (pad[0] + w + x, pad[1]))
for y in range(pad[1]):
    canvas.paste(canvas.crop((0, pad[1], canvas.width, pad[1] + 1)), (0, y))
blurred = canvas.filter(ImageFilter.GaussianBlur(24))
mask = Image.new('L', canvas.size, 255)
mask.paste(0, (pad[0], pad[1], pad[0] + w, pad[1] + h))
canvas.paste(blurred, mask=mask.filter(ImageFilter.GaussianBlur(8)))
art = canvas.crop((left + pad[0], top + pad[1], left + pad[0] + side, top + pad[1] + side))

for density, scale in {'mdpi': 1, 'hdpi': 1.5, 'xhdpi': 2, 'xxhdpi': 3, 'xxxhdpi': 4}.items():
    px = round(108 * scale)
    art.resize((px, px), Image.LANCZOS).save(res / f'mipmap-{density}/ic_launcher_background.png', optimize=True)

(res / 'drawable/ic_launcher_foreground.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<!-- Transparent: the full-bleed art is the background layer. -->\n'
    '<shape xmlns:android="http://schemas.android.com/apk/res/android" android:shape="rectangle">\n'
    '    <solid android:color="@android:color/transparent" />\n'
    '</shape>\n'
)
(res / 'mipmap-anydpi-v26').mkdir(exist_ok=True)
(res / 'mipmap-anydpi-v26/ic_launcher.xml').write_text(
    '<?xml version="1.0" encoding="utf-8"?>\n'
    '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
    '    <background android:drawable="@mipmap/ic_launcher_background" />\n'
    '    <foreground android:drawable="@drawable/ic_launcher_foreground" />\n'
    '</adaptive-icon>\n'
)
# Preview of the circular mask (72dp of 108dp) for review; not shipped.
print('canvas', side, 'pad', pad)
