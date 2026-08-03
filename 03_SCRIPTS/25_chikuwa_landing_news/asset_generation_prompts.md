# 採用済み本番参照画像の生成プロンプト

すべて built-in `image_gen` で生成。没画像と旧プロンプトはこのランから除外済み。

## `logo_yume_tele_master.png`

```text
Use case: logo-brand
Asset type: Seedance production master logo for a fictional Japanese regional television news channel.
Primary request: Create a clean, credible Japanese local TV station logo reading exactly “ゆめテレ”.
Style: original polished broadcast graphic, deep navy and restrained coral-red, readable rounded Japanese sans-serif.
Constraints: exact text once; one logo only; no real broadcaster design, other words, English, slogans, mascots, watermark, or signature.
```

## `scene_01_studio_start_production.png`

```text
Use case: photorealistic-natural
Asset type: Seedance production start frame for a fictional Japanese local morning-news studio, 16:9.
Input image: “ゆめテレ” logo master, used only as the exact upper-right logo bug.
Subject: one Japanese female anchor in her late 30s with an ordinary believable appearance, natural asymmetry and skin texture, modest bob haircut, navy jacket and off-white blouse, seated behind a restrained blue-gray local-news desk, lips closed at frame zero.
Style: ultra-photoreal broadcast still, flat controlled newsroom lighting, standard eye-level anchor framing, no glamour or cinematic treatment.
Constraints: fictional presenter and set; no lower third, ticker, other text, real network logo, celebrity likeness, beautification, AI-smooth skin, watermark, or malformed hands.
```

## `scene_02_hamamatsu_harbor_start_production_v4.png`

```text
Use case: identity-preserve
Asset type: final Seedance production start frame with maximum character-identity fidelity.
Input images: Image 1 is the accepted harbor composition and environmental target. Image 2 is SOBAYA’s absolute mask and identity source. Image 3 is TOKUN’s absolute face and identity source. Image 4 is FUKUCHAN’s absolute face and identity source. Image 5 is OKAYAMAN’s absolute remote-face identity source.
Primary request: Correct only the identity-critical face, hair, mask, head shape and adjacent identifying details of the four Madogiwa members so they match their canonical sheets as faithfully as possible. Identity fidelity outranks beautification, generic realism and creative interpretation.
SOBAYA: exact white oval mask, two round black eye openings, centered black forehead dot, two tapered red vertical cheek markings, narrow horizontal mouth, short spiky black hair, broad gray neck and arms; remain a tiny accidental swimmer 12–15m away, empty hands and mouth, no beer.
Targeted color correction: both exposed arms of the tiny distant SOBAYA swimmer must be neutral medium gray skin matching his canonical sheet, with wet seawater highlights and distance haze. Never use human beige or pink skin on either arm. This correction must not alter his mask, hair, white T-shirt, pose, scale, waterline, splashes, or any other pixel-level scene element.
TOKUN: exact round slightly plump Japanese face, full cheeks, black side-swept hair, purple-tinted black sunglasses, nose and mouth proportions, straw hat and black band; preserve aloha, lei, ukulele, waterproof bibs, crate and pose.
FUKUCHAN: exact slim 48-year-old Japanese male face, center-parted medium black hair around cheeks, narrow jaw, eyelids, eye spacing, straight nose, gentle smile and pink lips; preserve canonical gyungyun expression, black outfit, graphic shirt, SPONSOR lanyard, “福ちゃん” badge, white boots and pose.
OKAYAMAN: exact medium black fringe, eye shape, nose, gentle smile, mustache and chin-beard outline, jaw, skin texture and black hooded jacket; remain only in the same upper-right white-bordered wipe.
World and composition invariants: preserve the harbor, fishermen, boats, wet pier, water, sunrise, logo, wipe geometry, blue crates, living chikuwa’s glossy seawater film and two or three small flops, all positions, poses, hands, clothing, camera, depth of field and color grade. No new text, duplicates, face blending, younger or beautified faces, stylization, or altered composition.
```

## `screen_morning_clock_production.png`

```text
Use case: productivity-visual
Asset type: transparent Japanese morning-news clock graphic for CapCut.
Text (verbatim): “7:00”
Style: compact white digital clock panel, bold dark navy numerals, thin coral accent, contemporary Japanese local morning-news design.
Constraints: one clock only, exact text once, no logo, channel number, weather icon, extra words or watermark.
```

## `screen_chikuwa_lower_third_clean_production.png`

```text
Use case: productivity-visual
Asset type: transparent Japanese morning-news lower-third graphic for CapCut.
Text (verbatim, each exactly once): “初夏の風物詩” / “天然ちくわ　水揚げ最盛期” / “静岡・浜松市”
Style: credible contemporary Japanese local morning-news typography; white and light-gray panels, dark navy text and rules, restrained coral accents.
Constraints: no person name, title, “窓際王”, “おかやまん”, station logo, ticker, extra words, pseudo-text, real broadcaster branding or watermark.
```
