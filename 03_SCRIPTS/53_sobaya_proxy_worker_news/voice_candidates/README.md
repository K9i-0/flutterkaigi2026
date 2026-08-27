# Irodori-TTSニュース原稿候補比較

## 共通条件

- モデル: `Aratako/Irodori-TTS-v4.1-Small`
- Irodori-TTS revision: `8224dafb46d0aba89209a8f905f1cb7e3299d9c1`
- 発話本文: 読みの揺れを避けた共通かな原稿。台本の意味と語句は変更していない
- caption: `落ち着いたニュース読み。標準語で、原稿を一語ずつ明瞭に、抑揚を抑えた真面目な調子で話す。`
- 尺: モデルの自動推定。`--seconds`と`--duration-scale`は不使用

## 候補

| ファイル | 話者 | 正典参照WAV | seed | 実測尺 | Integrated loudness | True peak | LRA |
|---|---|---|---:|---:|---:|---:|---:|
| `news_yotan.wav` | よーたん | `Yotan_voice.wav` | 100 | 25.480秒 | -15.77 LUFS | -0.56 dBTP | 1.80 LU |
| `news_okayaman.wav` | 窓際王おかやまん | `Okayaman_voice.wav` | 42 | 23.760秒 | -15.80 LUFS | +0.01 dBTP | 3.70 LU |
| `news_yametaro.wav` | 無職やめたろう | `Yametaro_voice.wav` | 7 | 25.605秒 | -15.52 LUFS | +0.01 dBTP | 3.70 LU |

## メンバー候補の暫定判断（後に置換）

当初はよーたんを第一候補としてエピソード直下の`news_narration_yotan.wav`へ暫定コピーした。その後、ユーザー指定によりエピソード25の女性アナウンサーを正典化し、この暫定判断は置換された。

人間の試聴では、全文、発音、声の本人らしさ、語尾の切れ、合成ノイズを最終確認する。

## 参照音声なしVoiceDesign候補

特定人物の声をクローンせず、Irodori-TTS v4.1-Small公式の`--no-ref` VoiceDesignで匿名女性アナウンサーを生成した。5候補は発話本文、caption、モデル、生成設定を固定し、seedだけを変更している。

- caption: `落ち着いた成人女性の日本語ニュースアナウンサー。標準東京語。低めで信頼感のある声。均一な速度、抑制された抑揚、明瞭な発音で、真面目に読み上げる。`
- 発話本文: 既存ニュース原稿の共通かな版
- 尺: モデルの自動推定。`--seconds`と`--duration-scale`は不使用
- 参照音声: なし。全候補でspeaker conditioning無効を生成ログで確認
- 後処理: 前後無音のみトリム。話速、ピッチ、音量は変更していない

| ラベル | ファイル | seed | 実測尺 | Integrated loudness | True peak | LRA |
|---|---|---:|---:|---:|---:|---:|
| A | `news_voicedesign_seed0011.wav` | 11 | 28.080秒 | -15.88 LUFS | -1.50 dBTP | 2.50 LU |
| B | `news_voicedesign_seed0042.wav` | 42 | 28.080秒 | -15.91 LUFS | -2.03 dBTP | 3.20 LU |
| C | `news_voicedesign_seed0100.wav` | 100 | 28.080秒 | -15.89 LUFS | -1.18 dBTP | 3.00 LU |
| D | `news_voicedesign_seed2026.wav` | 2026 | 28.080秒 | -15.95 LUFS | -1.93 dBTP | 3.50 LU |
| E | `news_voicedesign_seed530030.wav` | 530030 | 28.080秒 | -16.14 LUFS | -0.84 dBTP | 3.70 LU |

全候補が30秒以内で、true peakは0 dBTP未満。技術的なクリッピング候補はない。声質、全文、発音、自然さは人間の試聴で決める。

## エピソード25参照音声候補

エピソード25の完成動画`03_SCRIPTS/25_chikuwa_landing_news/chikuwa_hamamatsu_news_seedance2.mp4`から、女性アナウンサーだけが話す冒頭0.20〜3.85秒を抽出し、Irodori-TTSの短尺参照音声として使用した。

- 参照WAV: `../reference_yume_tele_anchor_ep25.wav`
- 参照WAV仕様: 3.650秒、48 kHz、mono、PCM 16-bit
- 抽出後処理: 70 Hz high-pass、-16 LUFS／-1.5 dBTP正規化
- 参照WAV SHA-256: `e3cd210adad43fb3338684555e7e066f83cfad2400265c8a73fa55b9f96b753f`
- モデル: `Aratako/Irodori-TTS-v4.1-Small`
- Irodori-TTS revision: `8224dafb46d0aba89209a8f905f1cb7e3299d9c1`
- caption: `落ち着いた地方局ニュース読み。標準語で、明瞭かつ均一な速度、抑制された抑揚で真面目に話す。`
- 発話本文: 既存ニュース原稿の共通かな版
- seed: `11`、`42`、`100`、`2026`、`530030`
- 尺: モデルの自動推定。`--seconds`と`--duration-scale`は不使用
- 後処理: 発話内容と尺は変えず、全候補を48 kHz mono PCM 16-bit、-16 LUFS／-1.5 dBTPへ正規化

| ラベル | ファイル | seed | 実測尺 | Integrated loudness | True peak | LRA |
|---|---|---:|---:|---:|---:|---:|
| A | `news_ep25_anchor_seed0011.wav` | 11 | 26.723秒 | -16.15 LUFS | -1.50 dBTP | 2.60 LU |
| B | `news_ep25_anchor_seed0042.wav` | 42 | 26.764秒 | -16.01 LUFS | -1.50 dBTP | 2.70 LU |
| C | `news_ep25_anchor_seed0100.wav` | 100 | 26.749秒 | -16.14 LUFS | -1.50 dBTP | 3.80 LU |
| D | `news_ep25_anchor_seed2026.wav` | 2026 | 26.726秒 | -15.93 LUFS | -1.50 dBTP | 3.30 LU |
| E | `news_ep25_anchor_seed530030.wav` | 530030 | 26.718秒 | -15.85 LUFS | -1.50 dBTP | 3.50 LU |

全候補が30秒以内で、正規化後のtrue peakは-1.50 dBTP。参照区間は3.65秒と短いため、声質の一致度や発音にはseed間の差が出る可能性がある。採用は人間が全文、自然さ、エピソード25との声質一致、合成ノイズを試聴して決定する。

### 採用結果

- 採用: D、seed `2026`
- 採用音声: `../news_narration_yume_tele_anchor.wav`
- 実測尺: 26.726秒
- Integrated loudness: -15.93 LUFS
- True peak: -1.50 dBTP
- LRA: 3.30 LU
- 今後のニュース用正典: `02_CHARACTERS/YumeTeleAnchor_voice.wav`、既定seed `2026`
