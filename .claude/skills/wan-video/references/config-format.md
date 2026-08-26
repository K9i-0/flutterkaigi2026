# `wan3_config.json`形式

```json
{
  "model": "wan3.0-video",
  "prompt_file": "prompt_wan3.txt",
  "media": [
    {"type": "reference_image", "path": "character.png"},
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
- `media`の配列順とプロンプトの`Image n`、`Video n`、`Audio n`を一致させる。
- `reference_*`と`first_frame`/`last_frame`を混在させない。
- スクリプトは`model`を`wan3.0-video`へ限定し、危険な任意エンドポイント指定を受け付けない。
- 出力MP4は設定ファイルのディレクトリ内へ保存する。絶対パスも指定できるが、通常は相対パスを使う。
