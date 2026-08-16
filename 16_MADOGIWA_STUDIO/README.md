# MADOGIWA STUDIO

「窓際族物語」の動画制作物を、エピソードと生成バージョン単位で閲覧・管理するCloudflare Workersアプリです。

## 構成

- React + Vite + shadcn/ui互換コンポーネント: 一覧、詳細、管理画面
- Cloudflare Workers: JSON API、入力アセット／動画配信、Remote MCP
- D1: Studio ID、登場メンバー、生成バージョン、使用モデル、プロンプト履歴、入力アセット、動画メタデータ、アップロードチケット
- R2: Seedance入力画像・参照音声・資料・生成動画の実体
- Cloudflare Access: 管理画面、管理API、Remote MCPの認証

公開ページと読み取り用`/api`はログイン不要です。`/admin`、`/admin-api`、`/mcp`はCloudflare Accessを要求します。
Workerは`ctx.access`の検証済みidentityを優先し、利用できない場合もヘッダーまたは`CF_Authorization` Cookieの
Access JWTについて署名・issuer・AUDをJWKSで検証してから
identityを採用します。`wrangler.jsonc`の`TEAM_DOMAIN`と`POLICY_AUD`はAccessアプリの値です。ローカル開発では
`access.dev`がテスト用identityを注入し、本番用の認証バイパスは設けません。

## 開発

```bash
npm install
npm run cf-types
npm run db:migrate:local
npm run dev
```

`http://127.0.0.1:5173`で開きます。

## 検証

```bash
npm run verify
```

`verify`はWrangler生成型の同期、TypeScript、ESLint、Workersランタイム内のD1・R2・HTTP Range・MCP統合テスト、
Workerの起動プロファイル、本番アップロードを行わないdeploy dry-runまでを実行します。

## データ構造

- エピソードは時系列やFork元の採番に依存せず、ランダムな`MS-XXXXXXXX`形式のStudio IDを持ちます
- 1エピソードにv1、v2…の生成バージョンを追加でき、プロンプト・入力アセット・動画は各バージョンへ紐づきます
- 登場メンバーは任意登録で、公開一覧から複数メンバーを指定して絞り込めます
- 使用モデルは生成バージョンごとの任意項目です。`Seedance 2.0`、`Seedance 2.5`、`MiniMax H3`を候補表示しつつ、任意名を登録できます

## 動画登録

管理画面で対象の生成バージョンを選んでアップロードできます。CLI/Codexからは、Remote MCPの
`create_video_upload`で一回限りのURLを発行してから、そのURLへPUTします。
ローカルAPIを使う場合は次の補助コマンドも利用できます。

```bash
npm run upload:video -- \
  http://127.0.0.1:5173 \
  sobaya-beer-battery \
  ../03_SCRIPTS/40_sobaya_beer_battery/final_video.mp4 \
  "Final video"
```

アップロードURLは1時間有効・一回限りです。トークンのハッシュだけをD1へ保存し、
動画本体はWorkerでバッファせずR2へストリーミングします。

## 入力アセット

管理画面の`inputs`タブから、生成時に渡す画像、参照音声、資料、その他ファイルを登録できます。
各ファイルには`@Image 1`や`@Audio 1`などの参照名、`Clip A`などのグループ、用途メモ、
表示順を付けられます。公開詳細ページでは画像をプレビューし、音声をその場で再生できます。
CodexからはMCPの`create_input_upload`で同じ登録を行います。

## Remote MCP

Streamable HTTPのエンドポイントは`/mcp`です。

- `list_episodes`
- `list_members`
- `get_episode`
- `create_episode`
- `set_episode_members`
- `create_generation`
- `update_generation`
- `upsert_prompt`
- `create_video_upload`
- `create_input_upload`
- `set_video_status`

新規MCPサーバー向けの現行推奨に合わせ、`createMcpHandler`によるステートレス構成です。

## デプロイ

1. `madogiwa-studio` D1と`madogiwa-studio-media` R2を用意する
2. `wrangler.jsonc`へリソースIDを設定する
3. `npm run db:migrate:remote`
4. `npm run deploy`
5. `/admin*`（`/admin-api/*`を含む）と`/mcp*`へCloudflare Accessポリシーを設定し、`TEAM_DOMAIN`と`POLICY_AUD`を合わせる

R2の初回利用時は、Cloudflare DashboardでR2サブスクリプションの有効化が必要です。

## CI/CD

`.github/workflows/madogiwa-studio.yml`は、Pull Requestで`npm run verify`を実行し、`main`への反映後に
D1の未適用マイグレーション、本番Workerのデプロイ、公開APIのヘルスチェックを順に実行します。
同時デプロイは直列化され、PR以外の実行は途中キャンセルしません。

D1マイグレーションはデプロイより先に適用されるため、通常はテーブル・カラム・インデックスを追加する
後方互換な変更にします。rename・drop・意味変更は、先に新旧両方へ対応するコードをデプロイし、
データ移行後の別PRで古い構造を削除する二段階変更にします。

GitHubの`madogiwa-studio-production` Environmentへ次のSecretsを登録します。

- `CLOUDFLARE_ACCOUNT_ID`: Studioを配置しているCloudflareアカウントID
- `CLOUDFLARE_API_TOKEN`: 対象アカウントに限定し、Workers Scriptsの編集とD1マイグレーションに必要な権限だけを持つトークン

依存パッケージとGitHub ActionsはDependabotが定期的に更新PRを作成します。Secrets未登録でもPRのCIは動作し、
本番デプロイだけが実行できません。

## 別リポジトリから利用する

Fork元などStudio本体を持たないリポジトリでも、次のファイルを取り込めば同じHosted MCPを利用できます。

1. `.claude/skills/madogiwa-studio/`をコピーする
2. Codex向けに`.agents/skills/madogiwa-studio`から上記ディレクトリへ相対symlinkを作る
3. `.mcp.json`と`.codex/config.toml`へ、スキル内`references/mcp-tools.md`の接続設定を追加する
4. 利用者のメールアドレスをCloudflare Accessの許可ポリシーへ追加する
5. 各利用者が自分のアカウントでOAuthログインする。Codex CLIでは`codex mcp login madogiwa-studio`を実行する

OAuthキャッシュやCloudflare API tokenをリポジトリ間・利用者間で共有する必要はありません。
