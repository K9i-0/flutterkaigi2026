# `wan3_config.json`形式

```json
{
  "model": "wan3.0-video",
  "audio_source": "wan3",
  "project_duration": 15,
  "generation_mode": "single",
  "prompt_file": "prompt_wan3.txt",
  "media": [
    {"type": "reference_image", "path": "character_sobaya_basic_sheet.png"},
    {"type": "reference_image", "path": "logo.png"}
  ],
  "parameters": {
    "resolution": "480P",
    "ratio": "16:9",
    "duration": 15,
    "audio": true,
    "seed": 300030,
    "watermark": false,
    "prompt_extend": false
  },
  "output": "wan3_result_seed300030_480p.mp4"
}
```

- パスは設定ファイルのあるディレクトリを基準にする。
- 通常形の人物シートはテンプレートから設定ファイルと同じエピソードディレクトリへ実ファイルとしてコピーし、その相対パスを指定する。
- テンプレート、`02_CHARACTERS/`、過去エピソードの人物画像を設定から直接参照しない。正典参照WAVは`VOICE_CAST.md`の指定に従う。
- `media`の配列順とプロンプトの`Image n`、`Video n`、`Audio n`を一致させる。
- `reference_*`と`first_frame`/`last_frame`を混在させない。
- スクリプトは`model`を`wan3.0-video`または`wan3.0-video-prime`へ限定し、危険な任意エンドポイント指定を受け付けない。
- 出力MP4は設定ファイルのディレクトリ内へ保存する。絶対パスも指定できるが、通常は相対パスを使う。

## `audio_source`

`audio_source`はAPIパラメータではなく、送信前に音声生成元を強制検証するための必須メタデータである。

- `wan3`: 窓際族メンバーの日本語音声以外。英語・他言語のナレーション、非メンバーの音声、効果音、環境音、BGMをWan 3.0に生成させる。`parameters.audio`は必ず`true`にする。
- `local_madogiwa_member_japanese`: 窓際族メンバーの日本語発話だけを`VOICE_CAST.md`準拠のローカル音声で後付けする。Wan側に台詞を生成させない。効果音等も必要なら`parameters.audio=true`でWanへ生成させ、不要なら`false`にできる。
- `silent`: ユーザーが無音を明示した場合だけ使う。`parameters.audio`は必ず`false`にする。

字幕後付けは`audio_source`を`local_madogiwa_member_japanese`または`silent`へ変える理由にならない。音声が例外外なら`wan3`を使う。

## `project_duration`と`generation_mode`

- 完成尺が30秒以下なら`project_duration`へ完成尺を整数秒で記録し、`generation_mode`を`single`にする。`parameters.duration`は`project_duration`と一致させ、一つの設定・一つのWanタスクで全編を生成する。
- 30秒以下では、ショット別設定、複数タスク、生成後のショット連結を禁止する。複数場面は単一プロンプトのタイムラインにまとめる。
- 完成尺が30秒を超える場合だけ`generation_mode`を`segmented_over_30`にできる。各設定の`parameters.duration`は最大30秒とし、必要最小数へ分割する。
- `generation_mode=segmented_over_30`なのに`project_duration`が30秒以下、または`generation_mode=single`なのに`parameters.duration`と`project_duration`が異なる設定は検証エラーになる。
