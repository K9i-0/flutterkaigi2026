# 無職やめたろう
42歳 デフォルメキャラクター。
紫色ワイシャツ、丸メガネ。
『どうせワイなんて』が口癖。
ギャグ担当。
賞金2億のWANTEDポスター（「窓際族物語」独自デザインの社内指名手配書）で社内指名手配中。
「正体がバレる→逃げる→確保される→脱走する」が定番ムーブ。
確保されるとタコ部屋に連行される。そば屋からは「やめさん」と呼ばれる。
作中の手配書表記は「YAMETARO」「やめ太郎」のことがある。
NG変更: キャラクターデザイン。
画像ファイル：Yametaro.jpg
声ファイル：Yametaro_voice.wav（Irodori-TTSの正典参照音声。既定seedは`VOICE_CAST.md`を参照）
参照音源集：`02_CHARACTERS/voice_references/`（`Yametaro_ref_intro_mid.wav`、`Yametaro_ref_intro_short.wav`など）
社内指名手配書：`../01_WORLD/props/yametaro_wanted_poster.png`
ボクセルモデル：`04_GAME_ASSETS/voxel/models/yametaro.glb`（二足リグ。再生成は`04_GAME_ASSETS/voxel/tools/build_yametaro_voxel_model.py`）

## 喋り方・セリフ制作ガイド（Seedance / Irodori-TTS）
- **声質・トーン**: 落ち着いた中音域〜やや低め。独特の脱力感と哀愁、柔らかな関西イントネーション。飾らない親しみやすさ。
- **語り口**: 自虐やボヤきを交えつつも、どこか楽しそうにユーモアたっぷりに話す。話し出しに「はい、」「まあ〜」「結構僕は〜」と一呼吸置き、語尾を少し伸ばすリズム感。
- **特徴的な口癖・語尾**:
  - 一人称・自虐：「ワイ」「どうせワイなんて…」「働かされておりま〜す」
  - 関西弁・語尾：「〜やで」「〜あかん」「〜してたんすけど」「〜やないですか」「〜のとちゃうかい」
  - エンジニア視点のボヤき：「フロントエンドばっかりやってたんで」「〜って言われる可能性が…」
- **Irodori-TTS生成推奨設定**:
  - 参照WAV: `02_CHARACTERS/voice_references/Yametaro_ref_intro_mid.wav`（脱力感・関西弁重視）または `Yametaro_ref_intro_short.wav`（明瞭短尺）
  - 既定seed: 7
  - caption例: `落ち着いた成人男性。やや脱力感のある関西弁交じりで、飄々としたユーモアを含んで話す。`
