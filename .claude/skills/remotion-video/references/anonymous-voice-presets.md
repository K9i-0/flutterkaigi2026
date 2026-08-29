# 匿名証言者・犯人音声プリセット

ニュースの「音声を変えています」演出では、許可済みの完成原音をFFmpegで加工してからRemotionへ配置する。Remotionの再生速度だけで声を変えず、原音の発話尺を維持する。

## 選択規則

| mode | 用途 | pitch比 | 変化量 |
|---|---|---:|---:|
| `low` | 太く低い強加工 | 0.66 | 約-7.2半音 |
| `high` | 細く高い強加工 | 1.48 | 約+6.8半音 |
| `random` | 指定なしの既定 | 50/50 | 実選択をJSONへ記録 |

- ユーザーが低め／高めを指定したら、そのmodeを使う。
- 指定がなければ確認せず`random`を使う。
- `random`は再現用seedを自動生成し、sidecar JSONへ保存する。同じ選択を再現するときは記録されたmodeを明示するか、同じ`--seed`を渡す。

## 実行

```bash
python3 .claude/skills/remotion-video/scripts/process_anonymous_voice.py \
  input.wav output.wav
```

明示指定:

```bash
python3 .claude/skills/remotion-video/scripts/process_anonymous_voice.py \
  input.wav output.wav --mode low

python3 .claude/skills/remotion-video/scripts/process_anonymous_voice.py \
  input.wav output.wav --mode high
```

ランダム選択をseed固定:

```bash
python3 .claude/skills/remotion-video/scripts/process_anonymous_voice.py \
  input.wav output.wav --mode random --seed 2026
```

出力と同じ場所へ`<output-stem>.anonymous-voice.json`を作る。例: `witness.wav`なら`witness.anonymous-voice.json`。採用時は`selected_mode`、`random_seed`、入力・出力SHA-256、実測尺、ラウドネス、true peakを制作記録へ転記する。

## 加工内容

- `low`: Rubber Bandでpitchとformantを連動して強く下げ、75–3000 Hzへ帯域制限し、180 Hzを補強して圧縮する。
- `high`: Rubber Bandでpitchとformantを連動して強く上げ、180–4300 Hzへ帯域制限し、2200 Hzを補強して圧縮する。
- 共通: 48 kHz、mono、PCM 16-bit、既定-16.5 LUFS。入力と同じ発話尺を維持する。

加工済み音声を可視話者へ後付けしても、リップシンクを修復した扱いにしない。匿名証言では口元を見せない、シルエットにする、資料映像へ切り替えるなど、映像側でも設計する。

単純なpitch・formant加工は演出であり、実在人物の匿名性を保証しない。厳密な身元保護が必要なら別人による再収録または許可済みTTSへの置換を優先する。
