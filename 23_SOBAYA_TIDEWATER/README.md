# そば屋ハザード — Tidewater移植プレビュー

Tidewaterの島をFlutterへ移す最初の検証アプリ。現在は島・村・桟橋の形状と一人称歩行の土台。原作の写実的な材質や海を再現した完成版ではない。

## 実装方針

- Flutter **3.47.2 stable**（ルートmise設定）。Flutter GPU / SDK / Impellerは無改修。
- Flutter Sceneは既存fork [K9i-0/flutter_scene](https://github.com/K9i-0/flutter_scene) の `93d420be938213d19744723f8f6bb56be301187d` をGit依存として固定。今回fork本体への追加パッチは不要だった。
- 島固有の描画はアプリの `.fmat`。今後エンジン共通機能が必要になった場合はFlutter Scene forkのみ拡張する。Compute API追加や独自Flutter SDK配布は行わない。
- 通常操作は一人称。将来、会話・イベントで操作キャラクターを映す。モデルは既存採用正本を共有する予定で、現在は未導入。

## 起動

```sh
cd 23_SOBAYA_TIDEWATER
mise exec -- flutter pub get
mise exec -- flutter run -d macos --enable-flutter-gpu
```

macOS/iOSはInfo.plistでもFlutter GPUを有効化。Dart MCP起動でも同じ設定になる。Androidも有効化設定を同梱するが、今回の動作検証対象はMacのみ。

WASD／画面の矢印で移動、ドラッグで見回す、Shiftで走る。Fで検証用飛行へ切り替え、Space/Cで上下移動。桟橋・村・俯瞰ボタンで固定地点へ移動する。歩行中の海への進入は止める。Space／ジャンプボタンで跳べる。重力・着地・天井への頭打ちを処理し、水泳や戦闘はまだない。

## 今回移植したもの

- Tidewater `4811ba48d795197de5621985f404e765c0b7c0ef` のseed 7の島。
- 島の地形（4m間隔、128mごとの分割、深い海底を省略、237,568三角形）。
- 元の村生成コードから21棟と桟橋、板道、小物のCPU形状・頂点色。原作の色・粗さ・法線テクスチャを生成するGPUシェーダーは未移植。
- 建物の整地後の1m高さデータ、回転した箱・円柱・歩ける床の衝突。表示用地形は粗いため、細かな地表と足元の高さには差があり得る。
- 深さによる吸収色・浅瀬の屈折・岸の泡・複数の波と画素単位の細かな法線、低解像度の平面反射。空・太陽・影と弱いBloom。FFT海洋ではない。
- メニュー切替、フォーカス喪失時の入力解除、背景化時のticker停止。

元データは [共通アセット正本](../04_GAME_ASSETS/3d/tidewater/README.md) を相対symlinkで参照する。runtime GLB importerのZ反転はインポート境界で相殺し、Tidewaterの座標と衝突データを一致させる。三角形の頂点順序は書き換えない。

## 残る移植

1. 地形の細部・木材・屋根・岩の材質、草木・岩の散布、表示距離とLOD。
2. 波に合わせた平面反射の歪み、砕ける波の立体形状、地形の細分化に合わせた岸辺の改善。
3. 原作の海岸線と同じ視点で見た目を比較し、Mac/iPhone実機でprofile計測。
4. 採用済みそば屋・福ちゃんモデル、会話カメラ、探索・戦闘。

FFT海洋、浅水流体、海中表現、立体的な雲は未実装。GPU本体の変更が必要な方式を採用条件にしない。

## 再生成・検証

```sh
# リポジトリルートから。初回は固定版Tidewaterを.localへ取得する。
node 23_SOBAYA_TIDEWATER/tools/export_tidewater.mjs
cd 23_SOBAYA_TIDEWATER
mise exec -- flutter analyze
mise exec -- flutter test --no-pub
```

変換は元ソースを変更せず、GPU用の村組み立て段階をサブクラスで迂回してCPUバッチを取り出す。元のプロシージャル材質、GPU魚インスタンス、アニメーション看板・一部ランタン、草木・岩散布は出力対象外。省略一覧はworld.jsonに記録する。

Marionette extension:

- `madogiwa.inspectTidewater`: ready、カメラ、依存コミット、建物数。
- `madogiwa.openTidewater`: `name=pier|village|overview|shore|water`。

Mac debugで見た目・操作を確認する。非アクティブ時は描画を止めるため、スクリーンショット確認時はアプリを前面にする。debugの描画結果はモバイル性能・発熱の保証ではない。


## 海の改善（2026-09-26）

現在のforkの `.fmat` / scene color・depth / PlanarReflectorComponent を使用。forkやFlutter GPUへの追加変更なし。透過は不透明シーンの色と深度を読み、光路長による吸収と屈折を計算する。水面自身はalphaパスで描き、計算済みの透過色を二重ブレンドしない。岸の深さは表示用4m地形の三角形から採取する。

水面メッシュは湾の周辺を1.5m間隔、外側を連続的に粗くした257×257頂点・131,072三角形。単一メッシュでリング境界の隙間を避ける。細かな波はフラグメント法線で補い、遠方では画素サイズに応じて弱める。静的な島はshadowStatic、反射の対象から水面自体を除外する。

- 平面反射は解像度倍率0.35。追加描画を伴う。`--dart-define=WATER_REFLECTION=false` で無効化し環境反射へ切替。
- `madogiwa.setWaterPreview` の `frozen=true` で水面時刻を12秒に固定。`reflection=false|true` で比較できる（起動時に反射自体を無効化した場合を除く）。
- `.fmat`の属性・engine_inputsを変更した際はアプリを停止して起動し直し、build hookによるshaderbundle再生成を確認する。Dartのhot restartだけでは古いbundleが残る場合がある。
- 反射は平面投影で、波の法線による反射UVの歪みは未対応。泡・コースティクスは見た目の近似。屈折は画面内の不透明物に限定される。水中や水平線の大波、原作FFTとの一致は未達。

### Profile比較

```sh
mise exec -- flutter run -d macos --profile --dart-define=WATER_BENCHMARK=true
# 同じコマンドに以下を追加して反射なし／旧材質を比較
# --dart-define=WATER_REFLECTION=false
# --dart-define=WATER_LEGACY=true
# 固定視点: --dart-define=WATER_SCENARIO=pier （既定overview）
```

起動して前面に置き、120フレームを除外した360フレームのFrameTimingを `WATER_BENCHMARK` JSONとしてログへ出す。非アクティブになった場合は採取し直す。UI build/rasterのCPU時間であり、GPU実行時間・表示FPSではない。`WATER_LEGACY`は旧材質と旧環境設定を新しい同一メッシュに適用する比較で、旧コミット全体の性能再現ではない。記録は [海の検証](qa/water-20260926/README.md) を参照。

### 起動時の準備

Tidewaterは `App.precompile()` で画面外・非表示メッシュや水面の派生パイプラインも先に準備し、GPU完了を待ったうえで2フレーム試し描画する。島・植生・沿岸データも起動時に生成している。

このアプリでは `.fmat` のソースコンパイルはbuild hookによりビルド時に実行済み。島の形状・高さはオフライン変換済み。さらにシーン構築後、表示前に `scene.warmUp([RenderView(camera: camera)], includeOffscreen: true)` を実行するようにした。実際の材質・影・反射・ポスト処理構成で小さな画面へ一度描画し、初回のパイプライン作成・リソース転送を先に進める。`inspectTidewater.warmedUp` で完了を確認できる。

forkのwarmUpはバックエンドが非同期コンパイルする場合、開始を促すが完了までのGPUフェンス待機を保証しない。また64×64の準備描画なので本番サイズのターゲット割当まで済むわけではない。原作の非同期コンパイル＋キュー完了待ちと同一ではなく、初回の引っ掛かりがゼロになる保証はしない。ロード時間・初回フレーム改善率のA/B計測は未実施。

今後、海岸への波の向き・距離の場、岩や木材の法線・粗さ、タイル可能な波の法線を事前生成すれば、実行時シェーダーの計算をテクスチャ参照へ置き換えられる。標準Flutter GPUのまま使える方向で、起動時間と容量・メモリとの配分を選べる。起動時準備だけで毎フレームのFFT・流体計算が不要になるわけではない。

参照: [Tidewater App.js 固定版](https://github.com/dgreenheck/tidewater/blob/4811ba48d795197de5621985f404e765c0b7c0ef/src/App.js#L373)、[fork Scene.warmUp 固定版](https://github.com/K9i-0/flutter_scene/blob/93d420be938213d19744723f8f6bb56be301187d/packages/flutter_scene/lib/src/scene.dart#L1263)。

## 波の常時再生と環境音

水面の大きなうねりは頂点、細かな波はフラグメント法線で毎フレーム更新。比較用extensionで止めない限り常時動く。`inspectTidewater.waterTime` で進行を確認できる。

環境音は `audioplayers` により、採用済みのTidewater実録音をローカル再生。遠い波・風・桟橋の水音を重ね、約6秒の沿岸の泡と同じ周期で砕ける波→寄せ波→引き波を鳴らす。海岸のゼロ交差を起動時に8m間隔・縦横の両方向で採取し、距離・高さ・視線から音量と左右定位を求める。カモメ／内陸の鳥は間隔を変えて鳴らす。原作の地点ごとの砕波シミュレーションとの完全同期やHRTFではない。

- 右下の音量ボタンでミュート。非アクティブ時は音も停止し、復帰時は背景ループだけを再開する。
- 更新は10Hz、同時に1回のみ実行。最大3背景ループ＋3波イベント＋1鳥。ピーク正規化された音源を元のLUFSに応じて下げて混合する。
- `madogiwa.inspectSoundscape`: ready/error、ミュート、海岸距離、各背景音の再生位置と音量、波・鳥のイベント数。
- 音源と出典は [共通正本](../04_GAME_ASSETS/audio/tidewater/README.md)。追加ダウンロードは不要。
- `WATER_BENCHMARK=true` は描画比較用に環境音をロードしない。環境音込みの端末別のCPU・電池負荷は別計測が必要。


## 一人称の歩行（2026-09-26）

- 左右移動をFlutter Sceneの左手系カメラの右ベクトル（up × forward）に統一。A/D・画面矢印・飛行の左右を修正し、沿岸音の左右定位も同じ向きにした。
- 地上はSpace／右側のジャンプボタン。初速5.8m/s・重力18m/s²で約0.9m上昇。移動中に跳べて空中操作も可能。二段ジャンプなし、短い先行入力・踏切猶予あり。飛行中は従来どおりSpace/Cで上下。
- 半径0.28m・高さ1.7mの直立カプセル相当。既存の394個の回転箱＋168個の円柱を用い、側面を滑る、36cmまでの段差、箱・樽への着地、天井への頭打ちを処理。高速時は6cm以下に分けて移動。頭が天井に触れた際に横へ押し出されないよう接触を区別する。
- 歩行加減速、目線高1.62m、歩行距離に合わせた小さい上下揺れ。非アクティブ時は移動入力・横速度を解除する。
- 接地中に実際に進んだ距離と着地で足音。砂／濡れ砂／木／草／岩の採用実録音を使う。地形の材質判定は高さと傾斜、人工物は接地した当たり判定からの近似。
- 砂・濡れ砂の足跡は左右交互の靴底形状。表示用地形へ沿わせて配置し、9秒後から薄れ18秒で削除。最大48個。壁へ押し続けた場合・空中・静止中には歩行の足跡を増やさない。接地タイミングの足跡は付く。

衝突形状は元データの箱・円柱で、描画メッシュそのものに対する精密判定や動的剛体ではない。元データに当たり判定のない装飾、小さな凹凸、傾いた屋根の表面は一致しない場合がある。海への進入は引き続き制限する。

検証用 `madogiwa.drivePlayer`: `seconds=0..3`, `forward/right=-1..1`, `jump=true`, `pitch=-1.45..1.45`。本番と同じ移動処理を120Hzで進めるdebug専用extension。再生時間を進めるため、通常の性能測定には使わない。詳細は [歩行検証](qa/player-20260926/README.md)。
