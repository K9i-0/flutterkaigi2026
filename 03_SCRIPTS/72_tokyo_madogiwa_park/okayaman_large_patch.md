# 72話・動画内のおかやまんの台詞改変

2026-09-30。既存動画の声を参照するIrodori部分修復をSmall / Largeで比較。未採用の実験であり、正典VOICE_CASTと本編は更新しない。

## 入力と生成

- 元動画: `../00_REPLY_CLIPS/72_おかやまん_おかやまん大変驚いております.mp4`（4.7秒、854×480、30fps、141フレーム）。
- 元シーン: `wan3_scene05_v4_480p.mp4` の3.3–8.0秒。
- 動画内の同一話者を参照: 返信クリップ0.24–2.74秒をmono 48kHz PCM16で抽出。元シーンでは3.54–6.04秒。歓声の開始約2.98秒より前。
- 全文「おかやまん！大変驚いていません！」「おかやまん！ギュンギュンしています！」を生成し、後半だけ使用。
- seed42、captionなし、自然尺、duration_scale=1、text CFG=3。Large否定形の再試行のみseed43。`tools/irodori_speak.sh`の既定の無音トリムを使用。
- Small: v4.1-Small、Large: v4-Large。MPS FP32。モデルrevision、参照・出力SHAは`okayaman_patch_manifest.json`。

## 編集

元の「おかやまん！」を維持し、1.25–2.90秒だけ差し替え。入力音声の後ろへ無音を追加し、語尾を切らず同尺へ合わせた。時間伸縮・ピッチ変更・クロスフェードなし。元台詞のRMSへ一定ゲインで合わせた。区間外PCMはサンプル単位で一致。歓声と後続タイムラインを維持する。

`okayaman_patch_segments.json`が切出位置の正本。個別動画の映像はstream copy。口の動きの再生成はしていない。

## 自動認識結果と限界

|候補|Whisper smallの認識（改変部分）|
|---|---|
|Small seed42 否定形|大変驚いていません|
|Large seed42 否定形|大変驚いといません|
|Large seed43 否定形|大変驚いていません|
|Large seed42 ギュンギュン|ギュンギュンしています|

ASRは発音の疑いを示す補助情報で、声色、自然さ、接続音、口パクの合格判定ではない。通しの聴覚監査は未実施。Largeが一律に改善するとは判断できず、否定形はLargeでもテイク差が出た。ユーザーの比較試聴で採否を決める。

## 出力

候補はGit管理外の `.local/ep72_okayaman_large_patch/`（リポジトリルート基準）。

- `large_not_seed43.mp4`: 否定形の再試行。単独試聴用。
- `large_gyun.mp4`: ギュンギュン。単独試聴用。
- `small_not.mp4` / `large_not.mp4`: 同じseed42の対照。
- `remotion/out/okayaman_large_patch_comparison.mp4`: 元動画→Small否定形→Large否定形seed42→Large否定形seed43→Largeギュンギュン、各4.7秒、計23.5秒。字幕は入力台詞でありASRの転記ではない。

## 再現

リポジトリルートで `okayaman_patch_experiment.py prepare` をLarge環境のPythonで実行。生成例:

```bash
HF_HUB_OFFLINE=1 IRODORI_TTS_CHECKPOINT=Aratako/Irodori-TTS-v4-Large \
tools/irodori_speak.sh 'おかやまん！大変驚いていません！' \
  .local/ep72_okayaman_large_patch/large_not_seed43.wav \
  .local/ep72_okayaman_large_patch/reference.wav 43
```

他の候補はmanifestの文面・モデル・seed・ファイル名に対応させて生成する。`okayaman_patch_experiment.py package` で全候補を配置、末尾に候補名を指定すると対象だけを処理。PCM helperは既存出力の上書きを拒否するため、再実行時は以前の候補を別ディレクトリへ保管する。`remotion/`で `npm run typecheck`、`node render-okayaman-patch.mjs`。

検証: 個別動画の全141フレーム一致、全編デコード、等尺・区間外PCM一致、Remotion TypeScript検査。比較動画の4/5表示フレームを目視し、文字切れ・顔への重なりがないことを確認。比較動画も全編デコード成功（映像23.5秒、AACを含むコンテナ23.552秒）。生成・候補WAV/MP4と監査データはローカル保持。

## SNS投稿用・3本比較

ユーザー指定で、元動画→Large否定形seed43→Largeギュンギュンseed42の3本に絞った。各141フレーム、計423フレーム（14.1秒）。下部に「元動画のセリフ」「Irodori v4 Largeでセリフを改変①／②」と台詞を表示。SNS向けにseed等の実験情報を省略した。

- 出力: `final_remotion_okayaman_large_sns.mp4`
- 編集: `remotion/src/okayaman-patch-sns.tsx`
- 再現: `remotion/`で`node render-okayaman-patch-sns.mjs`

## ユーザー評価・運用採用

2026-09-30、SNS比較を試聴したユーザーが「smallよりかなり良く感じた」と評価し、今後のセリフ修正はLargeへ更新するよう指示。`wan-video`の部分修復手順に反映した。モデル選択の運用採用であり、本編差し替えやキャラクターの新規発話用配役変更とは別。
