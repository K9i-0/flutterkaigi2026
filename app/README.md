# そば屋のビール雨（試作）

横画面固定、20秒のFlutter Scene製3Dキャッチゲーム。そば屋を屋上の面状ステージで動かし、降ってくるビールだけを集める。

## 遊び方

- スタート時の持ち方を中立にして、端末を小さく前後左右に傾けて移動。約14度で最大速度。
- 右下のボタンでカメラを45度回転。回転中も画面を基準に移動方向を変換する。
- 缶の影と着地点の輪へ先回りすると自動キャッチ。ビールは100点、連続キャッチで最大200点。発泡酒は−200点でコンボが切れる。
- ビールを逃すとコンボが切れる。発泡酒を避けても減点されない。
- 一時停止から再開すると持ち方を再調整する。センサーが使えないシミュレーターでは左下のパッドをドラッグ。
- 「配置」を押して次のプレイの配置seedを変更できる。

## 素材

窓際スーパーつらいは `03_SCRIPTS/00_TEMPLATES/props/product_super_try.png` を正典として3D缶へ投影。窓際ライトと発泡酒「つらめ」は今回限りの仮デザイン。仮の識別手掛かりとして発泡酒には紫帯を付けている。

モデルは `assets/models/` から共有資産への相対symlink。そば屋は `04_GAME_ASSETS/3d/hazard_rebuild/locomotion_v1/sobaya.glb` のIdle/Walk/Runを再利用し、体型や顔は変更していない。移動速度に歩行・走行モーションを同期する。効果音は既存の `25_SOBAYA_IPPAI/assets/audio/` を参照。

## 開発

```sh
cd 26_SOBAYA_BEER_RAIN
mise exec -- flutter pub get
mise exec -- flutter run -d <device-id>
mise exec -- flutter analyze
mise exec -- flutter test
mise exec -- flutter build apk --debug
mise exec -- flutter build ios --simulator --debug --no-codesign
```

Flutter 3.47.2 / Dart 3.13.2。Flutter Sceneはpubspec記載のfork commitに固定。`hook/build.dart` がGLBから実行用シーンを生成する。iOSはFlutter GPUを有効化し、横向きのみをInfo.plistへ指定。AndroidもDart側で横固定。

`tool/build_labels.py`（Pillow）→ `tool/build_cans.py`（Blender）の順で仮ラベルと缶を再生成する。正典缶の元画像は変更しない。

## 自動操作と撮影

Dart MCPでdebug起動し、App URIへMarionetteを接続する。

- `madogiwa.inspectCatch`: phase、時刻、座標、カメラ角、得点、落下缶、キャッチ履歴、センサー有無。
- `madogiwa.catchAction`: `action=start` で停止状態のラウンド開始。
- `action=step, seconds=0..25, x=-1..1, y=-1..1`: 60Hzで入力を進めて停止。xは画面右、yは画面奥。
- `action=rotate, direction=1|-1`、`action=pause|resume`。
- `action=demo`: 撮影用入力コントローラ。移動入力とカメラ操作だけを供給し、通常の衝突・得点計算を通す。実機の傾きセンサー収録ではない。最初の発泡酒にも向かうため減点を確認できる。

XcodeBuildMCP `record_sim_video` で開始→ `action=demo` →約25秒後に停止。`qa/playthrough.mp4` がローカルの納品動画。動画はゲーム内組み込み用資産ではないためGit管理しない。

## 検証範囲

iPhone 18 Pro / iOS 27シミュレーターで3D表示、右方向移動、カメラボタン、一時停止、20秒の完走、得点・減点を検証。Dartの5テストで画面座標変換、キャッチの一回性とコンボ、境界と終了、撮影入力の完走、センサー校正・無効値・途絶を検証。

実端末での傾きの感触、端末別GPU性能、Android実機の描画は未検証。落下はゲーム用の軌道計算で、缶同士の剛体衝突は扱わない。背景と仮缶は試作用の簡易造形。

## 左右移動版（2026-10-02追加）

起動時は左右移動版。開始・結果画面の切替ボタンで従来の面移動版も遊べる。

- 移動はX軸の一本道。前後入力を無視し、カメラを動かしても左右操作は逆転しない。
- カメラは30度ずつ、正面から左右60度まで。缶はカメラへ正対せず、左右70〜110度の固有の向きを保って落ちる。
- 左右版の缶は表140度にだけ識別ラベルを付け、残りは3種共通の銀色。裏から紫帯を見て即判別することを防ぐ。正典缶の表画像は従来と同じ。
- そば屋は共有GLBのWalkを速度同期で連続再生し、立ち止まるとIdleへ遷移。最大速度2.6。
- 専用GLBは `tool/build_cans.py -- --lane` をBlenderで実行して生成。既存の面移動用GLBは維持する。
- 自動操作は `madogiwa.catchAction` の `action=start|demo, mode=lane|plane`。撮影用コントローラは対象の向きへカメラ入力を供給する（人間の目視判定を再現するAIではない）。
- 新しいプレイ動画は `qa/lane_playthrough.mp4`（シミュレーター実画面、入力自動供給、無音）。

追加検証: 一本道のZ固定、前後入力無視、カメラ上限、缶の向きの独立性、左右版完走を含む計7テスト。iOSシミュレーターで正面の側面表示→斜め視点の表ラベル表示を確認。実機の傾き操作感は引き続き未検証。

## 鉄骨編の舞台

左右版を高所の鉄骨渡りへ変更。移動可能範囲に沿った幅0.95のI字鉄骨を、両端の支柱に架ける。広い床を撤去し、足場のない前後には移動できない理由を地形で示す。両端にはストッパーと警戒模様、天面にはボルトと黄色い縁線。下方約17単位に道路と建物を置き、見下ろすカメラで高さを見せる。

操作・得点・20秒ルールは左右版のまま。そば屋は鉄骨の中央線を歩き、転落操作は追加していない。取り逃した缶だけ下方へ落ちる。従来の面移動版を選ぶと元の屋上ステージに戻る。

最新動画: `qa/beam_playthrough.mp4`（26秒、横長、無音、シミュレーター入力自動供給）。
