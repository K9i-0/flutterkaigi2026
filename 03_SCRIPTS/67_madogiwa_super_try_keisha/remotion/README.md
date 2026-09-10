# 競謝CM・25秒編集版

ユーザー採用方針：生成済み後半20秒だけを本編にし、実況・セリフ字幕と共通商品カット5秒を追加。

- Composition: `KeishaCM`、854×480、30fps、750フレーム。
- `src/edit-manifest.json`: 本編600f、字幕7区間、商品カット開始のタイミング正本。
- `src/Effects.tsx`、`effects-manifest.json`、`endcard-audio.json`: 共通エンドカットからコピー。今回コピー「低姿勢で、ぶっちぎれ。」。共通正本は変更していない。
- `public/input.mp4`: エピソードの生成動画へのhardlink、Git管理外。再構築時は`../wan3_part2_480p.mp4`をこの場所へコピー／hardlinkする。
- その他PNG/WAVは共通エンドカットの採用素材の実ファイルコピー。
- 本編の映像・埋め込み音声を0–20秒維持し、20秒で共通エンドカットへ切替。コール音源はBGM込みで20.3秒から再生。追加TTS・有料生成なし。
- Remotion 4.0.523（2026-09-10 npm確認）、lockfile固定。ローカルnode_modulesは既存同版へのsymlinkで利用、再構築時は`npm ci`。

```sh
npm ci
npm run typecheck
npm run render -- --browser-executable='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome'
```

出力：`../final_remotion_cm.mp4`。

字幕原文は採用台本を使用。Whisperの時刻出力をタイミング補助とし、ASRが追加した「スタッフ！」は通常ASR結果・台本にないため字幕へ採用していない。直接の聴感監査とは区別する。
