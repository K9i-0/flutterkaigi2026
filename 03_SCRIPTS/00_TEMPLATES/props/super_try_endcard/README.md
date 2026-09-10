# 窓際スーパーつらい 共通CMエンドカット

2026-09-10採用。完成動画: `final_remotion_endcard_adopted.mp4`。
映像5秒（150フレーム）、1920×1080、30fps。AACパディングでコンテナ尺は約5.056秒。

## 採用素材

- `remotion/public/office_left.png`: 左に「労働」入り標準缶、右に余白を確保した夜のオフィス。内蔵imagegenで制作。プロンプトは `prompt_imagegen_left.txt`。
- `remotion/public/titles/title_meme.png`: 赤金の「窓際スーパー」＋右寄せの銀「つらい」。透過PNG。「パ」の穴は自然な小ささへ修正済み。生成指示は同フォルダの `prompt_meme.txt`。
- `remotion/public/product_call.wav`: エピソード63の末尾25.8〜30.0秒から採用した商品コール。BGMを含む元ミックス。声だけの素材ではない。
- 背景ぼかし2px、結露135粒、柔らかい反射の移動（採用B）。写真＋SVG/CSS合成で、Three.jsは使用していない。
- 左端の注意表示: 「お酒は20歳になってから。」「飲酒運転はしない。」。
- コピー例: 「今日も、よく働いた。」。白、48px、太さ700、字間2px。

## 次のCMで使う

コピーを変えない場合は完成動画を本編の最後へ繋ぐ。回ごとのコピーを変える場合は `remotion/src/effects-manifest.json` の `sampleCopy.text` を変更し、エピソード側へ別名出力する。共通の採用版を各回のコピーで上書きしない。長文は1行の収まりを再確認する。

```sh
cd 03_SCRIPTS/00_TEMPLATES/props/super_try_endcard/remotion
npm ci
npm run typecheck
npx remotion render src/index.tsx SuperTryEndcardFinal /absolute/path/to/episode/endcard.mp4 --concurrency=2 --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
```

ローカルの共通版を再生成する場合は `npm run render -- --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'`。
音声再抽出は `python3 remotion/scripts/extract_audio.py`。元動画が必要だが、通常は保存済みWAVをそのまま使う。

macOSのヒラギノ角ゴシックを使用。他OSでは同等フォントを用意して文字組みを確認する。
動画・レンダーキャッシュはGit管理外でローカル保存。採用PNG・WAV、編集コード、設定、lockfile、生成プロンプト、READMEは保存対象。没案は削除済み。

## 検証

型チェック、1920×1080・30fps・全150フレーム、終端デコード、最終画面の文字・半濁点・コピー配置を確認。ユーザーが音声・映像を含む現行版を承認。`adopted_manifest.json` に採用ファイルのSHA-256を記録。
