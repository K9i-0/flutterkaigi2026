# 福ちゃんの肌：キャラクターシート基準

福ちゃんが登場する画像・動画の新規制作、改修、肌補正、監査で使う共通基準。2026-09-29のユーザー指定：美容キャラとしてシート通りの綺麗な肌にし、適度なシワと年齢感は残す。ユーザーが別の肌・年齢表現を明示した場合は、その指定範囲を優先する。

## 参照と仕上がり

- 肌の綺麗さと年齢感の基準は [`character_fukuchan_basic_sheet.png`](../../03_SCRIPTS/00_TEMPLATES/characters/character_fukuchan_basic_sheet.png) の顔アップ。制作前と完成確認時に画像を表示し、通常表情と笑顔の両方を見る。
- 顔の人物同一性は引き続き [`Fukuchan.jpg`](../Fukuchan.jpg) が正本。肌を整えるために骨格、目・鼻・口、顔の輪郭を変えない。生成ツールへの画像添付方法は各制作スキルに従う。
- シートと同程度に手入れされた、均一で綺麗な肌を保つ。シートにないシミ、斑点、そばかす状の点、肌荒れ、過剰な毛穴・凹凸を追加・強調しない。「実写らしさ」「ホラー照明」「高精細化」を理由に肌を荒らさない。
- シートに見える目元・額・口元の自然なシワ、笑いジワ、ほうれい線、肌理、顔の立体感は残す。シワをゼロにした若返り、のっぺりした陶器肌・蝋人形肌にしない。シートにある特徴的な点まで一律に消さない。
- 年齢の数字からシワを描き足したり深くしたりせず、シートの見た目を基準にする。照明の色・方向・陰影はシーンになじませ、シートの明るい撮影光へ全体を合わせる必要はない。
- 過去の生成動画や肌補正済みフレームを、新たな肌・年齢の正本にしない。80話の採用補正は実装例であり、補正強度やマスクを他の素材へ固定適用しない。

## 生成プロンプト

福ちゃんが登場する生成では、顔同一性の指定に加えて、次の要点を実送信本文へ入れる。参照名・番号は実際の入力へ合わせる。「美肌」「smooth skin」だけに省略しない。

```text
Fukuchan's skin quality and apparent age must match the close-up portraits in his canonical character sheet. Keep his well-cared-for, clean, even complexion and natural fine skin texture. Preserve the sheet's subtle forehead lines, eye-area wrinkles, smile lines and nasolabial folds, including their natural changes with expression. Do not add or exaggerate dark spots, freckles, blemishes, rough pores or mottled skin beyond the sheet. Do not erase all wrinkles, de-age him, reshape his face, or give him plastic, waxy or porcelain skin. Preserve the scene's lighting and natural facial shading without turning shadows into blemishes.
```

## 後編集と監査

- 補正対象のシミ・斑点・色ムラと、残すシワ・表情の陰影を分ける。単純な全顔ぼかしで仕上げず、必要に応じて斑点を局所補修する。目元の保護マスクを広げすぎて、目の下・頬の斑点を残さない。
- 動画では補正範囲を追跡し、目・眉・口・髪の輪郭を保護する。補修の境界、ちらつき、追跡ずれ、ピント移動時の不自然さを確認する。肌だけの補正では音声・演技・尺を維持する。
- 「シートより斑点・肌荒れが増えていない」と「シートの自然なシワ・年齢感を失っていない」を別々に確認する。無表情だけでなく、笑顔・発話中・顔の向きや照明の変化をシートと比較する。
- 採用後は、依頼範囲の本編・切り抜き・サムネイル・SNS先頭画像にも同じ補正を反映する。スキルだけを根拠に公開・アップロードを追加しない。
