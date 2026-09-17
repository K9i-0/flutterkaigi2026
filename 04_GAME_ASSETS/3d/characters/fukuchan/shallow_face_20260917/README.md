# 福ちゃん：浅い顔の形状と陰影調整

2026-09-17。ユーザーの「彫りを浅くしてfrontのテクスチャを活かす」方針に沿った比較候補。元モデルは `../imagegen_texture_20260917/fukuchan_texture_fixed.blend`。本人らしさが完成したという判定ではなく、深い造形と強い陰影を弱める改善段階。

## 候補

- `fukuchan_mild.glb`：顔の凹凸を浅くする強さ0.25。
- `fukuchan_shallow.glb`：強さ0.42。中央の最大奥行き変位約18.7mm。全顔を42%縮小したという意味ではなく、滑らかに丸めた顔の基準面へ局所的に近づける係数。
- `fukuchan_balanced.glb`：shallowに肌・眼の照明応答の調整を追加。ローカル公式サイトの確認用候補。
- 各 `.blend`：編集用。

GLB・blend・レンダー画像はローカル保持。コード・比較ページ・検証記録をGit管理する。

## 変更と保持

`build.py` は毎回元モデルから開始する。顔の横幅・高さ方向の座標は厳密に保持し、前後方向だけを調整。目の周辺、鼻、口元、頬をなだらかな基準面へ近づける。UV分割された同位置頂点の変位を揃え、顔の変更箇所だけ法線を再計算する。口の内側も一緒に変形させ、外側を突き抜けないようにした。1.425mより下の身体は座標完全一致。顔の奥行き変更により、斜め・透視投影では見かけのパーツ位置も変わる。

テクスチャ画像とUVは変更しない。シワの消去や新しい顔画像の生成は行っていない。

`material.py` は肌と眼の拡散色を0.45倍、同じテクスチャの自己発光成分を0.55倍にし、強い照明で陰影が二重に強調される見え方を抑える。これは画像から物理的に完全なアルベドを復元したものではなく、参照画像の見え方を優先するスタイル上の材質設定。暗い場面では通常のPBR肌より明るく見えるため、今後ゲームの暗所照明へ使う際は別途確認が必要。

元の髪材質に分類されていた額の小面も、同じ肌の照明応答に揃えた。Blender 5.1.2のGLB出力ではMultiplyノードの係数が欠落したため、書き出し後にGLBの標準 `baseColorFactor` を明示する。`validate.py` はこの係数も検査する。

## 確認

- `review.py -- balanced --full`：GLBを再読込し、正面・斜め・左右側面・全身・名札を確認。
- `mild_report.json` / `shallow_report.json`：変位量と不変条件。
- `validation.json`：各GLBの構造・埋め込み画像・SHA-256。
- `site-review.html`：入力front、調整前、形状変更のみ、形状＋材質変更を並べるローカル比較ページ。公式サイトのThree.jsと同じライト・トーンマッピング・露出を使用し、顔の比較用正投影カメラで表示する。正面・斜め・横顔・形状のみを切り替えられる。

ローカルURL：`http://127.0.0.1:5173/.local/fukuchan-face/index.html`。通常の人物ページは `http://127.0.0.1:5173/characters/fukuchan`。本番デプロイは行っていない。公式サイトのモデルsymlinkはローカル確認の差分として残し、このモデル制作コミットには含めない。

## 再実行

リポジトリ直下で実行する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/shallow_face_20260917/build.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/shallow_face_20260917/material.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/shallow_face_20260917/review.py -- balanced --full
python3 04_GAME_ASSETS/3d/characters/fukuchan/shallow_face_20260917/validate.py
python3 04_GAME_ASSETS/3d/characters/fukuchan/shallow_face_20260917/setup_local.py
```

比較ページのGLB・front画像は正本への相対symlink。ローカルサーバーは `16_MADOGIWA_STUDIO` でNode.js 24の `npm run dev -- --host 127.0.0.1`。元モデルの髪際・耳の粗さ、低解像度の顔テクスチャ、frontとの差は残る。正面の目鼻口の配置の再調整は今回の奥行き比較には含めていない。
