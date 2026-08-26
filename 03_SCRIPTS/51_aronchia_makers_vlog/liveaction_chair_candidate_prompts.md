# episode_02 実写アーロンチュア候補 — ImageGenプロンプト記録

選定結果: 2026-08-26にAを採用。採用透過PNGは`prop_aronchia_completed_chair_production.png`へ正式配置し、比較用画像とB・Cは削除した。以下は生成判断の記録として残す。

## 共通参照

- `01_WORLD/story_timeline/episode_02.png`
- 用途: Wan 3.0で使う完成アーロンチュアの実写参照候補
- 共通ロック: そば屋、ビール、窓際の机、書類、紙コップ、`窓際族`の貼り紙、積み上げた配送用段ボール箱による椅子
- 禁止: 洗練された段ボール家具、曲線的な背もたれ、通気穴、クッション、キャスター、金属、プラスチック、CGI、ゲーム画面

## Candidate A — Faithful

Recreate the source as a convincing live-action photograph while preserving its exact story, composition and improvised chair concept. Keep Sobaya centered beside the window desk, holding one large beer mug. The chair must be a crude oversized structure made from intact rectangular shipping boxes: three stacked back boxes, two bulky box armrests, one box seat, one central cube base, side box blocks and many visible packing-tape patches. Preserve the desk clutter and handwritten signs. Use a 16:9 eye-level front-left three-quarter documentary view, flat believable office daylight and realistic cardboard, tape, paper, glass and beer. Do not redesign the chair.

## Candidate B — Full Chair

Translate the source into a live-action office documentary still using a slightly lower and wider camera so the complete box-chair construction is especially legible. Use at least eight recognizable closed shipping boxes with visible flaps, dents, crushed corners, seams and messy tape. Make the high back, both armrests, central base box and side supports clearly visible. Keep Sobaya seated with beer and the desk immediately beside him. Use neutral fluorescent light mixed with window daylight. Preserve crude everyday realism; no polished product design.

## Candidate C — Lived-in

Produce a candid live-action documentary version of the source, emphasizing the chair as a pile of office delivery boxes that happens to function as a chair. Preserve the uneven three-carton back tower, large carton armrests, low box seat, central support box, side blocks, dents, scuffs and lifting tape edges. Keep the desk crowded with paper stacks, an open carton, pens and cups, with normal employees working in the background. Use a 16:9 handheld 35mm view from the source's front-left side and mixed late-afternoon daylight and office fluorescent light.

## 文字監査

当初の実写シーン3候補は元絵の字形へ強く引かれ、`アーロンチェア`に近い表記になった。Wan参照用の椅子単体版では、正しい文字参照`prop_aronchia_handwritten_final.png`を使い、3案とも`アーロンチュア`へ修正済み。

## 椅子単体・透過候補

- ImageGenモード: 参照画像付き写実編集（単色緑背景で生成後、クロマキー透過）
- 共通指示: 人物、机、オフィス、ビール、紙類、道具をすべて除去し、段ボール椅子だけを全身で表示
- 背景指示: 完全に均一な`#00FF00`、床・影・反射・グラデーションなし
- 文字指示: 正確な文字列`ア・ー・ロ・ン・チ・ュ・ア`。`チェア`は禁止

| 候補 | 透過PNG | 形状の狙い |
|---|---|---|
| A（採用） | `prop_aronchia_completed_chair_production.png` | 元絵に近い箱の積み上げとバランス |
| B（没・削除済み） | — | 背もたれ、肘掛け、座面、基部の構造が最も読みやすい |
| C（没・削除済み） | — | 少し細身で不揃いな即席工作感を強めた |

B・CはImageGenの小文字が`ェ`へ戻ったため、Aの正しい`ュ`字形を抽出して局所置換し、最終画像を目視監査した。
