# 窓際族・無人島クラフト

窓際族のメンバーが無人島へ島流しされ、ブロックを採取・設置して生活基盤を作る
Minecraft風の256×256マス3Dクラフトゲームです。Flutter 3.47 stableで利用可能になった
Flutter Sceneを、窓際族物語の正典ボクセル素材で実ゲームへ使う検証も兼ねています。

## ゲーム内容

- そば屋を操作し、島の別々の場所に隠れたやめ太郎、ゆめみん、タコさんと再会
- 256×256マスの島をWASD／矢印キー／画面アナログスティックで自由に探索
- 歩いた周囲だけ地形が開く簡易マップと、4つの固有ランドマーク
- 木、岩、木の実、石炭、鉄鉱石、薬草を7マス以内から直接採取
- 木材、石材、食料、石炭、鉄、薬草をスタックするインベントリ
- 作業台から8種類の設備・道具をクラフト
- 好きな地面へ「床 → 壁 → 屋根」の順でブロックを設置
- 木材1個で松明を設置。開始キャンプにも検証用の松明を1本配置
- 床4枚、壁4枚、屋根、焚き火、作業台で生活基盤が完成
- 再会したメンバーは同行／拠点配置を切り替え可能
- 通信設備を直すたび「圏外の霧」が後退し、探索半径が最大120マスまで拡大
- 侵入可能範囲を地形追従の赤い発光リングとミニマップ上の赤円で常時表示
- 山頂の最終通信機を完成させ、「会社へ帰る」「島に残る」の二つの結末を選択
- 1本指ドラッグでカメラ旋回、ピンチでズーム、左右ボタンでも旋回
- 右下の状況アクションで、近い資源の採取・選択マスへの設置・設備調査を実行
- ミニマップはタップで76pxの簡易表示と146pxの詳細表示を切り替え

開始地点にはチュートリアル分の木8本・岩3個・木の実があり、島全域にも決定論的に
資源が生成されます。石の斧で木材入手量が増え、石のツルハシで石炭と鉄を採掘できます。

## キャンペーン

| 章 | 条件 | 探索半径 |
| --- | --- | ---: |
| 漂着海岸 | 小屋、焚き火、作業台を完成 | 24 |
| 密林地帯 | 石道具と橋を作り、やめ太郎と無線塔を修復 | 38 → 64 |
| 岩山・採掘場 | 鉄のツルハシと炉を作り、ゆめみんと中継器を起動 | 70 → 86 |
| 圏外の湿地 | 霧防護具を作り、タコさんとタコ石の門を修復 | 90 → 104 |
| 山頂の社内遺跡 | 3人と最終通信機を完成 | 120 |

各ランドマークへは1.25マスジャンプで踏破できる獣道を地形生成時に保証しています。
やめ太郎はマップ開示半径、ゆめみんは上位レシピ、タコさんは最終設備を解放します。

## Flutter Scene検証項目

- Flutter `3.47.1 stable` + Dart `3.13.1`
- Flutter Scene `0.22.2`
- 正典GLBから生成したモバイルGLB 4体の同時ロード（152→22 mesh nodes）
- GLBのPBRマテリアル、ノード階層、`Idle`アニメーション
- 256×256マス、16×16チャンクの決定論的なプロシージャル島生成
- 画質に応じ、現在地周辺3×3または5×5チャンクだけを動的ロード／アンロード
- 1ブロック1Nodeではなく、露出面をチャンク単位のindexed meshへ結合
- 木・岩・鉱石・植物を形状別InstancedMeshへ統合し、探索境界も288 Nodeから2 batchへ統合
- Dart isolateで地形メッシュを生成し、UI／描画isolateの停止を抑制
- vertex color付きPBRブロック地形、海、木、岩、家のランタイム生成
- 鉱石・植物・焚き火・作業台・橋・炉・通信ビーコンのランタイム生成
- `PerspectiveCamera.screenPointToRay`による3Dグリッド選択
- ゲーム進行に応じたNodeの追加・削除・移動
- プレイヤー追従カメラ、カメラ相対8方向移動、段差・海岸衝突
- 高低差1.25マスまでの放物線ジャンプと、それを超える崖の移動阻止
- 正典GLBの共通リグを使った脚・腕・触手の手続き歩行モーション
- `PhysicalSkySource`による10分周期の昼夜、太陽・月光・露出・色調の連動
- 画質別1〜3 cascades / 28〜56マス / 384〜1024pxの影と静的shadow cache
- 松明のemissive材質、ちらつくPoint Light、加算合成の火の粉
- ランドマーク固有光、朝夕限定God Rays、時間連動fog
- 海面の微動・時間帯別PBRマテリアル・低解像度SSR
- ACES tone mapping、Bloom、half-resolution AO、color grading、vignette
- 常設情報を絞ったFlutter WidgetのHUD、アナログスティック、状況アクション
- `Scene.renderScale`による0.58〜1.0xの描画解像度制御とAutoの5秒ヒステリシス
- 縦横両対応のレスポンシブUI、44px以上の主要タッチ領域、操作時の触覚フィードバック
- 端末の実ピクセル数から0.62〜2.4MPの描画予算を算出し、縦横回転時も負荷を一定化
- Androidでは高リフレッシュ端末も60Hzに寄せ、余剰描画と発熱を抑制

## ゲームメニューとビジュアル・デバッグ設定

通常画面は移動・状況アクション・ミニマップ・インベントリ・メニュー・簡易FPSだけを表示します。
右上のメニューから現在の目標、資材、通信／再会状況、詳細パフォーマンスと設定を確認できます。
建築パーツの選択とクラフトはインベントリ内へまとめています。

ゲームメニューでは、画質プリセット、時刻プリセット／時刻スライダーと次の機能を個別に
ON/OFFできます。描画負荷と見た目を同じ地点で比較するための設定です。

- Auto: FPS/P95を5秒ごとに評価する4段階制御。影・遠方範囲を順次軽量化し、最終段だけAO/Bloomをemissive材質と接地影へ置換
- Performance: 0.62x、3×3チャンク、1 cascade、AO/SSR/Bloom/God Raysなし
- Balanced: 0.75x、5×5地形＋3×3資源、2 cascades、half-resolution AO
- Quality: 1.0x、5×5地形・資源、3 cascades、SSR/Bloom/God Raysあり

- 昼夜サイクル
- 時間連動の環境光
- 太陽・月の影
- 接地影
- 松明ライト
- 松明の火の粉
- ランドマーク固有光
- 朝夕の光芒
- 時間連動fog
- 海面反射・微動
- 探索限界リング
- FPS・平均フレーム時間だけを示す簡易パフォーマンスHUD

パネル下部の「ビジュアル設定を初期化」で、時刻と全機能を既定値へ戻せます。
パフォーマンスHUDは`SceneView.onTick`を120フレーム分ローリング計測し、0.4秒ごとに
FPS・平均フレーム時間を更新します。P95、チャンク数、画質と実効render scaleはゲーム
メニュー内に表示し、Flutterの`FrameTiming`からbuild/raster値も内部計測します。最終的な性能比較はdebug固有の
オーバーヘッドを避けるため、profileビルドでも確認してください。

## ワールド構成

```text
全体       256 × 256 blocks = 65,536 cells
チャンク    16 × 16 blocks  = 256 chunks
描画範囲     3 × 3〜5 × 5 chunks  = 最大6,400 cells相当
地形保存     seed式で再生成（未変更チャンクは保存不要）
変更保存     将来はchunk座標 + local index + block IDの差分だけを永続化
```

固定サイズでも全マス分のNodeやセーブデータを作らないため、Minecraft系と同じく
「手続き生成 + 周辺チャンクだけ描画 + 変更差分だけ保存」へ拡張できる土台です。

参考実装は別リポジトリ`flutter_scene_tic_tac_toe`です。Scene初期化、GLBロード、
3D ray-plane picking、Widgetオーバーレイの構成を参照しています。

## 素材

`assets/models`は正典ディレクトリへの相対symlinkです。

```text
assets/models -> ../../04_GAME_ASSETS/voxel/models
```

GLBをこのプロジェクトへコピー・編集せず、変更時は`04_GAME_ASSETS/voxel/tools/`から再生成します。
ゲームでは`models/mobile/`の派生GLBを使い、剛体歩行リグのピボット単位でメッシュを
結合しています。外見、画像・透過・発光材質、歩行リグを維持し、単色材質だけを
頂点カラー付き共通PBRへ統合してノード巡回とdraw callを削減します。

Flutter Scene内部の120フレーム集計を取る場合は次のように起動します。

```bash
flutter run --profile \
  --dart-define=FLUTTER_SCENE_PROFILE=true \
  --dart-define=MADOGIWA_SKIP_INTRO=true
```

## 実行

miseのグローバル設定とモノレポの`.mise.toml`はFlutter 3.47.1に揃えています。

```bash
cd 17_FLUTTER_SCENE_GAME
mise exec -- flutter pub get
mise exec -- flutter run --enable-flutter-gpu
```

## Dart MCP / Marionette MCP

ルートの`.mcp.json`と`.codex/config.toml`は、どちらのMCPも必ず
Flutter 3.47.1のDartを経由して起動します。Marionetteのグローバル実行ファイルが
別バージョンのDartで作られていても、Kernel snapshotの互換エラーを避けられます。

初回だけMarionette MCP bridgeをFlutter 3.47.1で有効化します。

```bash
mise exec flutter@3.47.1 -- dart pub global activate marionette_mcp
```

ネイティブdebugビルドは`MarionetteBinding`を初期化し、次の専用extensionを登録します。

- `madogiwa.inspectIsland`: 座標、チャンク、探索、再会、資源、建築、時刻、描画設定を取得
- `madogiwa.setVisualOption`: 各描画機能を名前指定でON/OFF
- `madogiwa.setGraphicsQuality`: auto/performance/balanced/qualityを切り替え
- `madogiwa.setTimeOfDay`: morning/day/evening/nightまたは0.0〜1.0で時刻を指定
- `madogiwa.keyInput`: W/A/S/D・矢印キー相当のdown/up/tap入力
- `madogiwa.releaseKeys`: 押下状態をすべて解除
- `madogiwa.openScenario`: camp/radio/office/shrine/summitへ検証用移動
- `madogiwa.selectTool`: 採取・床・壁・屋根・松明を選択
- `madogiwa.grantResources`: キャンペーン検証用資源を追加
- `madogiwa.craftRecipe`: レシピ名指定でクラフト
- `madogiwa.performObjective`: 現在地付近の通信設備を起動
- `madogiwa.performContextAction`: モバイルの状況アクションと同じ操作を実行
- `madogiwa.advanceCampaign`: 現在の章を決定論的な状態で完了
- `madogiwa.chooseEnding`: rescue/stayのエンディングを選択
- `madogiwa.resetIsland`: 島を初期状態へ戻す

開始、インベントリ、メニュー、ツール、リセットの各ボタンにも安定した`ValueKey`を設定しているため、
通常のMarionette tapと専用extensionを使い分けられます。releaseとwebでは通常の
`WidgetsFlutterBinding`を使い、デバッグ用extensionは登録しません。

## 検証コマンド

```bash
mise exec -- dart format --output=none --set-exit-if-changed lib test hook
mise exec -- dart analyze .
mise exec -- flutter test
mise exec -- flutter build macos --debug
mise exec -- flutter build web --release
mise exec -- flutter build apk --debug
mise exec -- flutter build ios --simulator --debug
```
