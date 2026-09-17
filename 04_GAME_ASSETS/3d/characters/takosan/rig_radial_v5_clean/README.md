# たこさん：触手内側の突起除去

2026-09-17、公式サイト用v4の背面右側に見える触手内側の細い突起を除去。
14頂点を取り除き、以前の中央修整から残っていた開口を含む25辺の局所境界を既存の暗い材質で閉じた。
残存頂点の座標、UV、ウェイト、6本の触手、27ボーン、Idle / Talk / Waveのキーを維持。

- 再生成: `Blender --factory-startup --background --python tools/clean_takosan_tentacle_spur.py`
- 入力: `../rig_radial_v4_hands/takosan.blend`（ローカル保持）
- 出力: `takosan.glb` / `takosan.blend`（blendはローカル保持）
- 検証: `python3 tools/validate_hazard_npc.py 04_GAME_ASSETS/3d/characters/takosan/rig_radial_v5_clean/takosan.glb`
- 19,726三角形。GLB構造・ウェイト・3秒ループ端点検証PASS。背面とWaveのレンダーを確認。
- 公式サイトのモデルsymlinkを本版へ更新。ゲーム用 `rig_sheet_v2` は変更していない。
