# 「曇り時々そば屋」本番素材 — 生成記録

## 採用方針

- 画像生成：built-in `image_gen`
- 新規生成：赤坂の現場リポート開始フレーム、気象情報テロップ
- 過去ニュース回から実ファイルで再利用：女性アナウンサーのスタジオ開始フレーム、「ゆめテレ」ロゴ、朝7時時計
- テンプレート正本から実ファイルでコピー：そば屋の基本シート
- 生成画像をアクション絵コンテとして扱わず、実際にSeedanceへ入力する本番開始フレーム／画面素材として使用する

## 過去素材の出典

| 今回のファイル | 出典 | 用途 |
|---|---|---|
| `scene_01_studio_start_production.png` | `03_SCRIPTS/25_chikuwa_landing_news/scene_01_studio_start_production.png` | 同じ女性アナウンサーと朝ニューススタジオ |
| `logo_yume_tele_master.png` | `03_SCRIPTS/25_chikuwa_landing_news/logo_yume_tele_master.png` | 架空局「ゆめテレ」 |
| `screen_morning_clock_production.png` | `03_SCRIPTS/25_chikuwa_landing_news/screen_morning_clock_production.png` | 朝7時表示 |
| `character_sobaya_basic_sheet.png` | `03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png` | そば屋の外見・体格・必須ジョッキ |

## `scene_02_akasaka_street_start_production.png`

### 入力画像の役割

1. 改修前の `03_SCRIPTS/41_sobaya_weather_news/scene_02_akasaka_street_start_production.png`
   - 男性リポーター、赤坂の道路、東京タワー、曇天、濡れたアスファルト、カメラ、照明のedit target／composition master。
   - 改修前に存在した空中5人と路面3人のそば屋だけを変更対象にする。
2. `03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png`
   - 全てのそば屋の仮面、短い黒髪、筋肉質、灰色の肌、白Tシャツ、黒ジーンズ、白スニーカー、大型ガラスジョッキの唯一のdesign referenceにする。

### 最終プロンプト

```text
Use case: precise-object-edit
Asset type: revised final production first frame for the same Seedance Japanese TV field-news scene, landscape 16:9.
Primary request: Change only the number and placement of Sobaya figures in Image 1 to reduce the opening gag. Preserve the reporter, camera, road, buildings, Tokyo Tower, overcast weather, wet asphalt, lighting, color, perspective, and framing exactly.
Input images: Image 1 is the edit target and composition master. Image 2 is the sole design reference for Sobaya. Preserve the male reporter in Image 1 exactly: same face, hair, age, navy suit, white shirt, pose, serious expression, black handheld microphone, scale, and left-foreground position. Do not alter or regenerate him.
Required edit: Remove all five airborne Sobaya figures completely. Repair the cloudy sky naturally where they were, with no silhouettes, shadows, holes, motion streaks, or remnants. Remove two of the three Sobaya figures embedded in the road and repair their cracks and holes into continuous wet asphalt. Keep exactly one Sobaya total in the entire image. Place that one remaining Sobaya in the center-right midground, about 12 meters behind the reporter, embedded feet-first into the asphalt up to the waist. He remains rigid in an unmistakable 3D-model default T-pose: torso upright, head facing forward, both arms locked straight horizontally at shoulder height, elbows unbent. His right hand holds one large glass beer mug upright without spilling. Keep a tight cracked rim around only this one body.
Sobaya identity: exact white mask with black circular eyes, small black forehead circle, two vertical red cheek markings, thin mouth slot, short black hair, muscular body, neutral gray skin everywhere exposed, fitted white short-sleeve T-shirt, black jeans, white sneakers where hidden below the asphalt, and exactly one clear glass beer mug with amber beer.
Final state: Sky is empty of Sobaya; no character is visible above the horizon except the one embedded figure. The road contains exactly one cracked insertion point and no other holes. Distant ordinary office workers may remain tiny and indifferent on the far-right sidewalk.
Constraints: Change only the Sobaya count and associated asphalt damage. Keep all other pixels and visual relationships as close as possible to Image 1. No text or broadcast overlays.
Avoid: any airborne or falling person, extra Sobaya, duplicate reporter, altered reporter face, altered microphone, new people, cars, umbrellas, weather icons, text, logo, watermark, repaired-road patches with visible seams, extra cracks, blood, injury, gore, panic, smiles, dramatic lighting.
```

### 採用画像の監査

- 16:9、1672×941。
- 男性リポーターは過去ニュース回と同一の顔、髪、紺スーツ、白シャツ、黒マイク。
- 空は完全に空で、開始時に落下待機しているそば屋はいない。
- 路面のそば屋は中景の1人だけ。腰までアスファルトへ刺さり、周囲に密着した亀裂と小破片がある。
- 開始時に1人だけ見せ、後続の落下個体は全て動画内で画面上端の外から自由落下させる。
- 仮面、灰色の肌、白Tシャツ、黒ジーンズ、白靴を維持。血、傷、身体欠損なし。
- 画像内文字、局ロゴ、テロップなし。放送画面素材は別入力に分離。

## `screen_sobaya_weather_lower_third_production.png`

### 入力画像の役割

1. `03_SCRIPTS/25_chikuwa_landing_news/screen_chikuwa_lower_third_clean_production.png`
   - 過去ニュース回の紺・白・コーラル、横長形状、文字階層、縁取りだけをlayout/style referenceにする。

### 最終プロンプト

```text
Use case: text-localization
Asset type: final production lower-third graphic for direct overlay in a Japanese local-TV weather news video.
Primary request: Edit only the three text fields in Image 1 while preserving its exact broadcast graphic design, proportions, hierarchy, white panel, navy and coral-red palette, bevels, strokes, spacing, and wide horizontal shape.
Input image: Image 1 is the edit target and the sole layout/style reference.
Text (verbatim): top coral tab must read exactly "気象情報". Large central navy headline must read exactly "曇り時々そば屋". Bottom navy location tab must read exactly "東京・赤坂".
Typography: bold clean Japanese broadcast Gothic type, centered, highly legible, with no character substitutions. Render each required phrase once and only once.
Background: place the complete lower-third graphic on a perfectly flat solid #00ff00 chroma-key background for later removal. The green background must be uniform, with no gradient, shadow, reflection, floor, or texture. Do not use #00ff00 inside the graphic.
Composition: extremely wide horizontal banner, entire graphic visible with generous green padding on all four sides; no cropping at the left, right, top, or bottom.
Constraints: change only the three text fields and background outside the banner; keep the overall design matching Image 1. Exact Japanese text is mandatory.
Avoid: any extra text, old text from Image 1, pseudo-Japanese, misspellings, duplicate characters, weather icons, clouds, Sobaya characters, logos, watermark, signature, explanatory panel, alternate design.
```

### 透過処理と監査

- built-in imagegen出力をImageMagickの連結領域クロマキー処理で透過PNG化し、1668×350へ整形。
- 上段「気象情報」、中央「曇り時々そば屋」、下段「東京・赤坂」を原寸確認済み。
- 各文は1回だけ。誤字、旧文言、疑似文字、余計なロゴ、透かしなし。
- 背景四隅は完全透過。画面下部へ直接合成できる1ファイル1アセット。
