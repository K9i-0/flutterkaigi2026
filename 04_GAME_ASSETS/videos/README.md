# ゲーム組み込み用の完成動画（正典置き場）

CapCut（Seedance 2.0）で制作した完成動画のうち、ゲームにカットシーンとして組み込むものを置く。

- 置き方: `videos/<game-slug>/`（`<game-slug>`は`GAMES_PORTAL/games.json`の`id`と同じ）
- 命名: `opening.mp4` / `event_<slug>.mp4` / `ending.mp4`、ポスター静止画は`<name>_poster.png`
- ゲームからは`public/videos/`にここへの**相対symlink**を張って参照する（ボクセルGLBと同じ方式。コピーしない）
- Web配信用に H.264 + AAC / 長辺1280px以下 / 1クリップ10MB以下 を目安にする。Git LFSは使わない
- 詳細な受け入れ手順は `.claude/skills/2d-game/SKILL.md` を参照
