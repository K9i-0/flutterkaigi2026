# ゆめみ採用試験 モバイル向けモデル（2026-10-21）

ゆめみ採用試験専用の派生GLB。埋め込みテクスチャだけを上限サイズまで縮小し、形状・リグ・アニメーション・マテリアルは正本のまま。正本は変更しない。アプリは `app/assets/models/*.glb` から相対symlinkで参照する。

再生成: `python3 app/tool/build_mobile_models.py [名前…]`（Pillow・NumPy、名前を省くと全モデル）。元と縮小後の画像サイズ・ファイルサイズは `build.json`。

| モデル | 正本 | 上限 |
| --- | --- | ---: |
| fukuchan | `assets/3d/hazard_rebuild/locomotion_v1/fukuchan.glb` | 2048 |
| sobaya | `assets/3d/hazard_rebuild/locomotion_v1/sobaya.glb` | 2048 |
| cto_odatetsu | `assets/3d/characters/cto_odatetsu/game_mobile_20261021/cto_odatetsu.glb` | 2048 |
| yametaro | `assets/3d/characters/yametaro/rig_nose_v3/yametaro.glb` | 1024 |
| yumemin | `assets/3d/characters/yumemin/color_20260919/yumemin.glb` | 1024 |
| chikuwa（毒ちくわは`toxic`バリアント） | `assets/3d/props/chikuwa/game_v3/` | 1024 |

## 理由

起動時に3人のモデルをまとめて読み込む。4096²の画像が福ギュンだけで6枚あり、RGBA8＋mipmap換算で全GLB約803MiB（キャラクターとアイテムで約730MiB）。iPhone 14で読み込み時のピークが1アプリあたりのメモリ上限に達し、flutter_scene更新後は強制終了（Jetsam、per-process-limit）した。縮小後はキャラクターとアイテムで約240MiB。

プレイ中のキャラクターは画面上で約140px、顔は十数px。GPUは2048未満のmipmapしか参照しないため、Pixel 7aの固定フレーム比較でおだてつ周辺の平均差は0.04/255。福ギュン・そば屋の顔・髪・衣装・面の表示も実機で確認した。カメラを大きく寄せる用途では正本を使う。

## ちくわの統合（2026-10-22）

通常・毒ちくわは形状・リグ・アニメーションが同一で、胴と断面の色画像、断面内側の色だけが違う。`build_mobile_models.py` が毒ちくわの正本のマテリアルを `KHR_materials_variants` の `toxic` バリアントとして `chikuwa.glb` に追加し、`chikuwa_toxic.glb` は廃止した。形状のバッファが一致しないと生成を止める。粗さ・法線の画像は共有し、読み込みは1回。ゲームは `DropModels` でバリアントを選んでから複製し、見た目ごとの原型を固定する。

画像はRGBA8（mipmap前）で16.0→10.7MiB、GLBは2本計7.41→5.09MB。

## 福ギュンの重複テクスチャ統合（2026-10-22）

福ギュンの6枚は、同じUV展開を修正した版が別画像として残っていた（体全体の3枚は差2〜3%、髪と額の2枚は差0.03%）。`build_mobile_models.py` の `ATLASES` で、各グループの先頭を基準に、後の版はそれを使うマテリアルのUV島（周囲4テクセルのにじみ代を含む）だけに上書きして1枚にした。2048pxは維持。

- `fukuchan_finished_albedo` ← `texture_10`・`neck_atlas_10`（肌・服・前面の肌・髪の生え際）
- `texture_2` ← `atlas_12`（髪・額）
- 白目用の全身写真 `front`（832×1108）は使用範囲の66×30pxだけに切り出し、`KHR_texture_transform` でUVを合わせる。

UVが重なって版が食い違う画素は、生え際35・額4テクセルだけ。画像はRGBA8（mipmap前）で83.5→32.0MiB、GLBは16.07→8.33MB。シミュレーターで最大ズーム（キャラクター中心、昼・夜）を変更前と比較し、キャラクター部分の差は平均0.001/255（顔の最大10/255）。
