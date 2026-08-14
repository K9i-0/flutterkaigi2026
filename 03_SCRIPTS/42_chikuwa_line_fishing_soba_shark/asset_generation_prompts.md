# 本番参照画像・確認画像の生成記録

新規・差し替え画像はbuilt-in `image_gen`で生成し、採用画像をこのランへ保存した。実写のよーたんと福ちゃんを含む3枚は、`02_CHARACTERS/Yotan.jpg`と`02_CHARACTERS/Fukuchan.jpg`をそれぞれの顔の唯一のidentity sourceとして使用した。

## 本番入力画像

### `scene_01_fishing_boat_start_production.png`

```text
Use case: identity-preserve and precise-object-edit.
Asset type: final 16:9 Seedance production start frame, exact frame zero, for a photoreal Japanese creature-comedy short.
Input roles: the previous start frame fixes the exact small fishing boat, port-side camera, open sea, clear morning, YOTAN position, deeply bent rod and framing. Yotan.jpg is YOTAN's sole absolute face-identity source; his basic sheet fixes his slim body, blond hair, sunglasses, black leather rock outfit, boots and exactly one black electric guitar. Fukuchan.jpg is FUKUCHAN's sole absolute face-identity source; his basic sheet fixes his slim body, center-parted black hair, oversized black jacket, white graphic T-shirt, black wide trousers, white sneakers, SPONSOR lanyard and Fukuchan name badge.
Primary edit: replace the stylized YAMETARO at screen-right with the real live-action FUKUCHAN. FUKUCHAN stands one step behind and screen-right of YOTAN, leaning toward the bent rod with natural surprised anticipation, one hand slightly raised, not touching YOTAN or the rod. Keep exactly two real Japanese men aboard.
Identity: both faces strictly match their sole canonical photos in age, bone structure, eyes, brows, nose, mouth, skin and hair. No face mixing, beautification, rejuvenation or generic substitution.
Photorealism: candid observational footage from a small crew aboard a working coastal boat. Preserve pores, faint wrinkles, natural skin variation, individual wind-blown hair, cloth weave and seams, gravity and wind in clothing, salt marks, scratches, chipped paint, wet scuffed FRP, grounded contact shadows and restrained cool morning sunlight. No plastic skin, wax faces, excessive HDR, oversharpening, airbrushing, studio glamour or theatrical posing.
Invariants: preserve composition, lens, horizon, geography, YOTAN stance, rod geometry and taut line. Exactly one guitar on YOTAN. No catch visible yet.
Avoid: YAMETARO, cartoon people, third person, fish, chikuwa, dorsal fin, shark, Soba Shark, beer, extra rods, extra guitars, text overlay, subtitles, logo, watermark or reference-sheet layout.
```

採用結果：よーたんが画面左で曲がった竿を両手保持し、福ちゃんが一歩後ろで身を乗り出す実写二人画。福ちゃんのストラップと名札、船の擦れ・濡れ、自然な朝光を維持。

### `prop_large_living_chikuwa_production.png`

```text
Use case: product-mockup.
Asset type: Seedance production master image for exactly one living ocean chikuwa.
Primary request: one flexible natural chikuwa marine organism approximately 60cm long and 12cm in diameter, preserving the familiar single hollow food cylinder, pale beige fish-paste body, caramel-brown grilled marks and continuous central hole. Taut living tissue, seawater film and droplets, capable of shallow S-curves but with no face or appendages.
Composition: entire object visible diagonally in three-quarter view on a neutral medium-gray seamless background.
Constraints: exactly one chikuwa; no eyes, mouth, gills, fins, tail, legs, tentacles, blood, damage, people, boat, ocean, text, logo or watermark.
```

### `character_sobaya_sobashark_sheet.png`

- コピー元：`03_SCRIPTS/35_soba_shark/character_sobaya_sobashark_sheet.png`
- 変更：なし。白い仮面、粗末な灰色サメ着ぐるみ、銀色補修、縫い目、尾、黒ジーンズ、白スニーカーを正本とする。
- 今回のスケール：通常の人間サイズ、全高約1.8m。巨大化せず、ラストは右舷外の水面から腰〜上半身だけを出す。

## イメージ確認用画像

次の2枚は構図と実写ルックを確認するための`preview_`画像であり、Seedanceの入力画像、始終端、複数キーフレームへは登録しない。

### `preview_scene_02_large_chikuwa_celebration.png`

```text
Use case: identity-preserve and precise-object-edit.
Asset type: final 16:9 visual-approval still for the celebration beat.
Input roles: the previous celebration image fixes the boat, morning sea, YOTAN in his black leather rock outfit with one guitar, one thrashing 60cm chikuwa, rod placement and framing. Yotan.jpg and Fukuchan.jpg are the sole face-identity sources. FUKUCHAN's sheet fixes his black outfit, SPONSOR lanyard and name badge. The chikuwa master fixes its wet beige grilled texture and hollow food shape.
Primary edit: replace the stylized YAMETARO with real FUKUCHAN. FUKUCHAN stands screen-right, never touches the chikuwa, smiles naturally and performs the signature GYUN-GYUN pose with both hands close to his cheeks. YOTAN alone holds exactly one 60cm by 12cm living chikuwa at chest height.
Action: the chikuwa actively flexes into an irregular S-curve and sprays droplets. YOTAN struggles with uneven elbows, tense shoulders, adjusted grip, rearward weight and a happy but strained expression.
Identity: strictly preserve each canonical face, age and hair. No face mixing, beautification, rejuvenation or generic substitution.
Photorealism: candid observational boat footage with pores, faint wrinkles, natural skin variation, wind-blown hair, cloth weave, wet fabric, real droplets, scratched salt-marked FRP, contact shadows and restrained morning light. No glossy ad, plastic skin, wax faces, excessive HDR, oversharpening or airbrushing.
Avoid: YAMETARO, cartoon person, FUKUCHAN touching the chikuwa, extra people, shark, dorsal fin, Soba Shark, beer, extra chikuwa, extra rod, extra guitar, text, logo, watermark or reference-sheet layout.
```

採用結果：よーたんだけがS字に暴れる大ちくわを抱えて苦戦し、実写の福ちゃんは触れずに頬の近くでギュンギュンポーズを取る。

### `preview_scene_03_soba_shark_beer_surface.png`

```text
Use case: identity-preserve and precise-object-edit.
Asset type: final 16:9 visual-approval still for the closing gag.
Input roles: the previous closing image fixes the boat, morning sea, YOTAN with empty hands, one 60cm living chikuwa flopping on deck and normal human-sized SOBA SHARK outside the rail drinking one beer mug. Yotan.jpg and Fukuchan.jpg are the sole face-identity sources. FUKUCHAN's sheet fixes his black outfit, SPONSOR lanyard and name badge. The Soba Shark sheet is the sole costume-design source.
Primary edit: replace stylized YAMETARO with real FUKUCHAN. FUKUCHAN stands center-right, hands raised close to his cheeks as a startled GYUN-GYUN variation, looking between SOBA SHARK and the chikuwa without touching anything.
Preserve action: YOTAN remains screen-left with empty hands. Exactly one 60cm chikuwa remains lower center, flopping in a strong irregular S-curve with one end 10–15cm above the wet deck and a fresh impact splash. Normal-sized SOBA SHARK remains waist-up outside the starboard rail, tilting exactly one full glass beer mug to the mouth of his mask; left hand empty; no jump.
Identity and realism: strict canonical faces and age. Preserve natural pores, wrinkles, hair, fabric weave, soaked costume seams, real glass refraction, beer foam, water droplets, salt-marked FRP and restrained morning light. No beautification, plastic skin, wax faces, excessive HDR or studio pose.
Avoid: YAMETARO, cartoon person, FUKUCHAN touching the chikuwa, giant creature, jump, actual shark, empty or extra mug, handoff, extra people, extra chikuwa, collision, injury, text, logo, watermark or reference-sheet layout.
```

採用結果：通常サイズのそばシャークが右舷外で飲酒し、よーたんの両手は空。実写の福ちゃんは頬の近くへ両手を上げ、デッキ上の大ちくわはS字に跳ね続ける。
