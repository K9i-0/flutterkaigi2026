# README紹介映像

iPhone 18 Pro／iOS 27シミュレーターで収録した「ゆめみ採用試験」を、ゆめテレアナウンサーのナレーションとRemotionの字幕・見出しで紹介する32秒の動画。完成版は1280×720、30fps。

## 素材と編集

- `src/edit-manifest.json`: カット、見出し、字幕、音声開始位置の正本。時刻は整数フレーム（区間の終端を含まない）。
- `src/index.tsx`: ゲーム画面をクロップせずに配置し、枠に緩やかな角度変化を付ける。字幕色は共通正本のアナウンサー色 `#258D91`。
- `public/`: 元の画面収録、横向き変換版、採用音声。Git管理外。
- `out/`: 中間レンダー、ASR、QA画像、ログ。Git管理外。
- `../../docs/media/hero.png`: 紹介映像の静止画。READMEにはRelease添付の6秒GIFプレビューを表示する。
- `final_remotion_trailer.mp4`: 採用した完成版（Git管理外）。
- `validation.json` / `source-media.json`: 検証結果と入力素材のSHA-256。

入力映像はアプリそのものの描画。生成映像ではない。debugビルド・標準画質・日本語・キャラクター固有の固定配置を使用し、プレイは `action=demo` が移動とカメラ入力を供給する。人間による傾き操作や実機fpsの記録ではない。動画の速度は変更していない。ゲーム音声は無音化し、ナレーションのみを配置する。

## 収録

Dart MCPで `app/` をdebug起動し、Marionette **0.7.0** をApp URIへ接続する。版不一致なら `mise exec -- dart pub global activate marionette_mcp 0.7.0` 後にMCPサーバーを起動し直す。

1. `get_interactive_elements` で `result_dialog` がないことを確認する。残っていれば `tap(key: result_close)` で閉じ、再取得する。自動操作で次のラウンドを開始しても既存ダイアログは閉じない。複数ラウンド分が重なることもあるので、状態取得とスクリーンショットの両方で確認する。
2. `madogiwa.catchAction` の `action=select` でキャラクター・時間帯を選び、スクリーンショットを確認する。
3. XcodeBuildMCP `record_sim_video` で録画を開始し、`action=demo`。開始直後にスクリーンショットでダイアログがないことを確認する。
4. 約25秒後に停止。次の収録の前に結果ダイアログを閉じる。

| 元ファイル | 収録内容 |
| --- | --- |
| `odatetsu.mp4` | CTOおだてつ・昼のプレイ |
| `fukugyun.mp4` | 福ギュン・昼のプレイ |
| `sobaya.mp4` | そば屋・夜のプレイ |
| `gallery.mp4` | ギャラリーの赤坂ステージ・夜・自動回転 |
| `characters.mp4` | ギャラリーの福ギュン・正面・Idle |

ギャラリーは `madogiwa.galleryAction` の `open` → `select(subject: akasaka|fukuchan)` → `autoRotate(value: on)`。`akasaka` は `orbit(yaw: 20, pitch: 30)` で初期構図を整える。福ギュンは `orbit(yaw: 0, pitch: 7)`、`zoom(distance: 3.2)`、`autoRotate(value: off)` で正面のIdleを収録する。

今回のsimulator収録は1206×2622の縦フレームに横向きの映像が入るため、`prepare-media.py` で90度反時計回りに回転し、幅1600・30fpsへ変換する。別環境で既に横向きなら回転を外す。クロップや再生速度の変更はしない。

## レンダー

```sh
cd tools/readme-video
mise exec -- npm ci
python3 prepare-media.py
uv run --with pillow python audit.py
mise exec -- npm run typecheck
mise exec -- npm run render
mise exec -- npm run poster
```

RemotionとCLIは4.0.539へ固定。編集UIは `mise exec -- npm run studio`。日本語フォントはmacOSのHiragino Sansを使用するため、再生成もmacOSを前提とする。

横向き変換済みの採用動画と音声を含む `source-media.zip` はREADME用Releaseの添付ファイルから取得し、このディレクトリに展開すると同じ入力で再レンダーできる（変換済みのため `prepare-media.py` は不要）。動画はGit履歴へ入れず、README用Releaseに完成版と入力素材を置く。

## ナレーション

[台本と生成記録](script.md) を参照。ゆめテレアナウンサーの [正典キャスト](../../characters/VOICE_CAST.md) と [参照WAV](../../characters/YumeTeleAnchor_voice.wav) を使用する。音声の実測尺は29.642875秒。映像開始の15フレーム後に再生する。

制作ではSeedance_Madogiwa系ローカルリポジトリの `.claude/skills/remotion-video/SKILL.md`、`references/design-and-qa.md`、`references/manifest-format.md` と `tools/IRODORI_TTS.md` を参照した。今回はゲーム紹介のため、ニュース番組の時計・速報帯は使用しない。

## 検証

- アプリ: `flutter analyze` 問題なし、`flutter test` 59件成功。
- 音声: Whisper large-v3-turboで全台詞を照合し、固有名詞の表記は原稿へ合わせた。ASRは発音・声質・自然さの聴覚確認を代替しない。
- 各カットの開始・中間・終了、字幕・カット境界の静止画を確認する。結果ダイアログが重なった初回の福ギュン・そば屋・ギャラリー素材は不採用として撮り直した。
- 完成MP4は960フレーム・32秒・1280×720・30fps・H.264／AAC 48kHz。98箇所の境界・中間フレームを目視確認し、全編のデコードに成功した。
