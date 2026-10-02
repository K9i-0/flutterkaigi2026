# 接続編集

入力: 現代 `wan3_present_seed840101_480p.mp4` と過去 `final_past_takosan_irodori.mp4`。publicの入力はhardlink。Remotion 4.0.531、composition `MadogiwaEdit`、出力 `../final_remotion_story.mp4`。

タイミング正本は `src/edit-manifest.json`（30fps、endは排他的）。現代123〜183フレームの透ける無言カットを削除。現代504〜525フレームの無言を詰め、その位置に過去840フレームを挿入。発話の語尾はASRの区間と口を閉じた静止画で確認。映像・音声を同時に同じ位置で切り替え、速度変更、字幕、追加BGMなし。

完成1479フレーム、実測49.301秒、854×480、30fps、H.264/AAC。typecheck、終端までのデコード、開始・終了・全編集境界の静止画確認が完了。分割ASRで全10台詞の存在と順序を確認（`../audit_final/asr.json`）。境界画像: `../audit_final/boundaries.png`。独立した通し試聴と厳密なリップシンクの合格判定は未実施。

再現: `npm ci`、`npm run typecheck`、`npm run render`。入力hardlinkがない環境では上記2動画をそれぞれ `public/input.mp4` と `public/past.mp4` へ配置する。
