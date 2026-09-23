# 窓際族Tシャツ 発表会

そば屋ひとりが「窓際族」「T」「シャツ」を3つの革新的製品として紹介し、ひとつの商品へ合体させる基調講演パロディ。72話と同じ窓際族Tシャツを使用。福ちゃんの出演なし。

- ノージョブズ版: `final_remotion_nojobs.mp4`（無職やめ太郎、146.583秒。正典の顔・声、黒いトップスと青いズボン）
- 完成動画: `final_remotion_keynote.mp4`（ローカル保持、Git対象外）
- 台本: `script.md` / `remotion/src/dialogue.json`
- 編集時刻の正本: `remotion/src/edit-manifest.json`（24fps整数フレーム）
- 音声: エピソード直下の `line_*_sobaya.wav`、再生成設定とhashは `audio-generation.json`
- 素材と音源ライセンス: `asset-provenance.json` / `CREDITS.md`
- 検証: `production-result.json`

## 再生成

リポジトリルートから:

```sh
python3 .claude/skills/threejs-video/scripts/prepare_assets.py 03_SCRIPTS/75_madogiwa_tshirt_keynote/remotion
python3 03_SCRIPTS/75_madogiwa_tshirt_keynote/generate_audio.py
python3 03_SCRIPTS/75_madogiwa_tshirt_keynote/prepare_timeline.py
.local/Irodori-TTS/.venv/bin/python 03_SCRIPTS/75_madogiwa_tshirt_keynote/mix_audio.py
```

`audio_sources/`がなければ `asset-provenance.json` のdownloadから取得する。音声生成は `tools/IRODORI_TTS.md` に従ってセットアップ済みの環境を使用。採用WAVのfingerprintが一致する場合は再生成しない。

```sh
cd 03_SCRIPTS/75_madogiwa_tshirt_keynote/remotion
npm ci
npm run typecheck
npm run stills
npm run preview
npm run render
cd ../../..
python3 03_SCRIPTS/75_madogiwa_tshirt_keynote/finish_video.py
```

`render.mjs`はmacOSのGoogle Chromeを使用する。別環境では `browserExecutable` をインストール済みのChromeへ変更。固定依存は既存Three.js舞台キットから継承したRemotion 4.0.527。今回の実行では74話と同じインストール済みnode_modulesを参照。

正典GLBは素材準備でhardlink。衣装は作品内の材質シェーダーだけで変更し、正典の顔・メッシュ・ウェイトは変更しない。白い仮面は固定。指の骨がない既存リグのため指の本数の演技は行わず、スクリーンと既存の手振りで段階を表す。歩行は入場、説明中は既存Explain、腕の紹介はEmptyHands、お辞儀はHybrid_Bow。足場と上半身のカットを利用して構成する。

音声は正典そば屋の参照・モデル・加工を維持。舞台効果音のクレジットは動画内とCREDITS.mdに収録。ASR照合と実際の試聴は区別し、試聴の未確認範囲はproduction-result.jsonへ記録する。

## 2026-09-23 改修

窓際族イラストの詳細表示を、原画像の `(784,199)` から200×200の正方形へ変更。文字と人物を含む印刷全体を中央に配置し、「ひとつめ」「反復」「ディテール」の全場面、両バージョンへ反映。原商品の画像は変更していない。

ノージョブズ版は同じ台本を無職やめ太郎が演じる別動画。開始スライドに「No Jobs / ノージョブズ / 無職やめ太郎」を表示する。既存のTsukkomi・Wish・Idle・Walk・Waveで演技し、SpeechOpenを音声振幅へ合わせる。正典の短文設定を出発点に、ASRで検出した欠落・余計な発話・反復を7行再生成。採用設定は `dialogue-nojobs.json` と `audio-generation-nojobs.json` に記録。

再生成は音声生成・時刻作成・音声ミックス・仕上げへ `--variant nojobs`、レンダーへ `node render.mjs stills nojobs` / `node render.mjs preview nojobs` / `node render.mjs full nojobs` を指定する。時刻作成は口パク解析にNumPyを使うため `.local/Irodori-TTS/.venv/bin/python` で実行する。採用音声は `line_*_yametaro.wav`、編集正本は `edit-manifest-nojobs.json`。
