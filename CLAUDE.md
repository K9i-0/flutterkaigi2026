# ゆめみ採用試験（FlutterKaigi 2026）

FlutterKaigi 2026向けのFlutter Scene製3Dミニゲーム「ゆめみ採用試験」のリポジトリ。主な開発対象は `app/`。構成と起動方法は `README.md`、ゲームの仕様・検証記録は `app/README.md` を参照する。

## 構成

- `app/`: ゆめみ採用試験。Dartパッケージ名 `yumemi_recruit_exam`、アプリID Android `jp.madogiwa.yumemi_recruit_exam` / iOS・macOS `jp.madogiwa.yumemiRecruitExam`。
- `assets/`: ゲームが読み込む完成版の共有素材。アプリからは `app/assets/` 以下の相対symlinkで参照し、コピーしない。
  - 赤坂ステージ `assets/3d/stages/akasaka/`: `app/tool/build_akasaka_textures.py`・`prepare_stage_surfaces.py`（Pillow/NumPy）→ Blender `-b -P app/tool/build_akasaka_stage.py` → `optimize_stage_textures.py` → `audit_stage_asset.py` の順で再生成。手作業でGLBを編集しない。
  - `audit_stage_asset.py` の上限（三角形・プリミティブ・テクスチャ量）を超える変更はしない。同じ平面で重なる面（Zファイティング）を作らない。
- `characters/`: キャラクター設定 `*.md`、正典写真、キャラクターシート `sheets/`、小道具の正典 `props/`、ボイス参照。
- `packages/`: 共有Dartパッケージ。
- `labs/`: 以前に作ったFlutter Scene製のゲーム・検証アプリ。各ディレクトリの `README.md` を参照する。
- `tools/`: 主に `labs/` 向けの素材生成・監査スクリプト。

3Dモデルの作業原本、動画の台本・生成物、Webサイトはこのリポジトリにない。元の [Madogiwa Multimedia Universe](https://github.com/K9i-0/madogiwa-multimedia-universe) に残っている。原本から再生成するスクリプトには、MMU側でしか動かないものがある。

## キャラクター

- 唯一のハード条件: 登場キャラクターを同一人物・同一キャラクターとして識別できること。実写メンバーは正典写真の顔、非実写キャラクターは `characters/*.md` の「人物同一性」に書かれた顔・身体構造・固有シルエットを基準にする。それ以外（衣装・表情・性格・役割など）はユーザーの指定に従う。
- 福ギュン（2026-10-06改名、旧名は福ちゃん）: 表示名は「福ギュン」。内部IDと素材パスの `fukuchan` / `Fukuchan` は維持する。
- そば屋の白Tシャツ: `characters/01_Sobaya.md` と `characters/sheets/character_sobaya_basic_sheet.png` を基準にする。服越しの乳首の突起・輪郭・点状陰影は描かず、胸筋と自然な布のシワは保つ。
- 窓際スーパーつらいの標準缶: `characters/props/product_super_try.png`。詳細は `characters/props/README.md`。
- 架空企業の表記は `Accidenchua`（ロゴ `ACCIDENCHUA`）。

## Flutterの検証

- Flutterは `.mise.toml` の3.47.8。`mise exec -- flutter ...` で実行する。
- 変更後は該当プロジェクトで `flutter analyze` と `flutter test` を通す。
- UI操作・スクリーンショットは、Dart MCPでdebug起動し、Marionette MCPで行う。設定は `.mcp.json` と `.codex/config.toml`。
  - `app/`: `madogiwa.inspectCatch` で状態を取得し、`madogiwa.catchAction`（`select` / `start` / `step` / `rotate` / `fps` など）で決定論的に操作する。引数は `app/README.md`。
  - `labs/sobaya_hazard_lab/`: `madogiwa.inspectHazard` / `madogiwa.openScenario` など。profile測定は `--dart-define=LAB_BENCHMARK=true`。
  - `labs/flutter_scene_vrm_lab/`: `madogiwa.inspectVrm` / `madogiwa.injectFace`。
- 性能はprofileビルドで評価する。debugビルドのfpsは目安にとどめる。

## Git・GitHub

- リポジトリは `K9i-0/flutterkaigi2026`（Public）。`main` 単一ブランチで運用し、検証後に `origin/main` へ直接pushする。PRや作業ブランチは、ユーザーが明示的に依頼したときだけ作る。
- 元のMMUリポジトリへ誤ってpush・Issue作成しない。
- 動画ファイルは追跡しない。生成の中間物・候補・QA用の大きな画像はローカルに置き、採用した素材だけを正本の場所へ入れる。
- 2026-10-21にgit履歴を書き換えて整理した。経緯と旧パスとの対応は `MIGRATION.md`。

## スキル

- **人型モーション** (`humanoid-motion`): リアル頭身のそば屋・福ギュンのGLB/VRMへの動作適用、ローカル確認、スキニング診断、そば屋ハザードへの採用。詳細: `.claude/skills/humanoid-motion/SKILL.md`

スキルの実体は `.claude/skills/` に置き、Codex CLI向けに `.agents/skills/` からsymlinkで参照する。スキルを追加したら `.agents/skills/` にもsymlinkを張る。
