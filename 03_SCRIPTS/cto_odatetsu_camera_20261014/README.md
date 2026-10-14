# CTOおだてつ：カメラ・レンズ入力

`flutterkaigi2026` 専用。PR #20で本人モデル・装備・ポーズと一緒に管理し、mainへマージしない。

## 指定

- 黒い本体は [α7 V / ILCE-7M5](https://www.sony.jp/ichigan/products/ILCE-7M5/) の形状。
- 白い望遠レンズは [FE 70–200mm F2.8 GM OSS II / SEL70200GM2](https://www.sony.jp/ichigan/products/SEL70200GM2/) を装着。白い円筒形フードを含む。
- 文字は `SONY → ODATETSU`、`α7 V → O7 V`、`G系バッジ → O`。スイッチや数値は機能を示す小さい記号として扱う。
- カメラ＋レンズは剛体の別モデル。黒いストラップは装備時に垂れ方を変えられる別部品とする。
- 元キャラクターシート左端のポーズも作る。右手でカメラを持ち、レンズを肩に沿って上へ向け、左手を腰に添える。

## 入力制作

公式の指定body＋lens装着写真、body背面、フード付きlens側面をImagegenの形状参照にした。参照URLと実寸は `sources.json`。公式写真はローカルの監査資料として保持し、採用した生成入力をこのディレクトリで追跡する。

`camera_front.png` と `camera_back.png` は同じ物を反対方向から見た3/4画像。校正された投影ではないため、奥行き・背面・三脚座は生成後の確認対象。背面の初案では白い三脚座が本体下へずれたため、lens側へ修正してから採用した。初案はGit管理外。

プロンプトは `prompt_front.txt` / `prompt_back.txt` / `prompt_back_fix.txt`。文字の大きさと形状の参照には正面を優先。ストラップはTripo入力に含めない。

## Tripo

生成記録: `04_GAME_ASSETS/3d/props/odatetsu_camera/tripo_20261014/`。P2-20260801、quad、15,000面目安、詳細PBR、前後2入力、seed1014175の1件。生成成功、実消費120 credits。利用する保存済み認証の場所についてユーザーの明示承認を得て送信した。認証内容は記録しない。

## 装備

本人は `PropSocket.R` を持つ。専用ポーズは `04_GAME_ASSETS/3d/characters/cto_odatetsu/camera_equipment_20261014/`、別体カメラは `04_GAME_ASSETS/3d/props/odatetsu_camera/`。指の握りは装備時に重ね、元の20動作と本人の形状・材質を保持する。
