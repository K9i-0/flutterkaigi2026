# 窓際族物語 キャラクター同一性防衛プロンプト集

Gemini（`generate_image`）は、テキストプロンプトだけを渡すと一般的な人間・能面・侍・アニメ調の解釈に引きずられ、キャラクター固有のデザインが崩壊します。
キャラクター同一性を維持するために、**正典シートの添付**と**パーツ単位の厳格な逐語指定（ポジティブ指示＋禁止事項）**を必ずセットで適用します。

---

## 1. そば屋 (Sobaya)

### 正典参照画像
- `03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png`
- または `02_CHARACTERS/Sobaya.jpg`

### パーツ別必須指定（Positive）
- **仮面**: `A completely smooth, featureless, matte white egg-shaped ceramic/porcelain mask covering the entire face.`
- **目**: `Two simple, pitch-black hollow round holes for the eyes. Completely hollow, no eyeballs, no pupils, no sclera, no iris.`
- **隈取（赤ライン）**: `Two vertical, bold solid red stripes running straight down continuously through each black eye hole from top of the mask to bottom.`
- **額の点**: `A single small black circular dot centered on the forehead above the eyes.`
- **口**: `A narrow, subtle horizontal black slit for the mouth.`
- **肌色**: `Neutral ashen grey skin tone on all exposed skin (neck, hands, forearms, ears).`
- **体格**: `Extremely muscular and thick-set build, very wide thick neck, massive shoulders.`
- **衣装（通常形）**: `Dark grey or black short-sleeve work shirt, dark apron. Often holds a large beer mug.`

### 禁止事項（Negative Constraints）
- `NO human facial features on the mask: NO sculpted nose bridge, NO nostrils, NO realistic human lips, NO eyelids, NO eyelashes.`
- `NO realistic human eyes inside the holes; they must remain pure hollow black voids.`
- `NO flesh-colored/peach skin; skin MUST be ashen neutral grey.`
- `DO NOT remove, shift, tilt, or make translucent the white mask; the mask must fit securely and cover the face completely.`

---

## 2. たこさん (Takosan - 窓際トイジオラマ3D版)

### 正典参照画像
- `03_SCRIPTS/00_TEMPLATES/characters/character_takosan_basic_sheet.png`
- （旧写実版や廃止済みシートは使用しない）

### パーツ別必須指定（Positive）
- **スタイル**: `Toy diorama 3D style, soft matte vinyl / clay figurine aesthetic, clean miniature proportions.`
- **頭部・顔**: `Smooth rounded white face peeking out from inside a large oversized black hooded robe. Two simple solid glossy black bead eyes. Minimal, expressionless, mysterious alien-like presence.`
- **手・腕**: `Two human-like upper arms coming out of the robe sleeves, ending in cute, small, round white mitt-like hands with NO separated fingers (smooth nub hands).`
- **触手（下半身）**: `Six slender, dark cephalopod tentacles emerging from beneath the bottom hem of the black robe.`

### 禁止事項（Negative Constraints）
- `NO realistic human face, NO mouth, NO nose, NO complex anime eyes.`
- `Arms must NOT turn into tentacles; tentacles ONLY emerge from the bottom hem of the robe.`
- `Hands must NOT have five fingers; hands are smooth, rounded white nubs.`
- `DO NOT use realistic slimy octopus textures; keep the matte designer-toy / miniature diorama finish.`

---

## 3. 実写メンバー（とーくん、よーたん、福ちゃん、おかやまん）

実写メンバーは「似ている別人」や「アニメ風」にしてはならず、本人の顔立ちを最優先で維持します。

### 正典参照画像
| 人物 | 正典写真 | 設定ファイル |
|---|---|---|
| とーくん | `02_CHARACTERS/Tokun.jpg` | `02_CHARACTERS/03_Tokun.md` |
| よーたん | `02_CHARACTERS/Yotan.jpg` | `02_CHARACTERS/04_Yotan.md` |
| 福ちゃん | `02_CHARACTERS/Fukuchan.jpg` | `02_CHARACTERS/05_Fukuchan.md` |
| おかやまん | `02_CHARACTERS/Okayaman.jpg` | `02_CHARACTERS/07_Okayaman.md` |

### 共通指定構文
```text
STRICT FACIAL IDENTITY MANDATE:
The character must be the exact same real person as shown in the canonical reference photo [Person_Name.jpg].
Preserve exact facial bone structure, eye shape, eyebrows, nose, mouth contours, hairline, and skin texture.
Do NOT beautify, anime-fy, de-age, or replace with a generic Japanese model.
```

---

## 4. やめたろう (Yametaro)

### 正典参照画像
- `03_SCRIPTS/00_TEMPLATES/characters/character_yametaro_basic_sheet.png`
- または `02_CHARACTERS/Yametaro.jpg`

### パーツ別必須指定（Positive）
- `Weary, slumped office worker with messy disheveled dark hair and heavy dark circles (bags) under eyes.`
- `Loose, unbuttoned collar, crooked tie, wrinkled white business shirt.`
- `Tired, melancholic, but relatable Japanese salaryman aesthetic.`

---

## 5. ゆめみん (Yumemin)

### 正典参照画像
- `03_SCRIPTS/00_TEMPLATES/characters/character_yumemin_basic_sheet.png`
- （3D版の場合は `character_yumemin_toy_diorama_3d_basic_sheet.png`）

### パーツ別必須指定（Positive）
- `Cute dreamlike fairy / mascot creature with fluffy, cloud-like pastel features.`
- `Soft pastel color palette, gentle round silhouette.`

---

## 6. ゆめテレアナウンサー (Yume Tele Anchor)

### 正典参照画像
- `03_SCRIPTS/00_TEMPLATES/characters/character_yume_tele_anchor_basic_sheet.png`
- または `02_CHARACTERS/YumeTeleAnchor.png`

### パーツ別必須指定（Positive）
- `Professional Japanese female news anchor in a modern television news studio.`
- `Neat professional broadcast hairstyle, elegant studio blazer, calm neutral journalistic expression.`
- `News studio background with monitors, lighting grids, and news desk.`
- `STRICT CLEAN PLATE: NO rendered subtitles, NO fake lower-third ticker text, NO channel logos burned in (Remotion will overlay exact broadcast graphics later).`
