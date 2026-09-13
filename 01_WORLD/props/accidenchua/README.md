# ACCIDENCHUA 採用ロゴ

2026-09-13採用。DをIDEのデバッグアイコン風の虫へ置き換える。黒背景版が正本。

- logo-dark.png: 黒 #000000、白文字 #FFFFFF、虫D #5EFF00。目は黒。
- logo-inverted.png: 確認用の厳密なRGB反転。白 #FFFFFF、黒文字 #000000、虫D #A100FF。目は白。
- 反転は各8bit sRGBチャンネルで 255 - 値。HSL色相回転や線形光反転ではない。
- 隠しネタは、RGB反転すると元ネタを想起させる白・黒・紫の配色になること。
- 画像は3色に固定。サイトへの組み込みは未実施。

## 制作
内蔵Imagegenで採用形状を生成し、ImageMagickで厳密な色指定を適用。紫版からDの虫・文字形状を参照。

Prompt: Make the adopted final dark-background version of this exact ACCIDENCHUA bug-D logo. Preserve all lettering and the exact bug-shaped D with eyes, antennae, six legs. Background pure black RGB(0,0,0), ordinary letters pure white RGB(255,255,255), bug D RGB(94,255,0), eyes black. One single large horizontal logo, no duplicate, solid clean flat fills, no gradients, textures or glow.
