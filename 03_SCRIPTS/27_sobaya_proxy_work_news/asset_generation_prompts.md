# 27 代理出社で実刑 — アセット生成記録

## 25から再利用した素材

- `scene_01_studio_start_production.png`：`03_SCRIPTS/25_chikuwa_landing_news/`から実ファイルとしてコピー。
- `logo_yume_tele_master.png`：同上。
- `screen_morning_clock_production.png`：同上。
- `character_sobaya_basic_sheet.png`：過去回からではなく、`03_SCRIPTS/00_TEMPLATES/characters/`の通常形正本から実ファイルとしてコピー。

## scene_01_studio_start_male_production.png

- 生成方式：組み込みImageGen。
- 用途：男性アナウンサー版`script_male_anchor.md`の0.0秒へ直接使う本番開始フレーム。
- 編集対象：女性版`scene_01_studio_start_production.png`。25から再利用したスタジオ、机、海景、照明、固定画角、「ゆめテレ」ロゴを維持し、アナウンサーだけを男性へ変更。

```text
Use case: precise-object-edit
Asset type: alternate Seedance production start frame for scene 1 of a fictional Japanese local morning-news broadcast, 16:9 landscape.
Input image: the supplied studio image is the edit target and exact environment/composition reference.
Primary request: replace only the female anchor at center with one realistic Japanese male news anchor. Preserve the complete studio set, ocean-window background, desk, papers, camera position, crop, cool blue-white morning lighting, and the existing upper-right fictional “ゆめテレ” logo exactly as shown.
Subject: one Japanese male local-news anchor, approximately 43–48 years old, believable as a working regional broadcaster rather than an actor or fashion model. Average build, ordinary slightly long face, subtle natural facial asymmetry, visible pores and mild uneven skin texture, faint under-eye circles, light nasolabial folds, modest practical short black hair with a slightly receding hairline and a few gray strands near the temples, natural eyebrows, normal-sized eyes, clean-shaven or extremely faint beard shadow. Calm serious neutral expression, mouth closed, looking directly into the broadcast camera.
Wardrobe: conservative dark navy business suit, plain white dress shirt, subdued medium-blue tie, small black lapel microphone. No pattern, no badge, no branding.
Pose: seated centrally in the exact same anchor position, upright but natural posture, both hands resting separately on the papers at the desk, physically plausible hands and fingers.
Style/medium: photorealistic live-action Japanese local television frame, natural ENG/broadcast camera realism, normal lens, realistic skin and fabric texture. It must feel like a genuine frame from an ordinary morning news program.
Constraints: exactly one male anchor; preserve all background geometry, desk placement, papers, ocean view, lighting and “ゆめテレ” logo; no other people; no new on-screen text; no watermark.
Avoid: handsome celebrity face, idol face, model face, beauty retouching, airbrushed or porcelain skin, oversized eyes, perfectly symmetrical face, waxy AI skin, glamour makeup, dramatic cinematic lighting, smiling, exaggerated old age, caricature, duplicated hands, extra fingers, deformed fingers, changed logo, pseudo-text, real broadcaster resemblance or identifiable public figure.
```

### 男性版の原寸監査

- 1672×941、RGB、16:9相当。
- 人物は40代半ばの日本人男性1人。自然な目元、肌理、額のしわ、生え際、こめかみの白髪、顔の左右差を確認。
- 紺スーツ、白シャツ、青いネクタイ、ピンマイク、机上の原稿、左右の手を確認。
- 25のスタジオ構図、海景、青白い照明、右上の「ゆめテレ」ロゴを維持。
- モデル顔、アイドル顔、陶器肌、余計な人物・文字、手指の破綻がないことを確認。

## scene_02_proxy_office_start_production.png

- 生成方式：組み込みImageGen。
- 用途：6.7秒のハードカット直後へ直接使う本番開始フレーム。
- 編集対象：旧`scene_02_proxy_office_start_production.png`。オフィス構図を維持し、4人仮面から1人仮面へ修正。

```text
Use case: precise-object-edit
Asset type: revised Seedance production start frame for scene 2 of a fictional Japanese TV news report, 16:9 landscape.
Input image: the supplied office image is the edit target. Preserve its camera, office architecture, daylight, desks, chairs, computers, clothing colors, body positions and documentary news realism.
Primary edit: keep the Sobaya mask on exactly ONE person only: the man at far screen-left in the navy shirt. Completely remove the masks from the other three workers and reconstruct their full natural faces.
The three unmasked people:
- foreground center woman in beige: ordinary Japanese female software engineer in her late 30s, practical tied-back hair, mild under-eye fatigue, subtle facial asymmetry, natural pores and small skin imperfections, no makeup glamour, focused on laptop.
- center-back man in pale blue: ordinary Japanese male infrastructure engineer in his early 40s, slightly receding practical haircut, rectangular glasses, faint beard shadow, tired eyes, natural uneven skin texture, focused on laptop.
- screen-right woman in blue: ordinary Japanese female QA or backend engineer in her early 30s, practical chin-length hair, slightly rounded face, modest features, natural skin texture, focused on monitor.
Face direction: all three unmasked engineers look only at their own screens, never at camera.
Character realism: recognizably real working IT engineers rather than actors or models; varied ages and face shapes; mild asymmetry, pores, under-eye circles, faint blemishes, practical hair, neutral concentration. They must not be unusually beautiful, fashion-model-like, idol-like, airbrushed or perfectly symmetrical. Do not make them unattractive caricatures either.
Masked proxy worker: far-left navy-shirt man keeps exactly the existing rigid white Sobaya mask with two black circular eye holes, forehead black circle, two vertical red markings and small horizontal mouth slot. No other mask exists anywhere in the image.
Constraints: exactly four workers total, exactly one mask total, no loose masks, no gray skin, no muscular Sobaya body, no white T-shirt, no beer, no text, no logos, no watermark. Keep office equipment physically plausible.
Avoid: multiple masks, partial masks, face-mask fusion, duplicated faces, beauty retouching, porcelain skin, fashion photography, glamour makeup, idealized jawlines, oversized eyes, anime features, smiling at camera, uncanny AI symmetry, deformed hands, extra fingers, extra people.
```

## scene_03_home_drinking_start_production.png

- 生成方式：組み込みImageGen。
- 用途：17.0秒のハードカット直後へ直接使う本番開始フレーム。
- 編集対象：旧`scene_03_home_drinking_start_production.png`。そば屋本人と自宅を維持し、PCを派手なゲーム環境へ置換。

```text
Use case: precise-object-edit
Asset type: revised Seedance production start frame for scene 3 of a fictional Japanese TV news reenactment, 16:9 landscape.
Input image: the supplied Sobaya-at-home image is the edit target and absolute identity reference. Preserve Sobaya's exact mask, gray skin, short black hair, muscular build, white T-shirt, black jeans, one large clear beer mug, the modest Japanese apartment, daytime light and realistic news-camera style.
Primary edit: make his skipping work visually blatant and extravagant. Remove the closed laptop completely. Turn the living room into an active daytime gaming setup.
Scene changes:
- Add a large television clearly visible at screen-left or left background. It displays a vivid generic kart-racing video game with abstract colorful vehicles and track shapes, but no existing characters, franchise elements, logos, text or recognizable interface.
- Add one unbranded hybrid home/handheld game console dock near the television with small cyan and coral detachable-style controllers, suggesting the general category of a modern hybrid console without copying any logo or proprietary mark.
- Sobaya lounges shamelessly deep into the sofa, relaxed and slightly slouched, with one foot propped on the coffee table.
- His left hand holds one ordinary unbranded wireless game controller and is actively pressing buttons. His right hand still holds exactly one large beer mug at chest height.
- Put an open bowl of potato chips, two crumpled snack bags and three plain unbranded silver empty cans on the coffee table. Keep the clutter readable but physically plausible.
- Optional subtle gaming headset around his neck, not covering the mask or hair.
Mood: midday work hours, completely deadpan news reenactment; he is obviously gaming and drinking instead of working. No comedy pose toward camera.
Composition: medium-wide shot with Sobaya, controller, mug, television/game image and gaming clutter all visible at once. Keep his mask and mug unobstructed.
Constraints: exactly one Sobaya, one mask, one large beer mug, one wireless controller, one game console, one television. The mug remains in his right hand and the controller in his left. No laptop or office computer anywhere. The mask remains rigid and fully worn.
Avoid: Nintendo name or logo, Switch name or logo, Mario or other copyrighted characters, recognizable game UI, readable text, brand labels, duplicated controllers, duplicated consoles, duplicated mugs, extra people, extra limbs, finger errors, drinking through the mask in the still frame, looking at camera, glamour lighting, cartoon rendering, watermark.
```

## scene_04_courthouse_statement_start_production.png

- 生成方式：組み込みImageGen。
- 用途：23.8秒のハードカット直後へ直接使う本番開始フレーム。
- 入力：`character_sobaya_basic_sheet.png`をそば屋本人の絶対正本として使用。

```text
Use case: photorealistic-natural
Asset type: Seedance production start frame for the final shot of a fictional Japanese TV news report, 16:9 landscape.
Primary request: show the exact SOBAYA character from the supplied canonical sheet giving a brief statement to reporters just outside a generic Japanese courthouse after sentencing.
Scene/backdrop: broad gray stone steps and columns of a generic civic courthouse in Tokyo on an overcast afternoon; no readable court name, no government seal, no logos.
Subject: one and only one Sobaya centered in a press scrum. Age 41, 180 cm, 100 kg, extremely muscular, gray skin, short spiky black hair, fitted plain white short-sleeve T-shirt, black jeans, white sneakers, exact smooth white mask with two round black eye holes, centered forehead black circle, two vertical red cheek markings, and small horizontal mouth slot. He holds exactly one large clear glass beer mug with amber beer in his right hand at waist height. Three reporters remain mostly out of frame; only their hands and three plain black handheld microphones enter from left and right toward his mask. Sobaya is still, deadpan, about to speak; not drinking and not raising the mug.
Style/medium: photorealistic live-action Japanese local-news field footage, sober serious reporting, natural ENG-camera realism.
Composition/framing: stable chest-to-knee medium shot, Sobaya large enough for precise identity, microphones frame him without hiding mask or mug, courthouse entrance softly visible behind, no overlay graphics and no text.
Constraints: exact canonical Sobaya identity; exact one mug; no other masked person; physically plausible reporter hands and microphones; mask fully remains on.
Avoid: product labels, Asahi or Super Dry logo, beer cans, additional mugs, drinking action, mask removal, police uniforms, handcuffs, prison bars, judge, weapons, aggressive crowding, smiling, laughter, horror, gore, readable text, pseudo-text, watermark.
```

## screen_proxy_work_lower_third_production.png

- 生成方式：組み込みImageGenでクロマキー源画像を生成し、ImageGenスキル同梱の`remove_chroma_key.py`で透過PNGへ変換。
- 用途：6.7〜30.0秒の画面下部へ直接合成する本番テロップ。
- 入力：25の`screen_chikuwa_lower_third_clean_production.png`を放送意匠だけのstyle referenceとして使用。

```text
Use case: ui-mockup
Asset type: finished Japanese TV news lower-third graphic for direct compositing into Seedance; generate the source on a removable chroma-key background.
Primary request: create a new lower-third that precisely matches the supplied "ゆめテレ" lower-third's visual system: red slanted alert tab, white main plate with navy text, thin navy and red accent lines, centered navy bottom tab, broadcast-clean bevels and white border. Keep the same overall proportions and hierarchy, but replace all wording.
Text (verbatim, each exactly once):
Top red tab: "速報"
Large main headline: "「そば屋」に実刑判決"
Bottom navy tab: "代理出社で他人に同じ仮面"
Typography: highly legible bold Japanese broadcast Gothic type. The quotation marks around そば屋 are mandatory. Preserve exact Kanji and punctuation.
Background: perfectly flat solid #00ff00 chroma-key background for removal, one uniform color. Do not use #00ff00 anywhere in the lower-third itself.
Constraints: one finished lower-third only; no explanation panel, no comparison variants, no logo, no clock, no people, no photographs, no extra words. Crisp high-resolution edges suitable for alpha extraction.
Avoid: old text from the supplied image, "初夏の風物詩", "天然ちくわ", "水揚げ最盛期", "静岡・浜松市", misspellings, duplicate text, pseudo-Japanese, English, watermark, signature.
```

### 透過・原寸監査

- 透過PNGは2073×758、RGBA。
- 四隅と外周は透明。
- グレー背景への合成QAで、赤い「速報」、紺の「「そば屋」に実刑判決」、白抜きの「代理出社で他人に同じ仮面」を各1回、正しい順番で確認。
- 旧テロップの「初夏の風物詩」「天然ちくわ 水揚げ最盛期」「静岡・浜松市」、疑似文字、透かし、署名が残っていないことを確認。
- クロマキー源画像はSeedanceへ入力しない。
