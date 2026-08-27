# Remotion公式情報

API、依存関係、システム要件、ライセンスは変わるため、新規プロジェクトまたはアップグレード時に公式情報を確認する。

## 確認先

- 新規プロジェクト: https://www.remotion.dev/docs
- 既存動画の読み込み: https://www.remotion.dev/docs/videos/
- 音声: https://www.remotion.dev/docs/using-audio
- 字幕: https://www.remotion.dev/docs/captions/
- CLIレンダー: https://www.remotion.dev/docs/render
- API一覧: https://www.remotion.dev/docs/api
- Agent Skills: https://www.remotion.dev/docs/ai/skills
- ライセンス: https://www.remotion.dev/license
- npm安定版: `npm view remotion version`

## 2026-08-27確認事項

- 公式の新規作成コマンドは`npx create-video@latest`。
- ローカル動画は`public/`へ置き、`staticFile()`と`@remotion/media`の`<Video>`で読み込める。
- 動画音量は`volume`、無音化は`muted`で制御できる。
- 字幕には`@remotion/captions`のSRT処理APIがある。既存ASSは本スキルの変換スクリプトでフレーム化できる。
- CLIレンダーは`npx remotion render <composition-id>`。
- Remotionと全`@remotion/*`パッケージは同一バージョンへ揃え、正確なバージョンで固定する。
- 公式blankテンプレートはReact 19、TypeScript、Rspackを使用する。

固定したバージョンを永続的な最新版だと扱わない。新規プロジェクトでは当日の安定版を再確認する。
