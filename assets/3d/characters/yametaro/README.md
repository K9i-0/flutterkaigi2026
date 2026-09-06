# やめ太郎 — そば屋ハザード用 NPC

ゲーム正本は `rig_sheet_v2/yametaro.glb`。2026-09-06、`03_SCRIPTS/00_TEMPLATES/characters/character_yametaro_basic_sheet.png` をデザイン正本、同ディレクトリの `character_yametaro_toy_diorama_3d_basic_sheet.png` を立体・背面の補助資料としてTripo P2で再制作した。大きなセンター分け黒髪、台形の輪郭、白いレンズの丸眼鏡、丸いピンクの頬、ラベンダーの柄シャツ、短い体格を維持する。

- 1.3m、16,205三角面、23骨、1材質、2,474,204 bytes。カラー2K・その他PBR1K。
- 自動リグで頬・髪の一部に腕のウェイトが入る問題を修整。頭部の連結パーツをHead骨へまとめ、身振りで輪郭が引き伸ばされないようにした。
- Idle / Talk / Waveは各3秒のBlender制作ループ。Walkは既存Mixamo `walk_standard.fbx` を短い脚へ転写し足元を補正。1.2333秒、基準速度0.2483m/s。現在NPCの歩行クリップはゲームで未使用。
- SpeechOpen / SpeechNarrowを新しい口位置へ合わせて再制作。131頂点、最大顎変位0.018m。実ゲームの音声強度に同期する簡易口パクを維持する。

## 入力と費用

built-in Imagegenのeditモードでキャラシートから正面・背面の単独Aポーズ画像を制作した。[入力画像](tripo_sheet_p2_20260906/inputs/)と[実行プロンプト一式](tripo_sheet_p2_20260906/imagegen_prompts.json)を保存している。

Tripo `P2-20260801`、正面・背面2画像、quad、face_limit 8000、detailed PBR。task `4a23c7b9-a479-4f9b-a579-acc038c5b309`、120クレジット。biped / Mixamo auto rig task `92a00cec-1f61-4960-afc7-5bc12fa7fa2f`、25クレジット。

今回の2体合計は265クレジット（たこさん120＋やめ太郎120＋リグ25）。追加後のavailable 1070 → 完了時805。設定・入力・取得物ハッシュは `tripo_sheet_p2_20260906/` と `rig_sheet_source/` に記録する。

## 再生成と検証

取得済みリグFBXを `rig_sheet_source/raw/output_model_url.fbx`、既存歩行を `.local/mixamo_sobaya/source/walk_standard.fbx` に用意する。元FBX・署名付きURL・APIキー・中間blendはGit対象外。別環境で取得する場合は上記の既存task IDを使用し、新規生成を重複実行しない。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_yametaro_game_rig.py -- --sheet
python3 tools/validate_hazard_npc.py 04_GAME_ASSETS/3d/characters/yametaro/rig_sheet_v2/yametaro.glb
```

GLB構造・ウェイト・ループ端点・口モーフを検査し、BlenderのTalk/Wave/Walkと口開閉を確認。Flutter Scene実画面で登場・会話・音声再生とSpeechOpen約0.99の口パクを確認した。Flutter全140テスト通過。[統合検証記録](../../../../21_SOBAYA_HAZARD_LAB/qa/npc-tripo-sheet-20260906.json)を参照。差し替え後のprofile負荷測定は未実施。

旧 `rig_v1/yametaro.glb` は退避用として保持。ビルダーの `--sheet` を省くと旧ソースから旧版を再生成する。現行ゲームは正本への相対symlinkを利用する。
