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
