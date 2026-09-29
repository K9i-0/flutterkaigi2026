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

## Irodori v4-Large比較（2026-09-29）

`compare_large.py`は両話者の採用済み生成記録を読み、本文、参照WAV、seed、caption、
本文CFG、行別の生成尺倍率、トリム、そば屋の固有加工を維持してLarge候補を作る。
既存Small音声は再生成せず、そのまま比較する。既定モデル・正典参照・採用音声・動画は変更しない。
Small用に調整した尺倍率も維持するため、Largeに最適化した品質比較ではなく、設定を引き継いだ場合の移行検証である。

- Largeモデル: `Aratako/Irodori-TTS-v4-Large`、revision `2e0c55428ce97268a507f1feeb2478f8d9148e8b`
- Large実行コード: `.local/Irodori-TTS-large`、commit `89f9d8fbd4d51ea019867ee1197725ede1df13c5`
- Python依存: 既存 `.local/Irodori-TTS/.venv`（PyTorch 2.10.0、Transformers 5.12.1）
- 実行: MPS / FP32、40ステップ。Small本体は変更せず、Large用の公式コードを分離。
- 候補・ログ・比較ページ: `.local/irodori-large-ep75/`（Git管理外）

リポジトリルートから実行する。モデルは事前にHugging Faceキャッシュへ取得する。

```sh
.local/Irodori-TTS/.venv/bin/python 03_SCRIPTS/75_madogiwa_tshirt_keynote/compare_large.py
.local/Irodori-TTS/.venv/bin/python 03_SCRIPTS/75_madogiwa_tshirt_keynote/audit_large.py
python3 -m http.server 8975 --bind 127.0.0.1 --directory .local/irodori-large-ep75
```

`http://127.0.0.1:8975/`で各行のSmall/Largeと話者別の通し再生を利用できる。
`--ids intro`で冒頭だけ生成可能。fingerprintと出力hashが一致する候補は再利用する。
`generation.json`に全生成条件・hash・実測尺・生成時間、`runtime.json`に実行情報を記録。
MPSメモリは0.5秒ごとの観測最大で、OS全体の消費量ではない。RSSとMPS値は重複し得るため加算しない。
`audit_large.py`はローカルのWhisper Smallで両モデルを文字起こしし、WAVのデコードも確認する。
文字起こしと実際の試聴は別であり、自然さ・本人らしさは未採用の比較試聴対象とする。

実測結果は `large-comparison-result.json`。両話者32本ずつのLarge生成が完了し、
既存Smallを含む128本のデコード・ASR・HTTPリンクを確認した。平均生成時間は
やめ太郎17.9秒/本、そば屋23.9秒/本。MPSドライバ使用量の観測最大は22.65GB。
通常アプリ起動中の測定で、一部はCPUのASRと並行しているため専用ベンチマークではない。
やめ太郎の `one` / `how` / `simple` はASR上で台本外発話が疑われる。
`second` のT欠落、そば屋のTの認識差・短文・語尾を含め、10行を要試聴として記録した。
これらはASRによる指摘であり、耳で確認した不良判定ではない。既定モデルはSmallのまま。

### 2026-09-30 ユーザー試聴評価

- そば屋：Largeは「迫力が増して良くなってると思う」。
- やめ太郎：Largeは「元から微妙だった部分がそのままで強調されてるので微妙」。

話者ごとの総評として記録し、全セリフの個別合格やモデル切替の指示とは区別する。
キャラ別に採用を検討し、やめ太郎はLargeへの単純変更では改善していないと扱う。
モデル切替・既存音声差替えは未実施。
