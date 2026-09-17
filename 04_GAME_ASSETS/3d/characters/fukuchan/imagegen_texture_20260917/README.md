# 福ちゃん：Imagegenによる髪テクスチャ修正

2026-09-17。`../wan_multiview_20260917/inputs/front.png` の見た目を基準に、髪へ混入していた肌色を修正する。追加のシワ低減・美化は行わない。

## 入力と生成画像

- 形状・顔の元モデル：`../front_fidelity_20260917/fukuchan_front_faithful.blend`
- `edit_target.png`：元モデルの無照明Base Color投影。左上から正面、斜め左、斜め右、背面。
- `imagegen_hair_repair.png`：builtin Imagegenで修正した四面の画像。
- `edit_target_profiles.png` / `imagegen_profile_repair.png`：左右真横の追加修正。前髪の裏側と毛先を対象とした。
- 実行プロンプト：`prompt_imagegen.txt` / `prompt_imagegen_profiles.txt`

Imagegenは2回ともbuiltinツール。生成結果をこのディレクトリへ保存した。生成画像の顔全体への置換はせず、髪の修正に利用する。

## 適用方法

`apply.py` は毎回不変の元blendから開始する。6方向の深度を使って既存UVへ投影し、髪の領域へ限定する。投影から見えない前髪の裏面は、Imagegen画像から採取した髪色で補完する。髪と肌が同じメッシュに混在し、元の材質分けにも誤りがあるため、位置と奥行きを併用する。髪の補完範囲では生成画像から採取した暗色の範囲へ明度を制限し、灰色の混入を抑える。

目・鼻・口など顔中央は元のfront準拠のテクスチャを保持する。髪材質に誤分類されていた額の面だけは、前工程の `front_illumination_corrected.png` から再投影する。実際の耳と、前髪以外の下部境界・首は元のテクスチャを保護する。髪へ直した面の材質を揃え、UV島の外側へ余白を付ける際は他の面の画素を上書きしない。

頂点位置、UV座標、身体、衣装、名札「福ちゃん」の形状は変更しない。ゲームへの採用やリグ追加はこの修正に含めない。

## 成果物

- `fukuchan_texture_fixed.glb`：テクスチャ埋め込み・全身一体の静的モデル。
- `fukuchan_texture_fixed.blend`：編集用。
- `texture_2.png`：修正した髪材質のBase Colorアトラス。
- `texture_10.png`：髪と肌の混在箇所を修正した頭部アトラス。
- `comparison_front.png` / `comparison_oblique.png`：左が修正前、右が修正後。
- `qa/candidate_*.png`：書き出したGLBを再読込した正面・斜め・左右側面・全身・名札の確認画像。
- `comparison_reference.png`：左が入力frontの顔拡大、右が修正モデル。
- `repair_report.json` / `glb_validation.json` / `integrity_report.json`：適用箇所、ファイル構造、形状・UV・顔中央の保持の検証記録。

GLB、blend、焼き込みアトラス、確認画像はローカル保持。採用生成画像・入力・プロンプト・再実行コード・軽量記録をGit管理する。

## 再実行

リポジトリ直下で、元blendと採用済み生成画像を保持して実行する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/imagegen_texture_20260917/apply.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/imagegen_texture_20260917/review.py -- --full
python3 04_GAME_ASSETS/3d/characters/fukuchan/imagegen_texture_20260917/validate.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/imagegen_texture_20260917/integrity.py
python3 04_GAME_ASSETS/3d/characters/fukuchan/imagegen_texture_20260917/make_comparisons.py
```

`prepare.py` / `prepare_profiles.py` はImagegen入力の無照明画像を再出力する。2×2および横2面に結合したものが保存済みのedit_target画像。Imagegenの再実行は同一出力を保証しないため、採用生成画像を正本として保持する。

## 制約

元のTripoメッシュの髪際・耳の粗い形状は残る。テクスチャの修正であり、髪や耳のリトポロジーではない。顔の入力情報量は全身front画像の解像度に制約される。
