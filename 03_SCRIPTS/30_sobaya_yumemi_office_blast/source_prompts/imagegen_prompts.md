# ImageGen production prompts

Built-in ImageGenで生成した本番用画像のプロンプト記録。ここは制作履歴であり、Seedanceへはアップロードしない。

## `scene_01_yumemi_office_start_production_pose_fixed.png` — 体格対応・肩保持修正版

参照：既存の本番開始フレームを編集対象、そば屋基本シートを人物同一性、ユーザー添付2枚をランチャー保持の人体工学だけの参考にする。

```text
Use case: precise-object-edit
Asset type: corrected actual first frame for episode 30 Seedance video, finished 16:9 production still
Input images: Image 1 is the edit target and controls the building, street, camera, crop, lighting, launcher appearance, and overall composition. Image 2 controls Sobaya's identity, mask, gray skin, short black hair, muscular 180 cm / 100 kg body, white T-shirt, black jeans, and white sneakers. Images 3 and 4 control only the ergonomic relationship between a shoulder-fired box launcher, the shoulder rest, hands, forearms, face, and line of aim; do not copy the people, uniforms, scenery, exact weapon models, or movie imagery.
Primary request: Correct only Sobaya's launcher-carry geometry and the immediately affected shoulder, upper torso, arms, and hands. Account for his exceptionally broad, thick shoulders and very muscular arms. Place the olive-drab rectangular four-tube launcher outside his body, level and aimed at the same intact 「ゆめみ」 building. The front four-tube end must extend clearly forward past his mask; the rear body must extend behind his right shoulder. Add or reveal a distinct rigid shoulder-rest under the rear third of the launcher. Only that shoulder-rest may contact the outer top of his right shoulder.
Body clearance: preserve an unmistakable 3–5 cm air gap between the launcher housing and Sobaya's neck, trapezius, upper back, mask, head, and white T-shirt. The right shoulder cap, neck edge, shirt collar, upper-back contour, and both arm silhouettes must remain continuous and anatomically readable, never hidden inside or fused with the launcher. Raise and shift the launcher slightly outward/right as needed for his 100 kg muscular frame; do not compress or narrow his torso to make the weapon fit.
Hand placement: right hand firmly wraps the rear pistol/trigger grip below the launcher near the shoulder, wrist neutral and elbow angled down/back. Left palm and fingers support the forward underside below the box in front of the chest, wrist neutral and elbow forward/down. Both hands remain fully below/outside the launcher; no fingers, palms, wrists, forearms, or sleeves penetrate the housing. Keep realistic grip pressure and five anatomically plausible fingers per hand.
Invariants: exactly one Sobaya and one launcher; same Sobaya identity and intimidating broad muscular physique; same mask design, clothing, stance, aim, intact building, evacuated street, exact readable 「ゆめみ」 sign, daylight, rear-left camera side, and zero beer. Keep the launcher olive drab with one rectangular housing, four circular launch tubes in a 2x2 arrangement, open front covers, rear section, and top sight. No firing, projectile, muzzle flash, smoke, explosion, or damage.
Avoid: launcher intersecting shoulder, trapezius, neck, head, mask, shirt, back, arms, hands, or fingers; shoulder buried in the box; missing shoulder-rest; weapon resting directly on the neck; squeezed or shrunken torso; broken elbows or wrists; extra or fused fingers; duplicate person or weapon; soldiers, camouflage, actor likeness, copied movie frame, text changes, additional signs, beer, watermark.
```

## `scene_01_yumemi_office_start_production_pose_fixed_v2.png` — 肩当て分離・首クリアランス修正版

```text
Use case: precise-object-edit
Edit target: the first pose-fixed frame. Change only the launcher-to-body fit and the immediately affected pixels.
Lift the entire launcher housing 8–12 cm above Sobaya's shoulder line and shift it laterally outward onto his right side, away from his neck. The long rectangular housing must run beside the right side of his head, never behind or through the neck. Create a short, clearly visible rigid shoulder-rest/padded saddle projecting downward from the launcher underside beneath the rear third; only this small rest touches the outer crown of the right deltoid. Show clean daylight/background gaps beneath the main housing: 5–8 cm above the trapezius and upper back, and 4–6 cm beside the neck and mask. Preserve the complete neck outline, shirt collar, right trapezius slope, rounded deltoid cap, sleeve seam, and upper-back silhouette.
Keep his broad 180 cm / 100 kg muscular torso unchanged. Right hand stays on a rear vertical trigger grip below the box with neutral wrist and elbow down/back. Left hand stays under the forward third with neutral wrist and elbow forward/down. Reconnect both forearms and all fingers naturally without intersection. Preserve exactly the same Sobaya, launcher design, aim, building, 「ゆめみ」 sign, empty street, lighting, camera, composition, clothing, and zero beer. No firing or damage.
Avoid any launcher housing touching or covering the neck, trapezius, upper back, mask, shirt, arm, wrist, hand, or fingers; no broad box resting directly on the shoulder; no missing shoulder-rest; no squeezed torso; no extra fingers; no duplicate person or weapon; no text or background change.
```

## `scene_00_sobaya_m202_front_start_production.png` — 背景地理修正版

```text
Use case: precise-object-edit
Edit target: prior frontal M202 frame.
Replace only the background. Sobaya faces the camera and aims toward the 「ゆめみ」 building located behind the camera, so remove the target building and every occurrence of 「ゆめみ」 from the visible background. Replace them with the opposite side of the evacuated business street: generic offices, trees, sidewalk, overcast sky, no readable signs or logos. Preserve Sobaya, mask, M202A1, 2x2 four-tube face, hands, pose, camera, crop, lighting, and zero beer exactly. No firing, smoke, damage, text, extra people, vehicles, or watermark.
```

## `scene_01_yumemi_office_start_production.png` — 保持姿勢再修正版

```text
Use case: precise-object-edit
Edit target: prior rear three-quarter M202 frame. Use the supplied real-world shoulder-carry reference as the controlling source for launcher-to-body geometry.
Rebuild the holding pose so the M202A1 does not intersect the shoulder, trapezius, neck, head, shirt, arms, or hands. The forward four-tube end extends past the face toward the target; the rear body extends behind the shoulder. A distinct rigid shoulder-rest beneath the rear third touches only the outer top of the right shoulder. Preserve a clearly visible 2–4 cm air gap everywhere else between the launcher housing and the neck, trapezius, upper back, and shirt; keep the neck and shoulder silhouettes continuous. Right hand holds the rear/trigger grip near the shoulder, wrist straight, elbow down/back. Left hand supports the forward underside in front of the chest, wrist straight, elbow forward. Both hands stay below the box. Preserve exactly one Sobaya, one olive-drab rectangular M202A1 with four 2x2 tubes, open covers, top sight, intact 「ゆめみ」 building, evacuated street, daylight, and zero beer. Wider rear-left 50mm view. No firing, damage, soldiers, camouflage, actor likeness, movie-shot recreation, text changes, or watermark.
```

## `scene_01_yumemi_office_start_production.png` — ビール非携帯版への改修

参照：旧版`scene_01_yumemi_office_start_production.png`を編集対象とし、ビールとホルダーだけを除去。

```text
Use case: precise-object-edit
Asset type: revised actual first frame for a 15-second Seedance video, 16:9 landscape
Edit target: Image 1.
Primary request: Remove only the beer mug and the white rigid mug holster attached at Sobaya's left waist. Reconstruct the missing black jeans, belt/waist edge, white T-shirt hem, and nearby background naturally. Sobaya carries absolutely no beer, mug, glass, can, bottle, cup, beverage, holster, pouch, or drinking equipment in this opening frame.
Invariants: keep everything else pixel-compositionally consistent with Image 1: same one Sobaya, exact face mask design, gray skin, short black hair, muscular build, white T-shirt, black jeans, white shoes, exact pose and both hands on the same launcher, same fictional launcher design and aim, same intact office building, same street geography, same daylight, same camera angle and crop, same exact readable 「ゆめみ」 sign, no projectile, no muzzle flash, no explosion, no damage.
Constraints: edit only the mug/holster region and the pixels necessary for a seamless reconstruction; one Sobaya, one launcher, zero drink containers.
Avoid: changing pose, hands, weapon, mask, clothing fit, body proportions, building, logo spelling, street, lighting, lens, adding any other objects, text, watermark, fire, smoke, rubble, duplicate person, duplicate launcher.
```

## `logo_yumemi_master.png`

```text
Use case: logo-brand
Asset type: Seedance production logo/signage master for an office building facade
Primary request: Create a clean, original Japanese corporate wordmark showing exactly the three hiragana characters 「ゆめみ」, once and only once.
Style/medium: polished fictional Japanese IT company logo, simple geometric rounded lettering, trustworthy but slightly quirky, designed to remain readable on a modern office tower facade.
Composition/framing: centered front-facing wordmark only, generous blank white margin, no perspective, no mockup, no building, no explanatory panel.
Color palette: deep navy lettering with one restrained sky-blue accent; high contrast on white.
Text (verbatim): 「ゆめみ」
Constraints: exact spelling ゆ・め・み, one line, one occurrence, clear Japanese glyphs, production-ready, crisp edges.
Avoid: any other Japanese or Latin text, English slogan, icon mascot, stock logo, watermark, signature, perspective distortion, duplicate alternatives, comparison grid.
```

## `scene_01_yumemi_office_start_production.png`

参照：`character_sobaya_basic_sheet.png`は人物正本、`logo_yumemi_master.png`は文字正本、ユーザー添付漫画は発射という物語ビートだけの参考。

```text
Use case: stylized-concept
Asset type: actual first frame for a 15-second Seedance office-action parody video, finished production still, 16:9 landscape
Input images: Image 1 is the only identity/design source for Sobaya; Image 2 is the exact corporate wordmark source that must appear on the building facade as 「ゆめみ」; Image 3 is narrative-beat reference only for the idea of a man firing a shoulder launcher toward a building, but do NOT copy its manga composition, camera angle, panel layout, linework, text, or character design.
Scene/backdrop: daytime Akasaka-like Japanese business district, broad empty street, modern mid-rise glass-and-concrete office building 35 meters ahead, rooftop facade carries the clearly readable exact logo 「ゆめみ」 once. Evacuated area, no bystanders and no vehicles.
Subject: Sobaya, exactly matching Image 1: very muscular 41-year-old man, gray skin, short black hair, rigid white mask with two black circular eye openings, one black circle on forehead, two red vertical markings, small horizontal mouth slot; white short-sleeve T-shirt, black jeans, white sneakers. He stands in the near foreground with a shoulder-fired fictional recoilless launcher aimed directly at the office facade. His mandatory oversized half-full clear beer mug is secured upright in a simple rigid waist holster, fully visible and not spilling.
Action state: first frame immediately before firing; right hand on trigger grip, left hand supporting launcher tube, stock braced firmly against right shoulder, feet planted wide, torso leaning slightly forward. No projectile has left the tube yet, no muzzle flash, no explosion, building completely intact.
Style/medium: premium cinematic live-action tokusatsu office satire with photoreal materials and restrained absurdity; original staging.
Composition/framing: low waist-height 28mm camera behind-left of Sobaya, three-quarter profile so his mask remains readable, Sobaya fills left third, intact office building fills center/right, unobstructed line of fire, readable logo high on facade, strong depth.
Lighting/mood: neutral bright overcast daylight, serious documentary-like framing that makes the absurdity funnier.
Constraints: one Sobaya only, one launcher only, one mug only; exact character identity and clothes from Image 1; logo text exactly 「ゆめみ」; no blast yet; no harm to people.
Avoid: copying the comic panel composition, manga styling, panel borders, speech balloons, Japanese narration text, subtitles, captions, additional logos, watermark, fire, smoke, rubble, damaged glass, police, soldiers, gore, beer spill, missing mask, redesigned mask, extra fingers, duplicate objects.
```

## `vfx_yumemi_office_blast_production.png`

参照：`scene_01_yumemi_office_start_production.png`は無傷状態と地理の正本、`logo_yumemi_master.png`は文字正本。

```text
Use case: stylized-concept
Asset type: final VFX look reference for a Seedance video, finished cinematic frame, 16:9 landscape
Input images: Image 1 is the exact intact office building, street geography, daylight, and visual world immediately before impact; Image 2 is the exact 「ゆめみ」 logo design. Do not include Sobaya or his launcher in this VFX-only reference.
Primary request: Show the same evacuated modern office building at the precise instant just after a fictional recoilless projectile impacts the center of the upper facade. A dense orange-white pressure burst punches outward through several window bays; safety glass, light aluminum mullions, facade panels, dust, office paper, and dark gray smoke expand outward under gravity. The concrete structural core remains standing, lower entrance remains recognizable, and destruction is localized to the upper center rather than the entire city block. The rooftop sign is bent and scorched but still legibly reads exactly 「ゆめみ」 once.
Style/medium: premium photoreal live-action tokusatsu disaster VFX, serious physical weight, original imagery.
Composition/framing: stable wide 35mm street-level view of the same building, unobstructed impact point, no split screen, no arrows, no before/after comparison, no annotation.
Lighting/mood: neutral overcast daylight with strong orange-white blast illumination and physically plausible reflected light on nearby glass.
Materials/textures: fractured safety glass, bent aluminum, cracked concrete dust, layered volumetric smoke, hot sparks; rubble follows gravity and has visible mass.
Constraints: evacuated building and street, no visible people, no bodies, no injuries, no vehicles; one localized blast; preserve same building identity and street geography; exact visible Japanese sign 「ゆめみ」.
Avoid: nuclear mushroom cloud, citywide destruction, fantasy energy beam, floating debris, blood, gore, victims, fire covering the logo completely, duplicate or misspelled text, extra signs, captions, watermark, storyboard layout, manga panel style.
```
