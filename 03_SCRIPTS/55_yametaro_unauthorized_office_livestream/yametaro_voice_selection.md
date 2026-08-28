# やめ太郎 ハイテンション音声 採用記録

オフィス無断生配信回では、普段より明るく勢いのあるお調子者として話すIrodori-TTS音声のseed `100`を採用する。

## 生成条件

- 採用seed: `100`
- モデル: `Aratako/Irodori-TTS-v4.1-Small`
- Irodori-TTS revision: `8224dafb46d0aba89209a8f905f1cb7e3299d9c1`
- 正典参照WAV: `02_CHARACTERS/Yametaro_voice.wav`
- 正典参照WAV SHA-256: `ede825a58cf1920f1bdfb353eea17d0feb24f20592d7f36d7c5c22c5ab60530b`
- 生成スクリプト: `.agents/skills/seedance/scripts/irodori_speak.sh`
- 推論設定: 40 steps、text CFG `3.0`、caption CFG `3.0`、speaker CFG `5.0`
- 尺: v4.1-Smallの自動推定。`--seconds`と`--duration-scale`は不使用
- 出力: 48 kHz、mono、PCM 16-bit WAV
- 後処理: 全文は前後無音のみ自動トリム。話速、ピッチ、音量は変更していない

## 生成全文

`今からオフィスの様子を配信するやで！ じゃーん、彼が窓際族のエース、そば屋やで！ お、そば屋さん、勤務中に酒かー？ いやいや、最近のお茶って、ああいうのもあるから！ 福ちゃん！ ギュンにちわやで！`

## caption

`本人の中音域と柔らかな関西イントネーションを保つ成人男性。生配信でテンションが上がったお調子者として、明るく勢いよく、声に笑顔を乗せ、冒頭から間を空けず、テンポよく大きめの抑揚で話す。眠そう・落ち着きすぎ・低い独白調にはせず、語尾を前向きに跳ね上げる。焦る言い訳だけ少し早口にする。叫び声にはしない。`

## 採用全文WAV

- ファイル: `yametaro_high_energy_seed100_full.wav`
- 実測尺: 16.200042秒
- SHA-256: `790cf1e011faaea81b02740da77691e83c9983a96f3779b1f18cc9fa1c59c3e4`

## Wan 3.0用 voice-timbre参照

- ファイル: `voice_ref_yametaro_seed100_3_869s.wav`
- 切出元区間: 2.851312–6.720000秒
- 内容: 「じゃーん、彼が窓際族のエース、そば屋やで！」の前後無音を含む独立した意味単位
- 実測尺: 3.868688秒
- 形式: 48 kHz、mono、PCM 16-bit WAV
- 後処理: `loudnorm=I=-16:TP=-1.5:LRA=11`
- 実測: -16.3 LUFS、LRA 2.2 LU、true peak -2.7 dBFS
- SHA-256: `06ef793f79bd0acb1b0e26fcde8c754fcb272861bbcca91de473885a19ed33f8`

Wanにはこの短い参照だけを渡し、元の単語、間、時間軸はコピーさせない。本編台詞とリップシンクはWan側で同時生成する。

## 不採用候補

seed `7`、`42`、`2026`、`550030`は不採用。候補WAV、候補一覧、聴き比べ用プレイリストは削除済み。
