# 実機パフォーマンス検証（2026-10-21）

Pixel 7a（Android 14、Impeller Vulkan、2400×1080）とiPhone 14（iOS 26.5、Impeller Metal、2532×1170）。profileビルドの `STAGE_BENCHMARK=true`（seed 1・CTOおだてつ・正面・8秒時点で固定、120フレーム準備後に360フレーム）。値はFlutterのCPU側フレーム時間で、GPU実行時間・パネル表示fpsではない。生データは `benchmarks.json`。

## 結論

- Pixel 7aは約30fpsに張り付いていた。原因はflutter_sceneの点光源テクスチャの毎フレーム転送（`Texture.overwrite`）。Vulkanで同期待ちになり、UIスレッドの34〜65%を占め、ラスターも止めていた。
- フォークを元リポジトリ（bdero/flutter_scene、492コミット）に同期すると、変化のない転送の省略などが入って60fpsになった。
- 同期版はiPhone 14で読み込み時に強制終了した（Jetsam、per-process-limit、ピーク約3.0GB）。旧版もRSSピーク1.9GBで上限付近だった。キャラクターの4096²テクスチャを2048²に縮小した派生モデル（`../../../assets/3d/recruit_exam_mobile/`）で解消した。

## Pixel 7a（標準・夜、固定性能モード）

| flutter_scene | UI p50 / p95 ms | ラスター p50 / p95 ms | 送出fps |
| --- | ---: | ---: | ---: |
| 旧 `7934713` a | 11.2 / 20.6 | 16.6 / 18.4 | 47.2 |
| 旧 `7934713` b | 19.2 / 27.5 | 23.8 / 25.7 | 35.1 |
| 同期 `2606511` a | 3.2 / 9.6 | 1.4 / 7.6 | 60.1 |
| 同期 `2606511` b | 4.4 / 9.3 | 1.4 / 6.5 | 60.1 |

固定性能モード（`adb shell cmd power set-fixed-performance-mode-enabled true`）でもばらつきが残るため、旧・同期を交互に測った。通常モードでの実プレイ（FPS表示、0.5秒集計）は昼56.6〜60.1、夜53.2〜60.1fps、UI 6.5〜7.7ms、GPU 4.6〜6.9ms。60未満はワースト20〜35msの単発フレームによる。

旧版での作業灯2灯の有無の比較（`worklight-ab`）は端末の揺れが効果より大きく、結論が出なかった。旧版の初回計測4条件（`old-fork/run1`）はUI 16.7〜21.5ms、ラスター16.7〜21.7msで、軽量画質でも改善しなかった。

## iPhone 14

| 条件 | 読み込み時RSSピーク | 安定時RSS | 結果 |
| --- | ---: | ---: | --- |
| 旧flutter_scene、元モデル | 1,896MB | 約1,120MB | 完走、60fps |
| 同期flutter_scene、元モデル | 1,983MB以上 | ― | 強制終了 |
| 同期flutter_scene、縮小モデル | 739MB | 約570MB | 完走、60fps |

RSSは `ProcessInfo.currentRss` の1秒ごとの値（一時的な計測コードで取得、コミットしていない）。iOSの強制終了判定はGPUメモリを含むため、RSSより大きい。同期版・縮小モデルの標準画質はUI 4.1〜4.2ms、ラスター0.4〜0.5ms（昼・夜）。旧版の4条件はUI 3.6〜4.3ms、ラスター0.5ms前後で、もともと60fps。
