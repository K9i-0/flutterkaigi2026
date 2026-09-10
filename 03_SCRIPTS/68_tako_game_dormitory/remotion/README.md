# タコゲーム 字幕編集

Remotion 4.0.523（npm公式確認）、React 19.1.0。`npm ci`で依存関係を再現。現在はリポジトリ内の同一バージョンnode_modulesをsymlinkで再利用。

`public/input.mp4`はエピソードのWan生成MP4のhardlink。`src/edit-manifest.json`が字幕の文字とフレーム時刻の正本。`titleCard`は専用コンポーネントが描画。

```sh
npm run typecheck
npm run render -- --browser-executable='/Users/kotahayashi/Library/Caches/ms-playwright/chromium_headless_shell-1217/chrome-headless-shell-mac-arm64/chrome-headless-shell'
```

ブラウザパスはこの環境用。別環境ではローカルChromeを指定するかRemotion標準のブラウザ取得を使う。出力は `../final_remotion_subtitles.mp4`。

韓国語音声の置換・速度変更なし。字幕時刻はASR切出しと無音境界から調整し、完全な聴覚/口元同期監査は未判定。
