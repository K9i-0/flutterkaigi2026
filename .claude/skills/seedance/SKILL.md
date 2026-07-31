---
name: seedance
description: 窓際族物語のストーリーから、Seedance向けのキャラクターシート、アクション/VFXシート、秒単位のマスタービデオプロンプト、正確な日本語音声指示を制作・改修する。ユーザーからあらすじを渡されたとき、Seedance台本や動画プロンプトの作成・修正、キャラクターシートや参考画像の生成、セリフ尺や発音の改善を頼まれたときに必ず使用する。
---

# Seedance 動画制作

`03_SCRIPTS/08_giant_sobaya_enjo_anken/`で成功した、**キャラクターシートによる外見固定**と**単一の秒刻みマスタープロンプト**を標準方式にする。開始・終了キーフレームは必要な作品だけで使い、クリップごとの生成を必須にしない。

## 基準例

制作前に次を確認する。

- `03_SCRIPTS/08_giant_sobaya_enjo_anken/script.md`
- 同ディレクトリの `character_giant_sobaya_sheet.png`
- 同ディレクトリの `character_yametaro_liveaction_sheet.png`
- 同ディレクトリの `character_yametaro_enjo_anken_sheet.png`

基準例の物語上の結末や旧安全制約はテンプレート化しない。現在の `01_WORLD/WORLD_BIBLE.md` と `02_CHARACTERS/*.md`を優先する。

## ワークフロー

1. 世界観、正史年表、登場キャラクター設定、基準例を読む。
2. ラン専用ディレクトリを作る。
3. 正確なセリフを確定し、必要発話時間を先に計算する。
4. キャラクターシートと、必要ならアクション/VFXシートを生成する。
5. セリフ尺を起点に可変長のシーン構成を作り、`script.md`へ単一のマスタープロンプトを書く。
6. 画像、時間配分、正史、キャラ、小道具、発音を監査する。

## 参照する原典

- 世界観と表現方針: `01_WORLD/WORLD_BIBLE.md`
- 正史: `01_WORLD/STORY_TIMELINE.md`
- キャラクター設定と元画像: `02_CHARACTERS/*.md`
- 過去の制作物: `03_SCRIPTS/`

キャラクター設定のNG変更を守る。正史を夢オチや後付けで無効化しない。ジャンル、感情、結末をコメディや乾杯に固定しない。

## 出力ディレクトリ

毎回 `03_SCRIPTS/<NN>_<slug>/` を新設し、成果物を同じ階層に置く。

- `<NN>`: 既存番号の最大値 + 1（2桁ゼロ埋め）
- `<slug>`: 小文字の英語をアンダースコアで結ぶ
- 必須: `script.md`、主要な登場形態ごとの `character_<name>_sheet.png`
- 任意: `character_<name>_<action>_sheet.png`、`clip1_start.png`、`clip1_end.png`

既存成果物はユーザーから修正を頼まれた場合を除いて変更しない。

## キャラクターシート

画像生成時は`imagegen`スキルを使用する。`02_CHARACTERS/<name>.md`の「画像ファイル」と設定を入力し、1枚の16:9シートで外見を固定する。シートは構図参照ではなく、identity/design referenceとして使う。

### Identity sheetの必須要素

- 左側の大きな全身ヒーローポーズ
- FRONT / SIDE / BACK の直立ターンアラウンド
- 顔または仮面のクローズアップ
- 表情差分。仮面キャラは変更可能な目・姿勢などだけを示す
- 衣装、履物、眼鏡、武器、楽器、容器など識別に重要なディテール
- 色パレット
- 巨大化など通常と異なる形態では身長・比較対象・小道具の縮尺

背景は明るい無地、照明と画角は比較しやすく統一する。複数キャラクターや別衣装を同じidentity sheetへ混ぜない。正面・側面・背面で髪型、体格、衣装、必須小道具を一致させる。

### Action / VFX sheetを追加する条件

独自の必殺技、変身、複雑な武器操作、文字を形成するVFXなど、文章だけでは形がぶれやすい場合に追加する。

- FINISHの大きな完成像
- READY / IGNITION / RELEASEなど3段階以上の動作
- 手、足、武器の向きが分かるクローズアップ
- VFXの形、色、発生源、軌道、消失状態
- 画面に出す正確な文字や記号

生成後は画像を実寸で開き、顔、前後の髪、手、衣装、NG変更、小道具、文字を目視確認する。不一致があればプロンプトで変更箇所だけを明示して再生成する。

## セリフ時間を先に確保する

均等なシーン分割を禁止する。セリフを決めてから、その発話に必要な長さに合わせてシーンを割り当てる。

1. 各セリフについて、正確な日本語、かな読み、話し方を確定する。
2. 次のスクリプトでモーラ数と推奨シーン秒数を計算する。

```bash
python3 .claude/skills/seedance/scripts/check_dialogue_timing.py \
  --text 'すまんやで、そば屋さん。こうするしかないんや' \
  --reading 'すまんやで、そばやさん。こうするしかないんや' \
  --style normal \
  --window 6.0
```

この台詞は基準例では8秒から12秒までの実質4秒しかなく、推奨6.0秒に足りない。キャラクターシートとプロンプト構造は基準にするが、この時間配分は再現しない。

漢字を含む場合は `--reading` へ実際の読みをかなで渡す。

```bash
python3 .claude/skills/seedance/scripts/check_dialogue_timing.py \
  --text '秘技・炎上案拳' \
  --reading 'ひぎ・えんじょうあんけん' \
  --style shout \
  --window 4.0
```

話速の基準は、通常4.5モーラ/秒、低くゆっくり3.5、技名など明瞭な叫び4.0、明示的な早口5.5とする。各セリフには発話時間に加えて、前後それぞれ最低0.4秒の無音・表情・口の静止時間を確保する。

- `--window`には、発話前0.4秒から発話後0.4秒までカメラと口元を安定させる**会話ビート全体の長さ**を渡す。実際の発話区間は、その内側に別途指定する。
- `--window`が失敗したシーンは、そのまま採用しない。
- セリフ開始をシーン後半まで遅らせる場合、シーン全体ではなく**安定した会話ビートの開始から終了まで**で再検証する。
- 発話中は安定したショットを保ち、大きなカメラ遷移、複雑な格闘、別人の発話を重ねない。
- 尺が足りなければ、シーンまたは総尺を延ばす。上限がある場合は、動作、カット、台詞の順で整理し、意味を保って台詞を短くする。
- 「残り時間で急いで話す」「台詞を圧縮する」「言い換える」「反復する」指示は禁止する。

## `script.md`の構成

説明、見出し、映像プロンプトは英語で書く。実際に発話・表示する日本語だけを引用符内に保持する。

1. `# <Title> — <Duration> Seedance Master Prompt`
2. `## Reference Inputs`
3. `## First Frame`
4. `## Last Frame`
5. `## Prop and State Continuity`
6. `## Japanese Dialogue and Pronunciation Lock`
7. `## Dialogue Timing Audit`
8. `## Seedance Motion Prompt`
9. `## CapCut / Seedance Input Mapping`
10. `## Canon and Physical Audit`

### Reference Inputs

画像ごとにファイル名、固定する特徴、用途を明記する。必ず `identity/design reference, not a composition reference` または `action/VFX reference, not a composition reference` と役割を分ける。

### Pronunciation Lock

各セリフに、話者、正確な日本語、かな読み、Hepburn、英語話者向け音写、IPA、声と感情を記載する。発音情報は無音の指示であり、発話、字幕、画面表示を禁止する。台詞の追加、翻訳、言い換え、反復、重なりも禁止する。

### Dialogue Timing Audit

表に `Speaker / Exact line / Mora / Delivery rate / Minimum speech / Assigned speech interval / Required beat / Assigned beat` を記載する。発話区間は`Minimum speech`以上、会話ビートは`Required beat`以上にする。

### Master Motion Prompt

映像全体を1つのコードブロックにまとめ、`[0.0-5.5s]`のような可変長ブロックで総尺を隙間・重複なく埋める。各ブロックに次を順番に書く。

- その区間の主目的を1つ
- レンズ、構図、安定したカメラ移動
- 前状態 → 動作 → 後状態
- セリフの正確な開始・終了時刻
- 区間終了時の画面状態と次の接続点

1区間へ複数の大技、長台詞、複雑なカメラを詰め込まない。会話区間は口元と表情を優先し、アクション区間と分ける。末尾に全体のstyle、character lock、VFX language、palette、lighting、camera rules、negative constraints、model、duration、resolution、aspect ratioをまとめる。

設定が未指定なら、最後に検証できた基準としてSeedance 2.5、最大30秒の単一プロンプト、480p、16:9を使う。ユーザー指定や利用可能なモデル設定があればそちらを優先する。

## 入力画像の扱い

キャラクターシートを必須のidentity/design referenceとして渡す。Action / VFX sheetは該当動作の参照として追加する。開始・終了フレームは、構図や変化の両端を固定する必要がある場合だけ生成して入力表へ追加する。未生成ファイルを「入力する」と書かず、`optional / not generated`と明示する。

## 最終監査

- 全区間の時刻が総尺を過不足なく埋めている
- 全セリフが時間検証を通り、発話中の複雑な同時動作がない
- 発話内容、読み、Hepburn、音写、IPAが一致している
- キャラクターシートと動画プロンプトの顔、衣装、体格、NG変更が一致している
- 小道具が前状態 → 動作 → 後状態で連続し、勝手に補充、消失、破損しない
- 正史と現在の`WORLD_BIBLE.md`に整合する
- 入力対応表に実在するファイルだけが記載されている
