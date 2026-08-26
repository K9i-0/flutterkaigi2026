# 公式情報の確認先

有料実行または仕様案内の直前に、以下をウェブで確認する。二次情報ではなく公式ページを優先する。

- Qwen Cloud Wan 3.0モデル・現在価格: https://www.qwencloud.com/models/wan3.0-video
- Qwen Cloud Wan 3.0タスク作成API: https://docs.qwencloud.com/api-reference/video-generation/wan30-video/create-task
- Qwen Cloud Wan 3.0結果取得API: https://docs.qwencloud.com/api-reference/video-generation/wan30-video/query-result
- Qwen Cloud動画モデル一覧: https://docs.qwencloud.com/developer-guides/getting-started/video-models
- Alibaba Cloud公式プロンプトガイド: https://www.alibabacloud.com/help/en/model-studio/text-to-video-prompt
- Alibaba Cloud Wan 3.0 APIリファレンス: https://www.alibabacloud.com/help/en/model-studio/wan3-video-generation-api-reference

確認項目:

- `wan3.0-video`が対象アカウントで利用可能か
- 480P、720P、1080Pの現在単価
- 出力尺、参照画像・動画・音声の個数と容量上限
- `media.type`、`ratio`、`audio`、`seed`、`watermark`、`prompt_extend`の現在仕様
- エンドポイントとリージョン
- 結果URLの有効期間

ドキュメント間で表示が食い違う場合は、Qwen Cloudで実際に使うモデルページとAPIリファレンスを優先し、差異をユーザーへ明記する。
