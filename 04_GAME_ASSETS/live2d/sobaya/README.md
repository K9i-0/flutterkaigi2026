# そば屋 Live2D 胸上モデル素材

そば屋の胸上VTuberモデルをLive2D Cubismで制作するための正典素材置き場。

## 現行ランタイム

実際に動かす正規実装は `15_SOBA_VTUBER_WEB/` のMediaPipe＋PixiJS版へ移行した。
このフォルダの透過PNG 6枚を直接参照し、Webカメラ追跡、瞬き、口、頭、身体、ジョッキの動きをブラウザで処理する。

Cubism用PSDとリグ仕様は比較・将来利用のため残すが、ユーザーから再開指示がない限り `.cmo3` 制作は進めない。

## 原典と優先順位

1. `reference/sobaya_original.jpg` — ユーザー提供の最優先ビジュアル原典
2. `source/sobaya_live2d_master.png` — 原典を基にした胸上マスター
3. `source/sobaya_body_plate.png` — 頭部・ジョッキを外して補完した身体プレート
4. `parts/sobaya_head_unit.png` — マスターへ位置合わせ済みの透過頭部ユニット
5. `parts/sobaya_mug_hand.png` — マスターへ位置合わせ済みの透過ジョッキ＋手ユニット
6. `cubism/sobaya_live2d_source.psd` — Cubism取り込み用のレイヤーPSD
7. `RIG_SPEC.md` — デフォーマ階層・パラメータ・キーフォーム仕様

仮面と大型ビールジョッキはキャラクター設定上の必須要素であり、再設計・削除しない。

## 想定するCubismレイヤー

- `BodyPlate`：胸・肩・腕・白Tシャツ
- `HeadUnit`：髪、耳、頭、首、剛体の白い仮面
- `EyeLidL` / `EyeLidR`：仮面色の眼窩シャッター
- `MouthSlot`：音量連動で縦へ広がる黒い口スロット
- `MugHand`：キャラクター右手、大型ガラスジョッキ、ビール、泡

初版は仮面を剛体として扱う。人間の唇・眉・顔面変形は追加しない。

## 推奨パラメータ

| Parameter | Range | Purpose |
| --- | ---: | --- |
| `ParamAngleX` | -18..18 | 頭部左右 |
| `ParamAngleY` | -12..12 | 頭部上下 |
| `ParamAngleZ` | -10..10 | 首かしげ |
| `ParamBodyAngleX` | -6..6 | 身体の左右揺れ |
| `ParamBreath` | 0..1 | 胸・肩の呼吸 |
| `ParamMouthOpenY` | 0..1 | 口スロット内部の暗部のみ。仮面外形は固定 |
| `ParamEyeLOpen` | 0..1 | 左の黒い眼窩内部のシャッター表現 |
| `ParamEyeROpen` | 0..1 | 右の黒い眼窩内部のシャッター表現 |
| `ParamMugBounce` | -1..1 | ジョッキ＋手の小さな上下動 |

## Cubism取り込み前の作業

`tools/prepare_live2d_sources.sh` がクロマキー除去、頭部とジョッキの位置合わせ、合成プレビュー、Cubism用PSD生成を再現する。

生成後は `tools/validate_live2d_sources.sh` でキャンバス寸法、PSDの8-bit RGB形式、レイヤー名を検査できる。

PSDはCubismの素材要件に合わせてRGB・8-bit/channel・RLE圧縮で出力する。16-bit PSDはCubism 5.3.03のPSDパーサで読み込みエラーになるため使用しない。

Imagegenのクロマキー原版は、緑成分の優勢度からソフトアルファを生成する。髪や透明なガラスの縁に緑が残る場合はCubism取り込み前に手動マスクを優先する。

## Cubism 5.3.03への読み込み

1. Cubism Editorの「ファイル」→「ファイルを開く…」を選ぶ。
2. `cubism/sobaya_live2d_source.psd` を開く。
3. パーツ一覧に `BodyPlate`、`HeadUnit`、`EyeLidL`、`EyeLidR`、`MouthSlot`、`MugHand` の6件があることを確認する。
4. 自動メッシュ生成後、BodyPlateを親、HeadUnitとMugHandを前面パーツとしてデフォーマを作成する。
5. `cubism/sobaya_live2d.cmo3` として同じフォルダへ保存する。

デフォーマ階層とキーフォーム値は `RIG_SPEC.md` を使用する。

Cubism Editor 5.3.03の導入と起動は確認済み。最初に生成した16-bit PSDはログ上 `com.live2d.graphics.psd.a: error signature @ 0x00000026` で拒否されたため、8-bit固定へ修正した。

現時点では `.cmo3` は未生成。CubismのUIでPSDを読み込み、メッシュとパラメータを設定して保存すると初版モデルが完成する。
