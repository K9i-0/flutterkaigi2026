# 窓際族・無人島クラフト

窓際族のメンバーが無人島へ島流しされ、ブロックを採取・設置して生活基盤を作る
Minecraft風の256×256マス3Dクラフトゲームです。Flutter 3.47 stableで利用可能になった
Flutter Sceneを、窓際族物語の正典ボクセル素材で実ゲームへ使う検証も兼ねています。

## ゲーム内容

- そば屋を操作し、島の別々の場所に隠れたやめ太郎、ゆめみん、タコさんと再会
- 256×256マスの島をWASD／矢印キー／画面方向パッドで自由に探索
- 歩いた周囲だけ地形が開く簡易マップと、3つの固有ランドマーク
- 7マス以内の木・岩を直接タップして採取（遠距離・狙い外れは理由を表示）
- 好きな地面へ「床 → 壁 → 屋根」の順でブロックを設置
- 木材1個で松明を設置。開始キャンプにも検証用の松明を1本配置
- 床4枚、壁4枚、屋根を完成させると生活拠点が完成
- 再会したメンバーはそば屋の後ろから一緒に探索
- 1本指ドラッグでカメラ旋回、ピンチでズーム、左右ボタンでも旋回

開始地点にはチュートリアル分の木5本・岩2個があり、島全域にも決定論的に資源が
生成されます。開始地点の資源だけでも床4、壁4、屋根1を完成できます。

## Flutter Scene検証項目

- Flutter `3.47.1 stable` + Dart `3.13.1`
- Flutter Scene `0.22.2`
- 正典GLB 4体の同時ロード（合計152 meshes）
- GLBのPBRマテリアル、ノード階層、`Idle`アニメーション
- 256×256マス、16×16チャンクの決定論的なプロシージャル島生成
- 現在地周辺5×5チャンクだけを動的ロード／アンロード
- 1ブロック1Nodeではなく、露出面をチャンク単位のindexed meshへ結合
- Dart isolateで地形メッシュを生成し、UI／描画isolateの停止を抑制
- vertex color付きPBRブロック地形、海、木、岩、家のランタイム生成
- `PerspectiveCamera.screenPointToRay`による3Dグリッド選択
- ゲーム進行に応じたNodeの追加・削除・移動
- プレイヤー追従カメラ、カメラ相対8方向移動、段差・海岸衝突
- 高低差1.25マスまでの放物線ジャンプと、それを超える崖の移動阻止
- 正典GLBの共通リグを使った脚・腕・触手の手続き歩行モーション
- `PhysicalSkySource`による10分周期の昼夜、太陽・月光・露出・色調の連動
- 3 cascades / 56マス / 1024pxの動的な太陽・月の影と接地影
- 松明のemissive材質、ちらつくPoint Light、加算合成の火の粉
- ランドマーク固有光、朝夕限定God Rays、時間連動fog
- 海面の微動・時間帯別PBRマテリアル・低解像度SSR
- ACES tone mapping、Bloom、GTAO、color grading、vignette
- Flutter WidgetのHUD、長押し方向パッド、ツール選択、3Dシーンへのオーバーレイ

## ビジュアル・デバッグ設定

HUD右上のスライダーアイコンから、時刻プリセット／時刻スライダーと次の機能を
個別にON/OFFできます。描画負荷と見た目を同じ地点で比較するための設定です。

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

パネル下部の「ビジュアル設定を初期化」で、時刻と全機能を既定値へ戻せます。

## ワールド構成

```text
全体       256 × 256 blocks = 65,536 cells
チャンク    16 × 16 blocks  = 256 chunks
描画範囲     5 × 5 chunks  = 最大6,400 cells相当
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
- `madogiwa.setTimeOfDay`: morning/day/evening/nightまたは0.0〜1.0で時刻を指定
- `madogiwa.keyInput`: W/A/S/D・矢印キー相当のdown/up/tap入力
- `madogiwa.releaseKeys`: 押下状態をすべて解除
- `madogiwa.openScenario`: camp/radio/office/shrineへ検証用移動
- `madogiwa.selectTool`: 採取・床・壁・屋根・松明を選択
- `madogiwa.resetIsland`: 島を初期状態へ戻す

開始、カメラ、ツール、リセットの各ボタンにも安定した`ValueKey`を設定しているため、
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
