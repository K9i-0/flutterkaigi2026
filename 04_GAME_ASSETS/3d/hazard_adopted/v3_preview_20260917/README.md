# 福ちゃんv3の本編採用・口パク

承認済み `characters/fukuchan/rig_v3_20260917/fukuchan.glb` を入力に、ゲーム用の待機・歩行・走行エイリアスと口パクを追加。ゲームの `assets/models/fukuchan.glb` はこの派生GLBへの相対symlink。

2026-09-17: `SpeechOpen` / `SpeechNarrow`、口の切れ目・内側を追加。ユーザー指定で歯は表示しない。音声の強弱で最大5.4mm（初版の60%）開閉する。音素別のリップシンクではない。閉口時の顔を基準に口周囲だけを変形し、元20動作は最大サンプル誤差0.0000016以内で維持。ゲーム向け3エイリアスを含め23クリップ。

再生成: リポジトリルートで `python3 04_GAME_ASSETS/3d/hazard_adopted/v3_preview_20260917/build.py`。元GLBはローカル保持が必要。`tools/build_fukuchan_v3_speech.py` と共有処理 `tools/fukuchan_head_speech.py` を使い、元モデルは上書きしない。
検証: `python3 tools/validate_fukuchan_v3_speech.py`。生成記録は `speech_build.json`、構造・局所変形・動作比較は `speech_validation.json`。

Dart MCPでmacOSの `lib/game_main.dart` を通常起動する。口パク必須チェックを省くフラグは不要。ゲーム用歩走速度・銃の握りの本採用調整は別途。2026-09-17、ユーザー確認後に本編採用manifestを更新。公式サイトのモデルは変更していない。

顔アップ: `python3 tools/setup_fukuchan_speech_preview.py` で既存ローカルStudioに確認ページを接続する。URLは `http://127.0.0.1:5173/.local/fukuchan-speech/index.html`。歯なし版の正面・斜め・全開・音声再生をChromeで確認済み。口内は手前が赤茶、奥が暗い赤茶の頂点色グラデーションへ調整。小さい開口では控えめにすぼめ、大きい開口では横へ広がる。音量連動の変化であり音素認識ではない。

ゲーム通常起動でready=true。既存口パク・モーションテスト8件と静的解析は合格。歯あり中間版の実フレーム会話プローブは合格、歯なし最終版の同プローブは背景状態のため未完了。最終版の音声同期は顔アップページで確認。

2026-09-17 口内・開口量の調整後: 顔アップの正面全開、斜め音声再生を確認。GLB検証は歯なし・赤茶の頂点色の明暗差・5.5mm以内の局所変形・元20モーション一致が合格。関連Flutterテスト8件・analyze合格。Dart MCP通常起動でready=true、実行時エラーなし。ゲームは背景状態で読み込み確認、今回の連続した音声同期の目視は顔アップページで実施。

本編採用後のMac debugでforeground=true・ready=trueを確認。会話プローブは2,710msで合格。福ちゃん／やめ太郎の実音声・実描画フレーム・口形適用、非話者の閉口、一時停止・再開を検証。

2026-09-17 肌補正: 入力正本を `characters/fukuchan/skin_even_20260917/fukuchan.glb` に更新。正面の頬色を基準に左右の黒ずみを低減。既存ゲームGLBは肌画像だけを交換し、形状・ウェイト・口パク・23動作の非画像バッファ完全一致を検証。補正前は肌補正フォルダの `game_before.glb` にローカル保持。
