# やめ太郎：肌色の鼻

最新の標準シート（2026-09-09採用の鼻）を参照し、rig_sheet_v2の黒点鼻を肌色の低い膨らみに変更。顔表面に描き込まれた黒点も局所的に修復し、色と法線をGLB対応のテクスチャへ焼き込んだ。額の黒い印・眼鏡・頬・口は保持。

- `yametaro.glb`: 2026-09-16に公式サイトの3Dビューアへ採用。ゲームは未変更。
- `yametaro.blend`: ローカル保存（Git対象外）。
- 再生成: 元の `rig_sheet_v2/yametaro.blend` をBlenderで開き、`tools/revise_yametaro_skin_nose.py` をrunpyで実行。補助処理は `tools/yametaro_nose_normals.py`。
- 15,299三角形・23ボーン、Idle / Talk / Walk / Wave、SpeechOpen / SpeechNarrowを保持。
- 正面・斜めの拡大レンダーで確認。構造検証結果は `validation.json`。
