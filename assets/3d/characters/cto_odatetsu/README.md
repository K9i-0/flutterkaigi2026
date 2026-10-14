# CTOおだてつ

flutterkaigi2026専用キャラクター。mainへマージしない。作業はPR #20に集約。

- リグ・20動作入りモデル: `rig_v1_20261014/cto_odatetsu_rig.glb`
- リグの再生成・検証: `rig_v1_20261014/README.md`
- 静的モデル正本（リグ入力）: `finish_20261014/cto_odatetsu_static.glb`
- 仕上げ・再生成・監査: `finish_20261014/README.md`
- Tripo原型の生成記録: `tripo_multiview_20261014/`
- 参照シート・Wan入力・4面図: `03_SCRIPTS/cto_odatetsu_turnaround_wan_20261014/`
- プレビューのソース: `03_SCRIPTS/cto_odatetsu_turnaround_wan_20261014/remotion/`（Three.js / Remotion、回転12秒・動作24秒、720×1280・30fps・無音）
- 全20動作の確認ページ: 上記Remotionディレクトリで `npm run rig-viewer`、`http://127.0.0.1:8138/rig-preview.html`

カメラ・レンズは別モデルとして制作する方針。今回の本人モデルは空の両手、黒パーカー（GROW with YUMEMI）、紺デニム、Aマークのスニーカー。
福ギュンv3と同じ54骨・20クリップを持ち、歩行・走行・挨拶・ギュンギュン・ダンス・構えなどを再生できる。静的モデルの頂点位置・UV・材質・テクスチャを保ち、この体格に合わせた関節位置とウェイトで転写した。ゲームへの組み込み、別体カメラ、表情・口パクは未実施。
