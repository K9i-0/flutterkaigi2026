# 移行記録 — 2026-10-19

- 移行元: https://github.com/K9i-0/madogiwa-multimedia-universe/tree/flutterkaigi2026
- 移行元commit: `1f7061721f8f0f7e505e65c44208f7aa38e285ce`（PR #21・#22のマージを含む）
- 移行先: https://github.com/K9i-0/flutterkaigi2026 、公開、既定ブランチ `main`
- GitHubのfork networkとは独立したリポジトリ。元ブランチの履歴を引き継ぎ、ユーザー指定により動画ファイルを全履歴から除外。動画除外に伴いcommit SHAは変更。
- 未完了Issue 12件を正式移管。本文・担当者を照合し、親子関係を復元。旧URLはGitHubが転送する。
- 完了済みIssue #11は元リポジトリに残し、新Issue #5の子Issueとして参照を維持。
- 過去PRと元リポジトリ・元ブランチは維持。旧PRを新リポジトリへ複製していない。
- 新側Actionsは無効。既存のMMU向けデプロイ・Secretsを自動実行・複製しない。必要なCIは新リポジトリ用に設定してから有効化する。
- 共同作業者のアクセス権、Secrets、外部連携は自動継承されない。移行元のブランチ保護は未設定。

| 元Issue | 新Issue | タイトル |
|---|---|---|
| [#6](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/6) | [#1](https://github.com/K9i-0/flutterkaigi2026/issues/1) | キャラクターを選択できるようにする |
| [#7](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/7) | [#2](https://github.com/K9i-0/flutterkaigi2026/issues/2) | キャラクター選択画面を追加する |
| [#8](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/8) | [#3](https://github.com/K9i-0/flutterkaigi2026/issues/3) | キャラクター別パラメータを適用する |
| [#9](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/9) | [#4](https://github.com/K9i-0/flutterkaigi2026/issues/4) | 選択した3Dモデルとモーションを表示する |
| [#10](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/10) | [#5](https://github.com/K9i-0/flutterkaigi2026/issues/5) | 大きさと速度を変えるアイテムを追加する |
| [#12](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/12) | [#6](https://github.com/K9i-0/flutterkaigi2026/issues/6) | アイテムの取得判定を実装する |
| [#13](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/13) | [#7](https://github.com/K9i-0/flutterkaigi2026/issues/7) | 大きさ変更効果を実装する |
| [#14](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/14) | [#8](https://github.com/K9i-0/flutterkaigi2026/issues/8) | 速度増減効果を実装する |
| [#15](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/15) | [#9](https://github.com/K9i-0/flutterkaigi2026/issues/9) | アイテム効果を画面に表示する |
| [#16](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/16) | [#10](https://github.com/K9i-0/flutterkaigi2026/issues/10) | 効果名と残り時間を表示する |
| [#17](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/17) | [#11](https://github.com/K9i-0/flutterkaigi2026/issues/11) | 一時停止と効果時間を連動させる |
| [#18](https://github.com/K9i-0/madogiwa-multimedia-universe/issues/18) | [#12](https://github.com/K9i-0/flutterkaigi2026/issues/12) | 効果終了時の表示とパラメータを戻す |
## 動画の除外

ユーザー指定により `.mp4` / `.mov` / `.webm` / `.mkv` / `.avi` / `.m4v`（大文字小文字不問）を全コミットから除外。元MMUの動画は削除していません。動画カットシーンを使う別ゲーム等では、必要に応じて元MMUからローカルへ取得してください。今回の `26_SOBAYA_BEER_RAIN` のモデル・画像・音声は保持しています。

## 2026-10-21 ゆめみ採用試験への特化と履歴の整理

ユーザー指定により、ゆめみ採用試験とFlutter Scene系のゲームだけを残すよう、`git filter-repo` で `main` の履歴を書き換えた。削除したデータは元の [Madogiwa Multimedia Universe](https://github.com/K9i-0/madogiwa-multimedia-universe) に残っている。

- 削除: 動画の台本・プロンプト・生成物（`03_SCRIPTS/`、キャラクターシートと小道具の正典を除く）、Three.js / Web / Flutter Scene以外のゲーム（05〜16番台）、公式サイト・Madogiwa Studio、`GAMES_PORTAL/`、`01_WORLD/`、`docs/`、`output/`、ゲームが参照しない3D素材の作業原本、動画・Web向けのスキルとワークフロー。
- 残した素材は、残すプロジェクトのsymlinkとコードが参照するものだけ（中継のsymlinkを含む）。残したファイルの履歴は新しいパスで保持している。
- 書き換え前の `main` の先端は `5d543f51c8564ba7f03590051f66b772ec17e088`。履歴の書き換えでcommit SHAはすべて変わった。`.git` は約2.3GBから約0.6GBになった。過去のPR・Issueからの旧SHAへのリンクは、このリポジトリでは辿れない。
- `main` 以外のブランチを削除し、dependabotのPRを閉じた。

| 旧パス | 新パス |
|---|---|
| `26_YUMEMI_RECRUIT_EXAM/`（旧 `26_SOBAYA_BEER_RAIN/`） | `app/` |
| `17_FLUTTER_SCENE_GAME/` | `labs/flutter_scene_game/` |
| `19_FLUTTER_SCENE_VRM_LAB/` | `labs/flutter_scene_vrm_lab/` |
| `21_SOBAYA_HAZARD_LAB/` | `labs/sobaya_hazard_lab/` |
| `22_HUMANOID_MOTION_LAB/` | `labs/humanoid_motion_lab/` |
| `23_SOBAYA_TIDEWATER/` | `labs/sobaya_tidewater/` |
| `24_SOBAYA_HAZARD/` | `labs/sobaya_hazard/` |
| `25_SOBAYA_IPPAI/` | `labs/sobaya_ippai/` |
| `04_GAME_ASSETS/`（参照分のみ） | `assets/` |
| `02_CHARACTERS/` | `characters/` |
| `03_SCRIPTS/00_TEMPLATES/characters/` | `characters/sheets/` |
| `03_SCRIPTS/00_TEMPLATES/props/product_super_try*` | `characters/props/` |
| そば屋ハザードが参照するエピソードのポスター画像 | `assets/2d/hazard_posters/` |
| `packages/`、`tools/`（参照分のみ） | 変更なし |

