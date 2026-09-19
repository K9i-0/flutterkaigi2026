# ゆめみん 原典の水色への調整（2026-09-19）

公式サイト・ARの最新採用モデルは `yumemin.glb`。
原典 `02_CHARACTERS/Yumemin.jpg` の主要水色 #5EB6E8 に身体・尻尾・目の穴を塞いだ面の材質を合わせた。旧版は #4299C8。

- 入力: `../eye_seams_20260919/yumemin_clean_v2.glb`
- 白い服と黒い目の材質は維持。全形状・法線・UV・インデックスのバイナリ一致を確認済み。
- 再生成: NumPy / Pillow環境で `python recolor.py`。GLB内の青白混合テクスチャと単色青材質のみ再構築する。
- 公式3Dビューはゆめみんのみ NeutralToneMapping、露出0.8。水色が白っぽくなるのを抑える。
- ARはこのGLBからUSDZを生成する。ARの照明はQuick Lookと周囲の光に依存するため、サイトと完全同一の画面色にはならない。
- 元版は保持。検証値は `validation.json`。
