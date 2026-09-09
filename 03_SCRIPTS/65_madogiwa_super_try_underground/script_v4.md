# 窓際スーパーツライ 地下労働編 v4

v3の口が動かない点以外はユーザーが満足する品質と評価。v3台本の45秒（15＋30）、台詞、演出、音響、seed、参照順、480Pを維持。変更はやめ太郎の開口差分付きシートと、母音・子音に応じた口の開閉／顎の動作指示のみ。v3のファイルは保持。

新入力：`character_yametaro_speech_v4_sheet.png`。口パク改善は生成後の連続フレームで確認する。ネイティブWan音声を使用し、音声だけを全面差し替えしない。

## 生成結果

2026-09-09、2タスクとも成功。再送なし。口形差分と開閉指示により、確認フレームでは前半・後半ともやめ太郎の口が開閉し、閉じ笑顔の固定が改善。飲酒→缶を下ろす→発話の流れも確認。ASRは主要台詞と概ね一致するが直接試聴ではなく、完全な音素同期は未認定。無言区間のASR反復は尺外に及ぶため信頼しない。

生成記録：`generation_record_v4.json`。結合素材：`joined_wan_v4_480p.mp4`。商品テロップ付き：`final_remotion_cm_v4.mp4`。Wan音声を保持。
再現：`python3 remotion/scripts/assemble_v4.py`、remotion内で`npx remotion render src/index_v4.ts SuperTryCMv4 out/visual_v4.mp4`、`python3 scripts/assemble_v4.py --mux-final`。
