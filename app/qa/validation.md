# 検証記録 — 2026-10-02

- Flutter 3.47.2 / Dart 3.13.2、iPhone 18 Pro、iOS 27シミュレーター。
- `flutter analyze --no-pub`: No issues found。
- `flutter test`: 5 tests passed。
- `flutter build apk --debug`: 成功。
- `flutter build ios --simulator --debug --no-codesign`: 成功。最終ビルドでDart MCPから再起動して録画。
- Marionetteで右移動、`camera_right` のタップ、一時停止を検証。移動は右入力0.6で約1秒後x=−1.907となり、Flutter Sceneのカメラ右方向へ表示された。カメラタップ後yaw=0.762rad（目標π/4）。
- 描画を確認して、地面の輪の向きと画面右ベクトルを修正。缶ラベルにメッセージが重ならないよう左へ配置。
- Dart MCP `get_runtime_errors`: No runtime errors found（最終録画後）。
- 通常の移動・衝突・得点処理を使う入力コントローラで20秒完走。seed 1、1425点、ビール11本、発泡酒1本、取り逃し1本。詳細は `gameplay.json`。
- 動画: `playthrough.mp4`、26秒、1920×884、30fps、H.264、約2.2MB。XcodeBuildMCPの実画面録画を反時計回り90度回転、縮小、尺調整して出力。画面合成・得点の改変なし。無音。
- 冒頭〜途中〜結果をコンタクトシートで確認。カメラ切替2回と発泡酒減点を含む。

実端末のセンサー操作感とAndroid実機描画は未検証。シミュレーターの入力再生を実機の傾き操作収録とは扱わない。

再エンコード:

```sh
ffmpeg -i qa/playthrough_raw.mp4 -t 26 -vf 'transpose=2,scale=1920:-2,fps=30' -c:v libx264 -preset medium -crf 19 -pix_fmt yuv420p -movflags +faststart qa/playthrough.mp4
```
