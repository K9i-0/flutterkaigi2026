# character_takosan_basic_sheet.png

- Generator: built-in ImageGen
- Use case: identity-preserve
- Media style: 窓際トイジオラマ3D (`toy_diorama_3d`)。たこさんの標準媒体表現
- Edit target: `03_SCRIPTS/00_TEMPLATES/characters/character_takosan_basic_sheet.png` の旧版
- Identity references:
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip1_start.png` — `NEUTRAL`
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip1_end.png` — `OPEN MOUTH`
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip2_end.png` — `LISTENING`
  - `03_SCRIPTS/21_takosan_php_prompt_pun/clip3_end.png` — `HEAD TILT`
- Precedence: 上記4枚から切り出した完成フレーム準拠ポーズを最優先し、三面図は不足角度だけを補完する
- Output: 1672x941 RGB PNG
- Follow-up correction: 左右外側2本だけでなく、前後方向を向く内側触手もすべて先細りのJ字／C字カールで終端する
- Output SHA-256: `527c6eabf2e50e8e82f825916d31bb4835ceb3750255f8fe9aac0cc9c9682d7f`

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

## Tentacle-tip correction prompt 1

```text
Use case: precise-object-edit
Asset type: Seedance用の再利用可能な16:9横長・窓際トイジオラマ3D基本キャラクター設定シート
Primary request: Image 1を極小範囲だけ修正する。全キャラクタービューと「WIDE SIX-TENTACLE BASE」詳細パネルにある触手のうち、カメラ正面／背面方向へ突き出して先端が丸い切断面・足先・ソーセージ端のように見える内側の触手先端だけを、細くテーパーした自然な小カールへ直す。
Image role: Image 1 is the edit target and defines absolutely everything except the incorrect blunt inner tentacle tips.
Change only: 各触手の末端20〜30%だけ。左右外側の大きなC字カール2本は既に正しいので形・位置・太さを完全に維持する。中央および前後方向を向く残りの触手は、カメラへ真っ直ぐ突き出して円形端面を見せず、先端直前で少し左右へ曲がり、細くテーパーした小さなJ字または緩いC字のフックで終わる。各先端の輪郭が横から読め、触手がそのまま連続して湾曲していることが明確に見える。前3本と後ろ3本を含め、どの視点でも丸くぶつ切りの先端を残さない。カール方向は隣り合う触手同士で軽く交互にし、絡まない。小型で平坦な灰色吸盤は円形端面へ集中させず、湾曲した触手の下面に沿って先端へ向かい徐々に小さくなる。
Tentacle geometry: exactly six tentacles total per full-body view, same roots and same wide footprint as Image 1. Root and middle thickness stay unchanged. Each terminal segment narrows smoothly; very tip thickness is about 25〜35% of root thickness. Curl is compact and soft, not a tight spiral, and does not make the tentacles longer enough to disturb the layout. No circular cap or front-facing stump is visible.
Apply consistently: 修正を上段のNEUTRAL、OPEN MOUTH、LISTENING、HEAD TILT、下段のFRONT、SIDE、BACK、WIDE SIX-TENTACLE BASEへ一貫して反映する。SIDEとBACKでもカメラ方向へ向く触手の末端を横へ返し、先細りのカール輪郭を見せる。
Keep unchanged exactly: 1672x941の16:9構成、暖白背景、全パネル配置、罫線、余白、全英語見出しと綴り、4つの正典ポーズ、補完三面図、頭・胴体・触手の比率、短い胴体、広い触手ベース、フード、顔、口の有無、首傾げ、腕2本、指なしの白い丸手、ローブ模様、素材、影、色パレット。全ての目は反射・ハイライトのない完全な純黒#000000円のまま一切変更しない。
Strict priorities: 1) ぶつ切りに見える全ての内側触手先端を先細りカールへ変更、2) exactly six tentacles and same wide spread, 3) outer lateral curls unchanged, 4) every non-tentacle pixel and all labels unchanged.
Avoid: blunt rounded tentacle ends, flat circular end caps, leg-like stumps, sausage ends, tentacles pointing directly into camera, suction cups clustered on an end face, bulbous tips, extra tentacles, missing tentacles, tentacle fusion, tight spiral knots, long trailing tentacles, changed outer curls, changed poses, changed proportions, changed eyes, eye highlights, text changes, misspellings, duplicated labels, new text, arrows, watermark.
```

## Tentacle-tip correction prompt 2

```text
Use case: precise-object-edit
Asset type: Seedance用16:9キャラクター設定シート
Primary request: Image 1の一回目修正版には、中央の内側触手がまだ真下／カメラ方向へ直進して、丸い足先・切断端・つま先のように終わっている失敗が残っている。そこだけを再修正し、各全身図と「WIDE SIX-TENTACLE BASE」で6本すべての触手先端に、横から輪郭が見える明確な先細りフックを与える。
Change only the remaining blunt tips: 左右外側2本の大きなC字カールは完全に維持。内側4本は一本も垂直の丸端で終わらせない。各内側触手の末端30〜40%を画面平面内で左または右へ曲げ、その後先細りしながら上向きまたは斜め上向きに返す、小さく明確なJ字カールにする。隣り合う4本はカール方向を左・右・左・右と交互にする。中央正面の触手も必ず左右どちらかへスイープしてから上へ返り、先端の側面シルエットが見える。カメラへ向く円形端面を完全になくす。
Required visual test: 各触手を根元から目で追うと、6本すべてが途切れずに細くなり、最後は尖りすぎない細いフック状カールとして終わる。6本中0本が丸い棒、脚、足指、ソーセージ、円柱キャップに見える。「WIDE SIX-TENTACLE BASE」パネルでは、外側2つの大カール＋内側4つの小Jカール＝合計6つのカール先端を明確に数えられる。
Suckers: 吸盤は湾曲した下面に沿い、カール先端へ向かって徐々に小さくなる。先端の正面に吸盤の丸い束や円形キャップを作らない。
Keep unchanged exactly: Image 1の全レイアウト、全英語見出し、4正典ポーズ、三面図、頭身、短い胴体、広い触手ベース、触手根元と中間の太さ、触手6本の根元位置、フード、顔、純黒で無反射の目、口、腕、丸手、ローブ模様、色、素材、影、背景、パレット。触手末端以外を変更しない。
Strict priorities: 1) all six tentacle tips visibly curled in every applicable panel, including all four inner tips, 2) no blunt inner stump remains, 3) exactly six tentacles, 4) everything else pixel-stable.
Avoid: any straight-down blunt inner tentacle, rounded toe, foot, leg, sausage tip, circular end face, suction-cup cluster on end face, hidden tip pointing into camera, extra tentacles, fused tentacles, missing tentacles, long trailing curls, tight spiral knots, changed outer curls, changed labels, changed eyes, eye highlights, new text, watermark.
```
