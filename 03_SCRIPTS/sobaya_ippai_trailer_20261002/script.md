# そば屋の一杯 — ゲーム紹介

iPhone 18 Pro / iOS 27シミュレーターで実際のFlutter Sceneゲームを録画し、Remotionで編集する。16:9・1920×1080・30fps。そば屋本人のナレーション、ゲーム画面、接写、失敗と100点の成功を見せる。ビール7：泡3。

## ナレーション正本

1. そば屋の一杯。俺のビール、うまく注げるか？
2. スマホを傾けて、一気に注ぐ。
3. ビール七、泡三。最後は、ぴたりと止めろ。
4. あっ！何こぼしとんねん！
5. 止めた後の一滴まで、気を抜くなよ。
6. 百点！完璧やな。次は、お前の番や。

## 音声

ユーザー指定のそば屋紹介ボイス。ゲーム紹介のナレーションとして正典TTSを直接使用する（Seedance/Wanの制作経路ではない）。
- `Aratako/Irodori-TTS-v4-Large` / revision `89f9d8fbd4d51ea019867ee1197725ede1df13c5`
- 正典 `02_CHARACTERS/Sobaya_voice.wav` / SHA-256 `976916e670fea5fcf0f741d45e150eaf055c3b0e11d240e3be656dd724166b58`
- seed 42、captionなし、生成尺自動／倍率1.0、本文CFG 3、既定の無音トリム
- `tools/sobaya_monsterize.sh` の正典加工（-5 semitones / tremolo 70Hz）
- 採用WAVのみ本ディレクトリ直下で追跡。候補は `.local/ippai-trailer/`。

## 映像

`xcrun simctl io <device> recordVideo --codec=h264` で撮影。撮影用debug extensionの `capture` は通常の120Hzゲーム計算へ傾き入力を渡す。成功テイクは .694 の入力1429ステップ（導入含む）から差し出し、失敗テイクは最大入力。スコアや液量は注入しない。端末センサーの実機映像ではなく、シミュレーターの入力再生である。

編集タイミング正本は `remotion/src/edit-manifest.json`。完成版は `final_remotion_trailer.mp4`。録画・中間・完成動画はGit管理外。

## 再現

```sh
python3 03_SCRIPTS/sobaya_ippai_trailer_20261002/generate_voice.py
cd 03_SCRIPTS/sobaya_ippai_trailer_20261002/remotion
npm ci
node prepare.mjs
../../../.local/Irodori-TTS-large/.venv/bin/python build_music.py
node validate.mjs
npm run typecheck
npm run stills
npm run render
```

録画素材は `capture/perfect.mp4` と `capture/spill2.mp4`。再撮影はdebugアプリへ接続して `node capture.mjs <VMのWebSocket URI> <simulator ID> perfect`（またはspill）。撮り直した場合、録画の待ち時間が変わるのでmanifestのtrimBeforeを実映像へ合わせる。

Remotion / @remotion各パッケージは `4.0.532` へ固定（npm安定版確認済み）。日本語フォントはmacOSのHiragino Sans。楽曲は `build_music.py` が作るオリジナルの小音量マレット／ベース。注ぎ・こぼれ・乾杯の効果音はゲームの合成音を再使用。元録画は音声なし、Remotion側でそば屋の声と効果音を配置する。映像の速度変更はなし。接写カットだけ意図してクロップする。

## 音声監査

加工前・加工後をWhisper smallで全文照合。加工後の「何こぼしとんねん」「最後」「一滴」にはASRの不一致があるが、加工前は該当箇所を認識。冒頭の「注げる」が加工前も「つける」になるため、生成入力だけ「そそげる」へ変更して再生成した。字幕の表示本文は変更しない。

この実行環境では音声入力を受け取れず、直接の通し試聴・声質の聴覚評価は未実施。ASRを試聴合格の代用にはしない。声の設定は正典から変更していない。

冒頭の再生成後は加工済み音声でも「俺のビール、うまく注げるか」を認識。最終採用音声の実測尺・SHA-256は `voice-audit.json`、初回加工前の照合は `voice-raw-audit.json`、冒頭の修正確認は `voice-repair-audit.json`。

## 完成版の検証

- Composition: `IppaiTrailer`、1920×1080、30fps、1020フレーム＝34秒。AACパディングを含むコンテナ尺は約34.005秒。
- H.264 / yuv420p、AAC / 48kHz。映像は再圧縮せず、Remotion合成音声へ最終+3.5dBの音量調整を適用。測定は約-16.2 LUFS、true peak約-1.6 dBTP。
- `validate.mjs`: カット連続性、入力動画の尺、字幕の重なり、ナレーション末尾切れを検証。
- `audit_video.py`: 最後までデコード、1020フレーム一致、カット・字幕境界60枚と代表画面6枚を抽出。タイトル、字幕、比率、OUT、100点の表示を静止画確認。
- 停止カットは成功テイク40〜46秒を使用。注ぎ筋が消えた後の静止した液面まで含める。
- Remotion TypeScript検査成功。ゲームへ追加した録画入力のDart静的解析成功。撮影中の通常ゲーム計算で100点／OUTを確認。
- 試聴と実時間動画再生による聴覚・同期評価は未実施。ASR・フレーム監査・デコード検証と区別する。

公式API確認: https://www.remotion.dev/docs/offthreadvideo / https://www.remotion.dev/docs/html5-audio
