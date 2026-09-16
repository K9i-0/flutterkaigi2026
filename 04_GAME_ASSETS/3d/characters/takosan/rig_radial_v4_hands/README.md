# たこさん：丸い手＋突起1本

`rig_radial_v3` の6本脚・中央残骸除去版を元に、左右の手を丸い掌と内向きの短い突起1本へ変更。袖口の境界も整え、切り口を閉じた。

- 編集データ: `takosan.blend`（ローカル保持）
- 配布データ: `takosan.glb`
- 再生成: v3のBlenderファイルを開き、Blender Pythonで `tools/revise_takosan_single_thumb_hands.py` を実行。袖口処理は `tools/takosan_hand_cuffs.py`。
- 19,728三角形、27ボーン。Idle / Talk / Wave（各3秒）を維持。
- `tools/validate_hazard_npc.py` によるGLB構造検証: PASS（詳細は `validation.json`）。
- 正面・左右の手拡大・Waveの姿勢をレンダーで確認。プレビュー画像とblendはGit管理対象外。

ローカル確認版。公式サイト・ゲームの参照先は変更していない。
