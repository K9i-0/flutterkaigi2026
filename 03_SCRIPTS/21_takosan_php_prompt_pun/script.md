# Short Video: "PHP Means What?"

## Format

- Target length: approximately 13 seconds
- Structure: 3 clips, exactly one speaker per clip
- Aspect ratio: 16:9
- Genre: cheerful office slice-of-life wordplay comedy
- Visual style: polished anime-style 3D illustration, warm afternoon light, playful reaction timing
- Location: the Window-Side Tribe area inside Acciden-Ture Corporation, with a stable cardboard desk, an open laptop, handmade decorations, and Tokyo Tower visible through the window
- Safety premise: "パワ・ハラ・プロンプト" is only Yametaro's absurd expansion of the initials PHP. No actual harassment, threat, humiliation, coercion, hostile workplace behavior, or unhappy victim appears.

## Story summary

Takosan calmly asks Yametaro whether he can write PHP. Yametaro answers with enormous confidence, then proudly reveals that he thinks PHP means "Power-Hara-Prompt." Takosan gives one tiny deadpan reaction while Yametaro smiles at his own answer. Both remain comfortable friends, and the event is real rather than a dream.

## Character and design invariants

- Takosan: preserve the black hooded robe, white face, black round eyes, two human arms, and all octopus tentacles. The robe and tentacles never change. Takosan stays calm and nearly expressionless.
- Yametaro: preserve the exact stylized 42-year-old adult design, purple dress shirt, round glasses, and comic confidence.
- Both characters remain cheerful and friendly. No bullying, actual harassment, threat, intimidation, gloomy mood, injury, or abusive workplace behavior.

## Prop state ledger

| Prop | C1 start | C1 end = C2 start | C2 end = C3 start | C3 end |
|---|---|---|---|---|
| Laptop | OPEN on the cardboard desk; abstract colored code lines with NO readable text | OPEN, unchanged | OPEN, unchanged | OPEN, unchanged |
| Cardboard desk | Stable and clear except for the laptop | Stable and unchanged | Stable and unchanged | Stable and unchanged |

Logical check: no prop changes state. Every shared boundary uses the exact same image file, so the laptop and desk cannot jump between clips.

## Dialogue audio (all voices pre-generated locally — Seedance must NOT generate any voice)

| File | Clip | Character | Voice (engine) | Line (ja) | Duration |
|---|---:|---|---|---|---:|
| `clip1_line1_takosan.wav` | 1 | Takosan | VOICEVOX:Voidoll (style 89, speed 1.00) | パパ、PHPって書ける？ | 2.71s |
| `clip2_line1_yametaro.wav` | 2 | Yametaro | Irodori-TTS (ref: `Yametaro_voice.wav`, seed 7) | もちろん書けるで！ | 3.04s |
| `clip3_line1_yametaro.wav` | 3 | Yametaro | Irodori-TTS (ref: `Yametaro_voice.wav`, seed 7) | パワ・ハラ・プロンプトのことやろ？ | 3.12s |

---

## Clip 1: Takosan asks the question

### Time

0:00-0:04

### First frame

A warm medium two-shot in the Window-Side Tribe area. Takosan stands on frame left beside a stable cardboard desk, preserving the black hooded robe, white face, black round eyes, two human arms, and all tentacles. Yametaro sits on frame right at an OPEN laptop, preserving his purple shirt, round glasses, and exact stylized design. The screen shows only abstract colored code lines with no readable characters. Tokyo Tower is visible through the window. Both mouths are closed; the mood is relaxed and friendly.

### Last frame

The exact same composition, lighting, location, identities, and props. Takosan is mid-question with the small mouth area visibly open; one human hand makes a polite gesture toward the laptop. Yametaro looks toward Takosan with his mouth CLOSED, listening with a neutral-friendly expression. The laptop remains OPEN and unchanged.

### Prop states

- Laptop — First: OPEN with abstract non-readable code lines. Last: OPEN and unchanged; nobody types, closes it, moves it, or changes the screen.
- Cardboard desk — stable and unchanged throughout.

### Dialogue and sound

- Takosan — the mysterious white-faced figure in the black hooded robe — mouths "パパ、PHPって書ける？" (lip-sync to the attached audio file `clip1_line1_takosan.wav` — voice comes from the attached pre-generated audio, NOT generated).
- Yametaro does NOT speak; his mouth stays CLOSED and he only listens.
- Sound design: soft office ambience and a tiny curious synth pluck after the question. Keep effects below the attached dialogue.

### Seedance motion prompt

```text
Interpolate precisely from Frame A to Frame B in one continuous warm office-comedy shot. Preserve Takosan's black hooded robe, white face, black round eyes, two human arms, and all octopus tentacles exactly; the robe and tentacles never change. Preserve Yametaro's exact stylized adult design, purple dress shirt, and round glasses. The OPEN laptop remains stationary on the stable cardboard desk and its screen keeps the same abstract colored code lines with NO readable text. ONLY Takosan (@Image3, the mysterious white-faced figure in the black hooded robe with tentacles) speaks. Takosan turns slightly toward Yametaro, makes one small polite hand gesture toward the laptop, and asks "パパ、PHPって書ける？" in exact sync with @Audio1. Yametaro (@Image4, the stylized man in the purple shirt and round glasses) does NOT speak; his mouth stays CLOSED and he only turns his eyes toward Takosan to listen. Use @Audio1 AS-IS as the dialogue audio and do NOT generate any voice — no synthesized speech, no narration. Gentle camera push toward Takosan, warm afternoon light, Tokyo Tower outside, polished anime-style 3D illustration, cheerful friends, 16:9. No readable generated text, random letters, watermark, actual harassment, threat, humiliation, coercion, or gloomy mood.
```

### CapCut inputs (Clip 1)

- Start frame (Frame A): `clip1_start.png` (`@Image1`)
- End frame (Frame B): `clip1_end.png` (`@Image2`)
- Reference images (identity/design lock): `02_CHARACTERS/Takosan.png` (`@Image3`), `02_CHARACTERS/Yametaro.jpg` (`@Image4`). These are identity/design references, not composition references.
- Audio (attach to Seedance as input): `clip1_line1_takosan.wav` (`@Audio1` — spoken only by Takosan) — use AS-IS as the dialogue audio track.
- Motion prompt: use the Seedance motion prompt above verbatim.
- Duration: 4s
- Aspect: 16:9

---

## Clip 2: Yametaro answers with confidence

### Time

0:04-0:08

### First frame

Use `clip1_end.png` unchanged. Takosan is mid-question with one human hand gesturing toward the laptop. Yametaro looks toward Takosan with his mouth CLOSED. The laptop remains OPEN and unchanged.

### Last frame

The same composition, lighting, location, identities, and props. Yametaro turns toward Takosan, points one thumb proudly toward his chest, and finishes his confident answer with a broad friendly grin, mouth open mid-speech. Takosan's mouth is CLOSED and Takosan only listens calmly. The laptop and cardboard desk remain unchanged.

### Prop states

- Laptop — OPEN and unchanged throughout; nobody types, closes it, moves it, or changes the screen.
- Cardboard desk — stable and unchanged throughout.

### Dialogue and sound

- Yametaro — the stylized man in the purple shirt and round glasses — mouths "もちろん書けるで！" (lip-sync to the attached audio file `clip2_line1_yametaro.wav` — voice comes from the attached pre-generated audio, NOT generated).
- Takosan does NOT speak; the mouth stays CLOSED and Takosan only listens.
- Sound design: soft office ambience and one upbeat confidence sting after the line. Keep effects below the attached dialogue.

### Seedance motion prompt

```text
Continue seamlessly from the exact shared first frame in the same warm office-comedy two-shot. Preserve Yametaro's exact stylized adult design, purple dress shirt, and round glasses. Preserve Takosan's black hooded robe, white face, black round eyes, two human arms, and all tentacles exactly. The OPEN laptop remains stationary on the stable cardboard desk with the same abstract colored code lines and NO readable text. ONLY Yametaro (@Image3, the stylized man in the purple shirt and round glasses) speaks. He turns toward Takosan, points one thumb proudly toward his chest, grins with harmless confidence, and says "もちろん書けるで！" in exact sync with @Audio1. Takosan (@Image4, the white-faced figure in the black hooded robe with tentacles) does NOT speak; Takosan's mouth stays CLOSED and the body remains calm, only listening. Use @Audio1 AS-IS as the dialogue audio and do NOT generate any voice — no synthesized speech, no narration. Hold a stable two-shot with an almost imperceptible push toward Yametaro's grin. Warm afternoon light, polished anime-style 3D illustration, cheerful friends, 16:9. No readable generated text, random letters, watermark, actual harassment, threat, humiliation, coercion, or gloomy mood.
```

### CapCut inputs (Clip 2)

- Start frame (Frame A): `clip1_end.png` (`@Image1`) — exact same file as Clip 1 Frame B.
- End frame (Frame B): `clip2_end.png` (`@Image2`)
- Reference images (identity/design lock): `02_CHARACTERS/Yametaro.jpg` (`@Image3`), `02_CHARACTERS/Takosan.png` (`@Image4`). These are identity/design references, not composition references.
- Audio (attach to Seedance as input): `clip2_line1_yametaro.wav` (`@Audio1` — spoken only by Yametaro) — use AS-IS as the dialogue audio track.
- Motion prompt: use the Seedance motion prompt above verbatim.
- Duration: 4s
- Aspect: 16:9

---

## Clip 3: The confidently wrong expansion

### Time

0:08-0:13

### First frame

Use `clip2_end.png` unchanged. Yametaro points one thumb proudly toward his chest and smiles with his mouth open mid-speech. Takosan remains calm with mouth CLOSED. The laptop and cardboard desk are unchanged.

### Last frame

The same composition, lighting, location, identities, and props. Yametaro happily presents his absurd answer with both palms open toward the laptop, mouth open on the final syllable, still completely confident. Takosan remains nearly expressionless with mouth CLOSED and makes one tiny deadpan sideways head tilt. The laptop remains OPEN with the same abstract code lines. Both remain friendly and comfortable.

### Prop states

- Laptop — OPEN and unchanged throughout; nobody types, closes it, moves it, or changes the screen.
- Cardboard desk — stable and unchanged throughout.

### Dialogue and sound

- Yametaro — the stylized man in the purple shirt and round glasses — mouths "パワ・ハラ・プロンプトのことやろ？" (lip-sync to the attached audio file `clip3_line1_yametaro.wav` — voice comes from the attached pre-generated audio, NOT generated).
- Takosan does NOT speak; the mouth stays CLOSED and Takosan only makes a tiny deadpan head tilt.
- Sound design: soft office ambience, a tiny three-note pluck matching the three-part phrase, then a dry wooden click on Takosan's reaction. Keep effects below the attached dialogue.

### Seedance motion prompt

```text
Continue seamlessly from the exact shared first frame. Preserve the composition, warm office location, all character identities, and every prop state. Preserve Yametaro's exact stylized adult design, purple shirt, and round glasses. Preserve Takosan's black hooded robe, white face, black round eyes, two human arms, and all tentacles exactly. The OPEN laptop remains stationary on the stable cardboard desk with the same abstract colored code lines and NO readable text. ONLY Yametaro (@Image3, the stylized man in the purple shirt and round glasses) speaks. He releases the thumb-to-chest pose, cheerfully opens both palms toward the laptop as if explaining something obvious, and says "パワ・ハラ・プロンプトのことやろ？" in exact sync with @Audio1, staying friendly and proudly mistaken. Takosan (@Image4, the white-faced figure in the black hooded robe with tentacles) does NOT speak; Takosan's mouth stays CLOSED, and only after Yametaro finishes, Takosan gives one tiny deadpan sideways head tilt. The phrase is wordplay only: depict NO actual harassment, abusive conduct, threat, intimidation, humiliation, coercion, or unhappy victim. Use @Audio1 AS-IS as the dialogue audio and do NOT generate any voice — no synthesized speech, no narration. Keep the camera steady during the line, then widen slightly for the silent reaction and hold the final beat. Warm afternoon light, polished anime-style 3D illustration, cheerful harmless office comedy, 16:9. No readable generated text, random letters, watermark, or gloomy mood.
```

### CapCut inputs (Clip 3)

- Start frame (Frame A): `clip2_end.png` (`@Image1`) — exact same file as Clip 2 Frame B.
- End frame (Frame B): `clip3_end.png` (`@Image2`)
- Reference images (identity/design lock): `02_CHARACTERS/Yametaro.jpg` (`@Image3`), `02_CHARACTERS/Takosan.png` (`@Image4`). These are identity/design references, not composition references.
- Audio (attach to Seedance as input): `clip3_line1_yametaro.wav` (`@Audio1` — spoken only by Yametaro) — use AS-IS as the dialogue audio track.
- Motion prompt: use the Seedance motion prompt above verbatim.
- Duration: 5s
- Aspect: 16:9

---

## Keyframe generation prompts

### `clip1_start.png`

```text
Use case: illustration-story. Asset type: first-frame still for a 16:9 animated short. Image 1 is Takosan's identity reference and Image 2 is Yametaro's identity reference; preserve both designs exactly. Create a warm medium two-shot in the friendly Window-Side Tribe area of a fictional Tokyo IT company. Takosan stands on frame left beside a stable cardboard desk, with the canonical black hooded robe, white face, black round eyes, two human arms, and all octopus tentacles. Yametaro sits on frame right at an OPEN laptop, with the canonical purple dress shirt, round glasses, and exact stylized adult design. The laptop screen shows abstract colored code lines with NO readable text. Tokyo Tower is visible through the large window. Both mouths are CLOSED. Polished comedic anime-style 3D illustration, clean shapes, warm afternoon light, relaxed cheerful mood. No readable generated text, random letters, captions, watermark, extra people, aggression, harassment, gloomy mood, altered robe, missing tentacles, or altered character design.
```

### `clip1_end.png`

```text
Use case: identity-preserve. Image 1 is the edit target `clip1_start.png`; Image 2 is Takosan's identity reference; Image 3 is Yametaro's identity reference. Preserve the exact framing, location, lighting, character identities, laptop, desk, and prop positions. Change ONLY the poses: Takosan is mid-question with the small mouth area visibly open and one human hand making a polite gesture toward the laptop; Yametaro looks toward Takosan with his mouth CLOSED, listening with a neutral-friendly expression. The laptop remains OPEN with the same abstract non-readable code lines. Preserve Takosan's robe and every tentacle, and preserve Yametaro's purple shirt, round glasses, and exact design. No readable text, random letters, watermark, extra people, aggression, harassment, prop changes, or Yametaro speaking.
```

### `clip2_end.png`

```text
Use case: identity-preserve. Image 1 is the edit target `clip1_end.png`; Image 2 is Yametaro's identity reference; Image 3 is Takosan's identity reference. Preserve the exact framing, location, lighting, character identities, laptop, desk, and prop positions. Change ONLY the poses: Yametaro turns toward Takosan, points one thumb proudly toward his chest, smiles broadly, and has his mouth open mid-speech; Takosan remains calm with mouth CLOSED and only listens. The laptop remains OPEN with the same abstract non-readable code lines. Preserve Takosan's robe and every tentacle, and preserve Yametaro's purple shirt, round glasses, and exact design. No readable text, random letters, watermark, extra people, aggression, harassment, prop changes, or Takosan speaking.
```

### `clip3_end.png`

```text
Use case: identity-preserve. Image 1 is the edit target `clip2_end.png`; Image 2 is Yametaro's identity reference; Image 3 is Takosan's identity reference. Preserve the exact framing, location, lighting, character identities, laptop, desk, and prop positions. Change ONLY the poses: Yametaro cheerfully opens both palms toward the laptop and has his mouth open mid-speech; Takosan keeps the mouth CLOSED and gives one tiny deadpan sideways head tilt. Both remain friendly and comfortable. The laptop remains OPEN with the same abstract non-readable code lines. Preserve Takosan's robe and every tentacle, and preserve Yametaro's purple shirt, round glasses, and exact design. The phrase is harmless wordplay only; no actual harassment or unhappy victim. No readable text, random letters, watermark, extra people, aggression, prop changes, or Takosan speaking.
```

## Generation & assembly protocol (REQUIRED — read before generating anything in CapCut)

### Step 1 — Pilot clip first (batch generation is FORBIDDEN until the pilot passes)

Generate ONLY Clip 1, then verify ALL of the following before touching any other clip:
- [ ] The dialogue audio in the output is the attached wav AS-IS (no synthesized voice, no doubled voices)
- [ ] The CORRECT character lip-syncs to each line (the speaker named in the prompt moves their mouth; every non-speaker's mouth stays closed)
- [ ] Motion, poses and prop states match the Motion prompt and the Prop state ledger
- [ ] The clip duration equals the Duration specified in the CapCut inputs table (NOT the ~8s default)
If any check fails, fix the inputs/prompt and regenerate Clip 1 until all pass.
Only then generate the remaining clips, and re-run at least the audio + duration checks on every clip.

### Step 2 — Prompts are verbatim

Paste each clip's Motion prompt into CapCut EXACTLY as written in this file.
Do NOT summarize, shorten, or paraphrase it. If it seems too long, do not compress it —
go back to the script and split the clip instead.

### Step 3 — Final audio track (assembly)

The audio embedded in the generated clips is NOT the final audio, even when the wav was
attached at generation time. When assembling the final video on the CapCut timeline:
1. Mute (or delete) the audio embedded in every generated clip.
2. Lay the original wav files from the Dialogue audio table onto the timeline as the
   final dialogue track, aligned to each character's lip movements.
3. Play back the full timeline before export and confirm every line sounds exactly like
   the local VOICEVOX / Irodori-TTS takes (the source wavs are the single source of truth).

## Credits

- Required on-screen credit: `VOICEVOX:Voidoll`
- On-screen credit (add in CapCut as an end-card or small overlay on the final clip): `VOICEVOX:Voidoll`
- Add the credit with CapCut's text tool. Do NOT render it through Seedance or in the keyframe images.
