# 福ちゃんv3 — 正面を基準にした頬の肌補正

2026-09-17。正面は良好だが左右・斜めから頬が黒ずんで見えるという依頼に対応。承認済みリグ版から、頬外側・顎の茶灰色のムラを正面の明るい頬色へなじませた。

`build.py` は正面の頬の採取範囲（|X|=.025〜.05、Z=1.48〜1.535、Y<-.055m）の上位四分位色、sRGB [0.8431, 0.6510, 0.5961] を基準にする。左右の頬から顎へ滑らかな3Dマスクで最大78%を混合し、中央の目鼻口・暗い髪画素を保護する。Cycles Emissionベイクで局所材質をUVへ保存。顔の形状・法線・UV・骨・動作・照明係数は変更しない。自然な立体の影は残す。

## 出力と検証

- `fukuchan.glb` / `fukuchan_skin.blend`: 肌補正版。元のリグ版はそのまま保持。
- `cheek_atlas.png`: 局所材質のベイク結果。上記バイナリとQA画像はローカル保持。
- サイト: `../web_v3_20260917/build.mjs` の入力を本版へ更新。配信用GLBはGit管理。24,244,864 bytes、可逆WebP。
- ゲーム: `apply_game.py` で既存の口パク版の一致する肌画像だけを交換。再生成用の `tools/build_fukuchan_v3_speech.py` も本版入力へ更新。
- `web_validation.json`: 2,100個の非画像バッファ、形状・UV・骨・アニメーション・マテリアル定義が元と完全一致。他の5画像は全画素一致。肌アトラスの変更は239,759 / 16,777,216画素。
- `game_validation.json`: 23動作と口パクmorphを含め、画像以外のデータが完全一致。
- `tools/validate_fukuchan_v3_speech.py`: PASS。20元動作・23ゲーム動作・局所開口・歯なし・口内色を検証。
- Blenderで最終GLBを読み直し、同じ照明の正面・左右45度・左右90度を目視確認。Chrome/Three.jsで配信WebP版の正面・左右斜めと20動作の読み込みを確認。ゲーム実行画面での再確認は今回実施していない。
- サイトのAR関連3ファイル9テスト通過。

## 再生成

リポジトリルートで順に実行する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/skin_even_20260917/build.py
node 04_GAME_ASSETS/3d/characters/fukuchan/web_v3_20260917/build.mjs
node 04_GAME_ASSETS/3d/characters/fukuchan/skin_even_20260917/validate.mjs
python3 04_GAME_ASSETS/3d/characters/fukuchan/skin_even_20260917/apply_game.py
python3 tools/validate_fukuchan_v3_speech.py
python3 04_GAME_ASSETS/3d/characters/fukuchan/skin_even_20260917/setup_local.py
python3 -m http.server 8789 --bind 127.0.0.1 --directory 16_MADOGIWA_STUDIO
```

比較ページ: http://127.0.0.1:8789/public/.local/fukuchan-skin/index.html 。補正前／補正後、正面・左右斜め・横顔、動作を切り替えられる。

`review.py -- <GLBパス> <before|after>` をBlenderの `--python` で呼ぶと `qa/` に5方向をレンダリングする。
