# 福ちゃん：front忠実度の改善

2026-09-17。正本は `../wan_multiview_20260917/inputs/front.png`。シワ控えめ・美化・別の表情への変更を加えず、この画像の目元、眉間、鼻、唇、頬の濃淡と輪郭を目標にした。

## 成果物

- `fukuchan_front_faithful.glb`：全身一体、画像埋め込み、未リグの静的モデル。
- `fukuchan_front_faithful.blend`：編集用モデル。
- `comparison_front.png`：左から入力、改善前、改善後。同じ顔サイズで比較。
- `candidate_front.png` / `candidate_oblique.png` / `candidate_profile.png` / `candidate_right_profile.png`：書き出したGLBを再読込した顔の確認画像。
- `candidate_full_*.png` / `candidate_badge.png`：全身・名札の確認画像。

GLB・blend・監査画像はローカル保持。再実行コード、照明補正済みの採用投影入力、検証記録をGit管理する。既存ゲームの配布モデルは変更していない。

## 改善方法

1. 頭の表示寸法と位置をfrontへ合わせた。比較は180×180pxの入力領域（左上324,20）を900pxで表示。正投影590px/m、中心X=411px、Z=1.7mの投影Y=24.5px。生成画像の実カメラを復元したという意味ではなく、頭部比較用の近似校正。
2. まぶた・眼球の高さと開き、口幅、下顔面・顎、額を囲む前髪を局所調整。最初の「目を細くする」仮説は拡大比較で棄却し、入力の上まぶたの位置と瞳の見える範囲へ合わせた。
3. 前回の汎用的な虹彩キャップを除去。曲面眼球に入力の実際の虹彩・白目を直接対応させた。
4. frontの肌・眉・鼻・唇を元UVへ投影。別の生成顔への置換はしていない。UVを分割した同位置頂点の変位を揃え、顔の法線を再計算した。
5. 投影元画像の陰影と3D照明の二重掛かりを低減。白い拡散面で照明を測り、sRGBから線形色へ変換して低周波の明暗のみ補正。鋭い影を逆転させないよう補正を制限した。シワ・眉・唇を消す補正ではない。
6. 髪・側面・首への投影漏れを制限し、顔中央と側面を同じアトラスで連続させた。元モデルの首の暗い汚れを局所補修。

身体・手・衣装・名札の形状は保持。手の肌材質は頭部から分離して元のまま保持。身長約1.70m、最大局所変位は `iteration_report.json` に記録。

## 検証

`compare.py` は完成GLBを新規シーンへ読み込み、正面・斜め・左右側面・全身・名札を描画する。改善前も同じカメラ、Standard色変換、柔らかい正面光で比較する。

`measure.py` は入力解像度で眉・目、鼻、口、顔中央の輝度相関と平均差を測る。`image_agreement.json` に領域と結果を保存する。これは固定ビューでの画像一致の補助指標であり、人物同一性の認識率や3D全体の忠実度パーセントではない。形状・表情の目視確認と側面確認を併用する。

制作側の完了判定は、入力解像度で主要顔パーツと表情が十分近づき、左右側面の立体性と顔以外の形状保持を確認できたことによる。最終比較の輝度相関は、眉・目 0.7806→0.9567、鼻 0.4372→0.9341、口 0.6053→0.9503。残る髪際・耳の粗さは下記の制約として分けて記録。

`glb_validation.json` にファイルSHA-256、メッシュ数、画像埋め込み、リグ・アニメーションの有無を記録。

## 再実行

Blender 5.1.2。`../finish_C_20260917/fukuchan_finished.blend` と採用済み `front_illumination_corrected.png` を保持し、リポジトリ直下から以下を実行する。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/front_fidelity_20260917/refine.py
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python 04_GAME_ASSETS/3d/characters/fukuchan/front_fidelity_20260917/compare.py -- --full
```

`refine.py` は毎回不変の改善前モデルから処理し、変形を累積しない。`delight.py` は照明補正入力を再計算する補助コード。採用した補正入力を再利用する場合は実行不要。

比較の入力拡大はFFmpegで `crop=180:180:324:20,scale=900:900:flags=lanczos`。`compare.py -- --baseline` で改善前を描画し、その後 `python3 .../measure.py` で数値を更新する。

## 制約

入力は全身画像で、顔の実情報は約100px幅。極端な拡大ではぼけと元生成モデルの髪際・耳周辺の粗さが残る。正面入力の表情を持つ静的モデルであり、眼球回転・表情変更・リグ変形は未検証。照明が変われば見え方も変化する。正面画像の画素完全一致や、未知の角度・表情の復元を保証するものではない。
