# 福ちゃん — front準拠の本人らしさ仕上げ

2026-09-17。ユーザーが評価した「浅い形状＋陰影調整」を維持し、静的全身モデルの顔の仕上げを完了。ローカル公式サイトは `fukuchan_final.glb` を参照する。

## 変更

- 入力正本は `../wan_multiview_20260917/inputs/front.png`。追加のシワ除去・美化は行わず、元の眉・瞳・唇・肌色を使用。
- 承認済み `../shallow_face_20260917/fukuchan_balanced.blend` の頂点・面・材質割当・UVを完全に保持。正面から可視の肌へ元画像の色を再投影し、境界をフェザー処理。髪の修復済み画素と側面・耳・首の画像は維持。
- 公式サイトの強い照明に合わせ、顔の diffuse 0.36 / emission 0.44（従来45:55比を維持して全体を0.8倍）で白浮きを抑制。Blender exporterが省略する乗算係数はGLB JSONへ明示。
- 髪に弱いニュートラル寄りの発光色を加え、分け目と毛束が黒につぶれないよう調整。名札「福ちゃん」、衣装、体格は維持。

## 確認

`validate.py` で承認済み形状・面・UV・材質割当の完全一致、内蔵画像、顔の書き出し係数を検証。結果は `validation.json`。1 mesh / 9 primitives / 6 embedded images、静的GLB（リグ・アニメーションなし）。

`review.py -- final --full` で正面・斜め・左右側面・全身前後・名札をレンダリング。ローカル公式サイトと同じ照明の `site-review.html` でfront／承認済み／仕上げ版を比較し、正面と斜めで白浮き・髪の黒つぶれの軽減を確認。顔の本人らしさは目視評価であり数値スコアではない。原画像の顔は約100pxで、拡大時の細部と耳・もみあげ境界の粗さは元生成モデル由来で残る。

## 再生成とローカル確認

リポジトリルートで実行。入力のbalanced.blendは前工程から生成する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/likeness_finish_20260917/finish.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/likeness_finish_20260917/validate.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/likeness_finish_20260917/review.py -- final --full
python3 04_GAME_ASSETS/3d/characters/fukuchan/likeness_finish_20260917/setup_local.py
```

- 比較: http://127.0.0.1:5173/.local/fukuchan-final/index.html
- 公式サイト: http://127.0.0.1:5173/characters/fukuchan →「3Dで見る」

GLB・blend・派生atlas・QA画像はローカル保持。コード・記録をGit管理。公式サイトモデルのsymlink変更はローカル確認専用でcommitせず、本番配信やゲーム採用は変更していない。
