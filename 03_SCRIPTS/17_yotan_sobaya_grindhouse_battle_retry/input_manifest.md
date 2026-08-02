# Seedance入力マニフェスト

## 最重要ルール

この回は、矢印付きプランニング画像をSeedanceへアップロードしない。矢印、クレイ人形、図解バースト、同心円を含む画像は、人間が動線と因果を確認するためだけに使う。

Seedanceへ渡すのは、キャラクターシート、完成画質の環境、対応クリップの矢印なし開始・終了キーフレームだけ。

## Clip Aへアップロード

1. `character_sobaya_basic_sheet.png`
2. `character_yotan_battle_guitar_sheet.png`
3. `environment_grindhouse_battle_production.png`
4. `clip_a_start_production.png`
5. `clip_a_end_production.png`

## Clip Bへアップロード

1. `character_sobaya_basic_sheet.png`
2. `character_yotan_battle_guitar_sheet.png`
3. `environment_grindhouse_battle_production.png`
4. `clip_b_start_production.png`
5. `clip_b_end_production.png`

## Clip Cへアップロード

1. `character_sobaya_basic_sheet.png`
2. `character_yotan_battle_guitar_sheet.png`
3. `environment_grindhouse_battle_production.png`
4. `clip_c_start_production.png`
5. `clip_c_end_production.png`

## Seedanceへアップロードしない

- `planning_clip_a_arrows_not_for_seedance.png`
- `planning_clip_b_arrows_not_for_seedance.png`
- `planning_clip_c_arrows_not_for_seedance.png`
- 前回の生成動画
- 前回のクレイ絵コンテ
- 前回の赤い星形バースト、赤い同心円、青いカメラ矢印を含む画像
- 監査用コンタクトシート

## 役割

| 種別 | 固定する | 自由に生成させる |
|---|---|---|
| キャラクターシート | 顔、仮面、髪、体格、衣装、ジョッキ、強化ギター | 演技、姿勢、スタント中の自然な二次動作 |
| 環境画像 | 空間、実写材質、照明、スピーカー4基、ステージ段差 | 煙、埃、微細な反射、レンズ応答 |
| 開始／終了キーフレーム | クリップ境界の人物位置、向き、状態 | 中間の殺陣、カメラ移動、編集、物理VFX |
| プランニング画像 | 人間が動線を確認するだけ | Seedanceには入力しない |

## 出力

- Seedance 2.5
- 16:9
- 各クリップ10秒
- 利用可能な最高解像度を優先。480pは確認用に限定
- Clip A→B→Cの順にCapCutで接続
