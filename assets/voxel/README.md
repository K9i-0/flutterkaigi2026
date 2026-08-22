# 共用ボクセルキャラクターアセット

窓際族物語の全ゲームで共用する、リグ付きボクセルキャラクターモデル（GLB）の正典的な置き場です。
モデルの作成・修正は `build-voxel-character-from-image` スキル（`.claude/skills/build-voxel-character-from-image/`）のワークフローに従ってください。

## 構成

- `models/*.glb` … Web/Three.js用の正典モデル。**各ゲームはここを参照する**（`public/models/` からの相対symlink）。手作業で編集せず、`tools/build_*_voxel_model.py` から再生成する
- `models/mobile/*.glb` … 正典モデルから生成するFlutter Scene向けのdraw-call統合版
- `model_source/` … 編集用Blenderマスター（`*_voxel_master.blend`）、テクスチャ、承認済みターンアラウンド（`concepts/`）、確認用4方向レンダー（`previews/`）
- `tools/` … Blender Python ビルドスクリプトと共通キット
  - `voxel_character_kit.py` … ボックス生成・材質・共通リグ（rig contract v1）
  - `build_<キャラ>_voxel_model.py` … キャラ固有の形状・色・テクスチャパネル
  - `validate_voxel_character.py` … GLBのリグ検証
- `VOXEL_CHARACTER_KIT.md` … リグ契約（`VoxelRig_*` ノード）とキャラ追加手順

## モデル一覧

| キャラクター | GLB | リグ | 参照ゲーム |
|---|---|---|---|
| そば屋 | `models/sobaya.glb` | 二足（両腕＋両脚＋ジョッキ用ハンドソケット） | 05, 06 |
| たこさん | `models/takosan.glb` | 両腕＋触手6本（`VoxelRig_Locomotion_00`〜`05`） | 06 |
| とーくん | `models/tokun.glb` | 二足 | 06 |
| よーたん | `models/yotan.glb` | 二足 | 06 |
| ふくちゃん | `models/fukuchan.glb` | 二足 | 06 |
| 無職やめ太郎 | `models/yametaro.glb` | 二足 | 06 |
| おかやまん | `models/okayaman.glb` | 二足 | 06 |
| ゆめみん | `models/yumemin.glb` | 二足 | 06 |

各キャラのデザイン固定事項（NG変更）は `02_CHARACTERS/*.md` を参照。モデルにも同じ制約が適用されます。

## 再生成手順

このディレクトリ（`04_GAME_ASSETS/voxel/`）から実行します:

```bash
blender --background --python tools/build_<キャラ>_voxel_model.py -- \
  --face-texture model_source/textures/<キャラ>_face_albedo.png \
  ...（キャラごとの引数は各スクリプト冒頭を参照）... \
  --output-glb models/<キャラ>.glb \
  --output-blend model_source/<キャラ>_voxel_master.blend \
  --preview model_source/<キャラ>_voxel_preview.png \
  --turnaround-dir model_source/previews/<キャラ>-<日付>
```

検証:

```bash
blender --background --python tools/validate_voxel_character.py -- \
  --input models/<キャラ>.glb --rig-type biped   # たこさんは tentacled
```

## Flutter Scene向けモバイル派生GLB

正典GLBは変更せず、剛体リグの各ピボット直下にあるメッシュを結合した派生版を
`models/mobile/`へ生成できます。画像テクスチャ・透過・発光材質とリグ階層は保ち、
単色材質を頂点カラー付き共通PBRへ統合するため、外見と手続き歩行を維持したまま
Flutter Sceneのノード巡回とdraw callを削減できます。

```bash
blender --background \
  --python tools/optimize_voxel_model_for_mobile.py -- \
  --input models/sobaya.glb \
  --output models/mobile/sobaya.glb
```

## ゲームからの参照方法

1. ゲームの `public/models/<キャラ>.glb` に、ここの `models/<キャラ>.glb` への相対symlinkを張る
2. Three.js側は各ゲームの `voxel-character-kit.ts` で読み込み、`VoxelRig_*` ノードを回転させて歩行・スマッシュを再生する（スケルタルリグ不要）

新しいゲームを作る場合も、モデルをコピーせずこの置き場をsymlinkで参照してください。
