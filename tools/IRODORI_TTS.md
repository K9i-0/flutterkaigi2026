# Irodori-TTSローカル実行

キャラクターの正典参照WAVから、Seedanceへ渡すセリフ単位のボイスサンプルを生成する。
配役、固定モデル、参照WAV、既定seedは`02_CHARACTERS/VOICE_CAST.md`を正本にする。
発話時間は既定でv4.1-Smallの自動尺推定に任せる。

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
tools/irodori_speak.sh \
  'やったー、だいちくわだね！' \
  output.wav \
  02_CHARACTERS/Fukuchan_voice.wav \
  42 \
  '明るい成人男性。嬉しさが自然に弾む会話調で、語尾まで明瞭に話す。'
```

引数は`本文 出力WAV 参照WAV seed [caption]`。漢字の読みが揺れる語は、
台本の表示本文を変えず、生成本文だけをかなにする。通常はモデルの自動尺で生成する。
ユーザー指定の語尾修復では、下記の生成尺補正を使える。

別の場所へIrodori-TTSをcloneした場合だけ、`IRODORI_TTS_DIR`を指定する。

## やめ太郎の追加発話を抑える比較設定

2026-09-23の比較では、長いcaptionを外し、本文CFGを5へ上げる設定で
台本外発話が減った。正典参照WAV・モデル・seed 7は維持する。
短文への「台本の文だけを読む」「最後に口を閉じる」等の長いcaptionを
追加発話対策として重ねない。captionは自動尺予測にも入力される。

```bash
IRODORI_UNCUT=1 IRODORI_CFG_SCALE_TEXT=5 tools/irodori_speak.sh \
  '返事は、来るんですか。' \
  .local/yametaro_uncut.wav \
  02_CHARACTERS/Yametaro_voice.wav \
  7
```

- `IRODORI_UNCUT=1`：モデル内部の末尾トリムと生成後の無音トリムを両方無効にする。
- `IRODORI_CFG_SCALE_TEXT=5`：本文へのCFG強度を指定する。既定は従来どおり3。
- captionが必要な演技では短い演技指定を個別検証する。自動的に指示を削除しない。
- この設定は試聴・全文照合を省略できる保証ではない。ASRだけでは非言語の異音、
  短い相づちの欠落、声質の維持を判定しきれない。
- 比較音声と実行ログは`.local/yametaro-tail-20260923/`。候補WAVはGit管理外。

詳細は[比較記録](irodori-yametaro-tail-20260923.md)を参照。

### 短文の語尾引き伸ばし（2026-09-23追加）

前記の「追加発話なし」は自然な語尾の保証ではなく、ユーザー試聴で引き伸ばしが指摘された。
やめ太郎の短文では、同じ声・台詞・seedのまま生成尺を補正した候補を比較する。

```bash
IRODORI_UNCUT=1 IRODORI_CFG_SCALE_TEXT=5 IRODORI_DURATION_SCALE=0.70 \
  tools/irodori_speak.sh \
  '返事は、来るんですか。' \
  .local/yametaro_short.wav \
  02_CHARACTERS/Yametaro_voice.wav 7
```

`IRODORI_DURATION_SCALE`は自動推定された生成フレーム数への倍率。
生成後のカット、タイムストレッチ、ピッチ変更は行わない。未指定は1.0。
0.70は短文用の比較開始値であり、自然さの試聴合格や任意の台詞への適合を保証しない。
急ぎすぎる場合は0.85と比較する。そば屋や長文へ自動的に適用しない。
短文「ああ、それは失礼しました。」の「ああ」はASRが拾わないため、試聴で照合する。
倍率、caption、本文CFG、実測秒数を生成記録へ残す。

## 採用手順

1. 正典seedと自動尺推定で候補を作る。
2. 演技を変える場合は、声質ではなく感情、距離感、抑揚、語尾をcaptionで指定する。
3. 前後の無音、発音、本人らしさ、演技、ノイズを試聴する。
4. 採用した1本だけをエピソード直下の`clip<N>_line<M>_<character>.wav`へ移す。
5. モデル、参照WAV、seed、caption、自動推定後の実測長を`script.md`へ記録する。

候補WAVはSeedanceの`@Audio N`へ渡すボイスサンプルであり、最終動画へ重ねる音声ではない。
Seedanceが生成したクリップ埋め込み音声を最終音声とする。
