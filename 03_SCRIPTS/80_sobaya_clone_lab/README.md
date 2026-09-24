# そば屋クローン研究所 — 窓際力UI試作

本編生成前のUIのみ。1920×1080 / 30fps / 300フレーム（10秒）、音声なし。

窓際力は標準的な窓際社員を **10 MW** と定義した相対尺度。福ちゃん **213 MW**、やめ太郎 **5,082 MW**、そば屋 **10,247 MW**。福ちゃんは高値個体、やめ太郎とそば屋は規格外。規格外判定1,000 MWは今回のUI試作値。

たこさんの監視装置視点。二人を囲む枠の中へ後から監視映像を合成する。人物・研究所の映像、音声は未制作。青緑→福ちゃんの高値判定（琥珀）→やめ太郎の規格外判定（赤）→二人の生体回収指示。比較バーは差の大きい値を読めるよう対数表示と明記。

## プレビューと合成

- `final_remotion_scanner_preview.mp4`: 暗い仮背景付きのUI確認用動画。本編完成版ではない。
- `scanner_overlay_alpha.mov`: 背景透過のProRes 4444、同じ10秒。
- `remotion/out/scan-270.png`: 捕獲指示画面の静止画。
- `remotion/out/overlay.png`: 同フレームの背景透過PNG。
- `ScannerPreview`: グリッド背景と合成領域の案内付き。
- `ScannerOverlay`: 案内と背景なし。暗いUIパネルは残し、人物映像の上へ合成できる。

`remotion/src/edit-manifest.json`が寸法・整数フレームタイミング・測定値・人物枠位置の正本。人物枠は仮置きで、自動追跡は実装しない。本番映像の位置・動きに合わせて調整する。

```sh
cd 03_SCRIPTS/80_sobaya_clone_lab/remotion
npm ci
npm run typecheck
npm run studio
npm run stills
npm run render
npm run alpha
```

Remotion関連パッケージは作成時 `npm view remotion version` で確認した4.0.528へ統一固定。日本語フォントはmacOSのHiragino Sansを使用。他OSでの再現時は同フォントの用意、または日本語フォントの明示的な差し替えが必要。

postproduction=remotion。元動画入力なし。UI試作のみのため字幕・ニュースプリセット・音声は使用しない。

検証：TypeScriptチェック成功。測定中・確定・捕獲切替のPNGをレンダーし、文字と数値の配置を目視確認。MP4とProResは双方1920×1080・30fps・300フレーム・10秒、全編デコード成功。ProResのアルファチャンネルと人物合成領域の完全透過を確認。音声なし。
