# そば屋ハザード · 村・農場・山道と3D検証室

**本編が追加されました。** 福ちゃんで探索・射撃・ビール回収・画像収集を行う3区画の制作中体験版は `mise exec -- flutter run -d macos -t lib/game_main.dart` で起動します。[本編の操作・範囲・検証結果](GAMEPLAY.md)を参照してください。

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

ゲーム本体の接続・一括検査は [MCP_DEBUGGING.md](MCP_DEBUGGING.md) を参照。`madogiwa.debugSession` で接続先を確認し、`madogiwa.runGameProbe` の `name=conversation` で実フレーム上の会話・口の同期・停止再開をまとめて検査できる。

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

## ゲーム内の声と環境音（2026-09-06）

本編は「そば屋エンジン」の放棄と、廃村ゆめみ村へ島流しされた三人を中心に再構成し、被弾声を含む69本の発話、探索メモ8枚、ポスター12枚の裏書きを収録。[物語・事故の因果関係・探索仕様](STORY.md)を参照。福ちゃん・やめ太郎・そば屋は正典Irodori、たこさんは第21話と同じVOICEVOX:Voidoll（style 89）。[音声台本と生成条件](../04_GAME_ASSETS/audio/hazard/script.md)を正本とし、ゲームから相対symlinkで利用する。

村・農場・山道の環境音と、敵が近い時に入るオリジナル音楽を追加。会話中は背景音を下げる。設定で全体・台詞・BGM・効果音・環境音を個別に調整できる。台詞送りとスキップで旧音声を破棄し、一時停止／非アクティブ化で再生を止める。読み込み中はカットの時計を待機し、音声長＋0.5秒以上を確保する。音声が読み込めない場合は8秒で待機を解除して字幕を継続する。

`madogiwa.inspectHazardGame` の `voice` / `soundscape` は要求中の台詞、読み込み状態、エラー、ネイティブ再生位置／尺／再生状態を返す。[ネイティブ検証記録](qa/voice-native-20260906.json)、[素材検査](qa/voice-assets-20260906.json)、[ローカル文字起こし](qa/voice-transcript-20260906.json)を参照。そば屋エンジン編60本を文字起こしで確認済み。文字起こしには同音異字や認識誤りが残り、聴感・声の本人らしさの承認ではない。福ちゃん・やめ太郎は音声の強弱に合わせて口を動かす。音素ごとの口形ではなく、停止・再開と話者切り替えを含む簡易同期（[検証記録](qa/speech-mcp-20260906.json)）。音声追加後のprofileは下記の9条件で計測済みだが、口のモーフ追加後は未測定。

塔の登降と敵の追跡検証は `GAMEPLAY.md` の「塔の登り降り」を参照。
`madogiwa.openGameScenario` の `ladder` / `enemyLadder`、通常UIの再開とEで再現できる。
登攀GLBを生成し直した場合はビルドフックのアセット変換を伴う再起動が必要。
Dartのみのホットリスタートで新しいクリップを読み込めるとは限らない。


## 音声を含む本編profileとMacパッケージ

```sh
# 21_SOBAYA_HAZARD_LABから実行
mise exec -- flutter run -d macos --profile -t lib/game_main.dart --dart-define=LAB_BENCHMARK=true
mise exec -- flutter build macos --release -t lib/game_main.dart
# リポジトリルートから、実際にビルドしたコミットを指定
python3 tools/package_hazard_macos.py --revision BUILD_COMMIT --output .local/hazard_releases/sobaya-hazard-macos-BUILD_COMMIT
```

本編のベンチマークは村・農場・山道の7条件、福ちゃんの窓往復／そば屋2体の窓越え2条件、導入／最終戦の音声付き会話2条件の計11条件。標準音量を一時適用し、ユーザー設定には保存しない。`HAZARD_GAME_BENCHMARK`も同じ起動フラグとして使える。各条件で実描画240サンプル、前面状態、想定するゲームフェーズ、環境音再生、会話条件では発話開始を検証する。

窓の条件では通常の登降処理を繰り返し、60描画tick以上の通過姿勢と着地完了も有効性の条件にする。福ちゃんは双方向に往復し、敵は2体が着地した後に計測用の開始位置へ戻す。`windowMotionTicks`・`completedWindowPassages`はその条件の開始からの累積であり、通常プレイの経路証明や窓越えだけの単独コストではない。

[2026-09-06の全計測](benchmarks/game-audio-20260906.json)はMac M4、1280×840、DPR 2、別のiOS Simulatorが描画中の結果。最終9条件はすべて有効で、UI P95は4.869〜6.034ms、Raster P95は0.483〜9.304ms。標準85%の条件ではUI／Rasterとも16.7ms超過なし。100%の村8体ではRasterが240サンプル中5回超過した。標準85%を維持し、単独条件や長時間の安定FPSは未確認とする。発話を開始できなかった初回の2条件も無効な記録として残した。

音声の再生位置は200ms間隔で取得する。audioplayers 6.8.1はループ完了時も位置通知を停止するため、再生要求中だけ位置通知を再開する。ネイティブの音源自体を再スタートさせる処理ではない。Darwinで音がループ継続していても、プラグイン由来の`state`は`completed`になり得るため、`positionMs`・`loopCompletions`・セッション状態を併せて確認する。通知頻度の変更によるFPS改善をこの計測からは断定しない。

Macパッケージ作成では3区画、9シーン、各manifestに記載された音声キューと収集画像の同梱・ハッシュ一致、内部symlink、署名整合性、ZIPのCRCを検査する。シーンmanifestの一致も検査し、各生成元GLBと変換済みシーンのハッシュを別々に台帳へ記録する。正本GLBや認証情報は同梱しない。出力はローカルの検証用ZIPで、ad hoc署名・未公証。Intel用バイナリは含まれるが実機検証はApple Siliconのみ。公開配布と長時間の最終確認は別途必要。

最新のローカルMacプレビューは `.local/hazard_releases/sobaya-hazard-macos-adf5ea4.zip`。掴み・長押し脱出を含み、97テストとdebug実機の脱出確認、同梱素材・署名・ZIP整合性を通過。Release版の画面操作は未確認。[掴みの検証記録](qa/grapple-20260906.json)。

前版のローカルMacプレビューは `.local/hazard_releases/sobaya-hazard-macos-e7726a9.zip`。梯子・窓越え・衣服修正を含み、ビルド情報と確認範囲は[更新版Mac検証記録](qa/mac-traversal-preview-20260906.json)を参照。素材・署名・ZIP整合性とプロセス起動を確認済み。UIツールのウィンドウ取得エラーにより配布版の画面確認は未完了で、debugの全編確認や以前のReleaseの操作確認とは区別する。旧ZIP `19a9d86`の記録は[こちら](qa/mac-preview-20260906.json)。

窓・衣服修正後の[11条件のprofile結果](benchmarks/game-traversal-20260906.json)では全条件が有効。UI P95は4.552〜7.103ms、Raster P95は0.466〜1.011msで、各240フレーム内の16.7ms超過はUI／Rasterとも0。福ちゃんの窓往復は4回、敵の窓通過は2体以上を計測条件内で確認した。Mac M4・32GB・macOS 26.6.2、1280×840・DPR 2、別のiOS Simulator起動中。前回との差の原因や長時間の安定FPSを証明する結果ではない。

[窓追加後の全編検査](qa/campaign-traversal-20260906.json): 規則検査は0枚から全12枚の収集と20ドロップ回収、実描画は20体撃破・20ドロップ回収からクリア画面まで約7分41秒。実描画側は既収集12枚を引き継いだため、新規全収集の証明は規則検査と区別する。既知経路と自動照準であり、初見の尺・難度の評価ではない。

戦闘音・音楽を更新: [作曲・音色・再生成条件](../04_GAME_ASSETS/audio/hazard/SCORE.md)。探索/追跡は各48秒のオリジナル曲、発射/ジョッキ音と正典の「ビール」声は各3バリエーション。詳細は [本編の音響検証](GAMEPLAY.md) を参照。

### そば屋エンジン編の検証

`madogiwa.runGameProbe` は `conversation`、`companionYametaro`、`companionTakosan` を受け付ける。被弾プローブは本物のフレームで被弾声→倒れる台詞→ゲームオーバーを観測し、テスト中のセーブを書き込まない。`madogiwa.openGameScenario(name=storyMemo)` は最初のメモ前へ移動する。[今回の実機記録](qa/story-native-20260906.json)を参照。

最終の「ゆめみ村・特別研修」改訂は126テスト・音声60本の整合性・Macアプリ同梱ハッシュを確認済み。台詞とメモ改訂後の前面再生確認はMacのロック解除待ち。被弾声と口パクのネイティブプローブは改訂前に成功し、上記QAには確認した版を明記している。
