# 植生・波打ち際 QA — 2026-09-27

Flutter 3.47.2 / macOS Metal / stock Flutter GPU。Scene forkは既存固定revのまま。

- `flutter analyze --no-pub`: 指摘なし。
- `flutter test --no-pub`: 22件成功。追加2件は海岸距離の符号・実距離、実島でのseed再現性・建物回避・幹の衝突を確認。
- Dart MCPでnative debug起動。Marionetteで村・浜辺を表示、浜辺ボタンを操作し、カメラと生成数をextensionで確認。
- 植生: 樹木442、低木249、草2,052群、全LOD込み1,429,383三角形。海岸線6,028区間、スワッシュ16,126三角形。
- 最終shaderbundleのsidecarに`#compile_error`がないことを確認。build hookは失敗時に古いbundleを残す場合があるため、launch成功だけで新shader適用とは判断しない。
- 枝の頂点色で不自然な色が見えたため、幹・枝は色を固定した標準PBR材質に分離。葉・草だけを風で変形。
- 濡れ砂をscene colorから合成するパスは、海岸全体で1メッシュに統合。多数の海岸タイルが重なると8回以上の画面コピー警告と合成境界を生むため、分割しない。
- [村の記録](village.png)、[寄せ波の記録](swash.png)。記録画像は最終の浜辺ボタン・スワッシュ1バッチ化より前に撮影したもの。島・植生の形状は同じ。
- 流体シミュレーション、巻き波、飛沫、砂への浸透、写実的植生テクスチャは未実装。LODは距離による段階切替。画像だけでは風の連続性・音の聴感を保証しない。

## Profile

1600×1200 physical / DPR2 / renderScale1 / 高画質 / 13時・晴れ / 音声無効。
120frame除外後360frame。CPU FrameTimingでありGPU実行時間や表示FPSではない。

植生確認時の村（濡れ砂の最終合成変更前）:

| ms | p50 | p95 | max |
|---|---:|---:|---:|
| UI build | 2.619 | 8.133 | 67.236 |
| Raster | 0.259 | 0.514 | 86.175 |

最大スパイクが残る。GPU・長時間・iPhoneの測定は未実施。`--profile --dart-define=WATER_BENCHMARK=true --dart-define=WATER_SCENARIO=village`で再現。浜辺は`WATER_SCENARIO=shore`。

最終の浜辺profileは起動・表示まで確認したが、アプリの非アクティブ化により必要frame数の収集が完了せず、数値は未取得。最終構成の浜辺性能は未判定。
