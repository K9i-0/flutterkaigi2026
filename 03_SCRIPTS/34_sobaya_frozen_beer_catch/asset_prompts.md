# 本番用重要小道具 — ImageGenプロンプト

生成方式：Codex組み込みのImageGen。以下の2点を別々に生成し、1ファイル1アセットで保存する。

## `prop_important_documents_production.png`

```text
Use case: product-mockup
Asset type: Seedanceへ直接入力する本番用重要小道具画像。動画内でそば屋が抱え、衝突後に床へ散らばる重要書類の正本。
Primary request: 日本のオフィスで使う厚いA4クラフト紙製ドキュメント封筒を1つだけ、正面から見た高精細な商品写真として生成する。
Scene/backdrop: 均一な明るいニュートラルグレーの無地背景。説明パネルや机や手は置かない。
Subject: 少し厚みがあり、書類が入っていることが分かる丈夫なA4クラフト封筒。中央に白い長方形ラベルを貼る。
Style/medium: photorealistic product photography, clean Japanese office prop, movie-production quality.
Composition/framing: 封筒全体を正面向きで中央に大きく配置。四辺を切らず、十分な余白。遠近歪みを最小化。
Lighting/mood: 柔らかな均一スタジオ照明。紙繊維と封筒の厚みが読める。
Materials/textures: 茶色いクラフト紙、自然な紙繊維、白いマット紙ラベル、濃い赤の太いゴシック体印刷。
Text (verbatim): 「重要書類」
Text requirements: ラベル中央に「重要書類」の4文字だけを横一列で、非常に大きく、濃い赤、太い日本語ゴシック体で正確に1回だけ印刷する。文字は 重要書類。順番、漢字、字形を厳守。
Constraints: 1ファイル1アセット。封筒は1つだけ。ラベルは1枚だけ。文字は「重要書類」だけ。映像制作用の実物小道具として自然で、480p動画でも読める高コントラスト。
Avoid: 追加文字、英語、数字、ロゴ、透かし、署名、バーコード、社名、印鑑、スタンプ、説明文、比較案、手、人、机、複数封筒、画面分割、注釈、矢印。
```

## `prop_fragile_package_production.png`

```text
Use case: product-mockup
Asset type: Seedanceへ直接入力する本番用重要小道具画像。動画内でそば屋が抱え、衝突後に床へ落ちる荷物の正本。
Primary request: 日本のオフィス配送用の中型段ボール箱を1つだけ、正面から見た高精細な商品写真として生成する。
Scene/backdrop: 均一な明るいニュートラルグレーの無地背景。説明パネルや机や手は置かない。
Subject: しっかり封をされた中型の茶色い段ボール箱。正面中央に白い長方形の取扱注意ラベルを1枚貼る。
Style/medium: photorealistic product photography, clean Japanese office delivery prop, movie-production quality.
Composition/framing: 箱全体をわずかな正面寄り三分の一角度で中央に大きく配置。全ての辺を切らず、十分な余白。正面ラベルが真正面に近く明瞭に読める。
Lighting/mood: 柔らかな均一スタジオ照明。段ボールの波目、折り目、テープの厚みが読める。
Materials/textures: 茶色い段ボール、透明な梱包テープ、白いマット紙ラベル、濃い赤の太いゴシック体印刷。
Text (verbatim): 「割れもの注意」
Text requirements: ラベル中央に「割れもの注意」の6文字だけを横一列で、非常に大きく、濃い赤、太い日本語ゴシック体で正確に1回だけ印刷する。文字は 割れもの注意。順番、漢字、ひらがな、字形を厳守。
Constraints: 1ファイル1アセット。箱は1つだけ。ラベルは1枚だけ。文字は「割れもの注意」だけ。映像制作用の実物小道具として自然で、480p動画でも読める高コントラスト。
Avoid: 追加文字、英語、数字、ロゴ、透かし、署名、バーコード、社名、配送票、ピクトグラム、ガラス絵、上向き矢印、説明文、比較案、手、人、机、複数箱、画面分割、注釈。
```

## 原寸監査結果

- `prop_important_documents_production.png`：文字は「重要書類」1回のみ。誤字、追加文字、透かし、縁切れなし。
- `prop_fragile_package_production.png`：文字は「割れもの注意」1回のみ。誤字、追加文字、透かし、縁切れなし。
