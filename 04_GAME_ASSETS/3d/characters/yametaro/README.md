# やめ太郎 — そば屋ハザード用 NPC

ゲーム正本は `rig_sheet_v2/yametaro.glb`。2026-09-06、`03_SCRIPTS/00_TEMPLATES/characters/character_yametaro_basic_sheet.png` をデザイン正本、同ディレクトリの `character_yametaro_toy_diorama_3d_basic_sheet.png` を立体・背面の補助資料としてTripo P2で再制作した。大きなセンター分け黒髪、台形の輪郭、白いレンズの丸眼鏡、丸いピンクの頬、ラベンダーの柄シャツ、短い体格を維持する。

- 1.3m、15,299三角面、23骨、3材質、2,599,288 bytes。カラー2K・その他PBR1K。
- 2026-09-07、頬・顎を囲う独立した黒い帯（510頂点・906三角面）を除去。帯の下に転写されていた黒色と溝の法線表現も肌へ戻し、耳は肌色、襟の黒い縁はラベンダーへ変更した。顔のUV、黒髪、丸眼鏡、眉・鼻・口、ピンクの頬、シャツ柄を保持する。
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

輪郭除去は `tools/yametaro_surface.py` を `--sheet` の再生成時に適用する。肌の補修には周囲の肌色を3D空間で補間した頂点色を使用し、元画像を書き換えない。元テクスチャ3枚、骨格、Idle / Talk / Wave / Walkの全チャンネル値が変更前とバイト単位で一致することを確認した。SpeechOpen / SpeechNarrowも維持する。材質は肌補修・襟を加えて1→3、三角面は906減少。輪郭除去後のprofile負荷測定は未実施。

[輪郭除去の検証記録](../../../../21_SOBAYA_HAZARD_LAB/qa/yametaro-no-outline-20260907.json): GLB構造検査、Blenderの5方向、Flutter Sceneの会話画面を確認。Dart MCPで更新素材を再読み込みし、Marionetteの実フレーム／音声プローブで口パク・非話者の閉口・一時停止／再開が合格。実行時エラーなし。

GLB構造・ウェイト・ループ端点・口モーフを検査し、BlenderのTalk/Wave/Walkと口開閉を確認。Flutter Scene実画面で登場・会話・音声再生とSpeechOpen約0.99の口パクを確認した。Flutter全140テスト通過。[統合検証記録](../../../../21_SOBAYA_HAZARD_LAB/qa/npc-tripo-sheet-20260906.json)を参照。差し替え後のprofile負荷測定は未実施。

旧 `rig_v1/yametaro.glb` は退避用として保持。ビルダーの `--sheet` を省くと旧ソースから旧版を再生成する。現行ゲームは正本への相対symlinkを利用する。
