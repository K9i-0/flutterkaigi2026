# Wan 3.0プロンプトの型

## 音声生成元

- 窓際族メンバーの日本語発話と、正典ゆめテレアナウンサーの日本語ニュース音声は`VOICE_CAST.md`準拠のローカル音声を使える。
- それ以外の台詞、ナレーション、効果音、環境音、BGMは必ずWan 3.0へ生成させる。
- 「字幕は後付け」を「音声も後付け」と読み替えない。
- 例外外のナレーションでは`audio_source: wan3`、`parameters.audio: true`とし、プロンプトへ話者、全文、読み、声質、感情、音響を明記する。
- ショット分割時も汎用ローカルTTSで声を補わない。同じナレーター記述と発音指定を各ショットで完全に揃える。
- 可視話者のリップシンクを優先する場合は[lip-sync-workflow.md](lip-sync-workflow.md)を読み、Wan埋め込み音声を基本の同期源にする。生成後の全面差し替えを前提に可視口パクを設計せず、発音失敗の部分修正だけを例外とする。
- ユーザーがリップシンク、可視発話、正本音声を元にしたWan発話を指定した場合は、Irodori音声が存在してもWanの台詞生成を無効にしない。正典WAVを合計15秒以内の声質参照として渡し、発話中は胸上または寄りで口元を見せる。
- ニュース等の早口・長文・一字一句固定の日本語で正典ローカル話者を使える場合は、生成前に完成音声マスターを作る。画面内のWan台詞は短くし、長文は早めに資料映像へ切り替えてローカル音声で完成させる。生成後に発音失敗が残れば、音声だけの有料再生成より編集修正を先に行う。

## 生成単位

- 完成尺が30秒以下なら、複数場面でも一つのWan 3.0リクエストで全編を生成する。
- 各場面は同じプロンプト内の`Shot n [開始-終了 s]`へ記述する。ショットごとの設定ファイルや個別生成動画を作らない。
- 単一タスク内で人物、衣装、小道具、声、音響、照明、色調を連続させる。構図固定のために動画を分割しない。
- 完成尺が30秒を超える場合だけ最大30秒単位へ必要最小数で分割する。

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
Lip sync: generate speech and facial motion together; animate lips, jaw, and cheeks to the generated phonemes. Keep the mouth closed during silence and do not cut before the final phoneme ends.
Fast exact-script policy: keep visible Wan speech short. After the speaker is off-screen, use the canonical local master on the same timeline. If Wan mispronounces, omits, repeats, or changes a visible phrase, replace only that failed meaning unit in post and re-audit lip sync.
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
- `reference_audio`へ完成台詞が入っていても、Wanがそのサンプル単位の時間軸を再現すると仮定しない。声質参照なら元の語句をコピーしないと明記する。
- 各`Audio n`へ話者名と`voice-timbre reference only`を明記する。15秒は参照音声の合計上限であり、今回生成する台詞総尺の上限ではない。
- 正典ゆめテレアナウンサーを除く窓際族メンバー以外の声、または日本語以外の発話では、`No dialogue.`や`audio=false`で逃げず、要求された音声をWanの同期音声として生成する。
- 文字は専用画像を参照し、正確な表記、色、出現回数、位置を指定する。
- 既に詳細な秒設計がある場合は`prompt_extend=false`を使う。

## 監査しやすいタイムライン

生成前に、プロンプトと同じ内容を次の表として確認する。

| 区間 | カメラ | 人物 | 小道具状態 | 背景状態 | 音声 |
|---|---|---|---|---|---|
| 0.0-3.0 | 固定正面 | 1人 | 未使用 | 無傷 | ナレーション |
| 3.0-7.0 | 後方左 | 1人 | 使用中 | 状態変化 | 効果音 |

表とプロンプトが食い違う場合は、API送信前に修正する。
