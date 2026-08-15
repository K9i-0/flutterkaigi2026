# 福ちゃんボイスサンプル候補

> 旧v3・尺制御ありの比較用履歴。現在の正典はv4.1-Small・自動尺であり、以下の候補を新規採用しない。

候補WAV本体はローカル専用でGit追跡しない。このREADMEだけを比較履歴として残し、採用する場合は再生成した1本だけをエピソード直下へ配置する。

既存エピソード`42_chikuwa_line_fishing_soba_shark`の福ちゃんのセリフ
「やったー、大ちくわだね！」用。いずれも未採用で、ユーザーの比較試聴待ち。

## 共通生成条件

- 発話用本文：`やったー、だいちくわだね！`
- モデル：`Aratako/Irodori-TTS-500M-v3`
- Irodori-TTS revision：`8224dafb46d0aba89209a8f905f1cb7e3299d9c1`
- 参照WAV：`02_CHARACTERS/Fukuchan_voice.wav`
- 参照WAV SHA-256：`3b597fdb0c6c7e103a1998345f56565652b86b6344127b3d5d52e0a1fd5b9f35`
- seed：`42`
- 形式：48kHz、16-bit PCM、mono WAV
- 元エピソードの指定発話枠：2.7秒

## 候補

| ファイル | 制御 | 実測長 | SHA-256 | 状態 |
|---|---|---:|---|---|
| `clip1_line3_fukuchan_seed42_1x.wav` | 等速 | 3.600042秒 | `a740485836fb6deb51c25a2c46dcdbd02a28aec898f59f1d64d75e3a7c85d1f7` | 未採用・尺超過 |
| `clip1_line3_fukuchan_seed42_1_2x.wav` | 1.2倍速 | 3.000042秒 | `399f4bc4eb7c93f255fe2f5770a81607d26dc433a684ba5198e230800f767078` | 未採用・0.3秒超過 |
| `clip1_line3_fukuchan_seed42_2_7s.wav` | 固定2.7秒 | 2.700042秒 | `8d6f577fedfb99e4beeccc0acefe83fa5d74b1a0679a1f4dc8b3eed45e502004` | 未採用・尺一致 |

採用時は選んだ1本だけをエピソード直下の`clip1_line3_fukuchan.wav`へ配置し、
`script.md`のボイスサンプル台帳とSeedanceの`@Audio`参照へ反映する。
