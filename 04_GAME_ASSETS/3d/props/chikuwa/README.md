# ちくわ — Imagegen参照によるBlender造形試作

鉄骨ゲームのCTOおだてつ用。2026-10-20。現在は通常ちくわの形・焼き皮の品質を優先し、毒版の仕上げとゲーム組み込みは保留。

## 現在のモデル

`v3/chikuwa.glb` が最新の造形候補。Imagegenの目標画像 `references/ideal_v2.png` の通常ちくわを基準に、焼き皮の膨らみ・溝を実メッシュに付け、細かなしわを法線に分離した。

- 123,520三角形、Root＋8変形骨、`Wiggle` 1.6秒ループ、全長2.8単位、長手方向はGLBのY。
- 1024×1536の色・高さ入力。入力PNGはそのまま保持。Blender内でUV継ぎ目を狭くブレンドして色をベイク。
- 高さ画像を10px相当で平滑化して実形状へ変位。細部は2px平滑化との差から弱いバンプを作り、タンジェント法線へベイク。高さ画像の濃さは測定値ではなく制作上のガイド。
- 焼き皮は滑らかで少し光沢を持ち、白い身はやや粗くなるよう粗さを分けた。
- 端面と穴の内側は別材質で、白い身のテクスチャを使用。穴の輪郭と断面にも小さな不均一さを付けた。端面のUVが縮退して生じる筋と、焼き色が穴の縁へ引き延ばされる問題を解消。
- 見た目を優先した高密度版。ゲーム用の軽量化・多数同時描画・Flutter Scene実機検証はまだ行っていない。

## 比較用に残した版

| 版 | 場所 | 特徴 |
| --- | --- | --- |
| v1 | 直下の `chikuwa.glb` / `chikuwa_toxic.glb` | 手続き的な色とリング状のしわ。15,552三角形。初稿として保持 |
| v2 | `v2/chikuwa.glb` / `v2/chikuwa_toxic.glb` | Imagegenの色＋穏やかな不規則形状。15,616三角形。2色は同じメッシュ・骨格 |
| v3 | `v3/chikuwa.glb` | 通常色のみ。色に対応した凹凸を高密度メッシュへ追加。123,520三角形 |

生成画像はbuilt-in Imagegenを使用。目標・通常色・毒色・高さの4回のプロンプトを `references/imagegen_prompts_v2.json` に保存。Tripoは使用していない。

## ローカルプレビュー

2026-10-20ユーザー指定により、以後の確認はローカルを使用する。今回のv2/v3をChatGPT Siteへは公開していない。

```sh
cd 04_GAME_ASSETS/3d/props/chikuwa/preview
npm ci
npm run dev
```

`http://127.0.0.1:8766`。左にImagegenの目標（通常ちくわ部分）、右に実際の3Dモデルを表示。最初は静止したv3。v1/v2/v3、形状だけ（色・法線・粗さマップを外す）、斜光、焼き皮の拡大、端面、骨、ワイヤーフレームを切り替えられる。ボーンの再生、速度・強さの調整も維持。「同じモデルの高品質静止画」では実際のGLBをCyclesでレンダリングした `v3/beauty.png` を表示し、その間の3D操作は無効にする。

モデルと参照画像は相対symlink。Three.js 0.180.0をローカルへ準備する。小さく表示するボタンは実ゲームのカメラ再現ではない。

旧v1だけのSites公開URL: https://madogiwa-chikuwa-lab.geukfyger.chatgpt.site 。project ID `appgprj_6ad712b7ddc481919d8d0dc220f43c53` / `.local/chikuwa-site/` は旧公開の記録として保持。再公開はユーザーから依頼された場合に限る。

## 再生成・検証

リポジトリルートで実行:

```sh
# 最新の通常ちくわ（Imagegen入力画像が必要）
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_chikuwa_v3.py
python3 tools/validate_chikuwa_v3.py
# 実際のGLBを読み込んでCyclesで静止画を書き出す
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/render_chikuwa_study.py
```

v1は `tools/build_chikuwa.py`、v2は `tools/build_chikuwa_v2.py`。Blender 5.1.2で生成。ベイクPNG・中間blendは再生成可能でGLBにも必要データが埋め込まれるため追跡しない。

GLB検証は有限な頂点座標、正規化された法線・ウェイト、頂点／ボーン参照範囲、9骨、材質分離、1.6秒のループ端点を確認。Chromeで静止姿勢・骨の変形・停止中の振幅変更・全版の切り替え・診断表示・390px幅を確認。実機でのゲーム内品質は未確認。

## 2026-10-20: 毒版とゲーム組み込み

採用済みの通常 v3 を基準に毒版を追加。`v3/chikuwa_toxic.glb` は通常 v3 の
メッシュ・UV・法線・スキン・クリップをそのまま保持し、Imagegen の毒版色と
紫の内壁色だけを差し替える。採用済み通常 GLB は上書きしない。

`game_v3/chikuwa.glb` / `game_v3/chikuwa_toxic.glb` はゲーム用の 32,320 三角形版。
80 周分割 × 160 長手分割で同じ高さ画像をサンプリングし、微細法線と焼き色を保持。
9 ボーン、8 変形ボーン、1.6 秒の `Wiggle`。2 色は同一形状・UV・法線・ウェイト・動作。
高精細版は 123,520 三角形のまま比較用に保持する。ゲーム用メッシュは高精細版とは
頂点密度が異なり、輪郭の極小凹凸を省略している。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_chikuwa_v3.py -- --game
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python tools/build_chikuwa_v3.py
python3 tools/validate_chikuwa_variants.py
```

高精細の毒色移植は `tools/recolor_chikuwa_variant.py` を生成スクリプトから呼び出す。
通常モデルのバイナリを維持するため、再生成時の数値差によって採用形状を変えない。
ゲーム用のノイズ seed は 0 に固定。中間テクスチャは GLB に埋め込み、Git 対象外。

`26_SOBAYA_BEER_RAIN/assets/models/` から相対 symlink で参照する。
ローカルプレビュー http://127.0.0.1:8766 は「ゲーム版」「種類」で通常／毒を比較できる。
Sites への公開更新は行わない。
