# トイジオラマ版ゆめみん・可愛さ改良候補

- Generator: built-in ImageGen
- Use case: `identity-preserve`
- Identity/edit target: `03_SCRIPTS/00_TEMPLATES/characters/character_yumemin_toy_diorama_3d_basic_sheet.png`
- Material reference: `03_SCRIPTS/21_takosan_php_prompt_pun/clip1_start.png`
- Status: 比較検討用。選定されるまでテンプレート正本を置き換えない

## 全候補共通プロンプト

```text
Use case: identity-preserve
Asset type: Seedance用の再利用可能な16:9横長・窓際トイジオラマ3Dキャラクター改良候補シート
Input images: Image 1 is the edit target and sole canon for Yumemin's identity, required anatomy, colors, prop, and sheet layout. Image 2 is ONLY the material and warm Toy Diorama 3D rendering reference.
Subject invariants: Yumemin is a flying baku-like mascot with one blue rounded body, a warm ivory-white rear section, exactly two small blue ears, exactly two black dot eyes, one flexible blue trunk-like nose, one tiny blue rear tail, no legs, no arms, no mouth. The wooden mallet remains a separate prop and is never attached as an arm.
Keep unchanged: 16:9 sheet layout; large hero view; FRONT, SIDE, BACK; FACE / NOSE; three FLEXIBLE NOSE variations; detail panels for WHITE REAR, EARS, EYES, TAIL, WOODEN MALLET, NO LEGS; color palette; all labels and their spelling; blue/white boundary; warm off-white studio background.
Style/medium: high-quality Madogiwa Toy Diorama 3D, softly rounded small collectible toy, matte soft-touch resin and gentle paper-clay tactility, subtle handmade microtexture, warm cinematic studio light matching Image 2. Eyes alone may have restrained smooth black sheen.
Hard constraints: preserve recognizability in every view; no limbs, mouth, eyebrows, blush marks, fur, seams, clothing, accessories, extra characters, office scene, text changes, garbled text, labels on the character, watermark.
```

## Candidate A — ぷくもち幼体型

File: `../candidates/character_yumemin_toy_diorama_3d_cute_candidate_a_puku_mochi.png`

```text
Primary request — Candidate A “Puku-mochi baby proportions”: Make Yumemin clearly cuter through gentle baby-like proportions only. Give the body a subtly plumper, slightly vertically squashed mochi silhouette; place the two dot eyes a little lower and slightly farther apart; make the trunk shorter, softly tapered, and gently upturned at the tip; make the triangular ears slightly smaller, rounder, and softer at the tips. Keep the face calm and mouthless. The effect should be cuddly, innocent, and immediately readable, while still unmistakably the same Yumemin. Apply the exact same revised proportions consistently to every view and detail panel.
```

## Candidate B — 極小パーツ型

File: `../candidates/character_yumemin_toy_diorama_3d_cute_candidate_b_tiny_features.png`

```text
Primary request — Candidate B “Tiny-feature simple mascot”: Make Yumemin cuter through extreme visual simplicity and a generous round body. Keep the body almost perfectly spherical but softly pillowy; make the eyes, ears, trunk, and tail all slightly smaller and more compact than Image 1, with the tiny facial features grouped gently around the lower-middle of the face. The trunk is a short soft nub with a subtle downward-then-upward curve, still clearly a flexible baku nose. Preserve two visible dot eyes. The result should feel like a quiet, palm-sized handcrafted desk mascot: minimal, wholesome, and endearing. Apply the same design consistently across all views.
```

## Candidate C — きらきら活発型

File: `../candidates/character_yumemin_toy_diorama_3d_cute_candidate_c_bright_lively.png`

```text
Primary request — Candidate C “Bright lively mascot”: Make Yumemin cuter and a little more lively while preserving the minimalist identity. Keep the round body; enlarge the two black dot eyes only slightly and give each one a single very subtle soft catchlight, with balanced spacing. Make the small ears gently perk upward with rounded tips. Make the trunk slimmer, shorter, and more gracefully curved upward, as if curious. Keep absolutely no mouth or eyebrows. The result should feel alert, friendly, and toy-like without becoming anime-like or changing species. Apply the exact same revised face and proportions consistently to every view and detail panel.
```
