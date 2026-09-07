# そば屋・正典シート由来の頭部

正典: `03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png`。
入力画像は `inputs/front.png`・`left.png`・`back.png`。画像生成プロンプトは `imagegen_prompts.json`、出典・ハッシュは `provenance.json`。
Tripo P2-20260801、タスク `1034434c-2bf7-45b0-a534-b1fc12686f5d`、120クレジット使用。今回の接続調整では再生成なし。

`head.glb` は未接続の生成頭部（12,920三角面）。ゲーム採用版は `../../../motion_library/sobaya/sobaya.glb`。
頭部を幅1.15倍・奥行1.05倍・高さ1.02倍にし、生成された細い首を滑らかな太い首へ置換。襟の内側まで延長し、Neck/Headへウェイトを設定。目の内側は黒のunlit材質。
完成モデルは34,355三角面、45関節、78クリップ。`assembly_audit.json` に元のアニメーションデータとの完全一致・有限値・正規化ウェイトの検証結果を保存。

再生成:
```sh
blender --background --factory-startup --python tools/build_sobaya_head_assembly.py -- --source ORIGINAL_BODY.glb --work .local/sobaya-fitted
python3 tools/replace_glb_skinned_mesh.py ORIGINAL_BODY.glb .local/sobaya-fitted/mesh.glb OUTPUT.glb
```
`ORIGINAL_BODY.glb` は頭部置換前のモデルを指定する。既定は `rig_v3/sobaya_rig.glb`。通常の `tools/build_humanoid_motion.py --character sobaya` にも頭部置換を組み込み済み。
生FBX・署名付きレスポンス・作業用Blender・プレビューはGit対象外。

検証: Blenderの正面・側面・背面／全身レンダー、macOS FlutterアプリのIdle 1.0秒・Walk 0.35秒・Toast 1.2秒で首の接続を確認。`flutter analyze` は問題なし。
