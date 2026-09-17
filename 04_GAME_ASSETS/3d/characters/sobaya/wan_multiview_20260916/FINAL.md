# そば屋 全身モデル仕上げ版

2026-09-17 ユーザー確認済み。未リグ、ゲーム未採用。

## 顔パーツ修正版（2026-09-17、本番採用）

最新の顔の修正は `face_refinement_20260917/` に保存。

- `sobaya_front_matched.blend`: 編集用、テクスチャ同梱。
- `sobaya_front_matched.glb`: 配布用、テクスチャ同梱。
- `comparison.png`: Wan front・修正前v3・修正版を同じ目間隔で比較。
- `README.md` / `measurements.json`: 修正内容、検証方法と計測値。

`inputs/front.png` を基準に、目・口・額の丸の比率と赤い模様を調整し、鼻孔のない鼻先へ修正。ユーザー指示により輪郭と髪は元のv3を維持。公式サイトはこの顔パーツ修正版を参照する。

## 修正前v3の保存版

- `imagegen_mask_v1/sobaya_refined_final.blend`: 編集用、テクスチャ同梱。
- `imagegen_mask_v1/sobaya_refined_final.glb`: 配布用、テクスチャ同梱。
- `imagegen_mask_v1/sobaya_final_color_v2.png`: 最終カラーテクスチャ。

Wanのキャラクターシート由来回転動画から切り出した `inputs/` の4方向画像で、Tripoに全身を一度に生成させたモデルを仕上げた。

仮面を正面の色画像 `imagegen_mask_v1/albedo_front.png` に展開し、内蔵Imagegenで赤い模様と白地を補修。採用画像 `generated_projection.png` を元UVに転写した。生成指示は `prompt.txt`。

Blenderで目の凹みを浅くし、反射しない黒い材質を設定。口に丸い端の横長黒面を追加して本体に親子付け。髪の束と頭頂部の材質を整理し、襟とうなじの塗りを補修した。

正面・斜め・側面・後面・全身を目視確認。GLBを再読み込みしてレンダリングした `imagegen_mask_v1/glb_verified_front.png` でも確認済み。

中間モデル、旧レンダー、API応答、作業用スクリプトはローカル保管。仕上げの正本は上記Blendであり、中間スクリプトの一括再実行は保証しない。
