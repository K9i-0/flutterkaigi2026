# Irodori-TTSローカル実行

キャラクターの正典参照WAVから、Seedanceへ渡すセリフ単位のボイスサンプルを生成する。
配役、固定モデル、参照WAV、既定seedは`02_CHARACTERS/VOICE_CAST.md`を正本にする。
発話時間はv4.1-Smallの自動尺推定に任せる。

## 初回セットアップ

macOSではリポジトリルートから次を実行する。

```bash
tools/setup_irodori_tts.sh
```

公式`Aratako/Irodori-TTS`を`.local/Irodori-TTS`へcloneし、公式のmacOS向け手順
`uv sync --extra cpu`でPython 3.10環境を作る。`.local/`はGit管理外である。
固定チェックポイント`Aratako/Irodori-TTS-v4.1-Small`と音声コーデックは初回生成時に
Hugging Faceからキャッシュへ取得される。

## セリフ生成

```bash
.claude/skills/seedance/scripts/irodori_speak.sh \
  'やったー、だいちくわだね！' \
  output.wav \
  02_CHARACTERS/Fukuchan_voice.wav \
  42 \
  '明るい成人男性。嬉しさが自然に弾む会話調で、語尾まで明瞭に話す。'
```

引数は`本文 出力WAV 参照WAV seed [caption]`。漢字の読みが揺れる語は、
台本の表示本文を変えず、生成本文だけをかなにする。`--seconds`と
`--duration-scale`は使わず、モデルが予測した自然な長さで生成する。

別の場所へIrodori-TTSをcloneした場合だけ、`IRODORI_TTS_DIR`を指定する。

## 採用手順

1. 正典seedと自動尺推定で候補を作る。
2. 演技を変える場合は、声質ではなく感情、距離感、抑揚、語尾をcaptionで指定する。
3. 前後の無音、発音、本人らしさ、演技、ノイズを試聴する。
4. 採用した1本だけをエピソード直下の`clip<N>_line<M>_<character>.wav`へ移す。
5. モデル、参照WAV、seed、caption、自動推定後の実測長を`script.md`へ記録する。

候補WAVはSeedanceの`@Audio N`へ渡すボイスサンプルであり、最終動画へ重ねる音声ではない。
Seedanceが生成したクリップ埋め込み音声を最終音声とする。
