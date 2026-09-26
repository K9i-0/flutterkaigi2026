# そば屋の買い出し 完成編集

`npm ci` → `npm run typecheck` → `npm run render`。

Composition: `SobayaYakumi`。出力: `../final_remotion_yakumi_call_crop.mp4`。
`src/edit-manifest.json`の900フレーム新規素材＋137フレーム既存連行映像を接続する。
`public/input.mp4`は`../wan3_yakumi_seed810925_480p.mp4`、`public/ending71.mp4`は第71話の字幕なしWan原本のhardlink。動画はGit対象外のため別環境では元素材が必要。

生成上の差異・音声確認の限界はエピソードの`script.md`を参照。

現行コードは通報シーン[564,775)の左上基準1.255882倍トリミングを含む。旧採用版`final_remotion_yakumi.mp4`は保持。
