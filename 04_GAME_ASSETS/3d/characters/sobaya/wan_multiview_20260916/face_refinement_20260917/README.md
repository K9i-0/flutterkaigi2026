# そば屋・顔パーツ修正版

基準画像は `../inputs/front.png`（Wan回転動画のfront）。編集元は `../imagegen_mask_v1/sobaya_refined_final.blend`（公開中v3）。

## 最終スコープ

ユーザーの「輪郭は良かったので戻して、顔のパーツだけの修正」に従い、顎を延長する処理と前髪の変更を撤回。輪郭・髪・体格はv3を維持する。

- 目の縦横サイズを調整し、内部を反射しない黒に統一。
- 口幅・高さ・位置を調整し、端を丸める。
- 額の丸の位置を上げ、滑らかなドームにする。
- 鼻孔をなくし、閉じた鼻先にする。
- 赤い模様をfrontからなぞった滑らかな曲線に置き換える。専用UVと2048×2304画像で輪郭を保つ。

## 成果物

- `sobaya_front_matched.blend`: 編集用、画像同梱。
- `sobaya_front_matched.glb`: 配布用、画像同梱、未リグ。
- `comparison.png`: 左からWan front／v3／顔パーツ修正版。
- `glb_verified_front.png`, `glb_verified_-27.png`, `glb_verified_43.png`, `glb_verified_85.png`, `glb_verified_wholebody.png`: GLB再読み込み後のレンダー。
- `measurements.json`: 目間隔を100に正規化した計測。幅と高さはロール補正後に測る。
- `geometry_scope_check.json`: 顔パーツの局所領域外に頂点移動がないこと、髪が不変であることを検査。

## 検証上の注意

元のfrontでは顔幅が約100pxで、輪郭読み取りには1〜2px程度の不確かさがある。数値の小ささは撮影条件や三次元形状の完全一致を意味しない。顎の長さはユーザー指示でv3を維持し、frontとの差を埋める対象から除外した。

赤の計測は暗い部分も含めるためR>20を用いる。初回監査のR>65では暗い先端を取りこぼした。修正前・修正後とも同じ条件で再計測する。

`refine.py`でv3から修正、`export_verify.py`でGLB書き出し・再読み込み・各方向レンダー、`verify.py`で比率と比較画像を生成する。後者はPillow・NumPy・OpenCVを使う。鼻などの追加部品は本体に親子付けしている。

2026-09-17に公式サイトの本番モデルとして採用。モデルURL版番号は `v3-face-20260917`。
