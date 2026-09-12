# 窓際酒場スタイル素材

2026-09-12、組み込みimagegenで生成（CLI/APIへの切替なし）。背景素材なので文字・人物は生成しない。
原本PNGはこのディレクトリ、配信用WebP・書体・ライセンスは `../../public/themes/sakaba/`。
暖簾59KB、和紙10KB、見出し書体18KB。PNG原本はpublicへ含めない。

## 生成プロンプト（全文）

### noren-source.png

Create a production website background texture asset only. Straight-on flat scan of deep indigo blue Japanese cotton noren fabric. Wide landscape 3:1 aspect ratio. Uniform dark navy #142b40, subtle tactile woven cotton fibers, restrained natural dye variation. Very low contrast so cream text can be placed on top in HTML. Entire image filled by cloth. No folds, NO curtain shape or segmentation, no rod, no room, no lighting gradients, no shadows, no borders, no lettering, no symbols, no logos, no objects. Seamless-looking woven texture with consistent edges. Premium authentic neighborhood standing bar noren cotton, matte.

### washi-source.png

Create a production website background texture asset only. Flat scanned warm ivory Japanese menu paper / washi, light cream #f7f1e3. Square format. Extremely subtle sparse irregular fibers and fine paper grain. Almost flat overall color; intended for website text background, crisp black text needs high legibility. No objects, no lettering, no symbols, no stains, no folds, no edges, no frame, no gradients, no vignette, no shadows, no distressed grunge. Uniform edge brightness for unobtrusive tiling. Authentic everyday Japanese standing bar menu paper, tasteful and clean.

## 配信形式への変換

Studioディレクトリから実行。画像の生成・質感の編集はimagegen、以下はサイズ縮小とWebP圧縮のみ。

```sh
ffmpeg -y -i design-preview/source-assets/sakaba/noren-source.png -vf scale=1024:-1 -c:v libwebp -quality 78 design-preview/public/themes/sakaba/noren.webp
ffmpeg -y -i design-preview/source-assets/sakaba/washi-source.png -vf scale=768:-1 -c:v libwebp -quality 76 design-preview/public/themes/sakaba/washi.webp
```

## 見出し書体

Yuji Syuku（佑字 肅）、SIL Open Font License 1.1。Google Fonts配布の部分書体をローカル同梱。
取得元 `https://fonts.googleapis.com/css2?family=Yuji+Syuku&text=...&display=swap`。
収録文字: `窓際族物語酒場本日のおすすめ乾杯人物特集初めての方へ`。
利用箇所を増やす場合は部分書体を更新するか既存Noto Serif JPへフォールバック。
本文・作品名・操作文字はHTMLのまま。原作写真やキャラクター画像は再生成していない。

## そば屋提灯の刷り絵（2026-09-12）

`lantern-face-source.png` は組み込みimagegenで生成。参照画像は正典 `public/site/sobaya-icon.jpg`。
配信用は `../../public/themes/sakaba/lantern-face.webp`（512px・alphaあり・約41KB）。
Three.jsの曲面へ貼る刷り絵と、WebGL非対応時のCSS提灯で共有する。

生成プロンプト全文:

Use case: identity-preserve / production texture decal. Supporting reference is canonical Sobaya portrait. Create an isolated screen-printed emblem of ONLY this exact character's head/mask, front view, on genuine transparent background. Preserve recognizable short spiky black hair, smooth oval white mask, two large round black eye holes, symmetric long red vertical markings above and below the eyes, small round black forehead mark, small nose, small horizontal open black mouth. Faithful silhouette to reference, not a different horror mask. Style: tasteful Japanese lantern silkscreen print, simplified flat ink shapes in black, dark vermilion and warm ivory, very subtle natural printed edges, no photorealistic shading. Include no shoulders, no clothes, no beer, no circular badge, no text, no background, no shadow, no lantern itself. Face fills central 75% height of square transparent canvas, centered straight on. Intended as flat printable face art mapped onto a glowing paper lantern. True alpha transparency around the head; mask itself opaque ivory. Clean crisp small-scale readability.

配信変換:

```sh
ffmpeg -y -i design-preview/source-assets/sakaba/lantern-face-source.png -vf scale=512:512 -c:v libwebp -quality 86 design-preview/public/themes/sakaba/lantern-face.webp
```

## 現行の赤提灯

ユーザー指定により、顔柄は使用終了。現在は赤提灯に「窓際で生きていく」を筆文字で表示する。
追加フォント `public/themes/sakaba/lantern-lettering.ttf` はYuji Syukuの8文字部分書体（SIL OFL、同梱ライセンス参照）。画像生成ではなく、CanvasTextureとHTML縦書きで正確に描画する。
