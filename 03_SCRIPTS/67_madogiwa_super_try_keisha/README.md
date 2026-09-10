# 第5弾「土下座レース篇」生成準備

- `script.md`: 採用台本、全体時間、連続性、音声方針、未実施の監査。
- `prompt_wan3_part1.txt` / `prompt_wan3_part2.txt`: 各20秒、そのまま貼り付ける本文。
- `wan3_config_part1.json` / `wan3_config_part2.json`: 480P・16:9・音声あり。
- 入力順は両方とも、そば屋→やめ太郎→いーさん→缶。後半のみやめ太郎WAVをAudio 1に追加。
- `edit_plan.json`: 40秒本編＋5秒商品カット、大会名・肩書・失格・優勝の正確な表示。
- `assets_manifest.json`: 採用素材の来歴・ハッシュ。

リポジトリルートから乾式検証:

```sh
python3 .claude/skills/wan-video/scripts/qwen_wan3_generate.py 03_SCRIPTS/67_madogiwa_super_try_keisha/wan3_config_part1.json
python3 .claude/skills/wan-video/scripts/qwen_wan3_generate.py 03_SCRIPTS/67_madogiwa_super_try_keisha/wan3_config_part2.json
```

有料生成は未実行。実行承認と現行費用の確認後だけ、それぞれへ `--submit` を付ける。後半は前半の会場・実況声・人物を確認してから実行する。完成映像・音声・文字の監査は生成後。
