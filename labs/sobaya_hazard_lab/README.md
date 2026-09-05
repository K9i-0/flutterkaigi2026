# そば屋ハザード · 村の広場と3D検証室

**本編が追加されました。** 福ちゃんで探索・射撃・ビール回収・画像収集を行う第一章は `mise exec -- flutter run -d macos -t lib/game_main.dart` で起動します。[本編の操作・範囲・検証結果](GAMEPLAY.md)を参照してください。

以下は従来の3D検証室 `lib/main.dart` の説明です。Flutter Sceneでモデル・操作・衝突・描画負荷を個別に検証します。

## 起動

リポジトリルートから実行する。

```sh
cd 21_SOBAYA_HAZARD_LAB
mise exec -- flutter pub get
mise exec -- flutter run -d macos
```

性能比較は`mise exec -- flutter run -d macos --profile`で起動する。

- Flutter **3.47.2** / Dart **3.13.2** / flutter_scene **0.23.0**（lockfileあり）。
- ルート`.mise.toml`を現在のglobalにそろえた。global設定自体は変更していない。
- `.mcp.json`と`.codex/config.toml`も3.47.2。Dart MCPはこの版でアプリ起動ツールが既定無効のため`--enable=flutter_app_lifecycle`を追加。接続済みMCPは再接続から新設定になる。
- macOSの実描画を検証。iOS／Android／Webの雛形もあるが実機互換性・性能は未検証。nativeのFlutter GPU有効化設定を同梱。
- 初回はGLB変換・4Kテクスチャ圧縮に時間がかかる。SDK依存の`flutter_scene_generated/`はGit管理しない。

## シナリオと操作

| シナリオ | 確認すること |
| --- | --- |
| モーション | 9クリップ、再生速度、一時停止・時間送り、ジョッキ追従、正面／側面／背面 |
| 移動・衝突 | 三人称カメラ、壁で停止、壁沿い移動、カメラ遮蔽 |
| 群集負荷 | 1／4／8／12体、独立した骨格アニメーション、影・AO・解像度の比較 |

画面をドラッグして視点回転、ホイールでカメラ距離を変更する。移動モードでは画面をクリックしてからWASD／矢印で移動、Shiftで走る。画面内の方向キー長押しでも操作できる。「壁衝突テスト」は初期位置から2秒間走り、壁の手前で停止したかを表示する。フォーカス喪失・シナリオ変更時は入力を解除する。

衝突は半径0.34mの水平円と箱の簡易判定。最大5cmの分割移動で薄い壁のすり抜けを抑える。重力・階段・坂・ジャンプ・剛体・敵AIは未実装。カメラ遮蔽は壁の高さを考慮して距離を短縮する。

## モデルと軽量化

肩・顔・握り・ガラス／液体表現と、Tripo複数画像入力の調査は[品質改善方針](ASSET_QUALITY_PLAN.md)を参照。

`assets/models/sobaya.glb`は[GLB正本](../04_GAME_ASSETS/3d/characters/sobaya/rig_v3/sobaya_rig.glb)への相対symlink。ゲーム側へコピーしない。採用したGLBをGit管理対象にし、Tripo生レスポンス・署名付きURL・APIキーは含めない。

現行版は身長1.8m、28,576三角面、4材質、4K PBRテクスチャ、45ボーン／最大4ウェイト。歩行・走行・ゾンビ歩行・ダンス3種・乾杯・ジョッキ攻撃・待機の9クリップを持つ。[リグ仕様・再生成](../04_GAME_ASSETS/3d/characters/sobaya/rig_v3/README.md)を参照。

`assets/models/beer_mug.glb`も[共通小道具の正本](../04_GAME_ASSETS/3d/props/beer_mug_v2/beer_mug.glb)への相対symlink。8,276三角面・4材質で、右手のソケットに取り付ける。

モーション画面では0.25〜2倍速、一時停止、スライダーによる姿勢確認、リプレイができる。乾杯・攻撃を選ぶとジョッキを自動装備する。移動画面では速度に応じて待機／歩行／走行を切り替え、ゾンビ歩行も選べる。Cで乾杯、Eで攻撃、1／2／3でダンス。移動中のエモートは1回再生して待機へ戻る（再生中は移動停止）。攻撃のダメージ・敵への命中判定は未実装。

歩行1.25m/s・走行2.8m/s。クリップを180msでブレンドし、歩行の接地速度に再生速度を合わせる。足のランタイムIKや衣服シミュレーションはなく、腕を上げると袖の伸びが残る。

公式実装・同梱skillに沿って使用している処理:

- ビルドフックでGLBを変換。自動探索はsymlinkを除外するため`inputFilePaths`に明示。
- `compressTextures: true`の圧縮テクスチャ＋mipmap。端末対応形式へのtranscodeはエンジンに任せ、4K入力を維持。
- `loadScene`は各正本につき1回。`Node.clone()`でメッシュ・材質・テクスチャを共有し、骨・スキン・AnimationClipは個体ごとに独立させる。キャラクターのハードウェアインスタンシングとは異なる。
- グリッド42本は`InstancedMesh`。壁・地面は静的影キャッシュ、キャラクターは動的影。
- 影1カスケード／1024px／距離25m。AOは既定OFF、有効時は半解像度。
- 描画解像度50／75／100%。公式の可視判定・材質ソートを使用。
- SceneViewの事前warmupと離脱時のロード済みテンプレートclaim解放。

LOD・低解像度テクスチャ版・低ポリゴン版の比較は、Blenderでゲーム用派生モデルを作成後に追加する。

## 計測

UI／RasterのP95はFlutterの`FrameTiming`から採取。切り替え直後30フレームを除外し、直近240フレームを表示する。空サンプルは`—`／`null`とし、0msや合格として扱わない。設定・体数変更で自動リセットし、「計測リセット」でも採り直せる。

JSONコピーにはシナリオ・体数・設定・画面寸法・DPR・描画寸法・build mode・採取日時を含む。配置三角面は原型×配置数の概算で、実draw call数や影パス込み描画面数ではない。RasterはFlutterのraster処理時間であり、GPU実行時間・入力遅延・実fpsの直接測定ではない。

自動比較:

```sh
mise exec -- flutter run -d macos --profile --dart-define=LAB_BENCHMARK=true
```

前面に表示し、画面を操作せず待つ。固定カメラで1→4→8→12体、12体の影OFF、50%解像度、AO ONを各8秒以上測定し、`HAZARD_BENCHMARK {JSON}`をログへ出す。240サンプルが揃わない場合は最大30秒で`valid:false`。profile以外も無効。最後に`HAZARD_BENCHMARK_COMPLETE`を出す。

ウィンドウサイズ・端末・電源条件をそろえて比較する。全個体でWalkを再生し、スキニングも含む。本編のAI・戦闘は含まない。旧静止モデルとの測定条件差は[VALIDATION.md](VALIDATION.md)を参照。

## Dart MCP / Marionette

`dart-mcp.launch_app`のrootをこのディレクトリのfile URI、deviceを`macos`としてdebug起動し、返されたApp URIでMarionetteの`connect`を実行する。画面操作・スクリーンショットはMarionetteを使う。ローカル証跡は`evidence/`へ保存しGit管理しない。

debug native限定のカスタムextension（Marionetteの`call_custom_extension`から使用）:

| extension | 引数 |
| --- | --- |
| `madogiwa.inspectHazard` | なし。モデル・移動・計測・再生クリップ・手ソケット位置のJSON |
| `madogiwa.playMotion` | `name`: 上記9クリップ名、任意で`seek`: 秒（指定すると一時停止）、`speed`: 0.25〜2 |
| `madogiwa.openScenario` | `name`: `model` / `movement` / `crowd` |
| `madogiwa.setCrowdCount` | `count`: `1` / `4` / `8` / `12` |
| `madogiwa.setLabOption` | `key`: `shadows` / `ao` / `collision` / `motion` / `paused` / `turntable`、`value`: `true` / `false`。`key: scale`では`value`: `0.5`〜`1.0` |
| `madogiwa.setLabView` | `view`: `front` / `side` / `back` |
| `madogiwa.stepMovement` | 移動モードで`dx`, `dz`: -1〜1、`frames`: 1〜600、`sprint`: true/false。世界座標の決定論的ステップ |

## チェック

```sh
mise exec -- flutter analyze
mise exec -- flutter test
```

`test/simulation_test.dart`で壁停止、斜め速度、壁沿い移動、カメラ遮蔽、リセット、計測値の空・非有限入力を検証。GPU描画は単体テストで代用せず、実行画面とログを確認する。

参考: [公式リポジトリ](https://github.com/bdero/flutter_scene)、[flutter_scene 0.23.0](https://pub.dev/packages/flutter_scene/versions/0.23.0)。

## 品質改善版 v2

正本を`rig_v2/sobaya_rig.glb`と`props/beer_mug_v2/beer_mug.glb`へ切り替えた。43骨・28,576三角面、9モーション。肩／袖口と裾、仮面の黒い目、手と握りを改訂し、ジョッキを透過・吸収・液面モーフ付きにした。原型とv1は比較用に保持。

- ビューの「顔」「手元」で寄って確認。「乾杯」→一時停止→「手元」が持ち方の確認に向く。
- ジョッキ表示中は液量0〜100%、背景スタジオ／暗色／明色／格子を選べる。
- 近接は屈折を使用し、検証カメラの注視点距離が5m以上では軽い材質に切り替える。泡・液面は同じ傾斜に追従。
- Marionette: `madogiwa.setLabView`に`face` / `grip`を追加。`madogiwa.setBeerFill`は`fill=0..1`、任意`background=studio|dark|light|pattern`。
- profileベンチは従来7条件に、近接ジョッキ1個・遠景4個・12個を追加。欠けたサンプルを性能PASS扱いにしない。

詳細と制限は正本モデルのREADME、`VALIDATION.md`を参照。今回の改善ではTripo APIを実行していない。

## Mixamo歩行・走行 v3

WalkはMixamo「Walking / Male Standard Walk」、Runは「Running / Male Weighted Run」を修正済みそば屋へ移植。骨盤の重心移動・回転、腕振り、膝と足のタイミングは収録動作を基準とする。左右のつま先2骨を追加し、靴底の接地とつま先の支持位置を補正してGLBへベイクした。

- 元の周期は歩行1.233秒、走行0.833秒。移動モードでは衝突後の実移動量に再生速度を合わせる。
- 「モーション」で歩行／走るを選び、側面・0.5倍速で接地を確認できる。1倍速は元クリップの周期。
- Idle・ゾンビ・ダンス・乾杯・攻撃はv2のまま。開始／停止／旋回の専用モーション、段差への実行時IKは未実装。
- 元FBXと編集blendはローカル保持。取得条件と再生成手順は[rig_v3 README](../04_GAME_ASSETS/3d/characters/sobaya/rig_v3/README.md)。
