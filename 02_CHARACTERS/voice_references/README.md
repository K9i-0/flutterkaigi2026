# Irodori-TTS 参照音源リスト（福ちゃん・無職やめ太郎）

YouTubeの対談動画（ゆめみ×いえらぶ コラボ動画）から、福ちゃんと無職やめ太郎の発話部分を精密に抽出し、ノイズ除去・音量正規化（ラウドネス調整・無音トリム・低周波カット）を行ったIrodori-TTS用参照音源です。

このディレクトリ直下の参照WAVは同じ声を再生成するための入力資産として追跡する。`test_samples/`の試験生成音声はローカル専用でGit追跡しない。配役の最小正典とSHA-256は`02_CHARACTERS/VOICE_CAST.md`に従う。

---

## 1. 元動画情報

1. **前編**: [【初コラボ！】日本有数のエンジニアに人気の企業「ゆめみ」の秘密に迫る！｜いえらぶ](https://www.youtube.com/watch?v=pXtc-nwr-sc)
2. **後編**: [【急成長ベンチャーが徹底討論】受託開発と自社サービス、新卒エンジニアが入るべきは？｜ゆめみ・いえらぶ](https://www.youtube.com/watch?v=JvwkO78RvKU)

---

## 2. 参照音源一覧

### 福ちゃん（福太郎 / CCO）

| ファイル名 | 尺 | 元動画・区間 | 発話内容 | 推奨用途・特徴 |
|---|---|---|---|---|
| [`Fukuchan_ref_intro.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Fukuchan_ref_intro.wav) | 9.05秒 | 前編 `00:02:20` - `00:02:29` | 「株式会社ゆめみ執行役員CCOを担当している福太郎、通称福ちゃんです。よろしくお願いします。ぎゅぎゅんです。」 | **【第1推奨】** 元気・明瞭な自己紹介と決め台詞。汎用性が高く最も安定。 |
| [`Fukuchan_ref_cco_joke.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Fukuchan_ref_cco_joke.wav) | 11.30秒 | 前編 `00:02:30` - `00:02:41` | 「CCOっていうのはコミュニケーション担当役員という説が濃厚なんですけれども、もしかしたらクレイジーのCかもしれないっていう説もあって、その点今代表にどっちって確認中です。」 | ユーモアのある自然なトーン、表情豊かなセリフ向け。 |
| [`Fukuchan_ref_company.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Fukuchan_ref_company.wav) | 12.50秒 | 前編 `00:01:41` - `00:01:54` | 「株式会社ゆめみは2000年に創業をした会社です。で、元々創業者が京都大学大学院在学中に3人のゼミ仲間と一緒に立ち上げた学生ベンチャーですね。」 | 落ち着いたプレゼン・説明調のセリフ向け。 |
| [`Fukuchan_ref_slack.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Fukuchan_ref_slack.wav) | 10.70秒 | 前編 `00:06:37` - `00:06:48` | 「実はゆめみはSlackというツールを社内コミュニケーションに使っていまして、Slackの活用度が日本一なんですよ。」 | 自信に満ちたクリアなトーク向け。 |

### 無職やめ太郎（フロントエンドエンジニア / 著者）

| ファイル名 | 尺 | 元動画・区間 | 発話内容 | 推奨用途・特徴 |
|---|---|---|---|---|
| [`Yametaro_ref_intro_short.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Yametaro_ref_intro_short.wav) | 7.50秒 | 前編 `00:03:38` - `00:03:46` | 「はい、私は株式会社ゆめみのフロントエンドエンジニアの無職やめ太郎と申します。」 | **【第1推奨（短尺）】** 他音被りゼロの最もクリアな自己紹介。高速・安定生成向け。 |
| [`Yametaro_ref_intro_mid.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Yametaro_ref_intro_mid.wav) | 12.10秒 | 前編 `00:03:46` - `00:03:58` | 「30歳の時にプログラミングを始めて、そこから未経験転職して何社か渡り歩いて今40歳なんですけど、ゆめみで楽しく働かされておりま〜す。よろしくお願いします。」 | **【第1推奨（長尺）】** 独特の脱力感と関西アクセントが最もよく出ている。 |
| [`Yametaro_ref_intro_full.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Yametaro_ref_intro_full.wav) | 19.60秒 | 前編 `00:03:38` - `00:03:58` | 自己紹介の全文（名前＋経歴＋挨拶） | フルバージョンの自己紹介。情報量が最も多い。 |
| [`Yametaro_ref_bandman.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Yametaro_ref_bandman.wav) | 15.10秒 | 前編 `00:04:06` - `00:04:21` | 「30歳ぐらいまではバンドマンやってたんで、こじらせバンドマンみたいなのやってたんで、売れてるアーティストをちょっとSNSで批判したりとかそういった活動してたんすけど、やっぱり手に職つけなあかんっていう感じで一念発起してプログラミングやり始めました。」 | やめ太郎節の関西弁・語り口調を強く反映させたいセリフ向け。 |
| [`Yametaro_ref_frontend_v2.wav`](file:///Users/kotahayashi/Workspace/Seedance_Madogiwa-voxel-game/02_CHARACTERS/voice_references/Yametaro_ref_frontend_v2.wav) | 14.10秒 | 後編 `00:02:21` - `00:02:36` | 「結構僕はフロントエンドエンジニアばっかり最近までずっとやってたので、とあるWebサービスの表のユーザーさんが触る部分のフロントエンド開発と、あとは商品を登録したりだとかそういう管理画面があるので…」 | 落ち着いた技術者・業務説明トーン向け。 |

---

## 3. 音声仕様

- **フォーマット**: RIFF WAV (PCM 16-bit little-endian)
- **サンプリングレート**: 44,100 Hz（モノラル）
- **音量処理**: EBU R128 ラウドネス正規化 (`I=-16 LUFS`, `TP=-1.5 dBFS`)
- **フィルタ処理**: 60Hzハイパス（暗騒音カット）、前後無音自動トリム

---

## 4. Irodori-TTS での生成例

### CLI（`irodori_speak.sh` を使用）

```bash
# 福ちゃん
.agents/skills/seedance/scripts/irodori_speak.sh \
  "みなさんこんにちは！福ちゃんです。今日も張り切っていきましょう！" \
  output_fukuchan.wav \
  02_CHARACTERS/voice_references/Fukuchan_ref_intro.wav \
  100

# 無職やめ太郎
.agents/skills/seedance/scripts/irodori_speak.sh \
  "どうも、無職やめ太郎です。今日はちょっと新しいコードを書いてみようと思います。" \
  output_yametaro.wav \
  02_CHARACTERS/voice_references/Yametaro_ref_intro_mid.wav \
  7
```

---

## 5. 喋り方の特徴とセリフ（台本）作成ガイド

### 福ちゃん（福太郎 / CCO）
- **声質・トーン**: 明るく高め、人懐っこくエネルギッシュ。常に笑顔が浮かぶようなハキハキとした響き。
- **語り口・リズム**: テンポが良く流れるように話す。天然・破天荒なエピソード（「CCOはクレイジーのC説」「切手見つめが趣味」等）をサラッと大真面目・マイペースに語る。
- **特徴的な口癖・語尾**:
  - 「ぎゅぎゅんです！」「ぎゅぎゅ〜！」（決め台詞・挨拶）
  - 「〜という説が濃厚なんですけれども」「〜と言っても過言ではない」
  - 「〜ですね」「〜なんですよ」「ありがとうございます！」
- **セリフ作成のコツ**: 相手を巻き込むポジティブな挨拶や、ちょっとトンデモな珍説・マイペース発言を明るく発話させると福ちゃんらしさが爆発する。
- **Irodori-TTS 推奨設定**:
  - 参照WAV: `02_CHARACTERS/voice_references/Fukuchan_ref_intro.wav`（自己紹介・ぎゅぎゅんです）
  - 既定seed: 42
  - caption例: `明るくエネルギッシュな成人男性。人懐っこく、ハキハキとした笑顔のトーンで話す。`

### 無職やめ太郎（フロントエンドエンジニア / 著者）
- **声質・トーン**: 落ち着いた中音域〜やや低め。独特の脱力感と哀愁、柔らかな関西イントネーション。飾らない親しみやすさ。
- **語り口・リズム**: 自虐やボヤきを交えつつも、どこか楽しそうにユーモアたっぷりに話す。話し出しに「はい、」「まあ〜」「結構僕は〜」と一呼吸置き、語尾を少し伸ばすリズム感。
- **特徴的な口癖・語尾**:
  - 一人称・自虐：「ワイ」「どうせワイなんて…」「働かされておりま〜す」
  - 関西弁・語尾：「〜やで」「〜あかん」「〜してたんすけど」「〜やないですか」「〜のとちゃうかい」「〜ですからね」
  - エンジニア視点のボヤき：「フロントエンドばっかりやってたんで」「〜って言われる可能性が…」
- **セリフ作成のコツ**: 自虐・逃走・ツッコミ・ぼやき・関西弁を効かせるとやめ太郎らしさが際立つ。
- **Irodori-TTS 推奨設定**:
  - 参照WAV: `02_CHARACTERS/voice_references/Yametaro_ref_intro_mid.wav`（脱力感・関西弁重視）または `Yametaro_ref_intro_short.wav`（明瞭短尺）
  - 既定seed: 7
  - caption例: `落ち着いた成人男性。やや脱力感のある関西弁交じりで、飄々としたユーモアを含んで話す。`
