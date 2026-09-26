# 時間・天気の検証 — 2026-09-26

Mac / Flutter 3.47.2 / stock Flutter GPU、Scene fork固定revはアプリREADME参照。

- Dart MCPでnative debug起動、Marionetteで昼・夕暮れ・夜・朝霧・嵐を切替。夜の街灯／水面反射、星、雲、雨の画面を確認。
- 設定パネルから朝・夕暮れ・夜、天気、軽量を操作。Esc開閉、スクロールで下の設定へアクセス可能。パネル表示中F/Spaceを入力して飛行・ジャンプ・座標が変わらないことを確認。
- 保存後hot restartで時刻・天気・画質・時間経過設定が復元。自動時刻が進み、軽量256／高画質484雨粒へ変更されることをextensionで確認。
- 音声プレイヤーのrainループ再生位置と音量の変化、error=nullを確認。雨・雷は再生成可能な合成音。人による聴感評価は未実施。
- `flutter analyze`: 指摘なし。`flutter test`: 20件成功（保存形式、不正値回復、日付境界、昼夜包絡＋既存移動等）。
- UIのMaterial警告は修正。自動操作で描画更新前に次のボタンを探したエラーは、操作間にフレームを待ち再確認。最終runtime確認でアプリ例外なし。

## Profile

```
--profile --dart-define=WATER_BENCHMARK=true \
--dart-define=WATER_SCENARIO=pier --dart-define=WEATHER_SCENARIO=storm
```

1600×1200物理pixel、DPR2、renderScale1、反射0.45、影2048、雨484、16灯、音声無効。
120frame除外、360frame採取。CPU FrameTimingであり、GPU時間／提示FPSではない。

| ms | p50 | p95 | max |
|---|---:|---:|---:|
| UI build | 4.170 | 6.672 | 56.447 |
| Raster | 0.662 | 1.081 | 77.439 |

天気は起動時から嵐へ滑らかに遷移し、採取終了でrain=.75、wetness=.585。
最大スパイクは残る。原因をGPU測定で特定したものではなく、端末間や旧版との厳密なA/B比較ではない。iPhone検証、音込み測定、長時間の熱・電池負荷は未実施。
