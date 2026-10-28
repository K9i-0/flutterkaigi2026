# パフォーマンスの記録

ゆめみ採用試験（`app/`）の描画性能について、測った結果・考察・これまでの改善をまとめる。測定ごとの条件と生データは各 `qa/` 以下にあり、ここからリンクする。数値はその端末・ビルド・設定での結果で、ほかの端末の性能を保証するものではない。

## 現状（2026-10-28）

| 端末 | 状態 | 根拠 |
| --- | --- | --- |
| iPhone 14（iOS 26.5、Impeller Metal） | 実プレイで60fps安定 | 2026-10-28に実機で確認。2026-10-21のprofile測定では標準画質のUI 4.1〜4.2ms・ラスター0.4〜0.5ms（[記録](qa/device-performance-20261021/README.md)） |
| Pixel 7a（Android 14、Impeller Vulkan） | 通常の電力モードの実プレイでHUD 約46〜50fps。3Dの更新は毎秒約20回 | [2026-10-28の調査](#2026-10-28-pixel-7aで60fpsに届かない件の調査) |
| Pixel 7a（固定性能モード） | HUD 60fps。3Dの更新は毎秒約30回 | 同上 |

Pixel 7aで60fpsに届かないのは最近の変更のせいではない。2026-10-21の60fps化の時点（`4f3ffba`）から、通常の電力モードの実プレイでは届いていなかった。60fpsという記録は固定性能モード（`adb shell cmd power set-fixed-performance-mode-enabled true`、再起動まで残る）での値だった。当時の記録でも、通常モードの実プレイは53〜60fpsで、60には固定されていなかった。2026-10-28に同じ `4f3ffba` を遊ぶと約47fpsで、最新と同じだった（当時より低いのは端末の温度・場面の違いなどによると考えられるが、詰めていない）。プレイに支障はないため、2026-10-28の時点ではこれ以上手を入れていない。

## 数値の読み方

| 指標 | 何を数えているか | 注意 |
| --- | --- | --- |
| FPS表示（HUD）の fps | Flutterがフレームを出した回数（`FrameTiming` のvsync間隔） | 3Dが描き直された回数ではない（次項） |
| ベンチマークの `submittedFps` | 同上 | 同上 |
| 3Dの更新回数 | `ScenePass` を実行したフレームの数（`tool/scene_rate_probe.py rate`） | 体感の滑らかさに近い |
| UI（build） | UIスレッドの時間。Flutter Sceneは3Dの描画コマンドをUIスレッドで組み立てるので、3Dの重さの大半がここに出る | 16.7msを超えると次のvsyncを逃す |
| GPU（raster） | ラスタースレッドの時間 | GPUの実行時間ではない |

flutter_sceneは、GPUが前のフレームを終えていないと、新しく描かずに前の画像をもう一度出す（`Scene.maxGpuFramesInFlight = 1`、既定値）。そのフレームのUI時間は約1msで、HUDのfpsには数えられる。このためPixel 7aでは「HUD 60fps・3Dは毎秒30回」という状態がありうる。3Dの更新回数はタイムラインから数える必要がある。

ほかの注意点:

- 性能はprofileビルドで評価する。debugビルドやiOSシミュレーターの値は傾向を見るだけにする。
- Androidは電力モードとクロックで大きく変わる。固定性能モードで測った値は、普段の端末での値として扱わない。オン・オフを記録し、比べる版は交互に測る。
- 静止ベンチマーク（`STAGE_BENCHMARK=true`）は画面を止めて測るので、プレイ中だけ動く処理（カメラ追従・落下物・演出）の差は出ない。

## 端末差の考察

同じ場面で比べると、Pixel 7aは3Dを描くフレームの組み立てに、通常の電力モードで15〜19ms（ScenePass 7〜9ms＋ShadowPass 4〜5ms）かかっていた。固定性能モードではScenePassが2.3msまで縮むので、CPUのクロックが上がりきらないことが大きい。iPhone 14はUI全体で4ms前後で、余裕がある。

Pixel 7aの3Dが毎秒約20回になるのは、次の繰り返しによる（2026-10-28のタイムライン）:

1. 3Dを組み立てるフレームが16.7msを超え、次のvsyncを逃す。
2. 次のフレームは、GPUがまだ前のフレームを処理中なので、前の画像を出し直す。
3. 3フレームに1回しか3Dを描かない（60Hzで毎秒20回）。

固定性能モードでは組み立てが16.7msに収まるが、GPU側が1フレームに収まらないので、2回に1回の出し直しになる（毎秒30回）。毎フレーム3Dを描くには、CPU（UIスレッドでの組み立て）とGPUの両方を減らす必要がある。

Pixel 7aを改善するなら、次が候補（いずれも2026-10-28時点では未実施）:

- 夜の作業灯2灯に使われている点光源のクラスタリングを切る（`Scene.punctualLightClustering = false`）。[後述](#見つかった劣化と修正案不採用)
- 昼の影（ShadowPass、実プレイのDart CPUサンプルの約14%）を軽くする。カスケード・距離・解像度、影を落とす物の数
- `SceneView.maxFrameRate: 30` で3Dの更新を30回に固定し、間隔をそろえる（見た目の滑らかさと電力の安定のため。ピーク性能は上がらない）

## 2026-10-28: Pixel 7aで60fpsに届かない件の調査

最新（`5644173`、Flutter 3.47.8）と、60fps化した `4f3ffba`（Flutter 3.47.2）を、同じPixel 7aでprofileビルドにして比べた。生データは [qa/device-performance-20261028/benchmarks.json](qa/device-performance-20261028/benchmarks.json)。

### 静止ベンチマーク（夜・標準画質）

| 条件 | UI p50 / p95 | ラスター p50 / p95 | HUD相当 | 3Dの更新 |
| --- | ---: | ---: | ---: | ---: |
| 最新、固定性能モード | 3.6 / 8.5ms | 1.7 / 7.4ms | 60.0fps | — |
| `4f3ffba`、通常モード | 8.4 / 16.4ms | 3.2 / 9.8ms | 55.0fps | 30.2回/秒 |
| 最新、通常モード | 8.3 / 15.8ms | 3.2 / 9.3ms | 55.3fps | 30.2回/秒 |

静止画面では差がない。ステージ・看板・ライティングの追加は原因ではない。

### プレイ再生（夜・標準画質・CTOおだてつ・通常モード）

既存の `animateGameplay` モード（実際の固定時間刻みで移動・落下・接触を進める）を、一時的なパッチでprofileの自動ベンチマークから動かした（パッチはコミットしていない）。

| 条件 | UI p50 | ScenePass | 3Dの更新 | フロクセル計算（CPUの割合） |
| --- | ---: | ---: | ---: | ---: |
| `4f3ffba`（2回） | 8.9 / 9.0ms | 5.1 / 4.6ms | 約30回/秒 | ほぼなし |
| 最新（2回） | 11.6 / 11.6ms | 6.6 / 6.6ms | 約29回/秒 | 約15% |
| 最新、カメラ追従を止めた場合 | 9.3ms | 5.0ms | 30.0回/秒 | なし |
| 最新、クラスタリングを切った場合 | 9.4ms | 4.3ms | 29.6回/秒 | なし |

昼は、クラスタリングを切った最新がUI p50 7.4ms・3Dの更新30.1回/秒で、`4f3ffba`（6.9ms・28.1回/秒）と同等だった。

### 実際に遊んだ場合（昼・通常モード）

| 条件 | HUD | 3Dの更新 | ScenePass |
| --- | ---: | ---: | ---: |
| `4f3ffba`（通常のラウンド） | 47.2fps | 19.9回/秒 | 6.7ms |
| 最新（お試し） | 46.2fps | 20.2回/秒 | 7.2ms |
| 最新、固定性能モード | 60.2fps | 29.6回/秒 | 2.3ms |

実プレイでは新旧の差がない。プレイ再生より悪いのは、自動ベンチマークの場面・入力と違うためで、原因は詰めていない（実プレイのCPUプロファイルでは、影の組み立てが約14%、プラットフォームチャンネルの受信（傾きセンサーなど）が約3%）。

### 見つかった劣化と修正案（不採用）

`2c82262`（2026-10-21、ピンチズーム追加）から、カメラの注視点が毎フレーム操作キャラのXを滑らかに追う。flutter_sceneの `PunctualLightBuffer.buildFroxels` は、点光源を画面の区画に割り振った結果をカメラが動かない間だけ使い回す。歩いている間は毎フレーム計算し直し、区画のキー文字列を作る `join` を含めてUIスレッドの約15%を使っていた。点光源は夜の作業灯2灯だけなので、`StageLighting.configureRenderer` で `punctualLightClustering = false` にすると、物体ごとのライトリストに切り替わり、劣化分がなくなる。夜の静止画面の画素差は最大8/255（平均0.0003）で、見た目は変わらない。

この劣化は夜にUI時間を約2.7ms増やしているが、実プレイのfpsは新旧で同じで、ゲームに支障はないため採用しなかった。Pixel 7aを改善するときの最初の候補として残す。

## これまでの改善

| 日付 | コミット | 内容 | 効果・記録 |
| --- | --- | --- | --- |
| 2026-08-22 | `6ee02c9` `7dd86ef` | `labs/flutter_scene_game` に性能HUDを追加し、モバイル向けにFlutter Sceneの描画を整理（ボクセルモデルのモバイル版など） | [labs/flutter_scene_game/README.md](../labs/flutter_scene_game/README.md) |
| 2026-09-06 | `8bff6aa` | `labs/sobaya_hazard_lab` でキャンペーンの描画を監査し、profileの計測を追加 | [labs/sobaya_hazard_lab/GAMEPLAY.md](../labs/sobaya_hazard_lab/GAMEPLAY.md) |
| 2026-10-20 | `da13e9e` | 画質設定（標準／高画質／軽量）と静止ベンチマーク `STAGE_BENCHMARK` を追加。標準は3Dの長辺1440px・FXAA・影1カスケード | [README](README.md#ステージの質感画質設定2026-10-20) |
| 2026-10-20 | `8348b37` | ステージの画像をiPhoneの見える距離に合わせて縮小。RGBA8換算44.26→13.13MiB | [qa/texture-resolution/README.md](qa/texture-resolution/README.md) |
| 2026-10-21 | `f4ea5c5` | HUDを値の変化時だけ更新、3DをRepaintBoundaryへ分離、使わないモデルをシーングラフから外す、同じ骨行列の転送を省く、背景を65,220→45,254三角形、おだてつの不要な動作を削除。iPhoneシミュレーターで静止約25.8fps→プレイ56.5〜60fps相当 | [qa/performance-20261021/README.md](qa/performance-20261021/README.md) |
| 2026-10-21 | `310baa3` | FPS表示を追加 | [README](README.md#fps表示2026-10-21) |
| 2026-10-21 | `4f3ffba` | flutter_sceneのフォークを元リポジトリに同期（変化のない点光源の転送を省略）。Pixel 7aの固定性能モードで約30→60fps。キャラクターのテクスチャを2048に縮小し、iPhone 14の読み込み時RSSピーク1,896→739MB | [qa/device-performance-20261021/README.md](qa/device-performance-20261021/README.md) |
| 2026-10-22 | `b6a6792` | ピンチで近づかない看板・遠景などの画像をさらに縮小 | [assets/3d/stages/akasaka/README.md](../assets/3d/stages/akasaka/README.md#拡大されない画像の縮小2026-10-22) |
| 2026-10-27 | `5644173` | FPS表示を初期状態でOnにした（性能の変更ではない） | — |
| 2026-10-28 | — | Pixel 7aの調査。新旧の実プレイは同等と確認。カメラ追従によるフロクセル再計算を特定（修正は不採用） | このページ |

## 計測の方法

静止ベンチマーク（profile、起動すると自動で測ってログに出す）:

```sh
cd app
mise exec -- flutter run --profile -d <device> \
  --dart-define=STAGE_BENCHMARK=true --dart-define=STAGE_TIME=night   # 昼は day、軽量画質は STAGE_QUALITY=light
```

`STAGE_BENCHMARK {...}` の行に、UI・ラスター時間とHUD相当のfpsが出る。終わったあとも同じ場面を描き続けるので、続けて3Dの更新回数やCPUプロファイルを取れる。起動ログのVM Service URI（`ws://127.0.0.1:.../ws`）を使う:

```sh
uv run --with websockets python tool/scene_rate_probe.py ws://127.0.0.1:PORT/TOKEN=/ws rate 6   # 1秒×6回
uv run --with websockets python tool/scene_rate_probe.py ws://127.0.0.1:PORT/TOKEN=/ws cpu 4 60 # 4秒のCPUサンプル
```

`rate` は実際にプレイしている最中にも使える。debugビルドでは `madogiwa.catchAction` の `action=benchmark`（`animateGameplay=true` など）と `tool/perf_probe.py` で、プレイ再生や表示の切り分けを測れる（[README](README.md#負荷の再現測定)）。

Androidの電力モード:

```sh
adb shell cmd power set-fixed-performance-mode-enabled true    # 測定のばらつきを抑える。普段の性能ではない
adb shell cmd power set-fixed-performance-mode-enabled false   # 測り終えたら必ず戻す（再起動まで残る）
```
