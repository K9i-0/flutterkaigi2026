# そば屋ハザード 音声正本

[台本・声の生成条件](script.md)、[発話マニフェスト](voice-manifest.json)、[環境音マニフェスト](soundscape-manifest.json)。Flutterは `assets/audio/voice` と `soundscape` から相対symlinkで参照する。未加工・候補・ASRのモデルキャッシュは `.local/hazard_voice/` に置く。

再生成はリポジトリ直下から実行する。台詞を変更したら先に `21_SOBAYA_HAZARD_LAB/tool/export_hazard_voice.dart` をDartで実行して `voice-lines.json` を更新する。

```sh
python3 tools/build_hazard_voice.py
.local/Irodori-TTS/.venv/bin/python tools/build_hazard_soundscape.py
python3 tools/audit_hazard_audio.py
.local/Irodori-TTS/.venv/bin/python tools/audit_hazard_voice_transcript.py
```

発話生成には正典Irodori環境とFFmpeg、環境音生成にはNumPyを使用。文字起こしは公開 `openai/whisper-small` をローカルCPUで実行し、ゲーム音声を外部送信しない。モデルカード: https://huggingface.co/openai/whisper-small 。ASRは発話内容の粗い照合であり、自然さや本人らしさの聴感承認ではない。台詞変更時は `script.md` の採用記録も更新する。

村は風と木の軋み、農場は風・虫・金属音、山道は低い風と水音。各16秒ループ。緊張時はオリジナルの90 BPMの低音フレーズを追加し、会話中に背景音を下げる。ループ波形と反応音は数式・乱数seed 90449から生成し、既存ゲームの音素材を使っていない。
