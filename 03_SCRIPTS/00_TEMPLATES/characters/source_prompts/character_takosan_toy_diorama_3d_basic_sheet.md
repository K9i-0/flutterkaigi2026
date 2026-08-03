# character_takosan_toy_diorama_3d_basic_sheet.png

- Generator: built-in ImageGen
- Use case: identity-preserve
- Media style: 窓際トイジオラマ3D (`toy_diorama_3d`)
- Edit target: `03_SCRIPTS/00_TEMPLATES/characters/character_takosan_toy_diorama_3d_basic_sheet.png` の旧版
- Identity references:
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip1_start.png` — `NEUTRAL`
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip1_end.png` — `OPEN MOUTH`
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip2_end.png` — `LISTENING`
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip3_end.png` — `HEAD TILT`
- Precedence: 上記4枚から切り出した完成フレーム準拠ポーズを最優先し、三面図は不足角度だけを補完する
- Output: 1672x941 RGB PNG
- Output SHA-256: `fb4eac5e32450b56c9d941e19f2639ebf767a64c0376fa75f03f8d6745e1e99d`

## Final prompt

```text
Use case: identity-preserve
Asset type: Seedance用の再利用可能な16:9横長・窓際トイジオラマ3D基本キャラクター設定シート
Primary request: Image 1のシートを全面的に再構成する。Image 2〜5の完成フレームから「たこさん」だけをそれぞれ忠実に切り出した4つの正典ポーズをシートへ直接掲載し、その正典ポーズで見えないSIDEとBACKだけを補完三面図として新規作成する。Image 2〜5のたこさんが常に最上位正典であり、Image 1の誤った目の反射、頭身、胴体寸法、触手幅は引き継がない。
Input roles: Image 1 is only a layout/edit target. Image 2 supplies CANON NEUTRAL. Image 3 supplies CANON OPEN MOUTH. Image 4 supplies CANON LISTENING. Image 5 supplies CANON HEAD TILT. For each source frame isolate only Takosan; remove Yametaro, office, laptop, desk, Tokyo Tower, furniture, shadows from the environment, and all other source-frame content. Preserve Takosan's exact silhouette, pose, costume, material, proportions, and small mouth state from its assigned source. Place every isolated Takosan cleanly on the same warm-white sheet background. Do not reinterpret the four canon figures as a different character design.
Critical eye correction: EVERY eye in EVERY panel is a perfectly uniform featureless solid #000000 circular disk. Absolutely no catchlight, white dot, gray dot, blue rim, reflection, gloss streak, gradient, iris, pupil, rim light, or bright pixel anywhere inside either eye. The eyes in neutral, open-mouth, listening, head-tilt, front, side, and detail views must all read as flat pure black circles like the source frames.
Canonical proportions: Copy the head-to-body-to-tentacle ratio directly from Images 2〜5. Do not use Image 1's proportions. The large hooded head is dominant. The robe torso is visibly shorter and smaller than Image 1, about 15〜20% less vertical body length, with a compact short trapezoid hem. The six lower tentacles start immediately below the short robe and spread broadly sideways. The outer curled tentacles extend well beyond the robe hem, producing a low wide base. Total tentacle spread is visibly wider than the robe body and approximately as wide as or slightly wider than the hood. Keep the six tentacles slim, naturally tapered, individually readable and overlapping like Images 2〜5; outer two make loose C curls, center tentacles hang lower. No exposed legs.
Canonical design: one Takosan only, black-to-dark-charcoal oversized smooth hooded robe, deep black hood lining, warm-white round face, two human-like arms, two separate fingerless warm-white round stubby hands, and exactly six tentacles from the lower body. Short trapezoid robe with the same small number of thick dark-gray spiral/tentacle-shaped trim lines visible in Images 2〜5. Dry matte plush-cloth plus soft clay toy material, no wet marine skin.
Layout and hierarchy: clean polished 1672x941-style 16:9 sheet on warm white. Title at upper left. Upper half labeled "CANON SOURCE POSES" contains four clearly separated isolated source-derived Takosan figures in order: "NEUTRAL", "OPEN MOUTH", "LISTENING", "HEAD TILT". Each shows the full character including the full six-tentacle base whenever visible in its source. The OPEN MOUTH figure keeps only the tiny oval speaking mouth from Image 3. The HEAD TILT figure keeps the mouth fully closed and the small deadpan tilt from Image 5. Lower half labeled "SUPPLEMENTAL TURNAROUND" contains consistent "FRONT", "SIDE", and "BACK" views created only to fill missing angles; their scale and ratios must match the canon source poses. Also include three compact detail panels labeled "SOLID BLACK EYE", "STUBBY HAND", and "WIDE SIX-TENTACLE BASE", plus a small "COLOR PALETTE". The eye detail is a pure black disk without reflection. The lower-tentacle detail clearly counts exactly six broad-spreading tentacles.
Text: Render exactly and only these labels: "TAKOSAN — TOY DIORAMA 3D", "CANON SOURCE POSES", "NEUTRAL", "OPEN MOUTH", "LISTENING", "HEAD TILT", "SUPPLEMENTAL TURNAROUND", "FRONT", "SIDE", "BACK", "SOLID BLACK EYE", "STUBBY HAND", "WIDE SIX-TENTACLE BASE", "COLOR PALETTE".
Strict priorities: 1) four faithful isolated Takosan figures derived from Images 2〜5, 2) all eyes pure flat #000000 with zero highlights, 3) source-matched compact proportions with smaller torso and wider tentacle spread, 4) exactly six lower-body tentacles and exactly two separate human arms ending in fingerless round hands, 5) supplemental side/back views inherit the canon proportions, 6) legible uncluttered sheet.
Avoid: specular eyes, catchlights, eye reflections, gray eyes, blue highlights, glossy eyeballs, Image 1's tall torso, narrow tentacle footprint, long robe, tiny cramped tentacles, fewer or more than six tentacles, uniform radial starfish layout, arms changing into tentacles, fingers, five-fingered hands, visible legs, extra characters, Yametaro, office background, laptop, desk, Tokyo Tower, dense embossed robe patterns, wet skin, rubber, silicone shine, slime, glossy tentacles, huge suckers, mouth on neutral/listening/head-tilt views, smile on head-tilt view, duplicated or misspelled labels, Japanese text, arrows, logo, watermark.
```
