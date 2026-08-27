# Wan 3.0 v3生成記録

## 方針

- ユーザー採用のIrodori-TTS seed `2026`音声を30秒マスター化し、`Audio 1`としてWan 3.0へ入力する
- エピソード25と同じ女性アナウンサーの基本シートを`Image 3`として追加する
- `Audio 1`を映像同期に使い、生成後は同じ30秒WAVを最終MP4へそのままmuxして日本語音声を保証する
- 30秒以下のため、映像は1つのWan 3.0タスクで生成する

## 公式仕様・料金確認

- 確認日: 2026-08-27
- モデル: `wan3.0-video`
- 公式仕様: all-in-one referenceで`reference_image`と`reference_audio`を入力可能、動画入力なしで2〜30秒、480P/720P/1080P、16:9、音声出力、seed、watermark、prompt_extendに対応
- 480P表示価格: 通常$0.05/秒、30%割引表示$0.035/秒
- 30秒見積: **$1.05**

## 入力順

| 種別 | 番号 | ファイル | 役割 |
|---|---:|---|---|
| reference_image | Image 1 | `character_sobaya_basic_sheet.png` | そば屋本人と仮面 |
| reference_image | Image 2 | `character_fukuchan_basic_sheet.png` | 代理社員の福ちゃん |
| reference_image | Image 3 | `character_yume_tele_anchor_basic_sheet.png` | エピソード25アナウンサーの外見 |
| reference_image | Image 4 | `logo_yume_tele_master.png` | 正確なゆめテレロゴ |
| reference_audio | Audio 1 | `news_narration_yume_tele_anchor_input_30s.wav` | 採用済み日本語ナレーションと同期タイミング |

- Audio 1 SHA-256: `50e2be8f03b7d4bd53743fdfd13e72423a53f928d1301d79ae573d6892bbeaf3`

## 設定

- `audio_source=local_yume_tele_anchor_japanese`
- 480P、16:9、30秒、seed `530030`
- `audio=true`、`prompt_extend=false`、`watermark=false`
- 出力予定: `wan3_result_v3_seed530030_480p.mp4`
- 正確音声mux版予定: `wan3_result_v3_seed530030_480p_exact_audio.mp4`

## 実行状態

- 乾式検証: 合格。プロンプト10,887文字、参照画像4＋参照音声1、入力9.0 MiB、30秒単一タスクを確認
- 有料API送信: 2026-08-27実施
- タスクID: `7c416c5f-084c-4a2a-8155-f5b17872d42d`
- 結果: `FAILED`。送信直後の入力検証で`InvalidParameter`。参照音声は1本15秒以下が必要だが、30.0秒WAVを入力したため拒否された
- 出力動画: なし
- 再送: 未実施。修正版はv4へ分離
- 生成後監査: 対象動画なし
