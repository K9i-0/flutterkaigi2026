# たこさん — そば屋ハザード用

ゲーム正本は `rig_sheet_v2/takosan.glb`。2026-09-06、標準キャラクターシート `03_SCRIPTS/00_TEMPLATES/characters/character_takosan_basic_sheet.png` を基にTripo P2で作り直し、Blenderで修整・リギングした。白い顔と黒い丸目、閉じた黒いフード、刺繍入りローブ、人間型の腕2本と白い丸い手、巻いた触手6本を維持する。

- 1.433m、18,325三角面、27骨、2材質、1,535,664 bytes。カラー2K・法線1K、roughness 0.85 / metallic 0のマットな質感。
- P2が生成した8本の触手から後方の余分な2本を取り除き、前方5本・後方1本のシルエットへ修整。ローブ本体を切断せず、袖の付け根には内側の布を追加。
- 触手は各3関節。Idle / Talk / Waveは各3秒のBlender制作ループ。モーションキャプチャーではない。口のないデザインなので口パクは行わない。
- 接地が原点、Blender Z-up / 正面-Y。Flutter側は正本への相対symlinkを利用。

## 入力と費用

built-in Imagegenのeditモードでキャラシートから正面・背面の単独Aポーズ画像を制作した。[入力画像](tripo_sheet_p2_20260906/inputs/)と[実行プロンプト一式](tripo_sheet_p2_20260906/imagegen_prompts.json)を保存している。

Tripo `P2-20260801`、正面・背面2画像、quad、face_limit 10000、detailed PBR。task `0b7260e5-a9ec-4245-996e-7826cb69a721`、120クレジット。リグはローカルで制作し追加課金なし。設定と入力ハッシュは同ディレクトリのconfig / provenance、取得物ハッシュはdownload_manifestに記録。

## 再生成と検証

取得済みFBXを `tripo_sheet_p2_20260906/raw/output_model_url.fbx` に用意して実行する。raw・署名付きURL・APIキー・中間blendはGit対象外。ダウンロードにはローカルtask記録とTripo認証が必要。記録がない環境では既存task IDを使用し、新規生成を重複実行しない。

```sh
/Applications/Blender.app/Contents/MacOS/Blender --background --factory-startup --python tools/build_takosan_tripo_rig.py
python3 tools/validate_hazard_npc.py 04_GAME_ASSETS/3d/characters/takosan/rig_sheet_v2/takosan.glb
```

GLB構造・ウェイト・ループ端点を検査し、BlenderのTalk/WaveとFlutter Scene実画面を確認。商店の実入力でビール8→6、予備弾40→50、弾在庫3→2と購入音声を確認した。[統合検証記録](../../../../21_SOBAYA_HAZARD_LAB/qa/npc-tripo-sheet-20260906.json)を参照。差し替え後のprofile負荷測定は未実施。

旧 `rig_v1/takosan.glb` と `tools/build_takosan_game_rig.py` は手続き生成版の退避用として保持する。現行ゲームは使用しない。
