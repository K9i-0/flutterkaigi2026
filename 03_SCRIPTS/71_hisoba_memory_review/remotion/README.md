# ヒソバ 字幕編集

```sh
npm ci
npm run typecheck
npm run render
```

完成版: `../final_remotion_subtitles.mp4`。
字幕と整数フレームは `src/edit-manifest.json` が正本。
入力 `public/input.mp4` はエピソード直下のWan MP4のhardlink（Git対象外）。
再構築時は当該動画を `public/input.mp4` へ配置する。
macOSのHiragino Sans W6を使用。別環境ではフォントを用意し、文字幅と改行を再監査する。
字幕は台本に基づき、時刻はASRと無音区間による推定。直接試聴による同期確認は未実施。
