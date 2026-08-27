# `wan3_config.json`形式

```json
{
  "model": "wan3.0-video",
  "audio_source": "wan3",
  "audio_sync_strategy": "wan_generated_lip_sync",
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

- `wan3`: 下記の正典ローカル話者以外。英語・他言語のナレーション、正典ゆめテレアナウンサー以外の非メンバー音声、効果音、環境音、BGMをWan 3.0に生成させる。`parameters.audio`は必ず`true`にする。
- `local_madogiwa_member_japanese`: 窓際族メンバーの日本語発話だけを`VOICE_CAST.md`準拠のローカル音声で後付けする。Wan側に台詞を生成させない。効果音等も必要なら`parameters.audio=true`でWanへ生成させ、不要なら`false`にできる。
- `local_yume_tele_anchor_japanese`: `VOICE_CAST.md`の正典ゆめテレアナウンサーによる日本語ニュース音声をローカル生成して後付けする。Wan側に台詞を生成させない。効果音等も必要なら`parameters.audio=true`、不要なら`false`にできる。
- `silent`: ユーザーが無音を明示した場合だけ使う。`parameters.audio`は必ず`false`にする。

字幕後付けは`audio_source`をローカル音声または`silent`へ変える理由にならない。音声が上記の正典ローカル話者に該当しなければ`wan3`を使う。

## `audio_sync_strategy`

新規設定では、台詞と可視口パクの扱いを次のいずれかで必ず記録する。過去設定に値がない場合、検証スクリプトは`legacy_unspecified`として警告するが履歴再現のため拒否しない。

- `wan_generated_lip_sync`: Wanが台詞と口の動きを同時生成し、埋め込み音声を基本の同期源にする。`audio_source=wan3`かつ`parameters.audio=true`が必須。発音失敗がない区間は置換せず、修正が必要な区間だけ`post_audio_repairs`へ記録する。
- `hybrid_visible_wan_offscreen_local`: 可視発話区間はWan埋め込み音声を基本とし、画面外になった後は同じ時刻以降の正典ローカル音声へ切り替える。発音失敗がある可視語句だけは`post_audio_repairs`で修正できる。`audio_source=wan3`、`parameters.audio=true`、下記`hybrid_audio_edit`が必須。
- `local_post_mux_offscreen`: 正典ローカル音声を完成編集でmuxする。`audio_source`は`local_madogiwa_member_japanese`または`local_yume_tele_anchor_japanese`。発話中に同期対象となる可視口元を置かない。
- `no_visible_speech`: 台詞がない、話者が常に画面外、または口元を一切見せず同期を評価しない。`audio_source`は要件に応じて選ぶ。

`reference_audio`を渡すこと自体は同期方式にならない。声質参照なのか、完成編集で使う音声なのかをプロンプトと生成記録へ明記する。

ハイブリッド設定ではAPIパラメータ外の編集メタデータを追加する。

```json
"hybrid_audio_edit": {
  "switch_time": 8.4,
  "local_audio_path": "news_narration_input_30s.wav",
  "wan_gain_db": -8.0,
  "output": "wan3_result_hybrid_audio.mp4"
}
```

- `switch_time`: 可視話者の発話が終わった後、両音源が無音になる秒位置。
- `local_audio_path`: 正典ローカル完成音声。先頭からではなく`switch_time`以降を使う。
- `wan_gain_db`: 可視Wan区間へ適用する一定ゲイン。不要なら`0`。
- `output`: ハイブリッド編集後のMP4。

## `post_audio_repairs`

ニュース等の早口・文面固定原稿で、Wan音声の誤読、発音崩れ、欠落、反復、余計な語句を正典ローカル音声から部分修正した場合に記録する。APIパラメータではなく、完成編集の再現用メタデータである。

```json
"post_audio_repairs": {
  "local_audio_path": "news_narration_input_30s.wav",
  "segments": [
    {
      "source_start": 0.4,
      "source_end": 1.4,
      "target_start": 0.819208,
      "target_end": 1.819208,
      "reason": "mispronunciation"
    }
  ],
  "output": "wan3_result_hybrid_audio_v2.mp4"
}
```

- `local_audio_path`: `VOICE_CAST.md`準拠の採用済み正典ローカル音声。
- `source_start` / `source_end`: 正典音声から切り出す時刻。
- `target_start` / `target_end`: 完成タイムライン上で置換する時刻。動画尺と後続音声の時刻を変えない。
- `reason`: `mispronunciation`、`omission`、`repetition`、`paraphrase`、`extra_words`のいずれか。
- `output`: 部分修正後の最終MP4。`hybrid_audio_edit`もある場合はこちらを最終完成版とする。

既定では差し替え元と先の長さを一致させ、時間伸縮を使わない。長さが合わない場合は無音の取り方または画面外への切替を再設計する。

## `project_duration`と`generation_mode`

- 完成尺が30秒以下なら`project_duration`へ完成尺を整数秒で記録し、`generation_mode`を`single`にする。`parameters.duration`は`project_duration`と一致させ、一つの設定・一つのWanタスクで全編を生成する。
- 30秒以下では、ショット別設定、複数タスク、生成後のショット連結を禁止する。複数場面は単一プロンプトのタイムラインにまとめる。
- 完成尺が30秒を超える場合だけ`generation_mode`を`segmented_over_30`にできる。各設定の`parameters.duration`は最大30秒とし、必要最小数へ分割する。
- `generation_mode=segmented_over_30`なのに`project_duration`が30秒以下、または`generation_mode=single`なのに`parameters.duration`と`project_duration`が異なる設定は検証エラーになる。
