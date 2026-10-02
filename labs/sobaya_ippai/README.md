# そば屋の一杯

Flutter Sceneによる縦画面の3Dミニゲーム。18秒でジョッキを満たし、ビール7：泡3の一杯をそば屋に差し出す。端末を左右へ傾けると注ぎ、元の姿勢へ戻すと止まる。泡を含めて容量を越えたら即OUT。

## 起動

```sh
cd 25_SOBAYA_IPPAI
mise exec -- flutter pub get
mise exec -- flutter run -d macos
# iOS / Android は flutter devices の端末IDを -d に指定
```

Flutter 3.47.2 / Dart 3.13.2。iOS・Android・macOSのネイティブアプリ。Flutter GPUを有効化済み。Macは縦長ウィンドウでタッチ代替のスライダーを使用する。Web対象ではない。

## 遊び方

1. スマホを縦に持ち「一杯、注ぐ」。開始時の持ち方が基準になる。
2. 左右どちらかへ傾けて注ぐ。60度で最大。急な動きや強い流量は泡が増える。
3. 浅い傾きで量と泡を調整。目標は充填100%、泡30%。
4. 端末を戻し「止めて、差し出す」。制限時間でも自動的に止まる。
5. 0.24秒分の空中のビールが入った後に採点。止めてからの溢れもOUT。

センサー未対応・未検出時にはスライダーを表示。開始画面と一時停止でセンサー／タッチを切り替えられる。バックグラウンド移行で停止し、再開時に姿勢を再補正。ベストスコアは端末内へ保存。音量アイコンで効果音を消音できる。

## 採点と液体

`充填率 × 100 × 泡評価` を四捨五入。泡評価は30%との差1ポイント以内で1、それを越えた差に比例して低下する。99.5%以上の充填かつ泡が理想付近なら100点に丸める。溢れは0点／OUT、80点未満はそば屋が怒る。100点への到達は通常入力によるテストで保証。

液体は120Hzの体積モデルと、円形41×41格子の液面計算を組み合わせる。液面は最大240Hzでラプラシアンによる波の伝播、壁での反射、注ぎ口の衝撃、減衰を解く。平均変位を除去して波による体積増加を防ぎ、波頭も溢れ判定へ入れる。3次元の完全なNavier–Stokes計算ではなく、スマホでのリアルタイム描画を狙った高さ場の近似。

接写では次を使用する。

- 正典から細分化した厚み付きガラスと取っ手、IOR 1.52の屈折・反射。
- 動的メッシュによる液面、内壁の径に合わせた体積、壁際のメニスカス。
- ビール内の光路長とRGB吸収係数によるBeer–Lambertの吸収色。複数の奥行きで上昇する微細な気泡。
- Voronoiセルによる微細な泡の凹凸とフィルム。泡とビールの境界を同じ液面へ接続。
- 240個の結露を1メッシュへまとめて描画。落下に伴って断面が細くなる注ぎ筋、飛沫。
- 浮動小数点HDRのストリップライト環境、矩形面光源3灯、控えめなブルームと被写界深度。

ビールの内部は不透明な光学近似材質として先に描き、その色を外側の透過ガラスが屈折する。これは透明物同士の描画順による色抜けを避ける実装で、シーン全体のパストレーシングや厳密な多重屈折ではない。実写との一致を保証するものではなく、画面と操作を見ながら調整する。

- `lib/pour_game.dart`: 純Dartのゲーム計算・採点。
- `lib/tilt_input.dart`: 加速度の重力方向、平滑化、基準姿勢、古い入力の停止。
- `lib/pour_scene.dart`: 居酒屋、カメラ、光学材質、そば屋の待機と首振り。
- `lib/surface_fluid.dart`: 液面の波動計算。`lib/liquid_geometry.dart`: 液面・注ぎ筋・結露のメッシュ。
- `lib/studio_lighting.dart`: 線形HDR照明。`assets/materials/`: ビールと泡の専用GPUシェーダー。
- `lib/main.dart`: 縦画面UI、ライフサイクル、振動、記録、検証extension。
- `lib/pour_audio.dart`: オリジナル合成効果音の再生。台詞音声は収録していない。
- `tool/build_audio.py`: 3つの効果音を再生成するPythonスクリプト。
- `tool/balance.dart`: 実際の入力で泡の比率と採点を確認するスイープ。

人物は共有資産 `04_GAME_ASSETS/3d/hazard_rebuild/locomotion_v1/sobaya.glb` の相対symlink。既存Idleを使用し、結果の首振りだけHead骨へ加える。顔・仮面・体格や元GLBは変更しない。ジョッキは正典から派生させた `04_GAME_ASSETS/3d/props/ippai_mug/beer_mug.glb` への相対symlink。`tool/build_hero_mug.py` で再生成する。ビルドフックが生成する `flutter_scene_generated/` は再生成可能なので追跡しない。

## 検証

```sh
mise exec -- flutter analyze
mise exec -- flutter test
mise exec -- dart run tool/balance.dart
```

Dart MCPでdebug起動後、Marionetteで接続する。

- `madogiwa.inspectPour`: ロード、センサー、泡、充填率、空中の量、波頭、スコア、直近180フレームのFlutter build/raster時間。時間はCPU側の測定で、GPU実行時間・実機fpsの保証ではない。
- `madogiwa.pourAction`: `action=start|step|serve|pause|resume`。
- `step`: `seconds=0..22`, `tilt=0..1`。通常処理を120Hzで進めて描画を固定。値や勝敗の直接注入はしない。
- `start` は導入から開始。約1.6秒のカメラ移動後に注ぎが有効になる。
- `resume` は実時間に戻す。ボタンのKeyは `start / pour_slider / serve / retry / pause / resume`。

センサーの実際の持ち心地、実機のGPU性能、音の聞こえ方はシミュレーターと異なるため、実機確認の結果と分けて記録する。

## 確認済み（2026-10-02）

- 静的解析で指摘なし。ゲーム計算10件＋センサー計算2件＋液面計算2件のテスト成功。
- Dart MCPでMacとiPhone 18 Proシミュレーターをdebug起動。
- Marionetteで開始、スライダー、停止／再開を操作。通常の計算経路で100点と溢れOUTを確認。ランタイムエラーなし。
- Android debug APKビルド成功。iOS releaseの署名なしビルド成功。
- `qa/scenarios.json` に成功／失敗の入力結果。`qa/*.png` にローカルの画面記録（Git管理外）。
- 実機の傾き操作、Android端末上での描画、実機GPU性能・発熱は未検証。効果音はオリジナル合成音で、そば屋の台詞は字幕のみ。

Android APK: `build/app/outputs/flutter-apk/app-debug.apk`。iOSの `build/ios/iphoneos/Runner.app` は署名なしなので、そのまま端末へインストールする配布物ではない。iPhoneではXcodeの署名設定を使って `flutter run -d <端末ID>` で起動する。
