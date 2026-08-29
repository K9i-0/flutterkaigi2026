---
name: remotion-video
description: Remotionで生成済み動画を編集し、正確な日本語字幕、ニューステロップ、速報帯、局ロゴ、ティッカー、ローワーサード、音声差し替え、効果音、画面合成、尺調整を再現可能なReactコードとして作成・改修・レンダリング・監査する。Wan、Wan 3.0、Seedance等の生成動画を完成編集するとき、生成モデルに正確な文字やUIを描かせず後付けしたいとき、エピソード52の字幕やニュース動画の本格的な報道グラフィックを作るときに使用する。Wanのニュース系ネタ動画では、指定がなければゆめテレ標準ニュースプリセットを自動適用する。
---

# Remotion動画編集

生成モデルが得意な人物、背景、演技、カメラ、質感と、コード編集が得意な正確な文字、時間、レイアウト、音声を分離し、最終動画を再現可能に仕上げる。

## 必ず守ること

- `AGENTS.md`、対象エピソードの`script.md`、生成記録、入力動画・音声・字幕を先に確認する。
- 正確な字幕、ニューステロップ、ロゴ、UI、数値、日付、引用、音声修正は生成モデルへ焼き込ませず、Remotionで後付けすることを第一候補にする。
- ニュースの局ロゴと放送時刻は原則Remotionで後付けし、生成素材には文字なしの右上・左上安全域を確保する。時刻は実時間ではなく編集仕様へ固定して再現可能にする。
- Wanで制作するニュース、速報、架空報道、ニュース番組風のネタ動画は、スタイル指定がなければ[references/yume-tele-news-preset.md](references/yume-tele-news-preset.md)を読み、`yume_tele_news_v1`を確認なしで適用する。ユーザーの明示指定は該当項目だけ上書きする。
- 顔、人物同一性、仮面、手指、物体数、背景、演技、カメラ、物理破綻はRemotionの文字編集で直した扱いにしない。映像素材の再生成・差し替え・クロップで解決する。
- 音声を編集できることと、任意のローカルTTSを使えることを混同しない。音声生成元は`VOICE_CAST.md`、`wan-video`、`seedance`の規則を継承し、Remotionは許可済み音源を配置・切替・音量調整する。
- タイミングは秒の浮動小数ではなく、最終的に`round(seconds * fps)`した整数フレームへ固定する。同じイベントに秒とフレームの二重正本を作らない。
- 元動画、採用音声、ロゴ、フォントを上書きしない。編集コードとレンダーを分け、確認用・中間レンダーは`remotion/out/`、採用済み完成版はエピソード直下の`final_remotion_<用途>.mp4`へ置く。
- `03_SCRIPTS/`配下のレンダー動画、`node_modules/`、バンドルキャッシュはGit管理しない。`src/`、`edit-manifest.json`、字幕データ、`package.json`、lockfileは再現に必要なため追跡する。
- Remotionと`@remotion/*`は全て同一の正確なバージョンへ固定する。新規プロジェクト前に公式情報または`npm view remotion version`で安定版を確認し、`^`や`latest`をlockfile外の正本にしない。
- Remotionには利用形態によるライセンス条件がある。個人・小規模制作を超える利用や自動化サービス化では、実行前に公式ライセンスを確認する。

## 編集へ回す判断

生成と編集の分担を決めるときは[references/editing-strategy.md](references/editing-strategy.md)を読む。

- Remotionへ回す: 字幕、ニュース帯、速報ラベル、局ロゴ、ティッカー、名前・肩書、引用、日付、正確なUI、画面内数値、音声差し替え、音量、フェード、簡潔なトランジション。
- 生成モデルへ残す: 人物の演技、リップシンクの基礎、環境、照明、カメラ、複雑な動作、物理現象。
- 両者で設計する: 発話中の口元、文字を置く余白、資料映像へ切り替える時刻、ロゴや字幕を避ける構図、編集用の無音区間。

ニュース、字幕、レイアウトと監査基準は[references/design-and-qa.md](references/design-and-qa.md)を読む。Wanニュースの標準見た目は[references/yume-tele-news-preset.md](references/yume-tele-news-preset.md)を使う。Remotion APIや更新確認には[references/official-remotion.md](references/official-remotion.md)を使う。

## `wan-video`・`seedance`との連携

1. 生成前に完成編集を設計し、生成プロンプトから正確な字幕・テロップ・UI文字を外す。
2. テロップ安全域、ロゴ位置、字幕位置へ顔・手・重要小道具を置かない。必要なら文字なしのクリーンプレートを生成する。
3. `wan-video`では音声同期方式を確定し、採用MP4と正典音声を作る。音声修正後のMP4をRemotionの入力にする。
4. Remotionでは映像の全体時間軸を維持し、字幕・グラフィック・許可済み音声・効果音を合成する。
5. `script.md`または生成記録へ、入力動画、Remotionプロジェクト、composition ID、最終出力、監査結果を記録する。標準ニュースでは`visual_preset=yume_tele_news_v1`も記録する。

30秒以下を一つのWanタスクで生成するルールは、Remotionで字幕やテロップを後付けすることを禁止しない。生成単位と完成編集工程を分けて扱う。

## 画面差し替えとの連携

- ユーザーがモニター、テレビ、スマホ、タブレット、看板等の画面差し替え、クロマキー、追跡、揺れ・緑残り修正を明示した場合は[screen-replacement](../screen-replacement/SKILL.md)を併用する。画面が映るだけでは自動適用しない。
- 正確な文字・UIはRemotionで1000×600等の正規化された画面素材として作り、OpenCVの3×3ホモグラフィで実写表示面へ焼き込む。
- グリーン素材ではHSV輪郭検出と局所多項式平滑化を使い、通常画面では光学フローと必要時の手動キーフレーム補正を使う。
- 合成済み区間をRemotionの整数フレームで差し込み、字幕、配信UI、コメント、音声を上層で維持する。追跡とCSS変形を二重に適用しない。
- 完成版とは別に、追跡プレビュー、修正前後比較、切替境界の監査画像を`remotion/out/`へ残す。

## 制作ワークフロー

### 1. 素材を監査する

1. `ffprobe`で入力動画の尺、幅、高さ、fps、音声トラック、サンプルレートを確認する。
2. 字幕・原稿は`script.md`またはユーザー承認済みファイルを正本とする。ASRや画面OCRの結果を無確認で正本にしない。
3. カット境界、発話開始・終了、文間無音、テロップ表示区間をフレームへ変換する。
4. 既存のASS/SRT字幕、ロゴ、音声、フォント、完成動画候補を列挙する。

### 2. エピソード内へプロジェクトを作る

対象エピソード直下の`remotion/`へ一つだけ作る。テンプレート生成スクリプトは既存ディレクトリを上書きしない。

```bash
python3 .claude/skills/remotion-video/scripts/init_remotion_project.py \
  03_SCRIPTS/<episode> \
  --input-video 03_SCRIPTS/<episode>/<input>.mp4 \
  --remotion-version <verified-version> \
  --width <width> --height <height> --fps <fps> \
  --duration-seconds <duration>
```

スクリプトは`remotion/public/input.mp4`を入力動画のhardlinkとして作るため、同一ファイルシステムでは容量を重複させない。hardlinkを作れない場合だけ実ファイルをコピーする。Remotionのバンドルは`public/`内のsymlinkを追従しないため、入力動画へsymlinkを使わない。依存関係は自動インストールしない。生成後にユーザーの環境で`npm install`を実行する。

### 3. 編集仕様を作る

`remotion/src/edit-manifest.json`を唯一のタイミング正本にする。形式と例は[references/manifest-format.md](references/manifest-format.md)を読む。

- `composition`: 幅、高さ、fps、総フレーム数。
- `inputVideo`: `public/`基準の入力動画。
- `replacementAudio`: 完成音声へ全面差し替えするときだけ指定する。
- `overlays`: `news-lower-third`、`ticker`、`station-bug`。
- `station-bug`: 局ロゴ、固定の放送時刻、常時表示の小さな番組表示。ニュースでは左上の時刻と右上の局ロゴを別レイヤーにする。
- `captions`: 開始・終了フレームと正確な文字列。

ASS字幕を変換する場合:

```bash
python3 .claude/skills/remotion-video/scripts/ass_to_manifest_captions.py \
  03_SCRIPTS/<episode>/subtitles_ja.ass --fps <fps> \
  --output /private/tmp/captions.json
```

変換後は原文、改行、句読点、表示区間を人間が照合してから`captions`へ採用する。

### 4. 検証・プレビュー・レンダー

```bash
python3 .claude/skills/remotion-video/scripts/validate_edit_manifest.py \
  03_SCRIPTS/<episode>/remotion/src/edit-manifest.json \
  --public-dir 03_SCRIPTS/<episode>/remotion/public

cd 03_SCRIPTS/<episode>/remotion
npm install
npm run typecheck
npm run studio
npm run render
```

Studioを開く操作が不要なら`npm run studio`を省き、`npm run render`でCLIレンダーする。外部URLはレンダー時の変動要因になるため、入力動画、音声、ロゴ、フォントは`public/`へ置くかsymlinkする。

`remotion/out/`はフレーム確認や音声mux前の中間出力に限定する。監査へ合格した完成版は、後からFinderや`rg --files`で発見しやすいよう対象エピソード直下へ`final_remotion_<用途>.mp4`の名前で出力する。用途は`news`、`subtitles`、`trailer`など短い英小文字にする。複数の画角がある場合だけ`_16x9`、`_9x16`を末尾へ付ける。

### 5. 最終監査

1. `ffprobe`で最終尺、解像度、fps、映像・音声codec、サンプルレートを確認する。
2. 冒頭、末尾、全テロップ開始・終了、字幕切替、カット境界を静止画で確認する。
3. 正確な文字、禁則、改行、はみ出し、セーフマージン、顔・手・小道具との重なりを確認する。
4. 音声差し替えでは、二重音声、欠落、クリック、同期ずれ、語句の重複を通し試聴する。
5. 入力動画と最終動画を比較し、意図しないクロップ、速度変更、色変化、フレーム欠落がないことを確認する。
6. レンダー動画を再生終端までデコードし、エラーがないことを確認する。

## 成果物

- `remotion/package.json`とlockfile
- `remotion/src/`の編集コードと`edit-manifest.json`
- `remotion/public/`の軽量ロゴ・フォント・音声と、Git管理外の入力動画hardlinkまたはコピー
- `remotion/out/<intermediate>.mp4`（確認用・中間、Git管理外）
- エピソード直下の`final_remotion_<用途>.mp4`（採用済み完成版、Git管理外）
- `script.md`または編集記録の入力・出力・監査情報

一時フレーム、プレビュー、`node_modules/`、バンドル、レンダー動画をGitへ追加しない。
