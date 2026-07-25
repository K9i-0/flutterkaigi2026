# 窓際族物語 Production Kit

「窓際族物語」のIP（世界観・キャラクター設定）と、それを使った制作物（Seedance向け動画・ゲーム）を管理するモノレポ。

## Characters
- そば屋
- たこさん
- とーくん
- よーたん
- 福ちゃん
- 無職やめたろう
- 窓際王おかやまん
- ゆめみん

## Theme
窓際族の日常コメディ

## スキル（制作ワークフロー）
制作物ごとのワークフローはスキルに分離している。該当する作業ではスキルを呼び出して従うこと。実体は `.claude/skills/` にあり、Codex CLI向けに `.agents/skills/` からsymlinkで共有している。

- **Seedance動画制作** (`/seedance`): ユーザーからストーリー（あらすじ）を渡されたら、台本＋Seedanceプロンプト＋Codex参考画像（キーフレーム）を作成する。詳細: [.claude/skills/seedance/SKILL.md](.claude/skills/seedance/SKILL.md)
- **ボクセルモデル制作** (`build-voxel-character-from-image`): キャラクターの参照画像から、Blender／Three.jsで使えるリグ付きボクセルGLBを作成・修正する。成果物は `04_GAME_ASSETS/voxel/` に配置。詳細: [.claude/skills/build-voxel-character-from-image/SKILL.md](.claude/skills/build-voxel-character-from-image/SKILL.md)
- ゲーム開発スキルは今後追加予定。

## ゲーム
- **[そば屋のオフィスクラッシュ ～無限フロア大整理～](05_OFFICE_CRASH_GAME/README.md)** (`05_OFFICE_CRASH_GAME/`): 大型ビールジョッキを強化し、8つの備品循環フロアを攻略する3Dアクションハクスラ＋ローグライト。ラン履歴、自己ベスト、永続強化、ランキングをSitesのD1へ保存。Three.js + React + vinext製。
- **[Voxel Character Lab](06_VOXEL_CHARACTER_LAB/README.md)** (`06_VOXEL_CHARACTER_LAB/`): 全8キャラのボクセルモデル・リグ・基本アクション（Idle／Walk／Smash／Power Smash）を確認するThree.jsプロジェクト。
- **[そば屋の定時ダッシュ 〜バレずに脱出〜](07_SOBA_ESCAPE_GAME/README.md)** (`07_SOBA_ESCAPE_GAME/`): 定時のオフィスを、巡回する仲間（福ちゃん・よーたん・とーくん・やめたろう）や監視スクリーン（おかやまん）に見つからず脱出するトップダウン型ステルス。右上の監視レーダーで各キャラの視界を読みながら出口を目指す。Vite + TypeScript + Three.js製。
- **[窓際ボクセル・退勤作戦](08_FLUTTER_VOXEL_GAME/README.md)** (`08_FLUTTER_VOXEL_GAME/`): 正典のそば屋GLBをそのまま使い、発光空間・破壊FX・カメラ演出・自動デモで仕上げたAndroid／iOS向け展示ショーケース。Flutter + Flame + Flame 3D製。

## IPの原典
- 世界観: [01_WORLD/WORLD_BIBLE.md](01_WORLD/WORLD_BIBLE.md)
- 正史エピソード年表: [01_WORLD/STORY_TIMELINE.md](01_WORLD/STORY_TIMELINE.md)
- キャラクター設定: [02_CHARACTERS/](02_CHARACTERS/)
- 台本・生成済みプロンプト: [03_SCRIPTS/](03_SCRIPTS/)
- ゲーム用アセット（共用ボクセル）: [04_GAME_ASSETS/voxel/](04_GAME_ASSETS/voxel/)

## For Claude Code
プロジェクトのワークフローやSeedanceプロンプト作成ルールは [CLAUDE.md](CLAUDE.md) を参照。
