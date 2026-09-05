# そば屋ハザード — 第一章「村の広場」

福ちゃんで村を探索し、そば屋と戦い、紋章の鍵で農場側の門を開ける短編。PS2／原作バイオ4を目標にする最初のプレイ可能な章。原作の全編・村の厳密な寸法再現・完成版の品質に達したという意味ではない。

## 起動

```sh
cd 21_SOBAYA_HAZARD_LAB
mise exec -- flutter pub get
mise exec -- flutter run -d macos -t lib/game_main.dart
```

Flutter 3.47.2 / Dart 3.13.2 / flutter_scene 0.23.0。global Flutterに合わせた既存mise設定を使用。従来のモデル検証室は `-t lib/main.dart` で起動する。

## 遊び方

- WASD／矢印で移動、Shiftで走る（歩行1.25m/s・走行2.8m/s）。ドラッグで視点を回す。
- 右マウスボタン長押し／Qで構える。左ボタン／Spaceで発砲、Rで装填。構え中は立ち止まる。
- Eで拾う・調べる・木箱を壊す・はしごを使う。1／2で武器切替、Hでハーブ回復。
- Tabで10×6のアタッシュケース。ドラッグで配置、クリックで装備・使用・ハーブ調合。
- Cで収集した画像を鑑賞。クリックで拡大する。Escで一時停止・画質・音の切替。
- そば屋を倒すと流血せず消失し、ビールが1個出現する。ビールは収集数として数える。
- 二階建ての家にショットガン、北側の納屋に紋章の鍵。門を開けてその先へ進むと章クリア。
- 壁の画像は6枚。収集記録だけをローカル保存し、ゲーム再起動・再挑戦でも保持する。進行中の位置・体力は保存しない。

## 構成と現在の範囲

5軒の家、屋内探索、階段、見張り塔、広場、農場側の出口。敵は計8体、開始4体で撃退に応じて追加される。ハンドガン／ショットガン、弾薬、3色のハーブ、鍵、木箱・樽、ビール、収集画像を実装。壁は移動・射撃・拾得・敵経路で参照する。

福ちゃんは正典写真→Imagegen正面／背面→Tripo P2→Blender。そば屋は検証済みrig_v3。歩行・走行はMixamo由来、両手の銃構えは武器別のIKポーズ。建物・小道具はBlender生成。石壁と地面はbuilt-in Imagegenの専用テクスチャ。[設計と参照資料](GAME_DESIGN.md)、[福ちゃん正本](../04_GAME_ASSETS/3d/characters/fukuchan/README.md)、[村正本](../04_GAME_ASSETS/3d/environments/pueblo/README.md)。

まだ実装していないもの: 農場以降のマップ、たこさん／やめ太郎のゲーム内3D役、窓越え・蹴り・掴み・イベント、銃の専用反動／リロードモーション、指の個別把持、実時間の足IK。見張り塔のはしごは位置遷移。屋内では屋根を非表示にする。スマートフォン実機の操作・性能は未検証。

## 検証と描画

- `flutter analyze`: 警告なし。
- `flutter test`: 既存6＋ゲーム9の15件。撃退・単一ドロップ・無流血、壁で射撃を遮る、弾数移動、ケース満杯、画像重複、階段、鍵とクリア、攻撃予備動作、一時停止。
- macOS上のDart MCP／Marionetteで、実Spaceキー射撃4発／3命中→1撃退→Eでビール1個、階段→ショットガン取得、画像取得→再起動後保持、門開放→クリアを確認。ケースとギャラリーのスクリーンショットも確認。
- GLBビルド時変換・圧縮・mipmap、共有テンプレートclone、静的影キャッシュ、影1カスケード1024px、距離35m、AO OFF、標準描画倍率85%／軽量65%、公式の可視判定と材質ソートを使用。
- [M4のプロファイル計測](benchmarks/game-village-20260906.json): 1280×840論理px、村＋4体でUI P95 5.005ms、8体で5.125ms（各240フレーム）。Flutter Raster P95は0.735／0.507ms。GPU実行時間や実fpsの直接計測ではない。効果音プール修正前の値なので最終版との小さな差はあり得る。

```sh
mise exec -- flutter run -d macos -t lib/game_main.dart --profile --dart-define=HAZARD_GAME_BENCHMARK=true
```

このフラグの時だけ3条件を自動比較し、`HAZARD_GAME_BENCHMARK`のJSONをログへ出す。

## 自動操作拡張（debugのみ）

- `madogiwa.inspectHazardGame`: 状態、コレクション、骨格クリップ、直近FrameTiming。
- `madogiwa.openGameScenario`: `name=combat|pickup|collection|gate|stairs|death`。その周回をリセットし、収集記録は保持。
- `madogiwa.gameAction`: `action=interact|reload|fire|fireAtEnemy|step|move|aim|pause`。`step`は`seconds=0..10`、`move`はワールド方向`x,z`と`seconds`で60Hz移動。通常プレイには影響しない検証用。
