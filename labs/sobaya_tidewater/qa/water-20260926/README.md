# 海・起動準備・環境音の検証 2026-09-26

## 実画面

Mac debug、800×600 logical / 1600×1200 physical、renderScale 0.85。

| 視点 | 変更前 | 改善版 |
|---|---|---|
| 俯瞰 | [before](overview-before.png) | [after](overview-after.png) |
| 桟橋 | [before](pier-before.png) | [after](pier-after.png) |

追加: [浅瀬](shore-after.png)、[桟橋先端](water-after.png)、[平面反射なし](overview-reflection-off.png)。改善版の静止比較は時刻12秒。変更前は旧材質の実行時刻。カメラは同一の名前付きシナリオを使用。静止画像は音量ボタン追加前に撮影。

[shore-live-a](shore-live-a.png) / [shore-live-b](shore-live-b.png) は同じ浅瀬カメラで常時再生した水面。時刻30.55秒→74.06秒をextensionで確認。途中非アクティブになった時間も含むため、フレームレートの比較ではない。画面の波形が変化することを目視確認した。

## 自動・実機検証

- flutter analyze: No issues。
- flutter test: 10件通過。沿岸メッシュの三角形・閉じた内部辺・地形補間、音の海岸距離・左右定位・周期・採用WAV、既存の歩行衝突を検証。
- shaderbundleはMac向けに再ビルド。Dart MCP / Marionetteで起動、ready=true / warmedUp=true / waterFrozen=false を確認。
- 桟橋・俯瞰・浅瀬・海上を実画面で確認。反射なしの代替表示も確認。最終debugのruntime errorsなし。
- 音: WAVをnative playerで読み込み、3背景音のstate=playingとposition進行を確認。浅瀬の海岸距離5.99m。波イベント6回・鳥3回まで発火確認。音量ボタンで3背景音がpaused、非アクティブでもpaused、前面復帰でplaying。error=null。
- システム出力の録音・聴感監査は未実施。原作の実録素材を使用し、音量・定位・再生状態を検証した。iPhone/Android実機の音響・発熱・長時間再生は未検証。

## Profile（音なし）

M4 MacBook Air / 32GB、Flutter 3.47.2、Metal、120フレーム除外後360フレーム。各ケース1回。測定時はこのアプリの他のdebug/profileプロセスを終了。音はWATER_BENCHMARKにより無効。

| mode | UI p50 / p95 ms | raster p50 / p95 ms |
|---|---:|---:|
| 平面反射あり | 2.311 / 2.752 | 0.296 / 0.354 |
| 平面反射なし | 1.412 / 2.667 | 3.549 / 12.027 |

[生データ](profile.json)。FrameTimingはCPU側の処理時間で、GPU完了時間や表示FPSではない。反射なしのraster時間が大きく、単発比較にはばらつき・スケジューリングの影響がある可能性がある。この結果だけで「反射なしが速い」「モバイルでも余裕」「GPUの限界」とは判断しない。採用は見た目を確認できた反射あり。長時間のGPU計測とモバイル計測は今後の課題。

原作FFT・流体・水中・HRTFの完全再現ではない。現行forkに既存の機能を使った表現改善であり、Flutter GPU/SDK/Impellerは無改修。warmUp前後の初回フレームのA/B計測は未実施。
