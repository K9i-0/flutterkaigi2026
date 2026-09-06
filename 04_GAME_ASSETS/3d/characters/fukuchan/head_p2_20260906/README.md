# 福ちゃんの独立頭部

正典 `02_CHARACTERS/Fukuchan.jpg` を参照。built-in Imagegenで大きな頭部の正面・左側面・背面を個別に制作した。`inputs/`が採用入力、`imagegen_prompts.json`が全プロンプト。側面・背面は写真を直接計測した形状ではなく、正面からの生成による補完。

Tripo v3 `POST /generation/multiview-to-model`、`P2-20260801`、quad、6,000 face上限、detailed PBR、3方向入力。タスク `5b707218-e8be-48ef-a9c4-e9c95d962d17` は成功、120クレジット使用。2026-09-06の開始190→残70。追加購入なし。髪・頭・体の3回生成ではなく、髪を含む頭部1回と既存の体を組み合わせている。

出力FBX SHA-256: `b96c58a488638f204011f8b4f793622380aa6d74a11628608553554170936538`。生FBX・署名URL・アップロードレスポンスはローカルのみ。再取得時はこのディレクトリの `task.json` に `{"task_id":"5b707218-e8be-48ef-a9c4-e9c95d962d17"}` を設定し、`python3 tools/tripo_multiview.py download .../config.json` を実行する。`submit`は再生成を伴うため再取得に使わない。

完成GLBは `../rig_v1/fukuchan.glb`。生成源と組立処理を分け、元の体の骨格・14モーション・銃ソケットを維持している。旧版はGit履歴とローカル比較用に保持。

分割生成は顔に画素と形状予算を集中できるため採用した制作上の判断であり、品質の保証ではない。首の寸法・マテリアル境界・スキニング・口のトポロジーはBlenderで別途修正した。

仕様確認: [Tripo P Series multiview](https://developers.tripo3d.ai/en/docs/generation-multiview-to-model/p)（2026-09-06）。
