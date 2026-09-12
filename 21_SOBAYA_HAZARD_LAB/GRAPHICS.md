# 描画品質と性能の検証

2026-09-12。村・農場・山の建築、地面、遠景の形と配色を先に整え、限られた描画予算を画面の読みやすさへ使う。実写キャラクターの人物同一性は維持する。最初にM4以降のMacを改善し、その後のiPhone 16 Proでの発熱・操作のフィードバックを受け、iOSの測定と調整に着手した。機種名だけで速度を推定せず、最終判定は実機profileで行う。

## 画質の使い分け

Mac版の[実画面と美術方針](design/graphics-20260912/README.md)を保存した。Imagegenの見本から建築の面分けと遠景を選び、第1パスの草の形・明度を実画面で修正している。

解像度65／85／100%と演出プリセットは独立して保存する。古い設定にプリセットがない場合、モバイルはバランス、デスクトップは高画質へ移行する。保存済みの解像度は変えない。

| 演出 | バランス | 高画質 | 最高画質 |
| --- | --- | --- | --- |
| AA | SMAA | 人物の変形を含むTAA | 人物の変形を含むTAA |
| 太陽の影 | 1024px、2分割、32m | 1024px、2分割、32m | 2048px、2分割、40m |
| 建物の静的な影 | キャッシュ | キャッシュ | キャッシュ |
| AO | 半解像度、8サンプル | 半解像度、8サンプル | 半解像度、12サンプル |
| 会話の影・ぼけ | 通常の影、ぼけなし | PCSS、背景最大8px | PCSS、背景最大8px |
| 動的GI | なし | なし | 8×4×8プローブ、64更新／フレーム |

全プリセットで静的な空のIBL、暖色の主光源、弱いブルーム、色調、地域ごとの霧を使う。IBLの参照を設定・地域切替で再利用する。通常操作の被写界深度は無効。解像度の毎フレーム変更は行わない。使用中のSceneは変更ごとに描画ターゲットを確保し直すため、時間的に安定した画を優先する。

「光と影の演出」をOFFにすると簡易照明へ戻る。`HAZARD_ADVANCED_LIGHTING=false`は追加のAA・GI・会話ぼけを無効化する比較用フラグとして残す。

## 再現できるprofile比較

アプリを1個だけ起動し、同じウインドウ寸法・DPR・電源条件で比較する。別のアプリのGPU負荷、シミュレーター、画面収録、ビルドを止め、各条件を最低3回実行する。次は本編の村8体・同じ85%解像度で高画質を測る例。バランスと最高画質は`HAZARD_GRAPHICS`だけを変える。

```sh
cd 21_SOBAYA_HAZARD_LAB
mise exec -- flutter run -d macos --profile -t lib/game_main.dart \
  --dart-define=HAZARD_GAME_BENCHMARK=true \
  --dart-define=HAZARD_BENCHMARK_CASE=village-eight \
  --dart-define=HAZARD_GRAPHICS=quality \
  --dart-define=HAZARD_BENCHMARK_SCALE=0.85 \
  --dart-define=HAZARD_BENCHMARK_RUN=art-pass-quality-run1
```

`HAZARD_BENCHMARK_CASE`を省略すると全13条件を実行する。`HAZARD_BENCHMARK_SCALE`を省略すると従来どおり各ケース固有の85／100%になる。明示する値は0.5〜1.0。不明なプリセット・ケース名や不正な解像度は計測を中止してエラーにする。

`HAZARD_GAME_BENCHMARK`のJSONには採取日時、runLabel、プリセットと効果の実設定、viewport、DPR、実描画pixel寸法を記録する。各ケースは最低8秒動かし、最後の240 Flutterフレームと既存の行動・発話条件を確認する。`valid=true`は条件成立を意味し、60fps合格ではない。

UI／Raster P95・最大値・16.7ms超過数を並べ、60Hz予算の16.67msに収まるかを確認する。これらはCPU上のFlutterスレッド時間であり、GPU実行時間や画面に提示されたFPSではない。GPUが疑わしい場合はDevToolsのGPUTracerまたはMetalの計測を追加する。iPhoneのシミュレーターはUI・互換性の確認に使い、実機の性能証明には使わない。

最終の実機確認では通常移動、8体追跡、建物の近景、村の遠景、山のボス、会話のカメラ切替を見比べる。屋根や格子のちらつき、TAAの残像、影の浮き、霧による道の見失い、暗部の顔の可読性を確認し、15分以上の連続プレイで温度上昇後の変化も記録する。現時点でiPhone実機の長時間60fps達成を示すものではない。

## 2026-09-12 Macでの比較結果

M4 MacBook Air / 32GB / macOS 26.6.2。profile、本編の村・敵8体、1280×840 logical px、DPR 2、内部解像度85%（2176×1428 px）、各条件3回。各回の最後の240フレームを比較した。計測中に別のプロジェクトテスト・Blender・ゲーム描画を重ねていない。OS全体の背景処理や温度は固定していない。

| 条件 | UI P95の中央値（3回の範囲） | Raster P95の中央値（3回の範囲） |
| --- | ---: | ---: |
| 着手前 `a714509` | 18.24 ms（18.00〜18.55） | 5.90 ms（5.83〜5.92） |
| 改善後・高画質 | 13.03 ms（12.45〜13.54） | 4.20 ms（4.19〜4.45） |
| 改善後・バランス | 11.30 ms（11.13〜14.53） | 4.03 ms（4.01〜4.67） |

高画質のUI P95中央値は着手前より約29%減った。これは美術、静的建物の結合、カメラ計算、照明プリセットをまとめて変更した結果であり、個別の効果を分離した値ではない。全9回でワークロード条件が成立。高画質のUI 16.7ms超過は各240フレーム中2／2／5件、Rasterは0／0／0件だった。

Macでの最初の確認は高画質・85%を目安とする。最高画質や全機種、15分の連続負荷、実提示60fpsを保証する結果ではない。初期の探索計測はこの表に混ぜていない。[生の条件と結果](qa/graphics-profile-20260912.json)を参照。静的解析と全380テスト（任意監査1件スキップ）も通過した。iOSの最適化・性能評価は後続へ回す。

[高画質の追加13条件](qa/graphics-all-cases-20260912.json)もワークロード条件は全て成立した。ただし単回の連続測定では、山道100%がUI／Raster P95 18.56／18.37ms、敵の窓越え85%が20.38／21.22msなど、16.7msを超える条件が残った。村8体の改善値を全場面へ一般化しない。室内・窓付近の描画負荷、フル解像度、連続負荷後の変化は次の最適化対象とする。順序・温度を変えた反復がないため、熱と場面差の寄与は断定できない。

その後の[別起動での切り分け](qa/graphics-isolated-20260912.json)では、敵の窓越え・高画質85%が14.45／15.05ms、対照の村8体が12.43／4.06msだった。窓付近が常に20ms以上という結果ではない。各1回なので、順序や温度をそろえた長時間測定は引き続き必要。最終の設定画面だけのMaterial修正後に、この2条件と静的解析・関連UIテスト・実画面を再確認した。

## iOSの継続負荷と操作改善（2026-09-12追記）

ユーザーの試遊条件はiPhone 16 Pro、高画質・85%、約3分、充電なし。フレームレートには問題を感じなかったが、発熱が気になったとの報告。Appleも高負荷なゲーム中の温度上昇を想定しているが、FPSが維持されていることだけでは消費電力に余裕があるとは判断できない。[Appleの温度に関する説明](https://support.apple.com/en-us/118431)。

従来の本編は表示更新ごとにゲームとSceneを動かしており、30／60の上限はなかった。iOSのProMotion許可とFlutter 3.47.2の実装は確認したが、旧版がこの端末で実際に120 fps描画していた証拠はない。新しい「フレーム上限」は既定60、30も選べる。画質・解像度とは独立保存し、旧設定は60へ移行する。SceneViewで更新と描画要求を同時に制限し、間引いた時間を次の更新へ渡す。30 fpsにしただけで消費電力や発熱が半分になるとは限らない。ディスプレイ自体のリフレッシュレートを変更するAPIではない。

操作は左スティックで移動、左のタップで構える／戻す、右で撃つ／投げる、右で忍び足／走行の切り替えへ変更した。構えを押し続ける必要はない。二本の親指で操作する前提では、移動と視点からどちらの指を一瞬離すかという選択が残る。[PUBG MOBILEの公式設定案内](https://play.google.com/store/apps/editorial?id=mc_games_editorialevergreen_pubg_mobile_how_to_customize_your_settings_postinstall_now_fcp)でもボタン位置、スコープのタップ／保持、走行の入力などを調整できる。一つの配置だけを標準として強制する必要はない。現配置と誤操作防止の仕様は[GAMEPLAY](GAMEPLAY.md#スマホでの操作)を参照。

測定はまず高画質・85%・60 fpsを基準に、同じ場面・明るさ・室温・非充電・開始熱状態で比較する。次にバランス・85%・60 fpsで演出のコスト、必要なら30 fpsで更新回数のコストを分ける。最初の3分に加えて15分以上の試遊で、熱状態、実提示フレーム間隔、CPU／GPU／ディスプレイの消費電力を確認する。Metal／Instrumentsによるボトルネック計測を先に行い、自動解像度変更や温度で画質を上下する処理はまだ導入しない。[Appleのゲーム計測資料](https://developer.apple.com/videos/play/meet-with-apple/242/)。

`madogiwa.deviceDiagnostics` は物理iOSの熱状態と低電力モードを読み取り、ゲーム更新回数とScene.render呼び出し回数を別に返す。温度はOSの段階評価であり、摂氏温度ではない。操作感はdebugで確認し、性能はprofileで測る。Simulatorの結果を実機の熱状態として扱わない。[診断の呼び方](MCP_DEBUGGING.md#iosの熱状態とフレーム上限2026-09-12)。

3分間を同じ追跡条件で測る場合は、通常のprofileコマンドへ次を追加する。

```sh
--dart-define=HAZARD_GAME_BENCHMARK=true \
--dart-define=HAZARD_BENCHMARK_CASE=village-eight \
--dart-define=HAZARD_GRAPHICS=quality \
--dart-define=HAZARD_BENCHMARK_SCALE=0.85 \
--dart-define=HAZARD_BENCHMARK_FPS=60 \
--dart-define=HAZARD_BENCHMARK_SECONDS=180
```

FPSは30／60のみ、秒数は8〜300の整数（既定8）。条件未達時は `max(30,指定秒数+22)` 秒で無効な結果も出力する。最後の240 FlutterフレームのUI／Raster値と、ケース全体の `sceneRenderCallsPerSecond` は測定窓が異なる。熱状態は開始・10秒間隔・終了を採取し、取得失敗、取得時刻、観測したピークを残す。10秒の間に起きた未観測の変化を否定する記録ではない。計測中だけ既存のpollを使い、通常ゲーム中は熱状態を定期取得しない。設定と進行の保存には書き込まない。

今回のiPhone 16 Pro／iOS 26.6.2のdebug確認では、新しい左右配置で1タップ射撃（6→5発、shots=1）、忍び足の保持、30 fpsの保存・再起動を確認。30設定・バランス65%で12.231秒に367回、毎秒30.005回のScene.render呼び出しを観測した。休止中7.426秒では更新・描画カウンターが増えなかった。全425テスト（任意監査1件スキップ）と静的解析も通過。[検証記録](qa/ios-controls-thermal-20260912.json)。

初回の診断時点で熱状態はすでに `serious`、低電力モードはOFFだった。有線デバッグ中の観測で、開始温度・画面輝度・充電状態を統制していないため、原因や発熱の改善幅を示さない。初回起動にはバックグラウンドGPUエラーと紫色の材質があり、前面のままhot restartすると同一素材で正常に戻った。正本・検証コピー・iOSバンドルの生成シーン／シェーダーは一致し、素材変換の破損は見つからなかった。背景でのGPU初期化後のリソース状態が疑わしいが、エンジン内部の個別原因は未特定。実機の横向き操作感、15分の継続性能、非充電での発熱改善は未検証。

## クローンと実機負荷の切り分け（2026-09-12）

`madogiwa.deviceDiagnostics` に、公開APIによるプロセス全スレッドのCPU累積秒、メモリのphysical footprint、バッテリー状態・残量、画面輝度、利用可能なコア数を追加した。CPU率は累積CPU秒の差をnative採取時刻の差で割り、100を掛ける。100%は1コア分で、複数コアなら100%を超える。熱状態は `nominal / fair / serious / critical` の段階で、摂氏温度、GPU使用率、消費電力の測定ではない。[getrusage](https://developer.apple.com/library/archive/documentation/System/Conceptual/ManPages_iPhoneOS/man2/getrusage.2.html)、[Apple DTSのメモリ計測](https://developer.apple.com/forums/thread/105088)。

iPhone 16 Pro / iOS 26.6.2、profile、村8体追跡、高画質85%、60 fps上限、各60秒。縦画面402×874 logical px、DPR 3、内部1026×2229 px。USB接続・充電中、輝度35%。ユーザーの非充電試遊と条件が異なる。最初のGPU計測はInstrumentsの接続が完了せず停止し、以下はInstrumentsなしで採取した。

| 条件（実行順） | Scene.render呼出/秒 | UI P95 | プロセスCPU（1コア=100%） | 開始→終了の熱状態 |
| --- | ---: | ---: | ---: | --- |
| 従来描画 | 33.09 | 46.69 ms | 89.12% | fair→serious |
| 骨転送を一括化した試作 | 32.03 | 49.08 ms | 106.66% | fair→serious |
| 同じ試作コードで一括化OFF | 29.19 | 55.58 ms | 77.47% | serious→serious |

全ケースで8体の追跡と測定条件は成立。CPUは初回描画のwarmupを含む全区間、UI P95は最後の240 Flutterフレーム。呼出回数は実提示FPSではなく、CPU率は消費電力ではない。開始熱状態・バッテリー残量・背景処理を統制した反復比較ではないため、表から速度差や発熱低減率を確定しない。[値と条件の記録](qa/ios-clone-profiling-20260912.json)。

従来方式の既存Dart profiler記録5,493サンプルでは、leafの約80%がMetal command buffer作成中の `semaphore_wait_trap`。ゲームcontroller tickはinclusive約2.5%、経路更新は約1.4%だった。これらは待機も含むスタックの割合で、CPU使用率とは異なる。Bloom内部に待ちが多く現れたが、Bloom自体のGPU演算時間とは断定できない。Appleのcommand queueは空きがないとCPU側を待たせる。[command bufferの作成仕様](https://developer.apple.com/documentation/metal/mtlcommandqueue/makecommandbuffer%28descriptor%3A%29?language=objc)。

クローンの骨転送をまとめる試作は、個体ごとの行列・GPUテクスチャ・前フレーム履歴を維持したまま、1フレーム11回の転送を1 command bufferへ集約できた。MacのTAA・3体追跡・巨人・会話で正常表示、iPhoneではfallback 0を確認。ただし待ちの場所がDepthPrepass等へ移り、プロセスCPU負荷は低下しなかった。**発熱改善として採用せず、製品のrendererを元へ戻した。** 試作パッチと生ログはローカルに保存した。Bloomの複数描画パスを1 command bufferにまとめる案も、固定SDKのMetal encoder終了APIの制約から実機実行前に撤回した。

モデルのGeometry・元材質・アニメーション資産は `Node.clone` で共有済み。そば屋は1体1 skin、45骨、4材質で、材質ごとに骨転送を重複していない。ジョッキも近距離4m以内の最寄り1体だけ高詳細で、それ以外は屈折と細かい泡を省く。追加の材質共有だけではdraw数は減らない。

クローン設定をさらに使う本命は、共有するモデル内の骨姿勢と、個体ごとの位置・向きを分離し、同じ姿勢のグループをGPUでまとめて描く方式。現rendererは骨テクスチャに個体の世界座標を含め、skinned meshを自動instancingから除外しているため、色・深度・影・TAA速度の各パスをそろえて改修する必要がある。歩行の位相、攻撃、頭・ジョッキ位置、命中判定の独立性を維持する設計が必要で、今回の小変更へ無理に含めない。

採用した変更は診断・完全な分割ログ・CPU集計と、計測終了時の継続描画停止。通常ゲームへ定期的な計測や自動画質変更は加えていない。非充電・同じ開始熱状態での3分／15分比較と、実提示フレーム／GPU消費電力の取得は未実施。

## 参照資料

- [Flutterのprofile計測](https://docs.flutter.dev/perf/ui-performance)は実機・profile modeの利用を説明する。
- [DevTools Performance](https://docs.flutter.dev/tools/devtools/performance)でUI／Rasterの担当処理とフレームの内訳を確認できる。
- [Flutter Scene公式リポジトリ](https://github.com/bdero/flutter_scene)にIBL、GI、SMAA／TAA、インスタンシング、LODの対応が記載されている。このプロジェクトは既存パッチを含む`vendor/flutter_scene` 0.23.0に固定し、APIと描画ターゲットの再確保は同梱ソースでも確認した。
