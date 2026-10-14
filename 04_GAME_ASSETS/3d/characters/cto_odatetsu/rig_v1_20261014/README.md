# CTOおだてつ：リグと既存モーション

`flutterkaigi2026` 専用、PR #20で管理。mainへマージしない。

## 入出力

- 本人モデル: `cto_odatetsu_rig.glb`。テクスチャ内蔵、1メッシュ・1材質・1スキン。
- 静止形状の正本: `../finish_20261014/cto_odatetsu_static.glb`。
- 動作入力: `../../fukuchan/web_v3_20260917/fukuchan.glb`。元の福ギュンは変更しない。
- 編集用: `cto_odatetsu_rig.blend` / `cto_odatetsu_animated.blend`（ローカル、再生成可能）。

## 互換構成

福ギュンv3と同じ54骨・階層・20クリップ名。Root、体幹、左右四肢、左右5指×3骨、右手の `PropSocket.R` を含む。最大4ウェイトで正規化する。関節位置はおだてつのAポーズを多方向の描画とメッシュ断面で確認して定めた推定値で、`landmarks.json` に保持する。

| 用途 | クリップ |
| --- | --- |
| 基本 | Idle / Walk / Run / Greeting |
| ポーズ | GyunGyun / GyunGyunPose |
| ダンス | DanceStep / DanceDisco / DanceVictory |
| 構え・リロード | Aim / AimShotgun / ReloadHandgun / ReloadShotgun |
| アクション | Hit / Evade / Kick / Climb / Vault / Struggle / BreakFree |

元のrest姿勢と四肢方向・脚長を考慮して転写し、子関節はおだてつの骨長で再構成する。指は親となる掌に追従する。ソースの浮き高さを維持し、足裏の沈み込みだけを補正する。元クリップ名・尺・入力SHA・補正量は `motions.json`。異なる体格のローカル回転を単純コピーしたものではない。

## ウェイトの修正

- 頂点位置・面・UV・材質・テクスチャを維持し、同位置に分裂したUV境界の頂点は同じウェイトへ揃える。
- 腕と胴体はメッシュ表面の距離で分離。皮膚と袖が分かれた部分では距離計算の始点を補い、元メッシュを接合・変形しない。
- 胴体の骨に引かれていた肘下の内側を腕へ戻し、肩の付け根だけを連続的に混ぜる。
- フード・襟は胴体とつながる面から判定し、上部をSpine2へ追従させる。首の高さだけで布を頭へ割り当てない。髪は独立した面の集まりをHeadへ固定し、顔と首の皮膚には滑らかなウェイトを残す。
- 指の割当は表面距離で分け、隣の指へウェイトが飛ばないようにする。

## 再生成と確認

Blender 5.1.2と同梱numpyを使う。Git管理済みの2つのGLBだけを入力にし、新しい生成API呼び出しや原型FBXは不要。

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python 04_GAME_ASSETS/3d/characters/cto_odatetsu/rig_v1_20261014/build.py
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python 04_GAME_ASSETS/3d/characters/cto_odatetsu/rig_v1_20261014/animate.py
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python 04_GAME_ASSETS/3d/characters/cto_odatetsu/rig_v1_20261014/review.py
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python 04_GAME_ASSETS/3d/characters/cto_odatetsu/rig_v1_20261014/validate.py
```

形式・不変性・20動作の数値検証は `validate.py` と `validation.json`、ボーン・ウェイトの構築結果は `bind_report.json` を参照。`review.py -- --catalog` は20動作の代表姿勢、`-- --hands` は挨拶の出入りと指の拡大、`-- --neck` は勝利ポーズの襟を前後から描画する。

ブラウザで全20動作の選択・停止・シーク・骨表示ができる確認ページと、6動作をまとめた24秒のRemotion動画は `03_SCRIPTS/cto_odatetsu_turnaround_wan_20261014/remotion/README.md` を参照。静的回転動画は別に保持する。

## 最終検証（2026-10-14）

GLB SHA-256: `a00e99144f2fba32ae4a777a6084ebe56594828df13ae04fc33ee9cd9962ffd4`。

- 三角形ごとの頂点位置・UVと、埋め込み画像・材質が静的モデルと一致。書き出し時の頂点分裂は三角形の角単位で照合する。
- 54骨の名前・階層、20クリップ名・尺、最大4ウェイトと正規化、同位置のUV分裂頂点のウェイト一致に合格。
- 独立したglTFスキニング計算で20動作×5位相を検査。全姿勢が有限値で、床からの最小高さは2.795mm。
- Idle・Walk・GyunGyun・DanceVictoryの代表4姿勢で、Blender作業シーンとGLB再読込後の比較誤差は最大0.035mm。独立計算とBlenderの差は最大0.0011mm。
- 勝利ポーズの襟で最大133.35mmあった辺の伸長は38.26mmへ低減。修正前後の診断値は `validation_comparison.json`。数値は変形箇所の診断用で、見た目の完全性を保証する指標ではない。
- 最終版の挨拶、フード背面、勝利ポーズの前後を目視確認。`preview.png` は最終GLBの挨拶姿勢。

## 範囲

GLB内の20動作をこの体格へ転写した成果物。キャラクター固有の寸劇・犬モーションや、任意の外部モーション全般の直接互換を意味しない。元動作はMixamo・CC0・手付けが混在するため、全体をCC0とは扱わない。

布シミュレーション、表情・口パク、別体カメラの把持、武器や窓との接触合わせ、ゲーム内の移動速度調整は今回の範囲外。元の生成トポロジー由来の袖・股・指の折れは残り、完全閉曲面／3D印刷用モデルではない。
