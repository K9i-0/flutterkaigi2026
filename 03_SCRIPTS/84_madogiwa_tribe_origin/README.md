# 84 マドギワ族の秘密

完成接続版: `final_remotion_story.mp4`（49.3秒）。現代の透ける区間を除去し、導入→過去（たこさんIrodori修正版）→現在の締めへ接続。編集正本: `remotion/src/edit-manifest.json`。

最新の音声修正版: `final_past_takosan_irodori.mp4`。たこさんだけ80話採用A声のIrodori音声へ差し替え。詳細 `takosan_audio_patch.json` / `TAKOSAN_AUDIO_PATCH.md`。

最新の過去パート: `wan3_past_v2_seed840102_480p.mp4`。設定: `wan3_config_past_v2.json`、プロンプト: `prompt_wan3_past_v2.txt`。背景画像なし・三人座位で一本の幹・顔忠実度指定・そば屋更新シートを反映。初回と部分差し替え案は履歴。詳細 `audit_past_v2.md`。

[台本・演出・参照割当](script.md)が今回の正本。
現在24秒・過去28秒をそれぞれ1回生成し、現在前半→過去→現在後半の順に編集する。
現在・過去ともAPI生成完了。現在版は `wan3_present_seed840101_480p.mp4`（監査: `audit_present.md`）。preflight-report.json に乾式検証・画像条件・ハッシュ・参照分離・音声尺の確認結果を記録。

## ファイル
- prompt_wan3_present.txt / wan3_config_present.json：現在の3人、普通のオフィス。
- prompt_wan3_past.txt / wan3_config_past.json：過去の6人、窓際ジャングル。
- asset-provenance.json：本番入力画像・正典音声の来歴とSHA-256。
- 各設定のmedia配列だけを送信する。フォルダ全体を一括で添付しない。
- 本番の最新刺股は prop_sasumata_long_short.png（v3）。過去版のピンク刺股やロゴが接合部にあるv2は不使用。

## 乾式検証（リポジトリルート）
```sh
python3 -u .claude/skills/wan-video/scripts/qwen_wan3_generate.py 03_SCRIPTS/84_madogiwa_tribe_origin/wan3_config_present.json
python3 -u .claude/skills/wan-video/scripts/qwen_wan3_generate.py 03_SCRIPTS/84_madogiwa_tribe_origin/wan3_config_past.json
```

ユーザーが有料生成を指示した後、価格を再確認し、各コマンドに --submit を付けて実行する。DASHSCOPE_API_KEY は実行環境で設定し、値をログへ出さない。実行途中の同じタスクを再送しない。

## 公式仕様確認（2026-10-01）
- [API仕様](https://docs.qwencloud.com/api-reference/video-generation/wan30-video/create-task)：1回2〜30秒、480P / 16:9対応、音声参照合計15秒以内、プロンプト20,000文字以内。
- [価格ページ](https://www.qwencloud.com/models/wan3.0-video)：480Pの表示割引単価は $0.035/秒、通常表示 $0.05/秒。52秒なら割引単価で $1.82、通常単価で $2.60。税等は別途、実行時再確認。アカウント利用可否は未照会。

## 編集・監査
現在の「実はだな」の発話終端後〜「ということがあったんだ」前の無言ハンドルを実測して切る。
その間に過去を挿入。過去最後の絶叫は語尾まで保持。現在へ戻る瞬間に密林音を切る。
生成後に台詞・顔・Tシャツ・刺股・ロゴ・仮面・身体構造・参照混入・音声同期を script.md のリストで監査する。
