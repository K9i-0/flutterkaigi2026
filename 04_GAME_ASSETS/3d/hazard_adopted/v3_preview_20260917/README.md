# 福ちゃんv3のローカルゲーム試用・口パク

承認済み `characters/fukuchan/rig_v3_20260917/fukuchan.glb` を入力に、ゲーム用の待機・歩行・走行エイリアスと口パクを追加。ゲームの `assets/models/fukuchan.glb` はこの派生GLBへの相対symlink。

2026-09-17: `SpeechOpen` / `SpeechNarrow`、口の切れ目・内側を追加。ユーザー指定で歯は表示しない。音声の強弱で最大約9mm開閉する。音素別のリップシンクではない。閉口時の顔を基準に口周囲だけを変形し、元20動作は最大サンプル誤差0.0000016以内で維持。ゲーム向け3エイリアスを含め23クリップ。

再生成: リポジトリルートで `python3 04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917/build.py`。元GLBはローカル保持が必要。`tools/build_fukuchan_v3_speech.py` と共有処理 `tools/fukuchan_head_speech.py` を使い、元モデルは上書きしない。
検証: `python3 tools/validate_fukuchan_v3_speech.py`。生成記録は `speech_build.json`、構造・局所変形・動作比較は `speech_validation.json`。

Dart MCPでmacOSの `lib/game_main.dart` を通常起動する。口パク必須チェックを省くフラグは不要。ゲーム用歩走速度・銃の握りの本採用調整は別途。採用manifestと公式サイトのモデルは変更していない。

顔アップ: `python3 tools/setup_fukuchan_speech_preview.py` で既存ローカルStudioに確認ページを接続する。URLは `http://127.0.0.1:5173/.local/fukuchan-speech/index.html`。歯なし版の正面・斜め・全開・音声再生をChromeで確認済み。口内の暗さはユーザーから追加の調整相談あり。

ゲーム通常起動でready=true。既存口パク・モーションテスト8件と静的解析は合格。歯あり中間版の実フレーム会話プローブは合格、歯なし最終版の同プローブは背景状態のため未完了。最終版の音声同期は顔アップページで確認。
