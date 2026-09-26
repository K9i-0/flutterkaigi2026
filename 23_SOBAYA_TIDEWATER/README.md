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

WASD／画面の矢印で移動、ドラッグで見回す、Shiftで走る。Fで検証用飛行へ切り替え、Space/Cで上下移動。桟橋・村・俯瞰ボタンで固定地点へ移動する。歩行中の海への進入は止める。落下は簡易接地で、水泳や戦闘はまだない。

## 今回移植したもの

- Tidewater `4811ba48d795197de5621985f404e765c0b7c0ef` のseed 7の島。
- 島の地形（4m間隔、128mごとの分割、深い海底を省略、237,568三角形）。
- 元の村生成コードから21棟と桟橋、板道、小物のCPU形状・頂点色。原作の色・粗さ・法線テクスチャを生成するGPUシェーダーは未移植。
- 建物の整地後の1m高さデータ、回転した箱・円柱・歩ける床の衝突。表示用地形は粗いため、細かな地表と足元の高さには差があり得る。
- 簡易水面の頂点アニメーション、空と環境反射、太陽と影。FFT海洋ではない。
- メニュー切替、フォーカス喪失時の入力解除、背景化時のticker停止。

元データは [共通アセット正本](../04_GAME_ASSETS/3d/tidewater/README.md) を相対symlinkで参照する。runtime GLB importerのZ反転はインポート境界で相殺し、Tidewaterの座標と衝突データを一致させる。三角形の頂点順序は書き換えない。

## 残る移植

1. 地形の細部・木材・屋根・岩の材質、草木・岩の散布、表示距離とLOD。
2. 水面の細かな法線、浅瀬の色、屈折、海岸の泡。まず標準Flutter GPUのラスタライズで実装する。
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
- `madogiwa.openTidewater`: `name=pier|village|overview`。

Mac debugで見た目・操作を確認する。非アクティブ時は描画を止めるため、スクリーンショット確認時はアプリを前面にする。debugの描画結果はモバイル性能・発熱の保証ではない。
