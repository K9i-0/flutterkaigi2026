# 最初の一本篇・確認版編集

npm ci、npm run typecheck、npm run renderで編集。必要ならRemotionへ--browser-executableを指定する。
public/input.mp4はjoined_wan_480p.mp4のhardlink。元2動画を各10秒/30秒で連結した40秒素材。動画はGit対象外。
フレーム正本はsrc/edit-manifest.json。映像レンダーは無音でout/visual.mp4へ、scripts/mux_audio.pyが元Wan2本の音声を正確な10秒境界で合成して../final_remotion_cm.mp4へ保存。
生成限界・修正内容・聴感確認事項は../script.md参照。

## v2

npm run assemble:v2でv2の元2本を連結しpublic/input_v2.mp4へhardlink。npm run render:v2でv2専用compositionと音声muxを実行する。必要なら同じCLIへ--browser-executableを指定。v1の入力・コード・出力は維持。生成の不合格（前半の人物取り違え、後半の飲酒省略）は修正済みと扱わず、比較確認用として残している。
