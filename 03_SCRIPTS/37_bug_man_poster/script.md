# バグ男 — パロディポスター制作記録

## 生成タスク

- 種別：静止画ポスター（動画生成なし）
- 用途：窓際族物語の本番用キービジュアル
- 生成方式：built-in ImageGen
- Use case：`ads-marketing`
- 初稿：`prop_bug_man_poster_production.png`
- 採用版：`prop_bug_man_poster_no_way_debug_production.png`

## 参照素材

| 番号 | ファイル | 役割 | 厳守要素 | コピーしない要素 |
|---|---|---|---|---|
| Image 1 | ユーザー添付ポスター | 縦長の劇場ポスターらしい階層、暖色逆光、大作感のみ | 抽象的な構図と熱量 | 固有人物、衣装、ロゴ、ポーズ、文字組み、蜘蛛意匠 |
| Image 2 | `character_yametaro_toy_diorama_3d_basic_sheet.png` | やめ太郎の人物同一性と媒体表現 | 大きな黒髪、三角形の生え際、丸メガネ、ピンクの頬、薄紫の葉柄シャツ、トイジオラマ3D質感 | 設定シートの枠、見出し、ターンアラウンド構図 |

## 表示文字

次の3行を一字一句保持し、各1回だけ表示する。

1. `この男が触れたコード全てバグる`
2. `バグ男`
3. `ノー・ウェイ・デバッグ`

## 最終プロンプト

```text
Use case: ads-marketing
Asset type: 縦長の劇場公開風パロディポスター、完成版1枚
Primary request: オリジナルIP「窓際族物語」のトイスタイルのやめ太郎を主役にした、架空のコード事故ヒーロー映画「バグ男」の日本語ポスターを作る。
Input images: Image 1 is composition/mood reference only: use its dramatic vertical hierarchy, warm city backlight, airborne central hero and ensemble-movie energy, but do not copy any existing character, costume, logo, pose, web pattern, text layout, or identifiable movie artwork. Image 2 is the strict identity/design canon for Yametaro and the definitive Toy Diorama 3D material style.
Scene/backdrop: 夕焼けの東京・赤坂の高層IT街。宙に浮く半透明のコード断片、赤いエラー通知、ねじれたLANケーブルが放射状に走り、背景のオフィス画面が次々にクラッシュしている。コミカルだが大作映画級。
Subject: やめ太郎が画面中央上部で、コードの糸をつかんで飛び込むような大胆なヒーローポーズ。大きな丸い黒髪、中央の鋭い三角形の生え際、角丸の肌色の顔、黒い細縁の丸メガネと白いレンズ、小さな目鼻と笑った口、左右の鮮やかなピンクの丸頬、薄紫の葉柄シャツ、黒いズボン、黒い靴をImage 2どおり厳密に保持。衣装変更なし。人物はやめ太郎1人だけ。
Style/medium: 窓際トイジオラマ3D。丸く柔らかいトイフィギュア造形、マットな樹脂と布、わずかな手作り感、暖色の映画的照明、精巧な高品質3Dポスター。実写人間ではない。
Composition/framing: 2:3縦長。上半分に飛翔する主役、中央から下に崩壊するコードとオフィス街、最下部に大きなタイトル。読みやすい映画ポスターの階層。被写体と文字を切らない。
Lighting/mood: 金色の逆光、赤紫と電気的なシアンのエラー光、冒険大作の壮大さとオフィスコメディの脱力感。
Text (verbatim, each line exactly once): "この男が触れたコード全てバグる"; "バグ男"; "ノー・ウェイ・デバッグ"
Typography: 上部にコピー「この男が触れたコード全てバグる」。最下部中央に最大サイズの日本語タイトル「バグ男」、その直下に小さめのサブタイトル「ノー・ウェイ・デバッグ」。タイトルは赤紫〜電気的シアンの立体文字で、独自の回路・バグノイズ装飾を施す。既存映画ロゴ固有の字形は複製しない。
Constraints: Image 2の顔・髪・眼鏡・頬・葉柄シャツ・頭身・配色を最優先。指定した日本語3行を一字一句正確に、各1回だけ表示。オリジナルのパロディデザインにする。
Avoid: Spider-Manという文字、Marvelという文字、既存ヒーロー、赤青の蜘蛛スーツ、蜘蛛マーク、既存映画ロゴ、既存映画の人物や衣装、脇役人物、英語タイトル、追加コピー、クレジットブロック、意味不明な疑似文字、透かし、署名、血、ゴア。
```

## 生成後監査

- [x] 指定した日本語3行が正しい順序で各1回だけ存在する
- [x] やめ太郎の髪、生え際、丸メガネ、頬、葉柄シャツ、頭身、配色が正典に一致する
- [x] 既存作品の固有人物、衣装、蜘蛛マーク、ロゴ、題名を複製していない
- [x] 余分な人物、追加コピー、クレジット、透かし、署名がない
- [x] ポスター端、人物、タイトルが切れていない
- [x] 東京・赤坂、コード、エラー画面、LANケーブルが読み取れる

## サブタイトル差し替え

採用版では、初稿の構図・人物・背景・コピー・大タイトルを維持し、最下部のサブタイトルだけを次へ変更した。

```text
ノー・ウェイ・デバッグ
```

差し替えはbuilt-in ImageGenの`text-localization`として実行し、採用版を別ファイルで保存した。
