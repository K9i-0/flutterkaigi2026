---
name: seedance
description: 窓際族物語のストーリー（あらすじ）からSeedance用の台本・動画生成プロンプト・Codex参考画像を作成するワークフロー。ユーザーからストーリーを渡されたとき、台本やSeedanceプロンプトの作成・修正を頼まれたとき、クリップの参考画像（キーフレーム）生成を頼まれたときに必ず使用する。
---

# Seedance 動画制作ワークフロー

ユーザーからストーリー（あらすじ）を渡されたら、以下の4ステップを一連の流れとして実行する。

1. このラン専用の出力ディレクトリを作成する
2. 台本＋Seedanceプロンプト（英語）の作成（各クリップに開始状態と終了状態を明記する）
3. Codexによる各クリップのキーフレーム生成（**開始フレーム＋終了フレームの2枚**を作る）
4. Seedanceへの入力対応表（どの画像を開始/終了/参照として渡すか）を`script.md`に明記する

### 精度の要（この方式にする理由）

動画生成は**CapCutに統合されたSeedance 2.0**を使う。CapCutは**開始フレームだけでなく「開始＋終了フレーム（Frame A / Frame B）」入力に対応**しており、両端を固定して間を補間させることで、単一フレーム/text-to-videoで起きる**キャラのブレ（identity drift）・ちらつき・構図ズレを減らせる**。さらに**参照画像を多数**渡してキャラの同一性を固定できる。本スキルはこの両方を最大限使う設計にする。中間キーフレーム入力は存在しないため、**細かい動きの制御はクリップを短く割る**ことで代替する。

## 前提となる参照ファイル

- 世界観: `01_WORLD/WORLD_BIBLE.md`
- キャラクター設定: `02_CHARACTERS/*.md`（各キャラのNG変更＝デザイン上変えてはいけない要素に注意）
- 過去の制作物: `03_SCRIPTS/`

## 0. 出力ディレクトリ（毎回、新しい同一ディレクトリにまとめる）

**プロンプト（台本ファイル）と参考画像は、毎回そのラン専用の新しい1つのディレクトリにまとめて出力する。** 従来のように台本を`03_SCRIPTS/`直下、画像を共有の`ref_images/`に分散させない。

- ディレクトリ: `03_SCRIPTS/<NN>_<slug>/`
  - `<NN>` は既存の連番の次の番号（`03_SCRIPTS/`直下・サブディレクトリの最大番号 + 1、ゼロ埋め2桁）。
  - `<slug>` は内容が分かる英語の短い識別子（小文字・アンダースコア区切り。例: `yametaro_43degrees`）。
- そのディレクトリの中に、台本兼プロンプトファイル `script.md` と、全クリップの参考画像 `*.png` を **すべて同じ階層に** 置く。画像用のサブディレクトリは作らない。
- 台本内から画像を参照するときは、同じディレクトリ内の相対パス（例: `clip1_01_ref.png`）で書く。
- 既存の`03_SCRIPTS/`直下の古い成果物は移動・改変しない。この新ルールは新規ランから適用する。

## 1. 台本作成（deliverableはすべて英語）

`WORLD_BIBLE.md`のStory Formula（変なことを始める→巻き込まれる→少し騒ぎになる→最後は笑顔）と各キャラのNG変更を守りつつ、尺に応じてクリップ分割した台本＋Seedanceプロンプトを `03_SCRIPTS/<NN>_<slug>/script.md` に作成する。

`WORLD_BIBLE.md`の禁止事項（ブラック企業描写、いじめ、パワハラ、鬱展開、グロ描写）を厳守する。

### クリップ分割とキーフレーム設計（重要）

各クリップは**開始状態（first frame）と終了状態（last frame）を明確に区別して書く**。台本の各クリップに、次の2つを必ず記述する:

- **First frame**: そのクリップ冒頭の静止画で写っている内容（構図・キャラの位置・表情）。
- **Last frame**: そのクリップ終端の静止画。ここまでにどう動いた結果になるか。
- **Prop states**: そのクリップで状態が変わる小道具（グラス・瓶・食器・箱など）ごとに、First frame時点とLast frame時点の状態（中身の量、開栓/未開栓、手に持つ/置いてある、蓋の有無 等）を1行ずつ明記する。

さらに**つなぎ目を消すため、クリップNの Last frame と クリップN+1の First frame は同一の絵にする**（後述のとおり同じ画像ファイルを共有する）。小道具の状態も同様に引き継ぐ（クリップNのLast frameの状態 ＝ クリップN+1のFirst frameの状態。クリップをまたいで勝手に満杯に戻る/空になる等を起こさない）。

### 物理整合性ルール（小道具の状態遷移・重要）

状態の指定がないと、生成モデルは典型絵に寄る（例:「beer glass」→満杯のグラス、「holding a beer bottle」→ラッパ飲み）。その結果「満杯のグラスにさらに注ぐ」「ラッパ飲みした瓶からグラスに注ぐ」のような非常識な動画になる。これを防ぐため:

- **動作は必ず「前状態→動作→後状態」の形で書く。** 裸の動作だけ（"pours beer into a glass"）を書かない。両端の状態を英語で明示する: "lifts the bottle and pours beer into the EMPTY glass; by the end the glass is full with a foam head and the bottle is visibly emptier"。
- **デフォルトで典型絵になりやすい状態は、望む状態を大文字で強調して指定する**: "an EMPTY glass", "a FULL unopened bottle", "holds the bottle upright by the neck, NOT drinking from it"。
- **起きてほしくない動作は否定形でプロンプトに明記する**: "no one drinks directly from the bottle", "does not pour into an already-full glass"。開始/終了フレームの画像生成プロンプトとSeedanceのMotion promptの両方に入れる。
- **論理チェック**: 台本を書き終えたら各クリップのProp statesを通しで読み、状態遷移が物理的・社会常識的に成立しているか確認する（満杯のグラスに注がない、口をつけた容器から他人のグラスに注がない、空の容器から注がない等）。

Seedanceの1クリップは4〜15秒。**動きが複雑・カメラワークが多いクリップは短く割る**（中間キーフレーム入力が無いため、割ること自体が中間制御になる）。1本のプロンプトに詰め込みすぎない。

### 言語ルール（重要）

**`script.md` は全文を英語で書く。** Seedanceに渡すプロンプト（コードブロック）だけでなく、見出し・尺やアスペクト比の説明・「画面内容」「カメラ」「音」「生成メモ」などの人間向け解説も含めて、すべて英語で記述する。

例外として英語以外を使ってよいのは次のみ:

- **キャラクターのセリフ（発話内容）**: 実際に日本語で発話される台詞は日本語のまま `"..."` で引用して埋め込む（例: `shouting "島流し一択やろ！"`）。ナレーションや画面内の指定文字（温度計の「43℃」など）も同様に、実際に表示・発話される言語のまま引用する。
- **発音・読みを指定したい場合など、非英語でしか正確に表現できない理由があるとき**: その語のみ元言語で書き、必要なら英語で補足する。

理由: 日本語の説明文はSeedanceでの再現精度が落ちること、および成果物を言語横断で扱いやすくするため。

## 2. Codexによるキーフレーム生成（開始＋終了の2枚）

Seedance用プロンプトを作成したら、`codex` CLIの画像生成ツールで各クリップの**開始フレームと終了フレームの2枚**を生成し、**ステップ0で作成したラン専用ディレクトリに保存する**。これがSeedanceの First-Last-Frame 入力にそのまま渡る本番アセットになる。

### 枚数とファイル名

- **1クリップにつき開始フレーム1枚＋終了フレーム1枚の計2枚**を生成する（従来の「loose3枚」は廃止）。
- ファイル名は役割が分かる形にする: `clipN_start.png` / `clipN_end.png`（Nはクリップ番号）。
- 保存先は必ずラン専用ディレクトリ `03_SCRIPTS/<NN>_<slug>/` 内。台本ファイルと同じ階層に置く。

### 生成順序（整合性を壊さないため必須）

キーフレーム同士が食い違うとSeedanceの補間がモーフィング崩壊を起こすため、**必ず前の絵を種にして次の絵を作る**（ゼロから独立生成しない）。

1. **クリップ1の開始フレーム**を、登場キャラ全員の参照画像を`-i`で渡して生成する。
2. **クリップ1の終了フレーム**は、たった今作った**クリップ1の開始フレームを`-i`に加えて**「同じ絵のまま、状態だけ終了状態に変える」形で img2img 生成する（キャラ参照画像も引き続き渡す）。
3. **クリップ2の開始フレーム = クリップ1の終了フレーム**。原則ここは**新規生成せず同じ画像ファイルをコピー/参照して共有する**（つなぎ目消し）。カメラや場所が切り替わって共有できない場合のみ、クリップ1終了フレームを種に新規生成する。
4. 以降のクリップも 開始→終了 の順で、前フレームを種にチェーンしていく。

### キャラクター参照画像（同一性の固定）

- **そのクリップに登場するキャラクター全員の参照画像を`-i`で渡す**。各キャラの画像ファイルは`02_CHARACTERS/<キャラ名>.md`内の「画像ファイル：」に記載（`02_CHARACTERS/`配下に実体あり）。
- プロンプト文中で「Image N: <キャラ名> reference — keep face/design and NG-change elements consistent」のように役割を明記し、NG変更対象（そば屋の仮面/たこさんの触手/とーくんのウクレレ等）を維持させる。

### コマンド例（クリップ1・そば屋/とーくん/よーたん/福ちゃん/無職やめたろう登場）

開始フレーム:
```
codex exec -s workspace-write --enable image_generation \
  -i 02_CHARACTERS/Sobaya.jpg -i 02_CHARACTERS/Tokun.jpg -i 02_CHARACTERS/Yotan.jpg -i 02_CHARACTERS/Fukuchan.jpg -i 02_CHARACTERS/Yametaro.jpg \
  "Use your image generation tool to create the FIRST-FRAME still of a video shot. Input images Image 1..5 are character references (Sobaya: keep face/mask/build; Tokun: keep aloha/hat/ukulele; Yotan: keep blond/guitar/rock outfit; Fukuchan: keep stylish outfit; Yametaro: keep design) — keep every face/design and NG-change element consistent. Prompt: <English scene description of the clip's START state, excluding dialogue and camera-work notation>. Comedic slice-of-life anime-illustration style, single still frame, no text overlay. Save as 03_SCRIPTS/<NN>_<slug>/clip1_start.png."
```

終了フレーム（開始フレームを種にする）:
```
codex exec -s workspace-write --enable image_generation \
  -i 03_SCRIPTS/<NN>_<slug>/clip1_start.png \
  -i 02_CHARACTERS/Sobaya.jpg -i 02_CHARACTERS/Tokun.jpg -i 02_CHARACTERS/Yotan.jpg -i 02_CHARACTERS/Fukuchan.jpg -i 02_CHARACTERS/Yametaro.jpg \
  "Use your image generation tool to create the LAST-FRAME still of the same shot. Image 1 is this clip's start frame — keep the same characters, art style, framing, lighting and location, change ONLY what the motion changes. Images 2..6 are character references — keep every face/design and NG-change element consistent. Prompt: <English scene description of the clip's END state>. Single still frame, no text overlay. Save as 03_SCRIPTS/<NN>_<slug>/clip1_end.png."
```

### ポイント

- `--enable image_generation` と、プロンプト内での明示的な "Use your image generation tool" を必ず両方指定する（省くとPythonの簡易描画にフォールバックすることがある）。
- 終了フレーム生成では**開始フレームを必ず`-i`の先頭に入れ**、「framing/lighting/locationは維持、動きが変える部分だけ変更」と指示する。これが崩壊防止の肝。
- クリップ間で同じ絵を共有できるときは**再生成せずファイルを使い回す**（生成ゆらぎを持ち込まない）。
- 画像生成プロンプトには台本のProp states（グラスの中身の量、瓶の持ち方等）をそのまま含める。**生成後は各画像をReadで開き、小道具の状態が台本のProp statesと一致しているか目視確認する**（例: 開始フレームのグラスが空であるべきなのに満杯で描かれていないか、瓶に口をつけていないか）。ズレていたら再生成する。キーフレームが間違っているとSeedanceは間違った状態間を忠実に補間してしまう。
- 保存先は必ず `03_SCRIPTS/<NN>_<slug>/` 配下。
- ユーザーからストーリーを渡された際は、台本・Seedanceプロンプト作成に続けて、このルール（クリップごとに開始＋終了の2枚、前フレームを種にチェーン、キャラ参照を必ず添付、つなぎ目は共有）に沿ってキーフレームも生成する。

## 3. CapCut（Seedance 2.0）への入力対応表

動画生成は**CapCutに統合されたSeedance 2.0**で行う。CapCutは**開始フレーム（Frame A）と終了フレーム（Frame B）のデュアル参照**に対応し、参照画像も多数渡せる。`script.md`の各クリップに、**CapCutの各スロットへ何を渡すか**の対応表を必ず書く（ユーザーがそのまま設定できるようにするため）。

各クリップの記載例（英語で書く）:

```
### CapCut inputs (Clip 1)
- Start frame (Frame A): clip1_start.png
- End frame (Frame B):   clip1_end.png
- Reference images (identity lock): Sobaya.jpg, Tokun.jpg, Yotan.jpg, Fukuchan.jpg, Yametaro.jpg
- Motion prompt: <the clip's Seedance prompt — describe the motion BETWEEN the two frames as explicit state transitions (e.g. "pours beer into the EMPTY glass until it is full; no one drinks from the bottle"); dialogue kept in original language>
- Duration: 5s / Aspect: 16:9
```

- **開始/終了フレームは必ず両方セット**する。片方だけだと単一フレームからの外挿になりブレやすい。
- 参照画像は**必要な枚数だけ渡してよい**（CapCut/Seedance 2.0は多数の参照画像を受け付ける）。登場キャラ全員分＋必要なら小道具・環境の参照を足して同一性を固める。プロンプト側で「これらは identity/design reference であって構図ではない」と役割を明記する。
- クリップをまたぐつなぎ目は、**前クリップの Frame B と次クリップの Frame A を同一画像**にすることで消す（ステップ2のチェーンで担保）。
- **（上級）動きの誘導を強めたいクリップ**では、`04_GAME_ASSETS/voxel`の該当キャラGLBをThree.jsで動かして書き出した短い動画（webm/mp4、合計15秒以内）を**モーション参照として追加で渡す**（Seedance 2.0は動画参照に対応）。構図とキャラはキーフレームで固定したまま、動きだけ正確になぞらせられる。
