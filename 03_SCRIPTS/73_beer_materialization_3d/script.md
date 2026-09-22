# ビール具現化修業 — Remotion + Three.js 技術試作

ユーザー添付の漫画を元に、そば屋のビール具現化修業とやめ太郎のツッコミを3Dで映像化する。動画生成AIは使用せず、既存GLB、React Three Fiber、Remotionで構成する。

## 台本と演出

セリフの正本は `remotion/src/dialogue.json`。添付の修業の説明を短縮し、やめ太郎の「幸せな休日」「給料も具現化したい」とそば屋の返答を追加。

1. そば屋がビール具現化の修業を語る。
2. ジョッキを持って観察する回想。
3. やめ太郎「ただの幸せな休日やないか」。
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

- 1280×720、24fps、1279フレーム（53.292秒）、H.264/AAC。
- Composition ID: `BeerTraining`
- 出力: `final_remotion_3d.mp4`
- 素材パスとSHA-256: `asset-provenance.json`
- 非ボクセル版そば屋v3、やめ太郎nose-v3、既存ジョッキv2を使用。
- 会話、待機、ジョッキを持つ姿勢、挨拶は各GLBの既存クリップ。`AnimationMixer.setTime`でフレームから直接評価する。
- やめ太郎の口は正典モデルのSpeechOpenを音声RMSで動かす簡易口パク。音素別のリップシンクではない。
- 具現化する卓上ジョッキと粒子はthree.jsで生成。
- そば屋は仮面を維持。目・口・顔形状の描き直しなし。

## 音声

- エンジン: Irodori-TTS `Aratako/Irodori-TTS-v4.1-Small`
- そば屋: `02_CHARACTERS/Sobaya_voice.wav`、seed 42、`sobaya_monsterize.sh`必須加工。
- やめ太郎: `02_CHARACTERS/Yametaro_voice.wav`、seed 7。
- caption（そば屋）: 大真面目に修業の経験を語る。落ち着いて、少し誇らしげに。
- caption（やめ太郎）: 脱力した関西弁で、呆れたようにユーモラスにツッコむ。
- 自動尺推定。固定尺・話速変更なし。実測尺は `edit-manifest.json` の各区間へ24fpsで切り上げ。
- 環境修復: SciPy 1.15.3のmacOS共有ライブラリ読み込みエラーを、同環境のSciPy 1.14.1への変更で解消。音声モデルは不変。

## 技術資料

[Remotion ThreeCanvas](https://www.remotion.dev/docs/three-canvas) と [公式3Dガイド](https://github.com/remotion-dev/skills/blob/main/skills/remotion-best-practices/remotion-markup/3d.md) に従い、全動作をuseCurrentFrameで制御。Remotionと@remotion/*は2026-09-22確認の4.0.526に固定。

## 検証記録

- `npm run typecheck`: 合格。
- フルレンダー: 合格。GLBの非同期ロードをThreeCanvasのSuspense境界で待機。
- 最終MP4の全1279映像フレームをデコード。H.264、1280×720、24fps、53.291667秒。音声はAAC 48kHz。
- 最後まで映像・音声デコードエラーなし。AAC末尾パディングにより音声は53.354667秒。
- セリフ区間の重複なし、全WAV存在、音声RMS配列とフレーム長一致。
- 実際のMP4から6秒間隔の9コマを抽出し、顔・マスク・手持ちジョッキ・字幕・消失・具現化・終盤を目視確認。加えて各寄りカメラをPNGで確認。
- QA画像: `remotion/out/contact-sheet.jpg`。確認用の静止画・ログはGit対象外。
- 限界: 会話と既存身振り中心の技術試作。写生・舐める・嗅ぐ行為そのものの専用アニメーションは未制作。音素別口パク、通し試聴による声質・発音・微細な同期の監査は未実施。
