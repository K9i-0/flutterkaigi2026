# MADOGIWA STUDIO

「窓際族物語」の公式サイトをTanStack StartでEdge SSRし、コンテンツと動画制作物を管理画面とRemote MCPから共有管理するCloudflare Workersアプリです。

公式URL: https://madogiwa.work

ドメイン接続設定と `k9i.app` 移管の残作業は [DOMAIN_OPERATIONS.md](./DOMAIN_OPERATIONS.md) を参照。

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

## 公開データのD1読み取りとキャッシュ

`worker/public-repository.ts` は公開一覧を3つの一括SELECTで取得します。管理用の素材数・プロンプト集計は公開一覧で実行しません。関連作品・キャラクターページも同じ一覧を再利用し、制作プロンプトや入力素材は詳細ページに引き続き掲載します。

`worker/public-cache.ts` は公開JSONをCache APIへ300秒保存します。HTMLはテーマCookieに依存するためキャッシュせず、管理API・MCP応答・アップロードチケット・認証情報も対象外です。公開JSONの内容は利用者に依存しません。

各取得では `public_content_revision` の1行だけを確認します。migration `0010` のトリガーがコンテンツ変更と同じトランザクションでrevisionを更新するので、管理画面・MCP・アップロード・直接SQLのいずれから更新しても、次の取得は全拠点で新しいキーを使います。非公開化後に古いキャッシュへフォールバックしません。コンテンツ1行の更新につきrevisionの書き込みが1回増えます。既に表示済みのブラウザー画面は再取得時に反映されます。

Cache APIは拠点ごとに保存され、退避・TTL切れ・キャッシュ非対応環境では軽量SQLへ戻ります。DB停止時もrevision確認を省略しません。`public_data_cache` の構造化ログで `hit` / `miss` を確認できます。HTML・公開API・サイトマップの外側に無条件のCache Everythingルールを追加しないでください。

再測定（読み取りSELECTを各1回実行）:

```bash
node tools/benchmark-public-reads.mjs --remote
```

2026-09-13 07:13 JST、本番44エピソードで旧一覧5,168行、新一覧の初回1,025行（revision込み、80.17%減）。キャッシュヒット時はrevisionの1行のみです。日次削減率はアクセス分布・更新頻度・キャッシュ命中率によって変わります。

2026-09-13にmigration `0010` とWorker `8ce37455-5c58-4a60-a749-3b80d6f1a3e4` を本番反映済み。公開一覧・詳細で `miss` → `hit`、44作品の一覧、主要SSRページ、XMLサイトマップ、未認証の管理API/MCPの401を確認しました。22テストと本体・テストコードの型検査が通過しています。日次使用量は翌日以降のD1 Insightsで比較します。

デプロイ順は `npm run verify` → `npm run db:migrate:remote` → `npm run deploy`。Workerを以前の版へ戻しても追加テーブルとトリガーは残して問題ありません。

## 閲覧時の不要な通信を抑える

- 公式UIはroot loaderの `getOfficialShell` でページごとにデータを取得。動画一覧は人物・ピックアップをD1で絞り込み、18件＋次ページ判定1件だけを取得する。全件数・生成数・動画本数は集計しない。人物情報も表示する18件分のみ取得し、全動画を列挙せず代表動画とピックアップ有無を索引で取得する。
- 公開カタログは `worker/catalog-repository.ts`、索引はmigration `0013`。前後移動は表示順・作成日時・IDのカーソルで行い、OFFSETは使わない。条件・カーソルごとの結果をrevision付き300秒キャッシュで共有する。
- 動画一覧ではギャラリーを取得しない。トップと人物ページは軽量な全作品カードを使用し、原作漫画・はじめての方へ・ギャラリーでは作品一覧を取得しない。ページ移動はSSRを経由し、URLの条件・カーソルをそのまま再表示できる。
- フィルターは横並びの「表示」「登場人物」の2つ。キーワード検索とジャンル絞り込みは廃止。条件変更でカーソルをリセットする。制作ノートには取得済みの公開データから生成バージョン数・動画本数を表示する。
- 旧公開APIと制作ノートの取得は `public-repository.ts` を引き続き使用。上記2026-09-13の1,025行は旧一覧の測定値で、新しい18件カタログの測定値ではない。
- 詳細ページの主動画・別バージョンは `DeferredVideo` で再生クリック時だけvideo要素を作る。関連カードは遅延読み込みの画像。動画URLとVideoObjectのSEOメタデータは維持。
- リンクの一律先読みを無効化。テーマ切り替えはブラウザーで処理し、絞り込み・ページ送りはサーバーで処理する。
- 保存ログは10%サンプリング、トレースは5%。全リクエストを保存した統計ではないので、利用量判断はWorkers/D1/R2の集計メトリクスを使う。
- 2026-09-13本番確認: `fukuchan-yametaro-engineer-stereotypes` は変更前26動画要素、変更後は再生前0・クリック後1（残り22本は未ロード）。実際の動画再生と一覧検索をブラウザーで確認。
- 本番ログではホーム・一覧・ギャラリー・人物・原作ページで公開データ取得が各2件のhit、詳細は1件のhit。23テスト、型検査、ビルド、startup、dry-run通過。主要SSR/サイトマップ200、管理API/MCP未認証401。
- Workerバージョン: `c49e7758-f56a-49b8-8cc6-f7ebe0367698`。課金プランや公開範囲は変更していない。初回再生はクリックしてからロードするため、回線によって待ち時間が生じる。

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
- `/story`: 原作15話を一続きで読めるページ
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
表示順を付けられます。公開動画に採用された生成バージョンの入力素材は、公開詳細ページでも画像拡大・音声再生・資料プレビューとして表示されます。
Markdown・JSON・テキストはページ内ダイアログ（スマートフォンでは全画面）で閲覧でき、原文コピーとダウンロードを別操作で提供します。
MarkdownはHTMLを実行せず、見出し・表・箇条書きとして描画します。相対リンク・埋め込み画像は読み込みません。
`/inputs/:id?preview=1`はUTF-8テキストを最大1MiBまで配信し、`?download=1`は元ファイルを日本語名対応のattachmentとして配信します。
対応しない形式はダウンロードを案内します。入力素材の全配信モードで公開状態・Access認証を確認し、`private, no-store`で認証付き応答の共有キャッシュを防ぎます。
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

## 公式サイトの採用デザイン（2026-09-12）

`src/official/`が本番の3スタイル（窓際酒場・仕事してるふりExcel・地下労働ゆめポイント）の正本。番号は画面へ表示しない。選択は同一ブラウザのlocalStorageへ保存し、theme指定なしで復元。

`Layout`から既存の公開ページをフォールバックとして保持して読み込み、公開中のエピソード・ギャラリーを既存サーバー関数から取得する。管理画面・API・MCP・エピソード詳細の固有URLと公開メタデータを維持。動画は`/media/`、通常サムネイルは`/posters/`を使い、試作の固定エピソードJSON・動画キャッシュは本番へ含めない。

配信用の布・紙・コンクリート・フォントは`public/themes/`。原本と生成プロンプトは`design-preview/source-assets/`。採用音声は`public/voice/sobaya.wav`。以前のローカル比較は`design-preview/`に制作履歴として保持する。今後の本番修正は`src/official/`へ反映する。

### お品書き・地下売店の改善

酒場は木の板に写真付きのお品書き、短い店主の一言、常連の写真札を配置。提灯の点灯と木への暖色反射を連動。地下労働は支給票・ミシン目付きビール引換券・交換済み判子の売店として表示。

おすすめの一本は`theme-features.ts`で管理：酒場＝「タコゲーム — 目覚め」、Excel＝「プロフェッショナル 窓際の流儀」、地下労働＝「地下労働篇」。公開中で再生できる作品のみ選択し、対象がなくなった場合は公開ピックアップへフォールバック。

検証：型検査・lint・テスト15件・本番ビルド、PC/390px/320pxの表示、テーマ別動画再生、ポイント交換、検索を保持した着せ替え。素材の全文プロンプトと出典は`design-preview/source-assets/menu-v2/README.md`。

## 動画の音量設定

公開ページの動画は `useVideoPreferences` で音量（0〜1）とミュート状態を共有する。
`madogiwa-video-preferences` にブラウザーのlocalStorageで保存し、動画のマウント時と再生開始時に復元するため、別作品・再読み込み・再訪でも同じ設定を使う。
保存できない環境ではページ内のメモリーに保持する。端末やブラウザーをまたぐ同期は行わない。
再生位置・再生速度は保存しない。OSが音量を管理するモバイル環境では端末側の音量制御に従う。

## 登録済みコンテンツの編集（2026-09-13）

管理画面は制作ページと同じ明るい配色で、サムネ付き作品一覧と編集パネルを表示します。800px以下では選択した作品の編集画面へ切り替え、一覧へ戻ると検索・絞り込み・スクロール位置を維持します。新規登録はMCPを基本とし、手動登録は「追加操作」、生成モデル・プロンプト・入力素材・動画追加は「制作情報・追加操作」にまとめています。

- 作品一覧でタイトル・Studio ID・slug検索、人物・公開状態・イチオシの絞り込み、掲載順・登録日・更新日・タイトル順の切り替え。
- 「掲載順を編集」は全作品を対象にドラッグ／上下ボタンで移動し、「順序を保存」で確定。通常のソートは公開順を変更しません。
- 作品編集ではタイトル・概要・人物・公開状態と、全生成バージョンの動画の表示名・★・状態・順序をまとめて保存。未保存の表示、キャンセル、離脱確認、再読み込みに対応。
- 代表動画は作品一覧のサムネ・再生・制作ページ初期表示に使用。未指定なら掲載順先頭の再生可能な動画。イチオシは独立した動画単位のフラグ。
- migration `0012_editor_order.sql` が既存順を初期値として保持。新規MCP登録は `display_order=-1` で先頭に入り、既存作品の更新日時変更で掲載順は動きません。テーマ固有のおすすめ作品指定は引き続き別設定です。
- `PUT /admin-api/episodes/reorder` は全IDと変更前ID順を検証。`PUT /admin-api/episodes/:id/editor` は編集前タイムスタンプ・動画所属・人物ID・代表動画の再生可否を検証し、D1 batchで一括保存。revisionチェック用の制約により、保存中の競合時にも全体をロールバックします。
- 認証付き `/admin-api/videos/:id/preview` と `/poster` は非公開動画の管理プレビューにも対応し、`private, no-store` で返します。公開メディアのアクセス制御は維持。
- デプロイは `npm run verify` → `npm run db:migrate:remote` → `npx wrangler deploy`。追加列は旧Workerと互換性があります。公開JSONキャッシュのURL世代はv2です。

## キャラクターの3Dビュー

人物ページの音声ボタン付近に「3Dで見る」を表示する。そば屋v3・福ちゃんv2・たこさん・やめ太郎に対応し、ダイアログ内で人物切り替え、回転・拡大縮小、既存動作の再生・停止、正面へのリセットができる。

- 実装: `src/official/character-3d.tsx` / `character-3d-scene.ts` / `character-3d.css`。
- `public/models/characters/*.glb` は各モデル正本への相対symlink。そば屋は `wan_multiview_20260916/imagegen_mask_v1/sobaya_refined_final.glb`（v3、約17.5MB、未リグ）を参照し、3DビューとARは静止姿勢で表示する。そば屋ハザードのモデルは変更しない。ビルド時に静的アセットへ展開し、WorkerやR2のAPIを通さず配信する。
- ビューを開いてから描画コードと選択モデルを読み込む。背景タブ・画面外では描画を止め、閉じる／人物を切り替える際に通信・アニメーション・GPU資源を解放する。
- 初回公開は承認済み試作と同じ未軽量化モデル（そば屋約23.6MB、福ちゃん約19.4MB、たこさん約1.5MB、やめ太郎約2.6MB）。4体を先読みしない。モデル変更時は静的アセットの単一ファイル上限も確認する。
- ローカル確認: `npm run dev` → `/characters/sobaya`。4体の描画・動作切り替え、回転、一時停止、正面リセット、390px幅、閉じた後のcanvas除去を確認済み。スマホ実機の速度計測は未実施。
