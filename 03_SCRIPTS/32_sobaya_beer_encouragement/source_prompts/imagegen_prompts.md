# ImageGen source prompts

## `character_sobaya_toy_diorama_3d_no_mug_sheet.png`

- Use case: `stylized-concept`
- Mode: built-in ImageGen
- Image 1: `03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png` — strict Sobaya identity and design reference only
- Image 2: `03_SCRIPTS/32_sobaya_beer_encouragement/character_yametaro_toy_diorama_3d_basic_sheet.png` — strict Toy Diorama 3D medium, material, and identity-sheet layout reference only

```text
Use case: stylized-concept
Asset type: Production-ready Seedance character identity sheet for a 15-second Madogiwa Toy Diorama 3D episode.
Primary request: Create an episode-limited toy-diorama 3D identity sheet of Sobaya with completely empty hands and no beer mug.
Input images: Image 1 is the strict identity/design reference for Sobaya: preserve his exact white mask design, black short spiky hair, red vertical mask markings, black circular eye openings, black forehead circle, narrow rectangular mouth opening, very muscular 180 cm / 100 kg proportions, plain fitted white short-sleeve T-shirt, charcoal black jeans, and white sneakers. Do not copy the beer mug from Image 1. Image 2 is the strict medium/style/material/layout reference only: use the same Madogiwa Toy Diorama 3D language, rounded soft toy sculpting, matte resin and fabric, subtle handcrafted texture, warm cream studio background, and clear identity-sheet presentation. Do not copy Yametaro's face, hair, glasses, body, or clothing.
Subject: Sobaya remains much taller, broader, and more muscular than Yametaro even in toy style. Keep the mask attached and unchanged. Both hands must be clearly visible, natural, empty, and relaxed.
Composition/framing: A clean 16:9 character sheet with one large full-body hero view plus FRONT, SIDE, and BACK full-body views, a large mask close-up, and small close-ups of both empty hands, white T-shirt fabric, charcoal jeans, and white sneakers. Every full-body view is fully contained with generous margins. One character only.
Style/medium: High-quality stylized 3D toy-diorama render, matte resin skin and mask, soft woven cloth, simplified but strongly muscular anatomy, warm cinematic studio light, consistent with Image 2.
Lighting/mood: Warm neutral studio lighting, friendly and dependable rather than threatening.
Constraints: Preserve identity across every view. White mask never removed; exact red and black markings; exact outfit and colors; two normal human arms and two empty hands. No episode environment. No action arrows. No alternate costume. No text is required except minimal neutral view labels if unavoidable.
Avoid: Absolutely no beer mug, no glass, no can, no bottle, no alcohol, no drink, no liquid, no food, no tray, no vending machine, no weapon, no extra character, no duplicate limbs or fingers, no watermark, no logo, no explanatory paragraph, no Yametaro features.
```

## `environment_vending_break_corner_toy_diorama_3d_production.png`

- Use case: `stylized-concept`
- Mode: built-in ImageGen
- Image 1: `03_SCRIPTS/00_TEMPLATES/environments/environment_window_side_area_toy_diorama_3d_production.png` — strict Toy Diorama 3D medium, materials, lighting, and world-style reference only

```text
Use case: stylized-concept
Asset type: Production-ready 16:9 Seedance environment reference for episode 32, a 15-second office vending-machine comedy in the Madogiwa Toy Diorama 3D style.
Primary request: Create a new, unoccupied vending-machine break corner inside Acridenture's office, designed precisely for the scenario geography and action. This is a clean environment plate, not a storyboard and not a character scene.
Input image: Image 1 is the strict medium, material, lighting, and world-style reference only. Match its rounded handcrafted toy-diorama language, corrugated-cardboard DIY furniture, matte resin and cloth, warm cinematic afternoon sunlight, cozy office scale, subtle depth of field, and high-end stylized 3D finish. Do not preserve its exact furniture layout, noren, lantern, sofa, shelves, or octopus decorations.
Scene/backdrop: A compact rectangular break alcove adjacent to the window-side workspace. A large generic white beverage vending machine is fixed against the LEFT wall, fully visible from top to floor. It has an illuminated but completely non-readable selection panel, one clearly visible purchase button, coin/card area, and a waist-height dispensing slot large enough for one 350 ml can. Leave a clear standing space directly in front of the machine for a large muscular person. At CENTER, place a low corrugated-cardboard desk with one open laptop; the laptop shows only abstract red error-status bars and shapes with no readable letters. At RIGHT, place one empty sturdy corrugated-cardboard chair positioned for a seated character facing slightly toward the laptop and left-side vending machine. Behind the furniture, large office windows show a warm Tokyo afternoon skyline with Tokyo Tower visible but not dominating. Include a clear walking path from the vending machine to the right chair. Floor and walls are clean warm neutral office materials with a few restrained cardboard storage details and one small plant.
Composition/framing: Single polished cinematic wide shot, exact 16:9 landscape, camera on the front side of the future left-right character axis, seated eye height, approximately 50 mm equivalent. The left vending machine, center desk/laptop, right chair, rear windows, and the open handoff space between left and right must all be readable simultaneously. Keep generous negative space for future characters without placing silhouettes or placeholders. All important objects fully inside frame, no cropped vending machine or chair.
Style/medium: Madogiwa Toy Diorama 3D, rounded miniature architectural forms, corrugated-cardboard construction, matte tactile resin and fabric, subtle handcrafted imperfections, high-quality stylized 3D render consistent with Image 1.
Lighting/mood: Warm late-afternoon window light from rear-right with soft long shadows, complemented by a faint cool white glow from the vending machine. Quiet, safe, intimate office-rest mood suitable for a deadpan emotional comedy.
Color palette: Honey cardboard, warm cream walls, white vending machine, charcoal laptop, restrained red error UI, blue sky, soft green plant.
Text: No readable text anywhere.
Constraints: Environment only; exactly one vending machine, one desk, one laptop, one chair. Preserve the described left-center-right geography. The vending machine must look capable of producing a can but must not visibly display or dispense any can in this clean plate. The laptop remains open. No arrows, callouts, labels, character blocking marks, split panels, or comparison layout.
Avoid: No people, characters, mascots, hands, faces, hair, clothing, silhouettes, reflections or shadows of characters. No beer can, drink can, bottle, glass, beer mug, alcohol, food, vending products with visible labels, logos or readable text. No tavern, shop counter, cafe, convenience store, noren, paper lantern, bar stools, beer tap, alcohol shelf, sofa, octopus emblem, watermark, caption, border, UI overlay, or storyboard annotation.
```

### Final bench revision

- Use case: `precise-object-edit`
- Mode: built-in ImageGen
- Edit target: the first generated `environment_vending_break_corner_toy_diorama_3d_production.png`
- Selected output: this revision replaces the first generated environment in the episode directory

```text
Use case: precise-object-edit
Asset type: Final production-ready 16:9 Seedance environment reference for episode 32.
Edit target: Image 1 is the current vending-machine break-corner clean plate. Preserve its camera, architecture, white vending machine, windows, Tokyo skyline and Tokyo Tower, warm afternoon lighting, floor, walls, small plant, restrained storage details, matte Toy Diorama 3D materials, framing, and color grade.
Primary request: Remove the corrugated-cardboard desk, the open laptop, and the corrugated-cardboard chair completely. Replace those three objects with exactly one simple comfortable break-area bench on the SCREEN-RIGHT side.
Remove exactly: the full desk including tabletop, drawers, legs and every cardboard component; the full laptop including screen, keyboard, red error UI and its shadows; the full individual chair including seat, back, arms, legs and shadow. Reconstruct the floor, wall, window light, and all shadows seamlessly so none of those objects ever existed.
Add exactly: one freestanding two-person bench positioned on screen-right, facing slightly toward screen-left and the camera, suitable for Yametaro to sit while still facing the vending machine. The bench has a rounded deep-blue matte fabric seat and low backrest with simple warm light-wood legs, in the same high-quality Toy Diorama 3D language. It must be clearly a bench, not a sofa, office chair, armchair, stool, table, bed, or cardboard chair. Keep enough clear floor between the left vending machine and right bench for a large muscular person to stand, retrieve a can, and walk one step toward the seated person.
Composition: Maintain the existing single cinematic 16:9 wide camera. Vending machine remains fully visible at left. The new bench is fully visible at right and does not block the Tokyo Tower window. Preserve generous open handoff space in the center. No other furniture replaces the removed objects.
Constraints: Environment only. Exactly one vending machine and exactly one bench. No desk, no table, no laptop, no computer, no monitor, no keyboard, no individual chair, no armchair. No people, characters, hands, silhouettes, reflections or character shadows. No emitted can in the dispensing slot. Vending display products remain generic, unlabeled, non-readable color silhouettes and must not look like beer or alcohol.
Avoid: No beer can, drink can outside the sealed vending display, bottle outside the display, glass, beer mug, alcohol, food, logo, readable text, watermark, caption, border, storyboard annotation, arrows, blocking marks, tavern, cafe counter, sofa, extra bench, extra vending machine.
```

### Final poster-wall revision

- Use case: `precise-object-edit`
- Mode: built-in ImageGen
- Edit target: the selected bench revision of `environment_vending_break_corner_toy_diorama_3d_production.png`
- Selected output: this revision replaces the bench revision in the episode directory
- Integration rule: the poster artwork itself is not regenerated into the environment plate; Seedance receives it separately as image 5

```text
Precise object-level edit of the supplied 16:9 Toy Diorama 3D office vending-machine break room. Keep the same camera position, wide composition, warm late-afternoon lighting, palette, miniature materials, floor, left white vending machine, right dark navy two-person bench, open center floor, plant, and small wall file shelf. Modify only the wall/window geometry above and behind the bench: reduce the panoramic window width and convert part of it into a solid warm cream wall, while retaining one narrower window toward the upper-right with the same sunny Tokyo skyline and Tokyo Tower still clearly visible. On the new solid wall directly above the bench, add exactly one EMPTY portrait 2:3 poster mounting panel with a very slim dark frame, fully visible, front-facing in correct wall perspective, large enough for a movie poster, with its bottom edge safely above a seated character's head. The panel interior must be completely blank matte off-white: no poster artwork, no text, no symbols, no logo, no image. The bench must remain below it and must not overlap the panel. No humans, characters, cans, mugs, bottles, food, desk, table, cardboard desk, PC, monitor, keyboard, office chair, or extra furniture. Do not add any other frame or wall decoration. Preserve generous clear staging space between the vending machine and bench. Production-ready clean cinematic Toy Diorama 3D environment, 16:9.
```

## `prop_madogiwa_movie_poster_production.png`

- Use case: `text-localization`
- Mode: built-in ImageGen
- Edit target: the user-supplied poster previously stored at this same project path
- Selected output: replaces the prior poster because the user explicitly requested a title change
- Role: Seedance image 5, mounted flat inside the empty poster panel in image 4
- Fidelity rule: preserve the full 2:3 artwork and the exact final title text `映画` / `まどぎわ` / `1人10人月の島のひみつ`; never restore `窓際族物語`, add `物語`, crop, redraw, re-typeset, or animate the poster

```text
Use case: text-localization
Asset type: production-ready 2:3 portrait movie poster used directly as Seedance image 5.
Input image: Image 1 is the exact edit target and strict source of truth for every illustration, character, object, composition, lighting, color, texture, border, and all text not explicitly changed below.
Primary request: Change ONLY the large central Japanese title currently reading 「窓際族物語」 to the exact hiragana title 「まどぎわ」.
Text (verbatim): 「まどぎわ」
Exact character sequence: ま / ど / ぎ / わ. Render exactly once, left-to-right on one line. Do not use kanji. Do not add 「物語」. Do not omit, duplicate, reorder, or substitute any kana.
Typography: Preserve the original large title's playful thick rounded white lettering, subtle inner modeling, deep dark-green outline, teal drop shadow, size hierarchy, and centered lower-poster placement. Rebalance the shorter four-character title naturally across the same title area with generous readable spacing. Keep the small 「映画」 directly above it unchanged.
Strict invariants: Preserve the entire poster pixel-for-pixel in visual content as closely as possible outside the large title region. Keep the giant blue mascot, wooden mallet, storm clouds, lightning, rain, tropical island, portal, palm trees, ocean, raft, every foreground person and character, beer mug, laptop, chairs, boxes, monitors, colors, lighting, and exact composition unchanged. Keep the bottom subtitle exactly 「1人10人月の島のひみつ」 with the same typography and placement. Keep 「映画」 exactly unchanged.
Avoid: No redesign, no crop, no reframing, no changed characters, no added or removed objects, no altered subtitle, no altered 「映画」, no extra words, no pseudo-Japanese glyphs, no watermark, no signature, no border, no translated text. Output one clean full-frame 2:3 portrait poster.
```
