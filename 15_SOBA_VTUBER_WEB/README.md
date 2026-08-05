# そば屋 VTuber Web Rig

Live2D Cubismを使わず、既存のそば屋パーツをWebカメラで動かすコードネイティブな2Dモデル。

- 描画: PixiJS
- 顔追跡: MediaPipe Face Landmarker
- モデル設定: `src/sobaya.rig.json`
- 正典画像: `../04_GAME_ASSETS/live2d/sobaya/`

## セットアップ

```bash
cd 15_SOBA_VTUBER_WEB
npm install
mkdir -p public/models
curl -L \
  https://storage.googleapis.com/mediapipe-models/face_landmarker/face_landmarker/float16/latest/face_landmarker.task \
  -o public/models/face_landmarker.task
npm run dev
```

このリポジトリには現在、顔認識モデルを `public/models/face_landmarker.task` として配置済み。上記の`curl`はモデルを更新・再取得する場合だけ必要。

ブラウザで `http://127.0.0.1:5215` を開き、「カメラを開始」を押す。初回のみブラウザのカメラ権限を許可する。

## 操作

- `カメラを開始`: Webカメラの顔追跡を開始
- `ニュートラルを記録`: 現在の顔向き・位置を正面として補正
- `デモを開始`: Webカメラなしで頭、瞬き、口、身体、ジョッキの動作確認
- `乾杯！`: ジョッキを前上方へ掲げるモーション。`C`キーでも実行
- `背景`: スタジオ、透過、グリーン、マゼンタを切り替え

## リグの編集

`src/sobaya.rig.json`の`motion`を変更する。

| Key | Effect |
| --- | --- |
| `headYawPixels` | 頭部の左右移動 |
| `headPitchPixels` | 頭部の上下移動 |
| `headRollDegrees` | 首かしげ角度 |
| `bodySwayPixels` | 身体の左右揺れ |
| `mouthOpenScale` | 口スロットの縦方向倍率 |
| `mugBouncePixels` | ジョッキの上下動 |
| `smoothingHalfLifeMs` | 追跡平滑化。大きいほど滑らかで遅い |

## OBS

最初はChromeウィンドウをウィンドウキャプチャする。背景をグリーンまたはマゼンタにしてクロマキーを適用する。透過表示はWebページ埋め込み向け。

## 現在のトラッキング対応

- 顔の左右・上下・傾き
- 顔位置に追従する身体揺れ
- 左右の瞬き
- 顎の開きに連動する口スロット
- 呼吸のアイドルモーション
- 頭と身体に連動するジョッキの揺れ
- ボタンまたは`C`キーで実行する乾杯モーション

瞬きはMediaPipeの`eyeBlink`スコアが0.88を超えてから反応し、0.98で完全閉眼になる。目が細い状態は開眼として維持する。

## プライバシー

カメラ映像はMediaPipeによりブラウザ内で処理される。アプリ自身は映像やトラッキング値を保存・送信しない。

## 検証

```bash
npm test
npm run build
```

Sites公開用の成果物は`npm run build:sites`で生成する。
