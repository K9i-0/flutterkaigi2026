# CTOおだてつ：カメラと望遠レンズのTripo原型

`flutterkaigi2026` 専用、PR #20の制作物。mainへマージしない。

- ユーザー指定: α7 V型の黒い本体にSEL70200GM2型の白い望遠レンズを装着。文字はODATETSU / O7 V / O。
- 採用入力: `03_SCRIPTS/cto_odatetsu_camera_20261014/camera_front.png` / `camera_back.png`。公式資料からImagegenで作った反対方向の3/4画像。厳密な校正投影ではない。
- 2026-10-14に1件生成。P2-20260801、quad、15,000面目安、詳細PBR、seed1014175。
- task: `9b40f61c-4e17-4652-a333-3870513387ab`。成功、実消費120 credits。
- 原型: `raw/output_model_url.fbx`（5,737,100 bytes）。SHA-256 `43aa3f1f6ea6ae70d7f534f8385659792affb512fdf0859812eaa9fdd1d29033`。
- API応答の署名付きURL・upload token・元FBX・原型previewはローカル保持しGit追跡しない。生成条件・入力hash・task ID・取得hashは追跡する。

原型では望遠鏡胴が短く、架空文字に崩れがある。正本GLBへ直接採用せず、`../finish_20261014/`で実機に近い比率・文字・材質と装備anchorを仕上げる。ストラップは別部品。
