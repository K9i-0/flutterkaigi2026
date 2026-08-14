# 本番参照画像・確認画像の生成記録

新規画像はbuilt-in `image_gen`で生成し、採用画像だけをこのランへ保存した。そばシャークは過去の正本素材を変更せず、通常の人間サイズのまま複製した。

## 本番入力画像

### `scene_01_fishing_boat_start_production.png`

```text
Use case: identity-preserve
Asset type: final 16:9 Seedance production start frame for a live-action Japanese short comedy, exact frame zero.
Input images: YOTAN face reference is the sole and absolute face identity source; YOTAN character sheet fixes his slim build, black leather rock outfit, sunglasses, boots, blond hair, and exactly one black electric guitar; YAMETARO references fix his canonical deformed 3D identity, huge rounded-square head, black side-parted hair, round glasses, pink cheeks, purple patterned shirt, black pants, tiny body and proportions.
Primary request: On a small realistic Japanese coastal fishing boat at open sea in clear morning light, show exactly two Madogiwa members. YOTAN stands at the starboard rail in the left-center foreground, bracing both boots wide on the wet deck and straining backward while gripping one deeply bent fishing rod with both hands. The taut line exits frame into the sea at lower right. His black electric guitar is exactly one, secured diagonally on his back. YAMETARO stands one step behind and screen-right, leaning toward the rod with surprised anticipation, hands raised but not touching it. Both look toward the taut line and sea.
Composition: cinematic photoreal 16:9 wide-medium shot from slightly above deck height, 35mm lens, camera on port side, readable faces and upper bodies, boat bow and starboard rail visible, horizon level in the upper third. Exact opening state, ready for motion after 0.2 seconds.
Style: high-end practical live-action Japanese creature comedy, realistic boat, sea spray, wet fiberglass deck, natural skin and cloth, restrained color grade.
Constraints: strict character identity; no beautification or realistic-human conversion of YAMETARO; no fish, chikuwa, dorsal fin, shark, Soba Shark, beer, other people, extra rods, extra guitars, text, logo, watermark, split panels or character-sheet layout.
```

### `prop_large_living_chikuwa_production.png`

```text
Use case: product-mockup
Asset type: Seedance production master image for exactly one living ocean chikuwa used as the catch in a live-action Japanese creature comedy.
Primary request: Create one natural chikuwa marine organism approximately 60 centimeters long and 12 centimeters in diameter. Preserve the familiar food form: one flexible hollow cylindrical tube, pale beige fish-paste body, irregular caramel-brown grilled bands and patches, and one clean continuous central hole visible through both ends. Its taut living tissue is coated in seawater with droplets and wet highlights. It can flex into shallow S-curves when alive, but has no face or appendages.
Composition: entire object visible diagonally in three-quarter view, both outer cylinder and hollow center readable, generous padding, neutral medium-gray seamless production background. No fishing line or hook in the reference.
Style: ultra-photoreal practical creature prop and food photography, realistic fish-paste pores, subtle flexible weight, wet marine sheen, neutral cinematic lighting.
Constraints: exactly one 60cm chikuwa; no eyes, mouth, gills, fins, tail, legs, tentacles, scales, fur, bones, blood, damage, plate, packaging, people, boat, ocean, text, labels, arrows, panels, logo, watermark or signature. Do not turn it into an eel, fish, worm, rubber toy, bread, ceramic or plastic.
```

### `character_sobaya_sobashark_sheet.png`

- コピー元：`03_SCRIPTS/35_soba_shark/character_sobaya_sobashark_sheet.png`
- 変更：なし。過去素材の人物、白い仮面、粗末な灰色サメ着ぐるみ、銀色補修、縫い目、尾、黒ジーンズ、白スニーカーをそのまま正本にする。
- 今回のスケール：通常の人間サイズ、全高約1.8m。巨大化させない。ラストは右舷外の水面から腰〜上半身だけを出す。

## イメージ確認用画像

次の2枚はユーザーが構図とルックを確認するための`preview_`画像であり、Seedanceの入力画像、始終端、複数キーフレームへは登録しない。採用後にキーフレームとして使う場合だけ参照素材表を更新する。

### `preview_scene_02_large_chikuwa_celebration.png`

```text
Use case: precise-object-edit and identity-preserve.
Asset type: final cinematic 16:9 visual-approval still for the celebration beat on the same small Japanese fishing boat in clear morning light.
References: preserve the exact boat geography and production look; YOTAN's canonical face, blond hair, sunglasses, slim black-leather rock outfit and exactly one black electric guitar; YAMETARO's canonical tiny deformed 3D design, huge rounded-square head, round glasses and purple patterned shirt; the wet beige grilled texture and hollow food shape of the living chikuwa.
Primary request: YOTAN alone holds exactly one living chikuwa, approximately 60cm long and 12cm thick, horizontally at chest height. The chikuwa is actively thrashing, visibly bent into a pronounced S-curve, spraying droplets and twisting its ends in opposite directions. YOTAN is happy but clearly struggling: elbows at uneven heights, torso leaning back, grip being adjusted, tense shoulders and an awkward strained smile. He must not look calm or effortless. YAMETARO stands nearby cheering with both hands raised and never touches the chikuwa.
Composition: same port-side 40–50mm medium-wide angle, YOTAN screen-left, YAMETARO screen-right, entire chikuwa visible and clearly much shorter than YOTAN's height. One rod rests safely against the starboard rail. Wet deck and morning sea remain continuous.
Constraints: exactly two characters and one chikuwa; preserve both identities; chikuwa has no face, eyes, mouth, fins, tail or limbs; no shark, dorsal fin, Soba Shark, beer, extra people, extra rods, duplicate guitars, text, logo, subtitle, watermark, split screen, arrows or reference-sheet layout.
```

採用結果：大ちくわは約60cmで浅いS字にしなり、水滴を撒きながら暴れている。よーたんだけが抱え、左右の肘と体幹をずらして苦戦し、やめ太郎は触れずに喜ぶ構図。

### `preview_scene_03_soba_shark_beer_surface.png`

```text
Use case: precise-object-edit and identity-preserve.
Asset type: final cinematic 16:9 visual-approval still for the closing gag on the same small Japanese fishing boat.
References: preserve the boat, morning sea, YOTAN and YAMETARO continuity; preserve SOBA SHARK exactly as the canonical normal human-sized masked man in a shabby gray fabric shark costume; preserve the one 60cm living chikuwa's wet beige grilled texture and hollow food shape.
Primary request: At screen-right outside the starboard rail, normal human-sized SOBA SHARK has surfaced vertically with only his waist and upper body above the water. He is not giant and does not jump. His white mask, felt teeth, crooked dorsal fin, gray arms, seams and silver repair patch are readable. With his right hand he is already tilting exactly one large clear glass mug full of amber beer and white foam to the narrow mouth of his mask and drinking. His left hand is empty.
On deck, YOTAN stands startled with both hands empty after dropping the catch. Exactly one approximately 60cm living chikuwa lies on the wet deck and is still actively flopping: its flexible body bends into a strong S-curve, one end lifted 10–15cm, with fresh droplets and a small splash showing a deck impact. YAMETARO raises his hands in surprise and looks between SOBA SHARK and the flopping chikuwa.
Composition: stable 35mm three-subject shot—YOTAN screen-left, flopping chikuwa lower center, YAMETARO center-right, SOBA SHARK outside the rail at screen-right. Keep every subject readable; do not let spray hide the mask, mug or chikuwa.
Constraints: exactly normal human scale; exactly one full beer mug in the right hand; YOTAN holds no chikuwa; no jump, airborne pose, giant creature, actual shark, handoff or visible source for the mug, empty mug, bottle, can, extra people, extra chikuwa, collision, injury, text, logo, subtitle, watermark, split screen or arrows.
```

採用結果：通常サイズのそばシャークが右舷外で上半身を出して満杯ジョッキを飲み、よーたんの両手は空。大ちくわはデッキ上でS字に曲がり、水滴を飛ばして跳ね続ける構図。
