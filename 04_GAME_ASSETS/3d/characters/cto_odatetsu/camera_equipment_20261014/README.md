# CTOおだてつ：カメラ装備と肩持ちポーズ

`flutterkaigi2026` 専用。本人の正本 `../rig_v1_20261014/cto_odatetsu_rig.glb` から派生させ、カメラは別GLBとして装備する。

## 本人モデル

`cto_odatetsu_camera.glb` は54骨・21クリップ。元の20動作へ、右手でカメラを肩沿いに持ち、左手を腰へ置く `CameraCarry` を追加する。1秒の固定ポーズで、顔・髪・フード・衣装・全身の形状は元モデルを使う。

元GLBのbinaryバッファ全体、既存accessor、bufferView、node、mesh、skin、材質、画像、20動作の定義をそのまま保持し、新しいアニメーションのデータだけを追記する。元のリグ正本や20動作は変更しない。

## 別体カメラとの接続

`attachment.json` を使用する。カメラはメートル単位、-Xが撮影者から見たグリップ側、+Yが上、+Zがレンズの光軸。`GripAnchor` はその基準軸に平行なemptyとする。カメラを鏡像化せず、装備側の回転で右手へ合わせる。

```text
cameraWorld = socketWorld × socketToGrip × inverse(gripInCamera)
```

- 本人側socket: `PropSocket.R`。Three.jsのGLTFLoaderでは `PropSocketR` に変換されるため、元名を保持した `userData.name` での検索にも対応する。
- `socketToGrip`: column-majorの4×4行列。
- `rightGripPose`: 右15指の**絶対local quaternion**（xyzw）。アニメーションをsampleした後、装備中だけ適用し、world matrixとskeletonを更新する。RightHand自体は上書きしない。
- カメラを外すときは通常のsampleで指も元動作へ戻す。本人モデルへカメラを結合しない。

カメラ正本は `../../../props/odatetsu_camera/finish_20261014/odatetsu_camera.glb`。実モデルの `GripAnchor` から取り付け行列を計算し、掌に対する向き・高さを合わせた。人差し指はグリップ上部、他の指はボディ側へ回し、右手首のねじれを前腕へ分散する。カメラ側の座標系訂正は装備回転で吸収し、鏡像化していない。

## 再生成・検証

```sh
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python 04_GAME_ASSETS/3d/characters/cto_odatetsu/camera_equipment_20261014/build_pose.py
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python 04_GAME_ASSETS/3d/characters/cto_odatetsu/camera_equipment_20261014/validate.py
/Applications/Blender.app/Contents/MacOS/Blender -b -t 6 --python 04_GAME_ASSETS/3d/characters/cto_odatetsu/camera_equipment_20261014/review.py
```

`validate.py` は元20動作×3位相の全頂点が同一であること、新ポーズのBlender再読込と独立glTFスキニング計算が一致することを確認する。`review.py` は書き出しGLBの前・斜め・後ろと左右の手の拡大を描画する。生成した監査画像・作業blendはGit管理しない。

最終検証は `validation.json`。元20動作の60姿勢は全頂点差0。CameraCarryの作業シーンとGLB再読込の差は最大0.0011mm、独立glTF計算との差は最大0.00072mm。

実カメラとの三角形交差と距離は `contact_review.json`。頭・髪、背面フード、右握りを除いた全身に交差はない。距離は頂点から表面への片方向の測定値なので、厳密な表面間の最小距離とは区別する。握り部分は見た目を合わせた接触で、完全な衝突解消や物理的な把持シミュレーションは行っていない。前・斜め・後ろと左右の手の目視範囲、監査対象のSHAは `pose_review.json` に記録する。

最終調整では本人ポーズを保ち、カメラの取付位置だけを5mm下げた。掌から浮かずボディ側を押さえる見た目を確認し、数値だけを理由に指を大きく曲げ直していない。生成メッシュは閉曲面とは限らないため、握りの符号付き最近傍距離は参考値として扱う。`preview.png` は実カメラ装備の斜め正面像で、監査画像と同じくローカル保持する。
