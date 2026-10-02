# ビール雨用3D缶

`26_SOBAYA_BEER_RAIN/tool/build_labels.py` と `tool/build_cans.py` で再生成する共有GLB。

- `super_try.glb`: 正典 `03_SCRIPTS/00_TEMPLATES/props/product_super_try.png`（2026-09-10採用版）を缶の側面へ投影。銀地、労働、赤い「つらい」、Madogiwa、生を元画像から使用。元画像は無加工で保持。写真投影による試作UVで、印刷用の展開図ではない。
- `light.glb` / `light.png`: 仮の「窓際ライト」。金色帯のビール。
- `happoshu.glb` / `happoshu.png`: 仮の「つらめ」。紫色帯の発泡酒。

仮デザイン2種は今回のゲームの識別性を試すためのもので、世界観の新しい正典商品としては扱わない。胴、上下のリム、蓋、プルタブをBlenderで構築。ゲームからは相対symlinkで参照する。
