# CTOおだてつ：別体カメラ

`flutterkaigi2026` 専用、PR #20の制作物。mainへマージしない。

- 完成モデル: `finish_20261014/odatetsu_camera.glb`
- 形状・文字・座標・再生成: `finish_20261014/README.md`
- 装備アンカーと寸法: `finish_20261014/asset.json`
- Tripo生成記録: `tripo_20261014/README.md`
- 採用入力: `03_SCRIPTS/cto_odatetsu_camera_20261014/`
- 本人の装備用モデルと握り設定: `04_GAME_ASSETS/3d/characters/cto_odatetsu/camera_equipment_20261014/`
- 操作・動画プレビュー: `03_SCRIPTS/cto_odatetsu_turnaround_wan_20261014/remotion/` で `npm run camera-viewer`

ILCE-7M5型の黒い本体とSEL70200GM2型の白い望遠レンズ・円筒フードを一つの剛体として扱う。表示は `ODATETSU / O7 V / O`。黒いストラップはプレビュー側の別部品。本人のGLBへ結合せず、`PropSocket.R` とカメラの `GripAnchor` を使って装備する。
