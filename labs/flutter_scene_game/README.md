# 窓際族・無人島クラフト

窓際族のメンバーが無人島へ島流しされ、ブロックを採取・設置して生活基盤を作る
Minecraft風の256×256マス3Dクラフトゲームです。Flutter 3.47 stableで利用可能になった
Flutter Sceneを、窓際族物語の正典ボクセル素材で実ゲームへ使う検証も兼ねています。

## ゲーム内容

- そば屋、やめ太郎、ゆめみん、タコさんの4人が無人島へ異動
- 256×256マスの島をWASD／矢印キー／画面方向パッドで自由に探索
- 島の木をタップして木材、岩をタップして石材を採取
- 好きな地面へ「床 → 壁 → 屋根」の順でブロックを設置
- 床4枚、壁4枚、屋根を完成させると生活拠点が完成
- 採取・建築を担当したメンバーが対象ブロックまでリアルタイムで移動
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
- Directional Light、影、Bloom、AO、fog
- Flutter WidgetのHUD、長押し方向パッド、ツール選択、3Dシーンへのオーバーレイ

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
