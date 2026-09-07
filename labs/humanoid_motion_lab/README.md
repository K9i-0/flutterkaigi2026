# そば屋モーションラボ

そば屋ハザードのリアル頭身モデルを使う独立したmacOSアニメーション比較アプリ。**そば屋・福ちゃん各66クリップ、4手法**を収録。

## 起動

ビルド済みアプリは `dist/そば屋モーションラボ.app`。ソースからの起動:

```sh
cd 22_HUMANOID_MOTION_LAB
mise exec -- flutter pub get
mise exec -- flutter run -d macos
```

Flutter 3.47.2 / Dart 3.13.2。ゲームと同じFlutter Scene 0.23.0のvendored実装を使用。初回の4K素材変換には数分かかる。

## 比較

- **体格を比較**：同じ動作をそば屋・福ちゃんで同時再生。各自の脚長・腕長・肩幅を使う。
- **手法を比較**：選んだ人物を4手法で並べる。共通の「歩行」で違いを見られる。選んだ動作のない手法は「未収録」と明示する。
- 左の手法は、実演収録の比較基準2本、CC0ライブラリ39本、体格から作るIK8本、CC0にIKを加えた17本。
- 再生速度0.25〜2倍、一時停止、タイムライン、コマ送り、ループ、再開。
- 位相同期ONは各クリップの同じ周期位置、OFFは同じ経過秒。手法によって元の演技・周期は異なる。
- 正面・側面・背面は人物をそれぞれ回し、重なりを防ぐ。ドラッグでカメラ回転、ホイールで距離。
- 骨格表示はメッシュに隠れないオーバーレイ。Spaceで停止・再生、左右キーで1/30秒送り。
- 右パネルに骨格の実測値と靴底の最低位置を表示。「比較設定をコピー」でクリップ名・時間・体格などをJSONにできる。

## 共通資産

`assets/models/*.glb` と `assets/catalog.json` は[共通ライブラリ](../04_GAME_ASSETS/3d/motion_library/README.md)への相対symlink。ゲームの正本と同じ出力を使う。ビルド成果物には実行に必要な変換済みモデルが入る。

出典、CC0ライセンス、体格補正、再生成、平地IKの適用範囲は共通ライブラリのREADMEを参照。

## 検証

```sh
mise exec -- flutter analyze
mise exec -- flutter test
python3 ../tools/package_motion_lab.py
```

Dart MCPの `roots` にリポジトリを登録し、`launch_app(root=file:///…/22_HUMANOID_MOTION_LAB, device=macos)` でdebug起動。返されたApp URIへMarionetteを接続する。

| extension | 引数 |
| --- | --- |
| `madogiwa.inspectMotionLab` | 状態、各個体の実クリップ名・時間・骨格・足首位置・クリップ数 |
| `madogiwa.setMotionLab` | `method=captured|library|procedural|hybrid`, `action=Walk` 等。任意で `character=sobaya|fukuchan`, `compare=true|false`, `seek=秒`, `speed=.25..2`, `view=front|side|back`, `skeleton=true|false` |

GLBの数値監査は共通ライブラリの `validation.json`。macOSでGPU描画、両体格、4手法比較、側面表示、骨格表示、停止・コマ送りを検証。iOS/Android/Web版はこのアプリの対象外。
