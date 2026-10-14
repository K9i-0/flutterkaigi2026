# CTOおだてつ

flutterkaigi2026専用キャラクター。mainへマージしない。作業はPR #20に集約。

- リグ・20動作入りモデル: `rig_v1_20261014/cto_odatetsu_rig.glb`
- リグの再生成・検証: `rig_v1_20261014/README.md`
- カメラ装備用の派生モデル: `camera_equipment_20261014/cto_odatetsu_camera.glb`（元20動作＋固定ポーズ `CameraCarry`）
- 装備位置・握り・再生成: `camera_equipment_20261014/README.md` と `attachment.json`
- 別体カメラ＋望遠レンズ: `04_GAME_ASSETS/3d/props/odatetsu_camera/finish_20261014/odatetsu_camera.glb`
- 静的モデル正本（リグ入力）: `finish_20261014/cto_odatetsu_static.glb`
- 仕上げ・再生成・監査: `finish_20261014/README.md`
- Tripo原型の生成記録: `tripo_multiview_20261014/`
- 参照シート・Wan入力・4面図: `03_SCRIPTS/cto_odatetsu_turnaround_wan_20261014/`
- プレビューのソース: `03_SCRIPTS/cto_odatetsu_turnaround_wan_20261014/remotion/`（Three.js / Remotion、回転12秒・動作24秒、720×1280・30fps・無音）
- 全20動作の確認ページ: 上記Remotionディレクトリで `npm run rig-viewer`、`http://127.0.0.1:8138/rig-preview.html`
- カメラ装備の確認ページ: 上記Remotionディレクトリで `npm run camera-viewer`、`http://127.0.0.1:8138/camera-preview.html`（装備・ストラップの切替、全21クリップ。rig-viewerと同じポートを使用）

本人とカメラ・レンズは別モデル。黒パーカー（GROW with YUMEMI）、紺デニム、Aマークのスニーカーを維持し、カメラの文字はODATETSU / O7 V / Oへ置き換える。ストラップはプレビュー側で作る独立した部品。

福ギュンv3と同じ54骨・20クリップを持ち、歩行・走行・挨拶・ギュンギュン・ダンス・構えなどを再生できる。静的モデルの頂点位置・UV・材質・テクスチャを保ち、この体格に合わせた関節位置とウェイトで転写した。装備用派生モデルは元20クリップを変更せず、元絵の左端に合わせた「右手でカメラを肩の横へ持ち、左手を腰へ添える」固定ポーズを追加する。

装備は右手ソケットへ追従し、装備中だけ指の握りを重ねる。装備OFFでは各クリップの元の指姿勢へ戻る。接触の調整は `CameraCarry` を対象とし、他の全動作で身体や衣服との干渉がないことを保証するものではない。ゲームへの組み込み、表情・口パク、布シミュレーションは未実施。
