# Antigravity `generate_image` ツール仕様

Google Antigravity のネイティブツール `generate_image` のパラメータ仕様、制約、およびベストプラクティス。

---

## ツール概要

- **ツール名**: `generate_image`
- **エンジン**: Gemini Nano Banana / Imagen 系画像生成モデル
- **実行環境**: Google Antigravity 専用（Codex CLI、Claude Code、Cursor 等には存在しない）

---

## パラメータ仕様

| 引数名 | 型 | 必須 | 説明 | 許容値 / 制約 |
|---|---|---|---|---|
| `Prompt` | string | **必須** | 画像生成のプロンプト、または既存画像の編集・差分指示。詳細かつ具体的に記述する。 | 英語推奨（キャラ同一性指示・構図・照明等） |
| `ImageName` | string | **必須** | 生成された画像の識別名。ファイル名の一部となる。 | **小文字・アンダースコア区切り・最大3単語**（例: `sobaya_dojo_scene`） |
| `AspectRatio` | string | 任意 | 生成画像のアスペクト比。 | `'1:1'` (デフォルト), `'16:9'`, `'9:16'`, `'4:3'`, `'3:4'`, `'3:2'`, `'2:3'` |
| `ImagePaths` | array of string | 任意 | 参照画像の**絶対パス**の配列。キャラクターの見た目や背景の構図を保つために渡す。 | **最大3枚まで**。存在しないパスや相対パスは不可 |
| `toolAction` | string | **必須** | ツールの動作概要（文形式、2-5単語、例: `'Generating image'`） | Antigravity共通仕様 |
| `toolSummary` | string | **必須** | ツールの名詞句要約（名詞句、2-5単語、例: `'Image generation'`） | Antigravity共通仕様 |

---

## 出力と成果物の保存先

- `generate_image` を実行すると、画像は会話の Artifact ディレクトリ配下に自動保存される：
  `~/.gemini/antigravity/brain/<conversation-id>/<ImageName>_<timestamp>.jpg`
- 実行結果として、Artifact の URI（`file:///...`）が返される。
- **プロジェクトへの取り込み**:
  Wan 3.0、Seedance、Remotion、ゲーム等で使用する場合は、生成された Artifact 画像をプロジェクト内の対象エピソードディレクトリ（例: `03_SCRIPTS/60_sobaya_guardian_manga/`）へコピーして使用する。

---

## 主な制約と注意点

1. **参照画像の枚数制限**:
   - `ImagePaths` は **最大3枚まで**。4枚以上渡すとツール呼び出しがエラーになる。
   - 複数キャラが登場する場合でも、重要度の高い正典シート（または合成済みシート）を最大3枚に絞って渡すこと。
2. **UIフレーム・デバイス枠の禁止**:
   - ツール説明にある通り、不要な端末枠（スマホやノートPCのベゼル等）は自動付加させないこと。
3. **日本語テキストの直接描画の回避**:
   - 生成モデルに長文の日本語や細かいテロップを直接描かせると、文字化けや誤字が多発する。
   - テロップやセリフは必ず `remotion-video` または Python (Pillow) による透過PNG後付けで行う。
   - 題字（例: 掛け軸に「窓」の一文字）などの単一漢字・大文字ロゴであれば指定可能だが、余計な文字列が入らないよう `No other text / Clean background` を徹底する。
