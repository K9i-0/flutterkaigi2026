# 最初の一本篇・確認版編集

npm ci、npm run typecheck、npm run renderで編集。必要ならRemotionへ--browser-executableを指定する。
public/input.mp4はjoined_wan_480p.mp4のhardlink。元2動画を各10秒/30秒で連結した40秒素材。動画はGit対象外。
フレーム正本はsrc/edit-manifest.json。映像レンダーは無音でout/visual.mp4へ、scripts/mux_audio.pyが元Wan2本の音声を正確な10秒境界で合成して../final_remotion_cm.mp4へ保存。
生成限界・修正内容・聴感確認事項は../script.md参照。
