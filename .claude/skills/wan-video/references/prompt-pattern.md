# Wan 3.0プロンプトの型

## 基本式

公式ガイドの考え方を使う。

`主体の説明 + シーンの説明 + 動作の説明 + 美的制御 + スタイル`

マルチショットでは、最初に全体説明を書き、続けてショット番号、タイムスタンプ、ショット内容を書く。

## 推奨テンプレート

```text
Create exactly one <duration>-second, <ratio>, <style> video with synchronized audio.

References:
- Image 1: episode-local character sheet for <character>. Preserve <identity traits>. Use the sheet only for face, body, clothing, and design; do not reproduce its panel layout, labels, white background, or multiple views as multiple people.
- Image 2: exact prop/logo/environment reference. Use only for <role>.
- Audio 1: voice-timbre reference only. Do not copy its words.

Overall continuity: <location, time, palette, physics, identity, prop state>.

Shot 1 [0.0-3.0 s] — <shot size, lens, camera, subject, motion, state>.
Shot 2 [3.0-7.0 s] — Hard cut. <shot content and state transition>.

Audio: <speaker> says exactly once: 「<exact line>」.
Pronunciation: <reading notes>. No other dialogue. No background music.
Sound effects: <sources and timing>, mixed below speech.

Hard constraints: exact duration; exact subject count; exact prop count; exact state order;
no subtitles, watermark, duplicate subjects, unintended text, or extra dialogue.
```

## 書き方

- 参照画像は「似せる」ではなく、どの要素を保存するかを書く。
- 動きには速度、振幅、開始・終了状態を書く。
- カメラにはカット、画角、レンズ感、移動、軸を書く。
- 数え間違いが致命的な要素は`exactly four`のように繰り返し固定する。
- 途中状態は「開始時に4本、発射ごとに空になる、終了時は4本とも空」のように遷移で書く。
- 台詞がない人物には`No dialogue.`、BGM不要なら`No background music.`を明記する。
- 文字は専用画像を参照し、正確な表記、色、出現回数、位置を指定する。
- 既に詳細な秒設計がある場合は`prompt_extend=false`を使う。

## 監査しやすいタイムライン

生成前に、プロンプトと同じ内容を次の表として確認する。

| 区間 | カメラ | 人物 | 小道具状態 | 背景状態 | 音声 |
|---|---|---|---|---|---|
| 0.0-3.0 | 固定正面 | 1人 | 未使用 | 無傷 | ナレーション |
| 3.0-7.0 | 後方左 | 1人 | 使用中 | 状態変化 | 効果音 |

表とプロンプトが食い違う場合は、API送信前に修正する。
