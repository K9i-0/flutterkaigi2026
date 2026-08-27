# `edit-manifest.json`形式

テンプレートはこのJSONをタイミングと文字の唯一の正本として読む。

```json
{
  "composition": {
    "id": "MadogiwaEdit",
    "width": 832,
    "height": 480,
    "fps": 30,
    "durationInFrames": 900
  },
  "inputVideo": "input.mp4",
  "inputVideoVolume": 1,
  "replacementAudio": null,
  "overlays": [
    {
      "type": "station-bug",
      "startFrame": 0,
      "endFrame": 900,
      "text": "19:00",
      "position": "top-left",
      "variant": "clock"
    },
    {
      "type": "station-bug",
      "startFrame": 0,
      "endFrame": 900,
      "text": "ゆめテレ",
      "position": "top-right",
      "variant": "brand"
    },
    {
      "type": "news-lower-third",
      "startFrame": 15,
      "endFrame": 240,
      "kicker": "速報",
      "headline": "窓際社員の男に実刑判決",
      "subheadline": "代理社員に仮面を着けさせ出社・労働",
      "accentColor": "#c4142f"
    },
    {
      "type": "ticker",
      "startFrame": 240,
      "endFrame": 900,
      "label": "NEWS",
      "text": "男は判決を受け『スーパードライが美味かった』と話しています",
      "accentColor": "#c4142f"
    }
  ],
  "captions": [
    {
      "startFrame": 6,
      "endFrame": 119,
      "text": "本日、WAIをご紹介します。\\nWindow-Side AIです。"
    }
  ]
}
```

## 規則

- フレーム区間は`startFrame`を含み、`endFrame`を含まない。
- 全区間を`0 <= startFrame < endFrame <= durationInFrames`へ収める。
- 字幕同士を重ねない。複数話者の同時字幕が必要なら専用レイアウトを実装する。
- `replacementAudio`を指定すると入力動画音声を無音化し、指定音声だけを使う。
- `station-bug`は`text`または`image`のどちらか一つ以上を持つ。画像は`public/`基準。
- `station-bug.position`は`top-left`または`top-right`、`variant`は`plain`、`brand`、`clock`。`clock`の文字は再現可能な固定`HH:MM`にする。
- `news-lower-third`の主見出しは2行以内に収める。
- `news-lower-third.placement`は`top-left`、`bottom-left`、`bottom`、`variant`は`compact`または`full`。`widthPercent`は28〜90。
- `ticker`は長文を流せるが、主見出しと同じ情報を重複させない。
- `accentColor`はCSSで有効な色を使う。指定がなければテンプレート既定色を使う。

プロジェクト固有の複雑なUI、複数の帯、縦型字幕が必要なら型とコンポーネントを追加し、manifest validatorも同時に更新する。
