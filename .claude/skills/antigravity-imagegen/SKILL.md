---
name: antigravity-imagegen
description: Antigravity専用。Geminiネイティブの画像生成ツール（generate_image）を用いて、窓際族物語のキャラクター同一性を厳密に保持したシーン・背景・参照画像を生成する。CodexやClaude Codeなど他のハーネスにはgenerate_imageツールが存在しないため対象外・呼び出し不可。
---

# Antigravity画像生成（窓際族物語 同一性防衛）

Google Antigravity 環境固有の `generate_image`（Gemini Nano Banana / Imagen 系）ツールを使い、窓際族物語のキャラクター同一性を損なうことなく、高品質なシーン画像・カット・参照画像を生成するための制作ワークフロー。

---

## 1. 動作環境とガード（ハーネス分離）

> [!CAUTION]
> **本スキルは Google Antigravity 環境専用です。**
> Codex CLI、Claude Code、Cursor 等の他のハーネス・エージェント環境には `generate_image` ツールが存在しません。
> Antigravity 以外の環境で本スキルが呼び出された場合、または `generate_image` ツールが提供されていない場合は、**絶対に画像生成を実行せず、即座に終了してください**（各環境で指定された画像生成パイプラインや外部APIを利用すること）。

---

## 2. 全制作物に共通する唯一のハード条件

「窓際族物語」における唯一のハード条件は、**「登場キャラクターを同一人物・同一キャラクターとして識別できること」** です。

Gemini の画像生成モデルは、テキストプロンプト（例: `sobaya holding a sword in a dojo`）だけを渡すと、学習データの一般的な人間・侍・能面・アニメキャラの解釈に引きずられ、**キャラクター固有の造形（無機質な卵型仮面、黒丸の目穴、赤ストライプ、アッシュグレー肌など）をデフォルトで改変・崩壊させます**。

これを防ぐため、以下の2点を**絶対の鉄則**とします：
1. **正典キャラクターシート/正典写真を `ImagePaths` に必ず渡す**（最大3枚）。
2. **パーツ単位の厳格な逐語指定（ポジティブ指定＋禁止事項）を英語プロンプトに必ず含める**。

---

## 3. ツール呼び出しパラメータ仕様

`generate_image` を呼び出す際は、以下の仕様を厳守します（詳細は [references/tool-spec.md](references/tool-spec.md) 参照）：

| 引数 | 指定ルール |
|---|---|
| `Prompt` | シーン状況・構図に加え、後述の「キャラクター同一性プロトコル」を必ず含める。英語推奨。 |
| `ImageName` | **小文字・アンダースコア区切り・最大3単語**（例: `sobaya_dojo_scene`）。これを超える単語数はエラーとなる。 |
| `AspectRatio` | 用途に応じて指定：<br>・横型動画・シーン: `'16:9'`<br>・縦型動画（TikTok/Shorts）: `'9:16'`<br>・ポスター・立ち絵: `'2:3'` または `'3:4'`<br>・正方形・アイコン: `'1:1'`（デフォルト） |
| `ImagePaths` | 正典参照画像の**絶対パス**の配列（**上限3枚**）。存在しない相対パスや4枚以上の指定は不可。 |

---

## 4. キャラクター同一性防衛プロトコル

各キャラクターのパーツ別プロンプト定型句は [references/identity-prompts.md](references/identity-prompts.md) を参照すること。

### A. そば屋 (Sobaya)
- **参照画像**: `03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png`
- **必須指定**:
  - `A completely smooth, featureless, matte white egg-shaped ceramic mask covering the entire face.`
  - `Two simple, pitch-black hollow round holes for the eyes (no eyeballs, no pupils, no sclera).`
  - `Two vertical, bold solid red stripes running straight down continuously through each black eye hole.`
  - `A single small black circular dot centered on the forehead above the eyes.`
  - `A narrow, subtle horizontal black slit for the mouth.`
  - `Neutral ashen grey skin tone on all exposed skin (neck, hands, forearms). Very thick muscular neck.`
- **絶対禁止**:
  - 人間の鼻・唇・瞼の立体造形、瞳や白目の描画、肌の肌色化（ピンク・肌色禁止）、仮面のズレや透過。

### B. たこさん (Takosan)
- **参照画像**: `03_SCRIPTS/00_TEMPLATES/characters/character_takosan_basic_sheet.png`（トイジオラマ3D版が通常形）
- **必須指定**:
  - `Toy diorama 3D style, soft matte vinyl / clay figurine aesthetic.`
  - `Smooth rounded white face peeking out from inside a large oversized black hooded robe, with two simple glossy black bead eyes.`
  - `Two human-like arms ending in cute, small, round white mitt-like hands with NO separated fingers.`
  - `Six slender, dark tentacles emerging from beneath the bottom hem of the robe.`
- **絶対禁止**:
  - リアルな人間顔、5本指、リアルな生々しいタコ肌、腕の触手化。

### C. 実写メンバー（とーくん、よーたん、福ちゃん、おかやまん）
- **参照画像**: `02_CHARACTERS/{Tokun,Yotan,Fukuchan,Okayaman}.jpg` の正典写真。
- **必須指定**:
  - `STRICT FACIAL IDENTITY MANDATE: same real person as shown in canonical reference photo.`
  - `Preserve exact facial bone structure, eyes, nose, mouth contours, hairline, and skin texture.`
- **絶対禁止**:
  - 美化・アニメ化・別人化、一般的な日本人男性モデルへのすり替え。

---

## 5. クリーンプレート原則（Remotion後付け前提）

- **長文セリフや字幕を画像内に描かせない**:
  - 画像生成モデルに日本語テキストを描かせると文字化けやレイアウト崩れが発生します。
  - プロンプト末尾に `STRICT CLEAN PLATE: No random text, no watermarks, no subtitles, clean background` を必ず追加します。
- **テロップ・セリフの分担**:
  - セリフやテロップは、`remotion-video` または Python (Pillow) スクリプトで作成した透過PNGを後から合成します。
  - 単一漢字の題字（例: 道場の掛け軸に「窓」の一文字）のみ、`a hanging scroll with the single kanji "窓" written in bold black calligraphy` のように明示的に指定して背景の一部として生成させることが可能です。

---

## 6. 制作手順（Step-by-Step）

### Step 1: 要件の確認
- 生成対象（キャラクター、シーン、背景、アスペクト比）を特定する。
- 登場キャラクターに応じた正典画像ファイルのパスを確認する。

### Step 2: 正典参照画像のパス設定
- 絶対パスで `ImagePaths` を構築する（最大3枚）。
  ```python
  # 例: ワークスペースルートを基準とした絶対パス
  workspace = "/Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game"
  sobaya_sheet = f"{workspace}/03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png"
  ```

### Step 3: プロンプトの組み立て
1. **構図・シチュエーション**: カメラアングル、照明、背景、ポーズ。
2. **同一性防衛ブロック**: `references/identity-prompts.md` からキャラクター固有のポジティブ指示＋禁止事項を挿入。
3. **クリーンプレート指示**: `No random text, no subtitles, clean background`.

### Step 4: `generate_image` の実行
Antigravity のツールを呼び出す：
```json
{
  "ImageName": "sobaya_dojo_scene",
  "AspectRatio": "16:9",
  "ImagePaths": [
    "/Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/03_SCRIPTS/00_TEMPLATES/characters/character_sobaya_basic_sheet.png"
  ],
  "Prompt": "A wide cinematic shot of Sobaya standing in a traditional Japanese wooden dojo... [同一性防衛プロンプト] ... Clean background, no text."
}
```

### Step 5: 目視検査（同一性チェックリスト）
生成された Artifact 画像を確認し、以下を判定する：
- [ ] 仮面・顔の造形が正典シートと一致しているか？
- [ ] 目穴が空洞の黒丸になっているか（瞳や白目が描かれていないか）？
- [ ] 固有の模様（そば屋の赤ストライプ、額の黒点など）が正しい位置にあるか？
- [ ] 露出した肌の色が正しいか（そば屋はアッシュグレー）？
- [ ] 実写メンバーの場合、正典写真と同一人物に見えるか？
- [ ] 不要な意味不明の英数字や文字化けが焼き込まれていないか？

不合格の場合は、崩れた箇所をプロンプトでさらに強調・修正して再生成する。

### Step 6: 成果物の配備
合格した画像は、エピソードディレクトリ（例: `03_SCRIPTS/<episode_dir>/`）または用途に応じたディレクトリへコピーして保存する。
Wan 3.0 / Seedance の参照画像として渡すか、Remotion のコンポーネントで取り込んで使用する。
