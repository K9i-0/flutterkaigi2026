# 01_walk クレイ版

Wan 3.0 / 480P / 6秒 / seed 620102。福ちゃんのクレイシートから作った固定・側面の開始フレームを使用。`wan3_config_01_walk_clay.json` と `prompt_01_walk_clay.txt` が実送信入力。

- task: `364a188a-4a1d-4468-85bb-86384b1c938d`、SUCCEEDED。
- 出力: `wan3_01_walk_clay_seed620102_480p.mp4`（ローカル、Git対象外）。実寸842×474 / 30fps / 映像6秒。
- 生成見積り: US$0.21。請求実額は照会していない。開始画像はCodex内蔵imagegenで作成。
- SHA256: `551ec6598b1de184731c83de497ab4a88f27d6c5dfa928da48ae2c7314aa79c3`。

## 観測と再構成

MediaPipe Pose Landmarker Fullで180フレーム中178フレームを検出。壁の3マーカーは全180フレームで検出し、初期位置からの最大変位は0.192px。前回のカメラ追従は解消した。開始・停止を除いた45〜134フレームを使い、左足の前方ピーク81・121フレームから周期40フレーム（1.333秒）を取得。

観測した脚長は画像上109.48px、骨盤の移動は125.71px/秒。絶対距離の校正物はないため、この比率を各モデルの実脚長へ適用する。設定身長や体重から動画の距離を決めない。肩幅・脚長・腕長は各リグの値を保持する。

手首、足首、足の角度、骨盤上下の側面軌道を3次の周期関数へ近似。支持脚は周期の60%を接地区間として線形移動へ補正し、脚長を伸縮させない2ボーンIKと実メッシュの靴底を使う。左右の遮蔽を減らすため半周期ずらして平均化する。奥行き・横揺れ・骨盤回転・手の向きは補完であり、動画から得た3Dモーションキャプチャとは称さない。

比較アプリの「Wan見本 + IK」に両体格の `Wan_Walk` を追加。「1.25 m/s で歩行比較」では全手法が同じ移動速度になり、各クリップの基準速度に応じて再生を調整する。位相同期とは別の比較。8秒で比較区間をリセットする。

今回は定常歩行のみ。歩き始め・停止・走行・他11動作へ、この1本の結果をそのまま転用しない。

## 再生成

1. `.local/wan-motion-venv` に Python 3.12 / mediapipe==0.10.32 / opencv-python / scipy を用意。
2. 公式 `pose_landmarker_full/float16/1/pose_landmarker_full.task` を `.local/wan_motion/` に配置。
3. `tools/extract_wan_walk.py` → `tools/fit_wan_walk.py` を実行。観測JSON・骨格付きコンタクトシートは `.local/wan_motion/`。
4. Blenderで `tools/humanoid_video_walk.py` を実行。追跡する周期係数は共通ライブラリ `source/wan_walk_clay.json`。通常の `build_humanoid_motion.py` からも再生成できる。
5. `tools/audit_humanoid_motion.py` と比較アプリの検証を実行。

[MediaPipe公式資料](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker/python) / [Wan公式料金](https://www.qwencloud.com/models/wan3.0-video)

## 検証結果

全141クリップのGLB再インポート監査に合格。新歩行は各161時刻で検査し、床最低値はそば屋 -0.061 mm・福ちゃん +0.536 mm、最も低い足が床から3.1 mm以上浮く時刻はなし。支持中盤の足首滑りRMSはそば屋2.69 mm/秒・福ちゃん2.60 mm/秒。踵着地とつま先離地を含む足裏全体の誤差とは区別する。視線は水平を維持。

比較アプリはDart MCP / Marionetteで両体格・正面側面背面・5方式表示を確認。同速度モードは0.1秒で全員0.125 mの移動を確認。ゲーム本編も `Walk` → `Wan_Walk` の割り当てとGPU描画を確認。福ちゃんの通常歩行へ反映し、ジョギング・戦闘の割り当ては既存仕様を継続。
