# ゆめテレ「ゆめみ採用試験」紹介原稿

制作日: 2026-10-27。ゲーム画面を紹介するナレーション。話者の画面出演はなし。

## 表示原稿

ゆめテレから、採用試験のご案内です。

舞台は、赤坂の高層ビルに架かる鉄骨。

端末を傾けて、あたりだけをキャッチします。

福ギュン、おだてつ、そば屋。

選ぶキャラクターで、難しさも変わります。

100点満点、80点以上で合格。

はずれを取ると、10点減点です。

昼も夜も、試験は開催。

街やキャラクターは、ギャラリーでも楽しめます。

Flutterで動く、3次元の採用試験。

あなたは、合格できますか。

## 音声生成

- エンジン: Irodori-TTS
- モデル: `Aratako/Irodori-TTS-v4.1-Small`
- 参照: `characters/YumeTeleAnchor_voice.wav`
- 参照SHA-256: `e3cd210adad43fb3338684555e7e066f83cfad2400265c8a73fa55b9f96b753f`
- seed: `2026`
- caption: `落ち着いた地方局ニュース読み。標準語で、明瞭かつ均一な速度、抑制された抑揚で真面目に話す。`
- 本文CFG: 3.0、生成尺倍率: 1.0（自動尺）、無音トリム: ラッパー既定
- 実測尺: 29.642875秒
- 採用WAV SHA-256: `d2648f5c27305d5a1e98861c54f1514c0af7431f14e5221d233be4ec651cfe49`
- 編集: 15フレームから再生、速度・ピッチ変更なし。BGMなし。ゲーム音声はミュート。

生成本文では「100」を「百」、「80」を「八十」、「10」を「十」、「Flutter」を「フラッター」、「3次元」を「三次元」とした。それ以外は表示原稿と同じ。表記はASRではなく、この原稿を正本とする。

再生成はMMUリポジトリの `tools/irodori_speak.sh` に本文、出力WAV、上記参照WAV、seed、captionを渡す。ローカル環境は `IRODORI_TTS_DIR=/Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/.local/Irodori-TTS` を使用した。新たな生成で尺が変わった場合は、`src/edit-manifest.json` の字幕フレームを再確認する。

## 監査記録

Whisper large-v3-turboで、冒頭から末尾まで本文の欠落・台本外発話がないことを機械的に照合。ASRの「夢テレ」「福群」「小田鉄」「蕎麦屋」は字幕へ流用せず、原稿の正しい表記を採用した。聴覚による声質・自然さの通し確認は未実施。語句の認識一致と聴感上の合格は区別する。

参照スキル: [MMU remotion-video](https://github.com/K9i-0/madogiwa-multimedia-universe/blob/main/.claude/skills/remotion-video/SKILL.md)。720p、整数フレームによる編集、正典音声、アナウンサー字幕色、元素材の非破壊、公開動画をGit追跡しない方針を適用。
