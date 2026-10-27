# ゆめみ採用試験 効果音正本

- `countdown_tick.wav`: 開始前の「3・2・1」。G5（784Hz）に弱い倍音を足した0.22秒の電子音。
- `countdown_go.wav`: 「スタート！」。1オクターブ上のG6＋D7の和音を0.75秒鳴らす。

どちらも録音素材を使わず、`app/tool/build_countdown_audio.py`（Python標準ライブラリのみ）で数式から合成した。アプリは `app/assets/audio/` の相対symlinkで参照する。再生成はリポジトリ直下から `python3 app/tool/build_countdown_audio.py`。
