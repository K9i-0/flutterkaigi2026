# 酒場のお品書き・制作素材

組み込みimagegenで生成（2026-09-12）。原本 `menu-wood-source.png`。配信用は `../../../public/themes/sakaba/menu-wood.webp`（960×960、WebP quality 82）。文字・メニュー・判子はHTML/CSSで表示する。

## 全文プロンプト

Use case: photorealistic-natural. Production website material texture, not a finished webpage. A straight-on square full-frame scan of a well-kept old Japanese izakaya wooden menu board: deep warm smoked chestnut brown wooden planks, extremely subtle vertical wood grain, satin aged surface with gentle natural variations, narrow seams, restrained patina. Uniform diffuse warm light, seamless-looking edges for background tiling. Rich brown rather than black, quiet low contrast behind cream paper menu cards. No letters, no numbers, no menus, no objects, no food, no people, no perspective, no borders, no vignetting, no harsh scratches. Only wood surface filling the entire canvas.

## 採用動画からの表紙

`public/themes/sakaba/bar-opening.webp` は公開採用動画 `/media/ed9573c4-25e7-4dab-b7c5-0cd9a1f24b7e` の28.5秒をffmpegで抽出（WebP quality 88）。生成画像ではなく、実際に店主と仲間が乾杯する場面。元動画は複製してGit管理しない。

## 表示と実装

本番正本は `src/official/shop-details.tsx` / `shop-details.css`。木の板・写真札・添え書きと、地下売店のミシン目付き引換券・交換判子を実装。提灯の点灯状態に合わせて木の板への暖色の反射も切り替える。Three.jsを追加で読み込まず既存提灯を活用する。

おすすめの一本は `theme-features.ts`。酒場＝タコゲーム — 目覚め、Excel＝プロフェッショナル 窓際の流儀、地下売店＝地下労働篇。非公開・動画なしの作品は選択せず、公開ピックアップ→公開動画の順でフォールバックする。

ローカル4173番は本番のReactコンポーネントを直接利用し、公開API・動画・画像だけをプロキシする。固定スナップショットはローカルで通信できない場合のみ使う。
