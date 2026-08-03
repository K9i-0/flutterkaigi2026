# character_yumemin_toy_diorama_3d_basic_sheet.png

- Generator: built-in ImageGen
- Use case: style-transfer
- Media style: 窓際トイジオラマ3D (`toy_diorama_3d`)
- Identity/layout source: `03_SCRIPTS/00_TEMPLATES/characters/character_yumemin_toy_diorama_3d_basic_sheet.png`
- Material reference: `03_SCRIPTS/21_takosan_php_prompt_pun/clip1_start.png`
- Edit scope: ゆめみんの形状・配色・青白境界・鼻・耳・尻尾・木槌・シート構成を固定し、表面材質と照明だけを21のトイジオラマ質感へ寄せる

## Final prompt

```text
Use case: style-transfer
Asset type: Seedance用の再利用可能な16:9横長・窓際トイジオラマ3D基本キャラクター設定シート
Primary request: Image 1のゆめみん設定シートを限定編集し、キャラクターの形状・配色・全パネル構成を完全に維持したまま、表面材質とレンダリングだけをImage 2の21_takosan_php_prompt_punの窓際トイジオラマ3D質感へさらに近づける。
Input images: Image 1 is the edit target and the sole identity/geometry/layout canon for Yumemin. Image 2 is used ONLY as the material, tactile surface, tonal shading and warm Toy Diorama 3D rendering reference. Do not copy Takosan, Yametaro, clothing, tentacles, office objects or the scene composition from Image 2.
Change only: ゆめみんの青い体と白い後部を、Image 2と同系統の柔らかいマットなソフトタッチ樹脂／トイフィギュア素材へ変更する。表面にはImage 2の顔や衣装に見られる、ごく微細で均一な繊維感・紙粘土感・手作り感を薄く加える。完全なツルツルCGや光沢プラスチックではなく、光を柔らかく拡散する暖かな触感にする。黒い点目だけはImage 2の目と同じ、滑らかで深い黒の控えめな艶を保つ。白い後部は純白ではなくImage 2の顔に近い暖かなアイボリー。青は形を読みやすくする穏やかな明暗と柔らかな陰影を持つ。木槌はImage 2の段ボールや木製什器と調和する、暖かい自然木のマットな木目にする。接地／浮遊影はImage 2と同じ暖色寄りで柔らかく、スタジオ資料として中立な強さにする。
Keep unchanged exactly: Image 1のキャンバス比率、全レイアウト、すべての英語見出しと綴り、各パネルの位置、FRONT・SIDE・BACKの向き、球形の体型、青と白の境界位置、小さな青い耳2つ、黒い点目2つ、顔の鼻、柔軟な鼻の3差分、小さな青い尻尾、脚なし・腕なし・口なし、別小道具としての木槌、色パレット。キャラクターのプロポーションと輪郭は1ピクセル単位で変えない意識。
Style/medium: Image 2そのままの窓際トイジオラマ3Dの材質言語。丸く柔らかいトイ造形、マットで微細な手触り、控えめな手作り感、暖色の映画的照明を清潔な暖白色スタジオへ適用した高品質スタイライズド3D。クレイレンダー感よりも、Image 2の実在する小さなトイを撮影したような質感を優先する。
Lighting/mood: 暖かな斜め前方の大きなソフトライト、やさしい陰影、素材の微細な凹凸がわずかに読めるがコントラスト過多にしない。
Strict priorities: 1) Image 1の形状・配色・レイアウトを不変、2) Image 2のマットで暖かな微細素材感、3) 全ビューで同一の表面密度、4) 黒目だけの控えめな艶、5) 暖かなアイボリーの白い後部。
Avoid: 形状変更、鼻・耳・尻尾の変更、青白境界の移動、手足や口の追加、毛皮、長い毛、ぬいぐるみの縫い目、フェルトの切断面、強い布目、ざらざらした岩肌、陶器の強い光沢、濡れたプラスチック、金属、ロボット部品、追加キャラクター、Takosan、Yametaro、オフィス背景、東京タワー、文字変更、文字化け、追加テキスト、ロゴ、透かし。
```

