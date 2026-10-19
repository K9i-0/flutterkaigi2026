# おかやまん・大型モニター回転プレビュー

Remotion + React Three Fiber / Three.jsで正典GLBを回転表示する。12秒、1280×720、30fps、360フレーム、H.264、無音。正面から始まり、一定速度で一周する。最終フレームは359度で、ループ時に先頭へ自然につながる。

入力: `04_GAME_ASSETS/3d/characters/okayaman/monitor_v1/okayaman_monitor.glb`。写真・頂点・材質は変更せず、表示用の親groupを回転。正典写真の色を保つためThree.jsのトーンマッピングは無効。フレーム番号だけから角度を評価し、再生速度やシーク順序に依存しない。

```sh
cd 03_SCRIPTS/okayaman_monitor_preview/remotion
npm ci
npm run typecheck
npm run render
```

出力: `03_SCRIPTS/okayaman_monitor_preview/final_remotion_turntable.mp4`（Git管理外）。`npm run studio` でインタラクティブに確認できる。構図・尺・回転・カメラ設定の正本は `src/edit-manifest.json`。

`prepare_assets.py` が正本GLBをGit管理外のpublicへhardlink（別ファイルシステムではcopy）し、SHA-256を `asset-lock.json` に記録する。publicは編集しない。依存はRemotion 4.0.536に統一して固定（2026-10-19にnpmで安定版を確認）。
