# そば屋ハザード 音声正本

[台本・声の生成条件](script.md)、[発話マニフェスト](voice-manifest.json)、[環境音マニフェスト](soundscape-manifest.json)。Flutterは `assets/audio/voice` と `soundscape` から相対symlinkで参照する。未加工・候補・ASRのモデルキャッシュは `.local/hazard_voice/` に置く。

再生成はリポジトリ直下から実行する。台詞を変更したら先に `21_SOBAYA_HAZARD_LAB/tool/export_hazard_voice.dart` をDartで実行して `voice-lines.json` を更新する。

```sh
python3 tools/build_hazard_voice.py
.local/Irodori-TTS/.venv/bin/python tools/build_hazard_soundscape.py
.local/Irodori-TTS/.venv/bin/python tools/build_hazard_search_score.py
.local/Irodori-TTS/.venv/bin/python tools/build_hazard_stealth_foley.py
python3 tools/audit_hazard_audio.py
.local/Irodori-TTS/.venv/bin/python tools/audit_hazard_voice_transcript.py
```

発話生成には正典Irodori環境とFFmpeg、環境音生成にはNumPyを使用。文字起こしは公開 `openai/whisper-small` をローカルCPUで実行し、ゲーム音声を外部送信しない。モデルカード: https://huggingface.co/openai/whisper-small 。ASRは発話内容の粗い照合であり、自然さや本人らしさの聴感承認ではない。台詞変更時は `script.md` の採用記録も更新する。

村は風と木の軋み、農場は風・虫・金属音、山道は低い風と水音。各16秒ループ。探索曲「閉店後」と追跡曲「ラストオーダー・追い込み」は48秒、D Phrygianの共通音域で重なるオリジナル曲。追跡時は160 BPMの弦・低音・打楽器を前へ出し、見失うと短い保持とフェードで打楽器を抜く。捜索時は新曲「戸口の向こう」の持続弦・空気音を小さく残し、足音と正典の声を聞きやすくする。疑い・帰還でも持続音だけを薄く使用する。音楽の状態はAIの公開フィードバックと共通で、未発見の敵との距離だけでは変化しない。発見アクセントは追跡と捜索を含む一回の遭遇につき一度。曲は無音時も連続再生し、警戒の切替で冒頭へ戻さない。

捜索曲の生成条件は `search-score-manifest.json`（seed 90608）、そば屋の足音・ビール投擲・着地の条件は `stealth-foley-manifest.json`（seed 90609）に記録する。足音は靴底・擦れ・ジョッキの薄い共鳴、投擲は衣擦れ、着地はガラスと液体を数式で合成した非言語音。発話や別の人物の呼吸音は生成していない。環境音とたこさん反応音はseed 90449、既存探索・追跡曲はseed 60649。いずれも既存ゲームの音素材を使っていない。
