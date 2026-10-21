# ゆめみ採用試験 モバイル向けモデル（2026-10-21）

ゆめみ採用試験専用の派生GLB。埋め込みテクスチャだけを上限サイズまで縮小し、形状・リグ・アニメーション・マテリアルは正本のまま。正本は変更しない。アプリは `app/assets/models/*.glb` から相対symlinkで参照する。

再生成: `python3 app/tool/build_mobile_models.py`（Pillow）。元と縮小後の画像サイズ・ファイルサイズは `build.json`。

| モデル | 正本 | 上限 |
| --- | --- | ---: |
| fukuchan | `assets/3d/hazard_rebuild/locomotion_v1/fukuchan.glb` | 2048 |
| sobaya | `assets/3d/hazard_rebuild/locomotion_v1/sobaya.glb` | 2048 |
| cto_odatetsu | `assets/3d/characters/cto_odatetsu/game_mobile_20261021/cto_odatetsu.glb` | 2048 |
| yametaro | `assets/3d/characters/yametaro/rig_nose_v3/yametaro.glb` | 1024 |
| yumemin | `assets/3d/characters/yumemin/color_20260919/yumemin.glb` | 1024 |
| chikuwa / chikuwa_toxic | `assets/3d/props/chikuwa/game_v3/` | 1024 |

## 理由

起動時に3人のモデルをまとめて読み込む。4096²の画像が福ギュンだけで6枚あり、RGBA8＋mipmap換算で全GLB約803MiB（キャラクターとアイテムで約730MiB）。iPhone 14で読み込み時のピークが1アプリあたりのメモリ上限に達し、flutter_scene更新後は強制終了（Jetsam、per-process-limit）した。縮小後はキャラクターとアイテムで約240MiB。

プレイ中のキャラクターは画面上で約140px、顔は十数px。GPUは2048未満のmipmapしか参照しないため、Pixel 7aの固定フレーム比較でおだてつ周辺の平均差は0.04/255。福ギュン・そば屋の顔・髪・衣装・面の表示も実機で確認した。カメラを大きく寄せる用途では正本を使う。
