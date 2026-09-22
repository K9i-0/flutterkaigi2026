# ビール具現化修業 — Remotion + Three.js 技術試作

ユーザー添付の漫画を元に、そば屋のビール具現化修業とやめ太郎のツッコミを3Dで映像化する。動画生成AIは使用せず、既存GLB、React Three Fiber、Remotionで構成する。

## 台本と演出

セリフの正本は `remotion/src/dialogue.json`。添付の修業の説明を短縮し、やめ太郎の「念能力というかアルコール依存症やん」「給料も具現化したい」とそば屋の返答を追加。

1. そば屋がビール具現化の修業を語る。
2. ジョッキを持って観察する回想。
3. やめ太郎「念能力というかアルコール依存症やん」。
4. ビールを取りあげられ、テーブルが空になる。
5. 青緑の幻のビールと粒子が現れる。
6. 金色の本物へ変わる。
7. やめ太郎「給料で、それやりたいわ」。
8. そば屋「まず、実際の給料を用意しろ」。

## 再現

```sh
python3 03_SCRIPTS/73_beer_materialization_3d/generate_audio.py
python3 03_SCRIPTS/73_beer_materialization_3d/prepare.py
cd 03_SCRIPTS/73_beer_materialization_3d/remotion
npm ci
npm run typecheck
npm run studio
npm run render
```

音声は採用WAVがあれば再生成不要。`prepare.py`は既存正本GLBと採用WAVをpublicへhardlinkし、実測音声から整数フレームの`src/edit-manifest.json`を作る。モデルは変更しない。レンダー時の外部APIアクセスは不要。Hiragino SansのあるmacOSが既定環境。

## 仕様・素材

- 1280×720、24fps、1295フレーム（53.958秒）、H.264/AAC。
- Composition ID: `BeerTraining`
- 出力: `final_remotion_3d_v2.mp4`（初版は`final_remotion_3d.mp4`として保持）
- 素材パスとSHA-256: `asset-provenance.json`
- 非ボクセル版そば屋v3、やめ太郎nose-v3、既存ジョッキv2を使用。
- 会話、待機、ジョッキを持つ姿勢は各GLBの既存クリップを基礎に、`04_GAME_ASSETS/3d/motions/skit_v1/motions.ts`の12種類の手付け／手続き型演技を加える。`AnimationMixer.setTime`でフレームから直接評価する。
- やめ太郎の口は正典モデルのSpeechOpenを音声RMSで動かす簡易口パク。音素別のリップシンクではない。
- 具現化する卓上ジョッキと粒子はthree.jsで生成。
- そば屋は仮面を維持。目・口・顔形状の描き直しなし。

## 音声

- エンジン: Irodori-TTS `Aratako/Irodori-TTS-v4.1-Small`
- そば屋: `02_CHARACTERS/Sobaya_voice.wav`、seed 42、`sobaya_monsterize.sh`必須加工。
- やめ太郎: `02_CHARACTERS/Yametaro_voice.wav`、seed 7。
- caption（そば屋）: 大真面目に修業の経験を語る。落ち着いて、少し誇らしげに。
- caption（やめ太郎）: 脱力した関西弁で、呆れたようにユーモラスにツッコむ。
- line04改訂caption: 脱力した関西弁。前半は呆れ気味に、後半は鋭くツッコむ。採用音声実測4.920042秒。
- 自動尺推定。固定尺・話速変更なし。実測尺は `edit-manifest.json` の各区間へ24fpsで切り上げ。
- 環境修復: SciPy 1.15.3のmacOS共有ライブラリ読み込みエラーを、同環境のSciPy 1.14.1への変更で解消。音声モデルは不変。

## 技術資料

[Remotion ThreeCanvas](https://www.remotion.dev/docs/three-canvas) と [公式3Dガイド](https://github.com/remotion-dev/skills/blob/main/skills/remotion-best-practices/remotion-markup/3d.md) に従い、全動作をuseCurrentFrameで制御。Remotionと@remotion/*は2026-09-22確認の4.0.526に固定。

## v2の追加演技

- そば屋: 説明の身振り、ジョッキ観察、画板とペンで写生、匂いを嗅ぐ、泡の音を聞く、空の手を確認、具現化に集中、得意げな乾杯。
- やめ太郎: 手を出すツッコミ、両手でお願い、二度見、首で相づち。
- 生モデルの顔・仮面・体格・メッシュ・ウェイト・既存GLBは維持。各リグの腕の長さを使うCCD IKを姿勢へ重ねる。
- 各フレームで姿勢をリセットし、クリップと演技を絶対時刻から再評価。写生小道具はIK後に手の位置を追従。
- 観察と写生に専用の寄りカメラを追加。

## 検証記録

- TypeScript型チェック、台詞正本との一致、字幕／音声区間とRMSフレーム数の整合: 合格。
- 全1295フレームをレンダー。H.264、1280×720、24fps、53.958333秒。AAC音声48kHz（末尾パディング込み54.016秒）。
- 最終MP4を終端まで映像・音声デコードし、エラーなし。
- 最終MP4の観察、写生、嗅ぐ、泡の音、ツッコミ、没収後、集中、乾杯、お願いの9カットを画像確認。`remotion/out/final-v2-sheet.jpg`。
- 写生時の画板が手首と交差する初期案を不採用にし、左手首の向き・画板の角度・ペン位置を修正。`remotion/out/sketch-fixed.png`。
- 肩や腕の確認は今回の姿勢・カメラ範囲。自由視点・全体格での変形を保証するものではない。
- 音声の通し試聴による発音・声質と、細かなリップシンクの聴覚監査は未実施。口パクは音素別ではなくRMS連動。
