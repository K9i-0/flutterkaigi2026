# パロディの声質変換と部分発音改変

元音源の演技・リズム・節を認知の手掛かりとして残したい場合に使う。通常の新規ナレーションはTTSへ回す。音声変換でも音程・子音・長さが完全一致するとは限らない。

## 1. A（演技）とB（声質）を分ける

- source A：元音源の使う発声区間。前の台詞や投稿者の末尾画面を含む「動画の最後N秒」で機械的に決めず、発声の開始・終了と余韻を確認する。
- target B：`02_CHARACTERS/VOICE_CAST.md`の正典参照WAV。参照の台詞内容をAへ移すものではない。
- 原本は保持し、区間・ハッシュ・sample rateを記録する。BGMや効果音が混ざる場合は必要に応じてDemucs等で声を分離し、変換する声と元の背景音を別管理する。分離結果の声漏れ・欠落も確認する。短い単独コールで分離不要なら直接使える。

## 2. Seed-VCで声質を変える

このリポジトリの既存環境は `.local/seed-vc/`。新規インストール前に環境・`inference.py --help`・モデル設定を確認する。パッケージやチェックポイントはGit管理しない。2026-10-03の短い歌唱風コールで使った開始設定：

```sh
# リポジトリルートで実行。各入力は今回の採用元へ変更する。
repo_root="$PWD"
vc_source="$repo_root/.local/<task>/source_call.wav"
vc_target="$repo_root/02_CHARACTERS/Sobaya_voice.wav"
vc_output="$repo_root/.local/<task>/seedvc-output"
cd "$repo_root/.local/seed-vc"
PYTORCH_ENABLE_MPS_FALLBACK=1 .venv/bin/python inference.py \
  --source "$vc_source" --target "$vc_target" --output "$vc_output" \
  --diffusion-steps 50 --length-adjust 1.0 --inference-cfg-rate 0.7 \
  --f0-condition True --auto-f0-adjust False --semi-tone-shift 0 --fp16 False
```

- 歌唱風コールではsourceの音程を条件にし、targetへ自動移調しない設定から比較する。通常会話や別モデルへ一律に固定しない。
- `length-adjust 1.0`でもサンプル数は変わり得る。実測して挿入位置を合わせ、無条件に全体をタイムストレッチしない。
- そば屋固有後処理は`VOICE_CAST.md`と`tools/sobaya_monsterize.sh`を参照。変換のみ／後処理ありの比較は必要な場合に作り、二重適用を避ける。
- Apple Siliconで実際に必要だった変更は `03_SCRIPTS/chuagostini_20261003/seedvc-mps-float32.patch`：F0のfloat32化、BigVGANだけCPU、CPU threads=4。既存コードへ適用済みか確認し、別バージョンへ盲目的に当てない。チェックポイントのshape不一致警告は隠さず記録する。
- 音量を揃えて比較する。既にクリップした波形を後から小さくしても歪みは直らないため、変換直後の波形も確認する。

## 3. 名前の一部だけ変える

例：「ディア…」を「チュア…」へ。声質変換だけでは発音内容は変わらない。

1. 同じ対象話者のIrodoriで必要な音節を含む短句を作る。短音節単独が不安定なら自然な短句から必要区間を抽出する。モデル・seed等は正典と共通Irodori手順に従う。
2. 波形・試聴で接続点を決める。forced alignmentは補助とし、後続子音の閉鎖・破裂を切らない。
3. 必要ならPraat/ParselmouthのPSOLAで置換部分だけを元のF0曲線・区間長へ合わせる。有声区間のF0を確認し、未検出値をそのまま補間しない。
4. 短いクロスフェードで接続し、置換区間外は採用音源のPCMをコピーする。境界以降のサンプル一致を検証する。後処理が尺を変える場合は、加工版の接続点を別に実測する。
5. 最終ミックス後に境界のクリック、子音の欠け、二重発声、音量・声質の段差を確認する。

今回の再現例は `03_SCRIPTS/chuagostini_20261003/patch_chua.py` と `chua-patch.json`。未加工変換版の接続0.390秒、加工版0.420秒、クロスフェード12msはこのテイクの実測値で、別素材へ流用しない。採用③は `ending_chuagostini_v3.wav`。既存の採用コールを使う依頼なら再生成しない。

## 4. 採用・映像への反映

- 音声のみで候補を比較し、ファイル名に方式と版を含める。ASR一致を声質・節・自然さの合格としない。実聴不能なら記録し、ユーザーの採用判断と機械検証を分ける。
- 背景音を保持する場合は旧ボーカルを除いた背景へ配置する。元ミックスに新ボーカルを足して二重再生にしない。
- 映像変更がなければ `-c:v copy` で音声を差し替え、映像パケットのハッシュ、尺、同期、全編デコードを確認する。部分修復の区間外PCM一致はAAC圧縮前に検証する。
- 生成設定、正典参照、変換・加工の順序、置換区間、ゲイン、採用ファイルを制作記録へ残す。候補や中間物を正典扱いしない。
- 単体動画はローカルパスで渡す。複数候補をHTMLで並べるときだけTailscale共有を使う。
