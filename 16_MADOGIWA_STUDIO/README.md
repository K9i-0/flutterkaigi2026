# MADOGIWA STUDIO

「窓際族物語」の公式サイトをTanStack StartでEdge SSRし、コンテンツと動画制作物を管理画面とRemote MCPから共有管理するCloudflare Workersアプリです。

## 構成

- TanStack Start + React + Vite: 公開ページのSSR、型付きルーティング、サーバー関数、管理画面
- Cloudflare Workers: TanStack Start、JSON API、入力アセット／動画配信、Remote MCPを単一Workerで配信
- D1: ギャラリー、記事、Studio ID、登場メンバー、生成バージョン、使用モデル、プロンプト履歴、入力アセット、動画メタデータ、アップロードチケット
- R2: ギャラリー画像、Seedance入力画像・参照音声・資料・生成動画・動画サムネイルの実体
- Cloudflare Access: 管理画面、管理API、Remote MCPの認証

公開ページと公開済みコンテンツの読み取り用`/api`はログイン不要です。`/admin`、`/admin-api`、`/mcp`はCloudflare Accessを要求します。`/inputs`は公開エピソードで採用された生成バージョンの`ready`素材だけ公開され、非公開エピソードではAccessを要求します。
Workerは`ctx.access`の検証済みidentityを優先し、利用できない場合もヘッダーまたは`CF_Authorization` Cookieの
Access JWTについて署名・issuer・AUDをJWKSで検証してから
identityを採用します。`wrangler.jsonc`の`TEAM_DOMAIN`と`POLICY_AUD`はAccessアプリの値です。ローカル開発では
`access.dev`がテスト用identityを注入し、本番用の認証バイパスは設けません。

## リクエストフロー

```text
ブラウザ / SNSクローラー
  -> Cloudflare Worker
     -> TanStack Startのroute loader / server function
        -> D1から公開メタデータを取得
     <- canonical・OGP・X Cardを含むSSR HTML

動画プレイヤー
  -> WorkerでD1の公開状態を確認
  -> R2からHTTP Range対応で動画・サムネイルをストリーミング

管理画面 / Remote MCP
  -> Cloudflare Accessで認証
  -> D1へメタデータ、R2へバイナリを保存
```

公開UIのloaderは、同じWorker内のserver functionからrepositoryを直接呼びます。公開用`/api`を
HTTP経由で呼び直さないため、SSR時に余分な内部ネットワーク往復を発生させません。`/api`は外部クライアント向けの
読み取り口として残しています。

主なコード境界は次のとおりです。

- `src/routes/`: ファイルベースルート、loader、headメタデータ
- `src/pages/`、`src/components/`: 公開UIと管理UI
- `src/server/*.functions.ts`: TanStack Startのserver function境界
- `src/server/*.server.ts`: Workers Bindingを使うサーバー専用データ取得
- `worker/`: API、Access認証、MCP、R2ストリーミング、D1 repository
- `migrations/`: D1スキーマと初期データ

## 開発

Node.js 24を使用します。

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

## 公開サイト

公開側は「エピソード」を作品と共有の単位にしています。動画はエピソード内の再生コンテンツとして扱い、同じ作品の別バージョンを独立したページへ分散させません。

- `/episodes`: 公開済みエピソードの一覧。イチオシ・登場人物をURL検索条件で絞り込み可能
- `/episodes/:slug`: SSRされた作品ページ。動画、キャスト、関連作品、Web Share／X／LINE／URLコピーを提供
- `/characters/:slug`: キャラクター単位の共有ページと出演エピソード
- `/gallery/:slug`: ギャラリー作品単位の共有ページ
- `/story`: 原作14話を一続きで読めるページ
- `/sitemap.xml`、`/robots.txt`: 公開済みデータからWorker上で生成

ホームを含む全公開ページは、ルートごとのcanonical URLと、共通の`socialMeta`で生成したOpen Graph・X CardをSSR時に出力します。
エピソードやギャラリーなどの動的ページでは、D1から取得したタイトル・説明と、R2または静的アセットの画像をURLごとに
初期HTMLへ埋め込むため、SNSクローラーはJavaScriptを実行せず固有のカードを取得できます。このメタデータは
Workersランタイム上のSSR統合テストで公開ルートを横断検証します。

エピソードページはファーストビューに動画を配置し、`VideoObject`のJSON-LDも出力します。エピソードは作成時から公開され、非表示にする場合だけ`archived`へ変更します。公開動画と同じ生成バージョンの現行プロンプトと`ready`入力素材を制作情報として掲載します。プロンプト履歴、未完成素材、動画のない生成バージョン、登録者情報は公開しません。

## この構成を選ぶ理由

- CSRだけに依存せず、検索エンジンとSNSクローラーへページ固有のHTMLを返せる
- TanStack Startの型付きルート、loader、server functionを公開UIと管理画面で共有できる
- Workers BindingでD1とR2へ直接接続し、常時起動するNode.jsサーバーを管理しなくてよい
- 動画をWorkerメモリへ全量展開せず、R2からRangeレスポンスとして返せる
- R2は外向き転送料が無料。ただし動画再生ではRangeごとにWorkerリクエストとR2読み取り操作が発生する

## 動画登録

管理画面で対象の生成バージョンを選んでアップロードできます。CLI/Codexからは、Remote MCPの
`create_video_upload`で動画本体とサムネイル画像の一回限りURLを発行してから、それぞれへPUTします。
管理画面は動画の先頭付近からJPEGサムネイルを自動生成します。専用の`poster`画像を使うため、
iOS Safariでも再生前の動画カードを安定して表示できます。
ローカルAPIを使う場合は次の補助コマンドも利用できます。

```bash
npm run upload:video -- \
  http://127.0.0.1:5173 \
  sobaya-beer-battery \
  ../03_SCRIPTS/40_sobaya_beer_battery/final_video.mp4 \
  "Final video"
```

各アップロードURLは1時間有効・一回限りです。トークンのハッシュだけをD1へ保存し、
動画本体はWorkerでバッファせずR2へストリーミングします。

## 入力アセット

管理画面の`inputs`タブから、生成時に渡す画像、参照音声、資料、その他ファイルを登録できます。
各ファイルには`@Image 1`や`@Audio 1`などの参照名、`Clip A`などのグループ、用途メモ、
表示順を付けられます。公開動画に採用された生成バージョンの入力素材は、公開詳細ページでも画像プレビュー・音声再生・資料リンクとして表示されます。
CodexからはMCPの`create_input_upload`で同じ登録を行います。

## ギャラリーと記事

公式トップページのギャラリーと記事はD1を正本とし、管理画面の`Gallery`、`Articles`から追加・編集・
並べ替え・公開・非公開・アーカイブできます。ギャラリー画像はJPEG、PNG、WebP・10MB以下に限定し、
一回限りURLを使ってR2へ直接アップロードします。既存4件のギャラリー画像は静的パスを維持したまま
D1へ初期登録され、管理画面またはMCPで差し替えた時点からR2配信へ切り替わります。

漫画とキャラクターは引き続き`src/lib/site-content.ts`と`public/site/`の静的アセットを正本とします。
Cloudflare Accessを通過した管理メンバーは全管理機能を利用でき、メンバーの追加・削除はCloudflare Access側で行います。
物理削除APIは設けず、エピソードの公開取り下げは`archived`で行います。ギャラリーと記事は素材準備のため`draft`を引き続き利用します。

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
- `set_video_featured`
- `list_gallery_items`
- `create_gallery_item`
- `update_gallery_item`
- `create_gallery_image_upload`
- `reorder_gallery_items`
- `list_articles`
- `create_article`
- `update_article`
- `reorder_articles`

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
データ移行後の別コミット・別デプロイで古い構造を削除する二段階変更にします。

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
