# SuperTryCM

Wan素材（832×480、30fps、30秒）の同じ時間軸と音声を保ち、最後の4秒へ正確な商品名・コピーを重ねる。氷上の実写缶はWanの映像を維持する。

`npm ci`、`npm run typecheck`、`npm run render`でエピソード直下の`final_remotion_cm.mp4`へ出力。
入力は`public/input.mp4`へ採用Wan動画をhardlinkまたはコピーする。`previewOnly=true`は`public/endcard_background.png`（原動画27秒の抽出画像）を使うプレビュー専用。

タイミング正本：`src/edit-manifest.json`。フレーム780から900の間だけオーバーレイ。動画本体と抽出画像はGit管理外。未修正の「待遇も」の発音はscript.mdの監査制限を参照する。
