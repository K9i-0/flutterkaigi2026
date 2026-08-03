# environment_window_side_area_toy_diorama_3d_production.png

- Generator: built-in ImageGen
- Use case: precise object removal / reusable environment clean plate
- Media style: 窓際トイジオラマ3D (`toy_diorama_3d`)
- Edit source: `03_SCRIPTS/21_takosan_php_prompt_pun/clip1_start.png`
- Removed: たこさん、やめ太郎、および人物由来の影
- Preserved: 段ボール机、ノートPC、椅子、窓と東京タワー、暖簾、提灯、壁面ポスター、ソファ、棚、植物、午後の照明

## Final prompt

```text
Use case: precise object removal / reusable environment clean plate.
Asset type: production-ready 16:9 landscape Seedance environment reference in the established Madogiwa Toy Diorama 3D style.

Edit Image 1 only. Treat Image 1 as the exclusive visual canon for camera, framing, architecture, furniture, props, materials, lighting, depth of field, and color grading.

Primary request:
Remove ONLY the two foreground characters completely and create a clean, unoccupied version of this exact window-side workspace.

Remove exactly:
1. The entire dark hooded octopus character standing at left foreground, including hood, head, robe, arms, hands, all tentacles, suction cups, and its cast/contact shadow.
2. The entire seated human character at right foreground, including hair, face, glasses, head, torso, shirt, arms, hands, and character-derived shadows.

Reconstruct all areas formerly hidden by them:
- Continue the warm floor naturally beneath and behind the left character.
- Restore the full empty cardboard chair behind the desk where the seated character was.
- Restore any obscured portions of the cardboard desk, laptop keyboard area, background furniture, wall, window, and sunlight/shadows with seamless geometry and matching handmade materials.
- The result must look as though no characters were ever present.

Preserve unchanged:
- Exact camera position, composition, aspect ratio, and overall resolution.
- The corrugated-cardboard desk and the open laptop, including the same abstract colorful non-readable code-like bars on screen.
- The empty cardboard chair behind the desk.
- Navy noren curtain with white octopus emblem, red paper lantern, cardboard wall poster with black octopus emblem, blue sofa, green cushion, shelves, plants, woven/cardboard chairs, boxes, pencil cup, desk plant, and all handmade DIY furnishings.
- Window geometry, Tokyo Tower and skyline, blue sky and clouds.
- Warm afternoon sunlight, soft shadows, shallow depth of field, cozy palette, matte tactile toy-diorama materials.

Hard constraints:
- No people, characters, mascots, silhouettes, reflections of characters, clothing, hands, faces, hair, hoods, robes, or tentacles.
- Keep the octopus emblems on the curtain and wall poster; they are fixed environmental decorations.
- No ghost outlines, floating remnants, distorted furniture, obvious inpainting seams, or unnatural empty patches.
- No new props and do not move or redesign existing props.
- No added text, captions, labels, borders, or watermark.
- Output a polished reusable environment clean plate, not concept art.
```
