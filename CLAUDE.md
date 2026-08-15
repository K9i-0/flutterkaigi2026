# 窓際族物語 Production Kit

「窓際族物語」のIP（世界観・キャラクター設定）と、それを使った制作物（Seedance向け動画、今後はゲームも）を管理するモノレポ。

## 参照ファイル（IPの原典）
- 世界観: `01_WORLD/WORLD_BIBLE.md`
- 正史エピソード年表: `01_WORLD/STORY_TIMELINE.md`（これまでの出来事。全て現実として扱い、夢オチは採用しない）
- キャラクター設定: `02_CHARACTERS/*.md`（各キャラのNG変更＝デザイン上変えてはいけない要素に注意）
- ボイスキャスト: `02_CHARACTERS/VOICE_CAST.md`（Irodori-TTSのモデル、参照WAV、既定seed、固有後処理が正典。別シナリオでも同じ声を維持する）
- 台本・生成済みプロンプト: `03_SCRIPTS/`
- ゲーム用アセット（ボクセル）: `04_GAME_ASSETS/voxel/`（全キャラのリグ付きボクセルモデル`.glb`は`04_GAME_ASSETS/voxel/models/`が正典。`tools/build_*_voxel_model.py`から生成するため手作業で編集しない。新規ゲームはモデルをコピーせず、`public/models/`等からここへの相対symlinkで参照する。リグ仕様は`04_GAME_ASSETS/voxel/VOXEL_CHARACTER_KIT.md`を参照）
- ゲーム用アセット（完成動画）: `04_GAME_ASSETS/videos/`（Seedance/CapCutで制作したゲーム組み込み用の完成動画が正典。ゲームからはコピーせず`public/videos/`からの相対symlinkで参照する）

## Git管理方針

Gitでは、Seedanceの再生成と同じ声の継続利用に必要な最小限の入力資産を管理する。

- 追跡する：`script.md`、実際に貼り付ける`prompt*.txt`、本番入力画像、`VOICE_CAST.md`が指定する正典参照WAV、採用音声の再生成に使う参照WAV、エピソード直下の採用済みセリフWAV、軽量な台帳・README
- 追跡しない：入手した元動画、正典参照WAVへ採用していない元動画抽出物、候補・未採用・テスト・中間音声、`03_SCRIPTS/`配下の生成動画・previs・監査用動画
- 追跡しない素材はローカルまたは別ストレージへ保持し、採用した入力だけを正本の場所へ移す
- 例外：ゲームへ実際に組み込むことを決定した完成動画だけは`04_GAME_ASSETS/videos/`を正典として追跡する。エピソードディレクトリへ同じ動画を複製しない

## スキル（制作ワークフロー）
制作物ごとのワークフローはスキルに分離している。該当する作業ではスキルを呼び出して従うこと。

- **Seedance動画制作** (`/seedance`): ユーザーからストーリー（あらすじ）を渡されたら、このスキルに従って台本＋Seedanceプロンプト＋Codex参考画像を作成する。詳細: `.claude/skills/seedance/SKILL.md`
- **映画ポスター制作** (`create-movie-poster`): 映画ポスターの新規制作・改修・シリーズ統一では、独立した初回3案から方向性を選び、縦2:3正本、正確な日本語文字、キャラクター同一性を管理する。実写のよーたん、福ちゃん、とーくん、おかやまんは正典写真へ顔を厳密に一致させる。SNS安全域はユーザー指定時だけ調整し、生成画像への反復編集を避ける。詳細: `.claude/skills/create-movie-poster/SKILL.md`
- **ボクセルモデル制作** (`build-voxel-character-from-image`): キャラクターの参照画像からリグ付きボクセルGLBを作成・修正するときに使用する。成果物は`04_GAME_ASSETS/voxel/`に配置する。詳細: `.claude/skills/build-voxel-character-from-image/SKILL.md`
- **2Dゲーム制作** (`/2d-game`): 2Dゲームを新規作成するとき、およびSeedanceで制作した完成動画（添付mp4）をオープニング/イベントのカットシーンとしてゲームに組み込むときに使用する。完成動画の正典置き場は`04_GAME_ASSETS/videos/`（ゲームからは`public/videos/`の相対symlinkで参照）。詳細: `.claude/skills/2d-game/SKILL.md`
- **Madogiwa Studio登録** (`madogiwa-studio`): Remote Web MCP経由でエピソード、生成バージョン、使用モデル、プロンプト、入力画像・参照音声、生成動画をStudioへ登録・確認するときに使用する。詳細: `.claude/skills/madogiwa-studio/SKILL.md`

スキルの実体は`.claude/skills/`に置き、Codex CLI向けには`.agents/skills/`からsymlinkで同じスキルを参照させている（Claude Code・Codexの両方が同一のSKILL.mdを読む）。スキルを追加したら`.agents/skills/`にもsymlinkを張ること。

## 全制作物に共通の禁止事項
`WORLD_BIBLE.md`の「最低限の禁止事項」を守る。ホラー、バトル、シリアスな展開や結末を一律に制限しない。各キャラのNG変更（仮面/触手/ウクレレ等のデザイン要素）はどの媒体でも変更しない。

## FlutterゲームのUI検証

`14_MADOGIWA_CARD_GAME/`は`ccpocket`と同じくDart MCPでデバッグアプリを起動し、
Marionette MCPでUI操作・スクリーンショット・カスタムハーネス検証を行う。
プロジェクト設定は`.mcp.json`と`.codex/config.toml`、専用拡張は
`14_MADOGIWA_CARD_GAME/lib/automation/`を参照する。Flameキャンバス内の状態確認には
`madogiwa.inspectGame`、決定論的シナリオへの遷移には`madogiwa.openScenario`を使う。
