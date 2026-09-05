# やめ太郎 — そば屋ハザード用 NPC

正典 `02_CHARACTERS/Yametaro.jpg` と `06_Yametaro.md` の人物同一性を使用。大きなセンター分けの黒髪、台形の輪郭、白いレンズの丸眼鏡、丸いピンクの頬、ラベンダーの柄シャツ、短い体格を維持した。built-in Imagegenで正面・背面Aポーズを制作。入力と正確なプロンプトは `tripo_p2_20260906/` に保存。

- Tripo P2 `P2-20260801`、複数画像2枚、quad / face_limit 8000 / 詳細PBR。生成task `e49752eb-b371-4e7e-8bdd-300b12fa1c8a`、120クレジット。
- biped / Mixamo rig `v1.0-20240301`、task `7a6eeb04-a554-4e45-b392-3b4359be5c0e`、25クレジット。
- 2026-09-06、開始335 → 残190。新規購入なし。生成・リグとも完了、取得済み。出力実体はFBXのためBlenderで正規化・GLB変換。
- ゲーム正本 `rig_v1/yametaro.glb`。1.3m、15,423三角面、1材質、23骨、2.23MB。カラー2K／その他PBR1K。`rig.json` に入力SHA256とクリップ由来を記録。
- Idle / Talk / Wave はBlenderで制作したループ。Waveは大きな頭に手が埋まらないよう肘と手首を外側へ配置。Walk は既存Mixamo歩行から短い脚へ転写し、足元を補正（元の水平速度0.333m/s）。NPCは現在その場で案内するため、歩行は未使用。

村入口に配置し、近づくと手を振る。Eで会話、行き先・戦闘・収集のヒント、各周回で1回だけ弾10発を受け取れる。会話中は専用カメラとTalk/Idleを使用。敵が近づいている場合は会話を開始しない。

再生成:

```sh
python3 tools/tripo_generate.py download 04_GAME_ASSETS/3d/characters/yametaro/rig_source/config.json
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_yametaro_game_rig.py
```

downloadはローカル `task.json` を参照する。別環境では上記rig task IDを設定し、`.local/mixamo_sobaya/source/walk_standard.fbx` も準備する。新規リグ生成の汎用スクリプトは `tools/tripo_rig_character.py`。提出済みマーカーで重複課金を防ぐ。元FBX・署名URL・APIキー・中間blendはGit対象外。

macOSのFlutter Scene実画面で顔・会話画角・選択肢、Dart MCP / MarionetteでE入力と弾の受け取りを確認。口パク・指の個別把持・ボイスは未実装。
