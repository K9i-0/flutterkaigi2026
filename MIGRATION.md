# 移行記録 — 2026-10-19

- 移行元: https://github.com/K9i-0/madogiwa-multimedia-universe/tree/flutterkaigi2026
- 移行元commit: `1f7061721f8f0f7e505e65c44208f7aa38e285ce`（PR #21・#22のマージを含む）
- 移行先: https://github.com/K9i-0/flutterkaigi2026 、公開、既定ブランチ `main`
- GitHubのfork networkとは独立したリポジトリ。元ブランチの履歴と全追跡ファイルを保持。
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
