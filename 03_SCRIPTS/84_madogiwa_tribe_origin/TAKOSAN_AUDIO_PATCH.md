# 過去パート：たこさん音声差し替え

納品候補: `final_past_takosan_irodori.mp4`。過去パートv2の映像を維持し、たこさんの「仲間ナル、ギュンされる、エラべ」のみIrodoriで再生成した音声へ置換した。ユーザーによる試聴確認は未実施。

## 音声設定

- 参照: 第80話で採用されたA音声 `takosan_a_reference.wav` の完全コピー `takosan_irodori_reference_ep80.wav`。
- モデル: `Aratako/Irodori-TTS-v4.1-Small`。80話の採用設定を再現。
- seed: 43、caption: 空、CFG text: 5、uncut: true、duration scale: 1。
- 入力: `なかまなる。ぎゅんされる。えらべ。`
- 採用生成音声: `takosan_irodori_line.wav`。
- 最初のseed 42候補は「ギュン」の発音が不明瞭なため不採用。

## 編集と検証

30fpsの580〜690フレーム（19.333〜23.000秒）だけを差し替え。元音声の18〜24秒をDemucs htdemucsで分離し、環境音側を下地に使用。句間の無音を調整し、各句を585・620・666フレームに配置。速度・ピッチは変更せず、固定ゲインで音量を合わせた。境界の50msフェードは環境音にのみ適用。

- 映像はstream copy。元動画と出力の映像ストリームSHA256一致を確認。
- AACエンコード前のPCMでは、対象区間外が元のデコード音声と一致。出力音声全体はAAC再圧縮される。
- クリッピングなし、FFmpegによる出力全体のデコード検査成功。
- 単独音声および12〜23秒のASRで「ぎゅんされる」を確認。全尺ASRでは固有語の認識揺れあり。
- ASR記録: `audit_past_takosan_patch/asr.json`。
- 人による試聴、環境音分離の聴感、厳密な音素単位のリップシンクは未確認。

## 再現

リポジトリルートで実行。元動画とローカルIrodori環境が必要。

```sh
mkdir -p .local/ep84-takosan-patch
IRODORI_TTS_CHECKPOINT=Aratako/Irodori-TTS-v4.1-Small IRODORI_UNCUT=1 IRODORI_CFG_SCALE_TEXT=5 tools/irodori_speak.sh 'なかまなる。ぎゅんされる。えらべ。' 03_SCRIPTS/84_madogiwa_tribe_origin/takosan_irodori_line.wav 03_SCRIPTS/84_madogiwa_tribe_origin/takosan_irodori_reference_ep80.wav 43
ffmpeg -y -i 03_SCRIPTS/84_madogiwa_tribe_origin/wan3_past_v2_seed840102_480p.mp4 -vn -ar 48000 -ac 2 -c:a pcm_s16le .local/ep84-takosan-patch/original.wav
ffmpeg -y -i .local/ep84-takosan-patch/original.wav -ss 18 -t 6 -c:a pcm_s16le .local/ep84-takosan-patch/target.wav
.local/Irodori-TTS/.venv/bin/python -m demucs.separate -n htdemucs --two-stems vocals --shifts 0 -d cpu -o .local/ep84-takosan-patch/separated .local/ep84-takosan-patch/target.wav
.local/Irodori-TTS/.venv/bin/python 03_SCRIPTS/84_madogiwa_tribe_origin/patch_takosan_audio.py
```

詳細な区間・ゲイン・入力ハッシュは `takosan_audio_patch.json`。音声のみの修復のためRemotionでの映像再レンダリングは行っていない。
