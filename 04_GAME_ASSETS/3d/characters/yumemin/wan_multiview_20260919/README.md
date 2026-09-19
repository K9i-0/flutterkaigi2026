# ゆめみん — Wan回転動画からのTripoモデル

2026-09-19制作。公式サイト向けの新しい3D解釈の検討モデル。
原典の素朴さを残しながら、3Dで可愛く見える大きな丸い目を採用したB案が出発点。

## 入力

- 元動画: `03_SCRIPTS/yumemin_turnaround_wan_20260919/wan3_yumemin_turnaround_480p_square.mp4`
- `inputs/front.png`: 0.2秒
- `inputs/left.png`: 2.7秒、鼻が画面左を向く側面
- `inputs/back.png`: 4.3秒
- `inputs/right.png`: 5.7秒、鼻が画面右を向く側面
- 640×640の全フレームを無加工で抽出。実画像を見て選定した近似角度であり、カメラ校正された四面ではない。

## 生成・再現

`config.json`にTripo P2-20260801 / quad / face_limit 15000 / detailed PBR / seed 919030を記録。
生成タスクは`task.json`、入力の時刻は`source_frames.json`に記録する。
同じフォルダで再送しない。送信済みタスクは`tools/tripo_multiview.py status`で照会する。

`render_preview.py`はTripo出力を読み込み、全高1.0の任意単位へ正規化して`yumemin.glb`へ書き出す。
GLBを再読み込みして`qa/`の五方向を描画し、`yumemin.blend`を保存する。
全高1.0は表示用の尺度で、設定上の実身長ではない。元モデルは`raw/`に保持する。

これは静的モデル。リグ・動作・公式サイト公開はまだ実施していない。

## 生成結果・目視確認

Tripo成功。消費120クレジット。1メッシュ、14510頂点、16105ポリゴン。GLB約4.6MiB。GLB再読み込み後の五方向レンダリングを確認。大きな目・丸い身体・短い鼻・低い尻尾を保持。目の光沢と盛り上がり、青白境界の下部の段差状の塗り、表面陰影のうねりは仕上げ課題。厳密な球体ではない。
