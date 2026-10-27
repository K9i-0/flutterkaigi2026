# ゆめみ採用試験 トレーラー

**v4は2026-10-27にユーザー採用済み。README掲載の60fps版です。**

iPhone 18 Pro／iOS 27シミュレーターの実プレイを全面表示する32秒のゲームトレーラー。ゆめテレアナウンサーは声の配役のみで、局ロゴ・ニュースの体裁は使わない。「ついにゲーム化」「3人のゆめプロメンバーによる難易度」「Flutter Sceneの3Dと赤坂の昼夜」を紹介する。

2622×1206・60fps。端末の横長画面比率を維持し、外枠・ヘッダーなし。字幕は720p換算25px・通常ウェイトの1行で下部に表示する。ゲーム内HUDはそのまま残す。

## 素材と編集

- `src/edit-manifest.json`: カット、字幕、音声開始位置の正本。時刻は整数フレーム（区間の終端を含まない）。
- `src/index.tsx`: ゲーム画面を全面に配置。白い字幕、薄い影、下端の淡い暗転で可読性を確保する。
- `public/`: 元の画面収録、横向き変換版、採用音声。Git管理外。
- `out/`: 中間レンダー、ASR、QA画像、ログ。Git管理外。
- `../../docs/media/hero.png`: 採用版の静止画。今回のプレビューは `out/poster-v4.png`。
- `final_remotion_trailer.mp4`: 採用版（Git管理外）。今回の確認用は `out/yumemi-recruit-exam-v4.mp4`。
- `validation.json` / `source-media.json`: 検証結果と入力素材のSHA-256。

入力映像はアプリそのものの描画。生成映像ではない。debugビルド・高精細画質・日本語・キャラクター固有の固定配置を使用し、プレイは `action=demo` が移動とカメラ入力を供給する。人間による傾き操作や実機fpsの記録ではない。動画の速度は変更していない。ゲーム音声は無音化し、ナレーションのみを配置する。

## 標準録画（v4）

Dart MCPでdebug起動し、Marionetteの`madogiwa.catchAction`で`action=fps,value=on`と`action=graphics,json={"fullResolution":true}`を指定する。FPS表示はゲーム内の実表示で、編集による数値の上書きはしない。性能の正式評価ではなく、シミュレーター映像の収録。

録画はApple標準の`xcrun simctl io <UDID> recordVideo --codec=h264 --mask=ignored <file.mov>`。SIGINTを送り、プロセスが終了してファイルが確定するまで待つ。XcodeBuildMCPの`record_sim_video`はAXe経由なので今回使わない。録画中はTTS・動画変換・レンダーを並行しない。

結果ダイアログが残っていないことをMarionetteで確認し、プレイは`action=demo`で入力する。キャラクター選択、タイトル、ギャラリーの昼夜も同じ標準録画で再収録した。

元録画は`public/*-v4.mov`。縦2622pxのストリームに回転メタデータが付く。`prepare-native-media.py`はFFmpegの自動回転を使い、2622×1206を維持して60fpsへ正規化する。旧AXe録画用の明示的なtransposeは重ねない。動く映像の速度変更・フレーム補間はしない。静止しているタイトル画面は標準録画が1フレームだけ保存するため、末尾用にその静止画を保持する。元録画のフレーム間隔も監査し、単に出力を60fpsにしただけで滑らかと判定しない。

## レンダー

```sh
cd tools/readme-video
mise exec -- npm ci
python3 prepare-native-media.py
uv run --with pillow python audit.py
mise exec -- npm run typecheck
mise exec -- npm run render
mise exec -- npm run poster
```

RemotionとCLIは4.0.539へ固定。編集UIは `mise exec -- npm run studio`。日本語フォントはmacOSのHiragino Sansを使用するため、再生成もmacOSを前提とする。

採用版の入力動画はREADME用Releaseの `source-media-v4.zip` に保存してある。v4は高精細で撮り直した実プレイ・キャラクター選択・ギャラリー・タイトル映像と、採用ナレーション `public/narration-v3.wav` を使う。動画はGit履歴に入れない。

## ナレーション

[台本と生成記録](script.md) を参照。ゆめテレアナウンサーの [正典キャスト](../../characters/VOICE_CAST.md) と [参照WAV](../../characters/YumeTeleAnchor_voice.wav) を使用する。音声の実測尺は29.486417秒。映像開始の30フレーム後に再生する。

制作ではSeedance_Madogiwa系ローカルリポジトリの `.claude/skills/remotion-video/SKILL.md`、`references/design-and-qa.md`、`references/manifest-format.md` と `tools/IRODORI_TTS.md` を参照した。今回はゲーム紹介のため、ニュース番組の時計・速報帯は使用しない。

## 検証

- アプリは今回変更なし。前回の `flutter analyze` と59件の `flutter test` が成功している。
- 音声: Whisper large-v3-turboで全台詞を照合し、固有名詞の表記は原稿へ合わせた。ASRは発音・声質・自然さの聴覚確認を代替しない。
- 各カットの開始・中間・終了、字幕・カット境界の静止画を確認する。結果ダイアログが重なった初回の福ギュン・そば屋・ギャラリー素材は不採用として撮り直した。
- 今回の検証結果は `validation.json` に記録する。承認と聴覚確認は別に記録する。
