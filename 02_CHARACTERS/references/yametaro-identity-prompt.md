# やめ太郎：生成プロンプトの顔固定

やめ太郎を画像・動画へ登場させる制作では、初回から本書を読み、下記の顔固定を実際に送るプロンプトへ入れる。「シートを参照」「同一人物を維持」だけに省略しない。2026-09-11のユーザー指定による常用ルール。衣装・演技・ジャンルを制限しない。ユーザーが外見変更を明示した場合は、その変更だけを優先する。

## 使い方

1. 現行の `03_SCRIPTS/00_TEMPLATES/characters/character_yametaro_basic_sheet.png` を実際に表示して確認する。過去の生成動画や採用静止画を、通常形の顔の正本へ昇格させない。
2. 下記の共通文を入力番号に合わせて送信本文へ展開する。Wanは `Image n`、Seedanceは `@Image n`。文章の同義な調整は可、列挙した顔の要点は落とさない。今後シート自体が更新された場合は、本書と画像の差を確認し、旧顔指定を機械的に貼らない。
3. 起床、横顔、叫び、大きな表情、寄りのショットには、該当する崩れを防ぐ短い一文を加える。全ショットへ長文を複製しない。
4. 実写の照明・質感・映画ジャンルの指定は背景と撮影へ適用し、やめ太郎の顔を人間化する指示にしない。演技は声・口形・首・姿勢・手で出す。

## 実送信用共通文

```text
Yametaro identity lock — [IMAGE REFERENCE] is the exact design authority, not loose inspiration. Preserve its head width-to-height ratio, hair silhouette and hairline, cheek and ear placement, short neck and compact body proportions in every frame. Keep the round black spectacle frames and the sheet's simple white lens/eye areas; do not invent visible pupils, irises, realistic eyeballs, eye sockets, eyelids or eyebrows. Keep the tiny black forehead mark separate from the low, subtle skin-colored nose; no black nose dot, outlined nostrils or projecting nose. Preserve the round cheeks and flat pink blush marks, smooth skin-colored chin, ears and nape, with no black contour bands or facial creases. Do not lengthen the forehead/head, inflate the hair, enlarge ears or add realistic lips. Animate the small inset mouth using the sheet's rest and A/I/U/E/O views as articulation guidance, with visible mouth interior when speaking; do not freeze the smile, protrude the lips or stretch the mouth into a new facial design. Emotion and cinematic lighting must not redesign the face. Wardrobe follows the scene instructions independently of identity. A previous generated take is not an identity reference.
```

起床の追加例：`Show waking through breath, head and body movement while keeping the reference's white lens design; do not add eyelids, pupil movement or closed-eye lines.`
叫びの追加例：`Make the shout forceful through voice, posture and the reference-based speaking mouth; keep the same white lenses, head proportions and hair silhouette, with no bulging eyes or enlarged face.`
横顔の追加例：`Match the side view's low nose, cheek-to-ear relationship and continuous skin-colored jaw/nape; do not grow a muzzle or lengthen the head.`

禁止指示を足すだけでなく、維持する形と許可する動きをセットで書く。表情禁止・口パク禁止にしない。参照シートの文字、分割線、白背景、複数ビューは映像へコピーさせない。

## 生成前・生成後の確認

- 送信本文に顔固定が入り、入力番号が正しいこと。「目を見開く」「まぶたを開ける」「全員を実写化」などの競合がないこと。
- 正面、斜め、横顔、初登場、各カット境界、叫び等の最大表情を現行シートと並べて確認。瞳だけでなく、頭髪の高さ、顔の縦横比、鼻、口、耳、首、体格を見る。
- 「キャラとして識別できる」と「シートの造形に一致」は分けて報告。強い指定でも完全一致を保証しない。
- ズレが残る場合は部位・フレームを特定し、必要に応じて正典シートから顔／横顔参照や検証済みの衣装付き参照を準備する。追加画像は入力上限と役割競合を確認し、単なる画像枚数の増加を解決策にしない。有料再生成の承認は別途既存ルールに従う。

## 今回の根拠

`03_SCRIPTS/68_tako_game_dormitory/` の初回では瞳・目の立体化が発生。改訂2の強い指定で覚醒後の白いレンズは改善したが、冒頭の閉眼線と頭髪の高い解釈は残った。強い指定を初回から採用する根拠であり、完全防止の実証ではない。
