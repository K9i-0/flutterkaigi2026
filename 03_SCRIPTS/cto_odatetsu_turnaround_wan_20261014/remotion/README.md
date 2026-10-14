# CTOおだてつ・3D回転プレビュー

Three.jsで完成GLBを直接表示するRemotionプロジェクト。`flutterkaigi2026`専用、PR #20の範囲で管理し、mainへマージしない。

- 720×1280、30 fps、360フレーム（12秒）、無音・音声ストリームなし。
- 正面から一定速度で1回転。固定の正投影カメラ、明るいグレーの背景と床。テロップなし。
- 回転・画角・総フレームは `src/edit-manifest.json` が正本。`useCurrentFrame()`から毎フレーム直接評価し、任意順のseekでも同じ向きになる。
- 元GLBの形状・材質を維持し、表示用cloneを床へ合わせる。モデル正本は `assets.json` のsource。

## 再実行

このディレクトリで実行する。全依存は正確なバージョンで固定し、73/74の検証済みlockfileを継承した。2026-10-14のnpm registry安定版確認は4.0.535、採用する既存互換版は全Remotionパッケージ4.0.527。

```sh
npm ci
npm run typecheck
npm run prepare-assets
npm run still -- --frame=0
npm run render
```

`npm run render`も描画直前に素材を再配置する。`public/models/`は同一ファイルシステムではhardlink、それ以外ではコピー。**public内のGLBは編集しない**。正本を再書き出しした場合は再度prepareを実行する。素材ハッシュとサイズは `asset-lock.json` に記録する。

今回のローカル制作では、既存74プロジェクトの同一バージョンのnode_modulesをAPFSのcopy-on-writeでこのディレクトリへ複製した。共有元へバンドルキャッシュを書き込まない。この依存ディレクトリは追跡せず、別環境では `npm ci` で再現する。

## 確認と出力

確認フレームは0（正面）、90（側面）、180（背面）、270（反対側）、359（終端）。まず静止画で全身の余白・フード・靴底・材質・接地を確認してから全編をレンダーする。

```sh
npx remotion still src/index.tsx CtoOdatetsuTurntable out/front.png --frame=0 --gl=angle
npx remotion still src/index.tsx CtoOdatetsuTurntable out/back.png --frame=180 --gl=angle
ffprobe -v error -show_entries stream=codec_type,codec_name,width,height,r_frame_rate -show_entries format=duration -of json out/cto-odatetsu-turntable.mp4
ffmpeg -v error -i out/cto-odatetsu-turntable.mp4 -f null -
```

`out/`は確認・レンダー出力用で追跡しない。完成版は監査後にエピソード直下の `final_remotion_turntable.mp4` として採用する。完成モデルの確定前に旧版を最終レンダーしない。

## 2026-10-14の確認結果

`npm run typecheck`合格。以下のコマンドで正面・背面を先に確認し、12秒の全編を書き出した。

```sh
npm run render -- --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
```

MP4はH.264・yuv420p・720×1280・30fps・360フレーム・12.000秒、音声ストリームなし。四方向と最終フレームの画角・フード・接地・靴のAを目視確認し、ffmpegの全編デコードがエラーなしで完了した。素材正本・publicコピー・asset-lockのSHA-256一致、および動画SHA-256は `render_validation.json` に保存。

## リグ動作プレビュー

`RigMotionPreview`は720×1280・30fps・24秒。Idle、Walk、Run、Greeting、DanceDisco、GyunGyunを各120フレームずつ再生する。正面斜めの固定カメラで全身を表示し、字幕は動作名だけ。`src/rig-manifest.json`をタイミングと画角の正本とする。既存の回転動画のmanifestとasset-lockは維持し、リグは`rig-assets.json`と`rig-asset-lock.json`で分離する。

`SkeletonUtils.clone`で表示用の骨を複製し、`src/rig-sampler.ts`で毎フレーム初期姿勢を復元してからAnimationMixerへ`frame / 30`を渡す。クリップ切り替え・逆向きseek・非連続レンダーも同じ姿勢を返し、未収録のクリップへはfallbackしない。54骨・20クリップを読み込み時に検査する。

```sh
npm run typecheck
npm run verify-rig-viewport
npm run still-rig -- --frame=420 --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
npm run render-rig -- --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
```

リグ正本が存在しない段階では`prepare-rig-assets`が明示的に失敗する。既存の`prepare-assets`と回転動画レンダーはリグ正本に依存しない。監査済み完成版の置き場はエピソード直下の`final_remotion_rig_motion.mp4`。

リグ動画はJPEG品質95・同時描画1で書き出す。この環境ではPNG・同時描画2の動画に画面上部の反復が混入したため、単独の静止画成功だけでは完成判定しない。代表ポーズ・境界の抽出画像と全編デコードに加え、全フレームで身体が描画されていることも検査する。

`verify-rig-viewport`は動画と同じsampler・カメラで720フレームの全変形頂点を投影し、画面内への収まりを検査する。Nodeで画像読込を省くため材質だけを除外し、元の形状・ウェイト・骨・モーションはそのまま評価する。`rig_viewport_validation.json`へモデルのSHA-256と各動作の最大範囲を記録する。最も右へ伸びるのはDanceDiscoの515フレームで、手先に約49pxの余白を確保した。

### ローカルで20動作を確認

```sh
npm run rig-viewer
```

[ローカル確認ページ](http://127.0.0.1:8138/rig-preview.html)を開く。クリップ選択、再生・停止、フレームseek、骨表示、視点回転・拡大を使用できる。全素材とThree.jsはローカルから読み込み、外部CDNにはアクセスしない。`viewer/`がページの正本、`public/`は再生成可能な管理外コピー。動画と同じsamplerをTypeScriptから書き出す。ブラウザーの`window.rigPreview.sample(clip, frame)`/`snapshot()`は姿勢の再現性を確認するためのAPI。

「全動作のseek検証」で、各クリップの37%地点を保存→別の全20クリップの79%地点→対象の91%→0%→37%へ移動し、54骨すべてのworld matrixを完全一致で比較する。`rig_seek_validation.json`は2026-10-14の実機結果で、20動作とも一致し、NaN・Three.jsの警告はない。実測尺はGLTFLoaderの値を保持する。GyunGyunは4.000秒／120フレームで、最後の描画フレームの時刻は119/30＝3.967秒。UIの総尺には最終フレーム時刻ではなく実測尺を表示する。

### 2026-10-14のリグ動画の確認結果

最終GLB（SHA-256 `a00e99144f2fba32ae4a777a6084ebe56594828df13ae04fc33ee9cd9962ffd4`）から24.000秒・720フレームを書き出した。H.264・720×1280・30fps・音声なし。JPEG入力由来のフルレンジ4:2:0としてffprobeでは`yuvj420p`と表示される。全編decode、全720フレームの身体表示検査、全変形頂点の画角検査、21枚の代表ポーズと境界の目視確認が通過。詳細と完成動画SHAは`rig_render_validation.json`に記録した。

## カメラ装備と肩持ちポーズ

`CameraEquipmentPreview`は720×1280・30 fps・16秒。元イラストに合わせた`CameraCarry`を全身6秒・寄り4秒、その後に装備状態の既存動作を各3秒表示する。`src/camera-manifest.json`が画角とフレームの正本。カメラとレンズは別GLBとして読み込み、人物の派生GLBへ追加された21番目のクリップを使う。元の54骨・20動作のモデルと既存2本のプレビューは保持する。

```sh
npm run typecheck
npm run verify-camera-equipment
npm run still-camera -- --frame=0 --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
npm run render-camera -- --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
npm run camera-viewer
```

[カメラ装備の確認ページ](http://127.0.0.1:8138/camera-preview.html)でCameraCarry・既存20動作、装備ON/OFF、ストラップ、骨表示、視点回転、seekを操作できる。同じ8138番ポートで以前のviewerサーバーが動作中なら、`npm run prepare-camera-viewer`後にURLを開く。

`src/camera-equipment.ts`をviewerと動画で共用する。毎フレーム元クリップをsampleし、装備中のみ右15指の絶対local quaternionを適用する。`PropSocket.R`（Three.jsでは`PropSocketR`）とcameraの`GripAnchor`を`socketWorld × socketToGrip × inverse(gripInCamera)`で一致させる。各nodeの座標は正本GLBと`attachment.json`から読み、カメラのグリップ方向や鏡像をコードへ固定しない。装備を外すと指も元クリップへ戻る。

ストラップは独立した幅22 mmの黒いribbonに正確な`ODATETSU`文字を描画する。2個のStrapAnchorからworld空間の重力方向へ垂れ、frameごとに直接評価する。簡易表現で、布の慣性・人体衝突はシミュレーションしない。既存20動作での装備追従はできるが、全動作について人体やレンズの接触回避を自動保証するものではない。

入力は`camera-assets.json`、ハッシュは`camera-asset-lock.json`へ記録する。`verify-camera-equipment`は全21動作×3位相を順不同に評価し、装備OFFが独立した元クリップsampleと一致すること、ONでの再現性、GripAnchor一致、有限な頂点、動画480フレームの画角を検査する。寄りカットは腰より下とストラップ下端を意図的にクロップするため、上半身とカメラを検査対象にする。監査済み動画の採用先はエピソード直下の`final_remotion_camera_equipment.mp4`。

### 2026-10-14のカメラ装備プレビュー検証

人物`2376c9e1…`・カメラ`a7a0badde…`・装備設定`4d72b080…`の確定版で検証した。63組すべてで任意seekの完全一致、装備解除時の元クリップ復元、有限な骨・ストラップ頂点を確認し、GripAnchorの最大行列誤差は`2.22e-16`。動画480フレームの全変形頂点の画角検査も通過した。数値とSHA-256は`camera_equipment_validation.json`に記録している。

完成動画は16.000秒・480フレーム・720×1280・30 fps・H.264、音声ストリームなし。JPEG品質95・concurrency1で書き出し、ffprobeでは`yuvj420p`と表示される。全編decode、全480フレームの撮影破損チェック、15枚の代表ポーズ・カット境界の目視監査を通過した。寄りカットはラベルに背景を付け、衣服へ重なっても文字が読めるようにした。動画SHA-256は`89b158824875c72e7ef6f6eef6208feaf017ff84f213195fca46849414f472f9`。詳細は`camera_render_validation.json`。

ブラウザの最終版でも全21動作のseek検証、装備ON/OFFの描画、警告・エラーなしを確認した。停止中は操作時だけ描画し、開いたまま不要にGPUを使用しない。CameraCarry・Walk・Greetingの代表位相についてカメラと顔・身体の大きな交差を目視確認した。21動作すべての接触安全性を保証する検査ではない。
