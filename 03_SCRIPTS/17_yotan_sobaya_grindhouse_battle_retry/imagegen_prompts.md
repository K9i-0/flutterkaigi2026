# imagegenプロンプト方針

すべて組み込みimagegenで生成する。完成素材は16:9 PNG。

## 完成ルック共通

```text
Use case: photorealistic-natural
Asset type: Seedance 2.5実写映画用の完成環境または開始・終了キーフレーム
Style/medium: high-budget live-action feature film still, practical stunt photography, realistic human skin, leather, glass, metal, concrete and dust; subtle 35mm film texture
Look: tense 1970s Japanese grindhouse martial-arts cinema energy translated into original modern live action; long stillness and sudden kinetic violence; do not reproduce any specific film character, costume, set, choreography or shot
Color: deep black, tungsten amber, controlled crimson practical light, cool Tokyo-night blue outside windows
Avoid: clay render, mannequin, previs, game CGI, plastic skin, arrows, trajectory lines, camera icons, red starburst, concentric rings, visible soundwave rings, beam, magic, comic impact graphic, text, watermark
```

## プランニング共通

```text
Use case: infographic-diagram
Asset type: 人間の制作確認専用。Seedanceへアップロードしない超抽象アクションプラン
Style: primitive geometry only. Featureless sphere heads, box torsos, cylinder limbs. No face, no hair, no mask pattern, no clothing, no fingers, no skin, no realistic materials. Large off-white figure with a plain transparent cylinder mug. Slim charcoal figure with a plain black guitar-shaped block.
Motion overlays: cyan body path, orange weapon path, red contact point, blue dashed camera path
Avoid: recognizable character likeness, detailed room, textures, realistic lighting, production art, text, labels, watermark
```

## 画像別

| ファイル | 内容 |
|---|---|
| `environment_grindhouse_battle_production.png` | 無人の完成実写環境。窓際族ライブ兼立ち飲みフロア、4基スピーカー、低いステージ段差、琥珀・クリムゾン・東京夜景の青 |
| `planning_clip_a_arrows_not_for_seedance.png` | 対峙→ジョッキ横薙ぎとダック→ギターボディ脇腹接触と右滑走 |
| `planning_clip_b_arrows_not_for_seedance.png` | 床叩き→ステージを蹴る空中打撃と受け流し→4基音圧と右滑走 |
| `planning_clip_c_arrows_not_for_seedance.png` | 右から突進→三手の攻防と武器噛み合い→左右分離 |
| `clip_a_start_production.png` | 無傷の床。よーたん左、そば屋右、静かな横長対峙 |
| `clip_a_end_production.png` | そば屋が右へ滑った直後。床に短い滑走跡。両者低い構え |
| `clip_b_start_production.png` | Clip A終了状態。そば屋がジョッキを頭上へ上げる直前 |
| `clip_b_end_production.png` | 4基音圧後。空気屈折と粉塵、そば屋右端、よーたん左の演奏姿勢 |
| `clip_c_start_production.png` | Clip B終了状態。そば屋が粉塵を割って中央へ突進開始 |
| `clip_c_end_production.png` | 最終衝突後。左右へ分離した強いシルエット、未決着、全床損傷保持 |
