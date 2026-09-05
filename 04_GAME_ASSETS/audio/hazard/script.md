# そば屋ハザード — ゲーム内音声台本

正本はゲームへ組み込む採用済みWAV。生成候補と未加工音声は `.local/hazard_voice/raw/` に保持する。

## 生成条件

- モデル: `Aratako/Irodori-TTS-v4.1-Small`
- Irodoriエンジン: `8224dafb46d0aba89209a8f905f1cb7e3299d9c1`
- 正典: `02_CHARACTERS/VOICE_CAST.md`。参照音声と既定seedを維持。時間はモデルの自動推定。
- そば屋は正典の `sobaya_monsterize.sh` を適用。全発話を -18 LUFS / -2 dBTP / LRA 7、24 kHz・mono・PCM16へ整える。
- たこさんには固定された発話キャストがないため、独自の短い非言語反応音＋字幕を使用。
- 発話25本、字幕に対応する反応6箇所。台詞総尺139.622秒。
- 読み間違い候補はローカルWhisperで照合。最後の短い返しを再生成し「えーまた集まるの」と認識された。ASRの同音異字や認識誤りは残るため、聴感・本人らしさを検証済みとは扱わない。

## 採用台詞

### やめ太郎 / d864ef7a0e18f59d

福ちゃん！ 広場がそば屋だらけなんだ。
全員、乾杯する気満々でさ。

- 使用箇所: event:opening:1
- 採用ファイル: `voice/d864ef7a0e18f59d.wav`
- 実測尺: 5.880042 秒
- 読み上げ入力: 福ちゃん！ 広場がそば屋だらけなんだ。 全員、乾杯する気満々でさ。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `e188774418abe80f8b67fdf18014db094de598740caaed87f555a6d102f8397c`

### 福ちゃん / 99588c724f7df5d4

乾杯にしては、ジョッキの振りが大きすぎるだろ。

- 使用箇所: event:opening:2
- 採用ファイル: `voice/99588c724f7df5d4.wav`
- 実測尺: 3.600042 秒
- 読み上げ入力: 乾杯にしては、ジョッキの振りが大きすぎるだろ。
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。
- SHA-256: `ac0a2603bd523d3e5b8ac8692929375685dd1db4ed7097d176b0ef4dff8e1669`

### やめ太郎 / baf75fba08fee9f9

北の納屋に門の鍵がある。農場へ抜けよう。
壁の記録も、できるだけ回収しておいて。

- 使用箇所: event:opening:3
- 採用ファイル: `voice/baf75fba08fee9f9.wav`
- 実測尺: 6.800042 秒
- 読み上げ入力: 北の納屋に門の鍵がある。農場へ抜けよう。 壁の記録も、できるだけ回収しておいて。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `b50344d93eee7896253fc9e7f5fcfbeda04d2bc0d856734a2a1d3833a3f5c3a2`

### たこさん / 0d48ddcb529c5db1

……。東の門から山道へ進めます。
ビールは弾やハーブと交換できます。

- 使用箇所: event:farm:1
- 採用ファイル: `voice/takosan_response.wav`
- 実測尺: 0.850000 秒
- 生成: `tools/build_hazard_soundscape.py` の非言語反応音

### たこさん / 37a20882f1242958

納屋の二階も、お調べください。
青いメダリオンは七つ。全部落とせば、おまけもあります。

- 使用箇所: event:farm:2
- 採用ファイル: `voice/takosan_response.wav`
- 実測尺: 0.850000 秒
- 生成: `tools/build_hazard_soundscape.py` の非言語反応音

### そば屋 / e279a5b4f20956a8

最後の一杯だ。乾杯！

- 使用箇所: event:last_order:1
- 採用ファイル: `voice/e279a5b4f20956a8.wav`
- 実測尺: 2.581375 秒
- 読み上げ入力: 最後の一杯だ。乾杯！
- 参照: `02_CHARACTERS/Sobaya_voice.wav` / seed `42`
- Caption: 相手を誘うように、堂々と。最後の乾杯を呼びかける。
- SHA-256: `5cb80913933ce560ea2dc716916ebf9180713d20177f09a72e9f28b4646d3d3f`

### 福ちゃん / ceb0620a2d88fba6

その一杯、遠慮させてもらう！

- 使用箇所: event:last_order:2
- 採用ファイル: `voice/ceb0620a2d88fba6.wav`
- 実測尺: 2.800042 秒
- 読み上げ入力: その一杯、遠慮させてもらう！
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。
- SHA-256: `d8fa4bfd9b7ce0fbb83e9abf11c23d3a7747285f524120c0e362a0426eeed5a8`

### やめ太郎 / a553dbde8d155536

おかえり、福ちゃん。
……今日はもう、乾杯は遠慮したいな。

- 使用箇所: event:ending:1
- 採用ファイル: `voice/a553dbde8d155536.wav`
- 実測尺: 4.400042 秒
- 読み上げ入力: おかえり、福ちゃん。 ……今日はもう、乾杯は遠慮したいな。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。
- SHA-256: `7cc14c31f384d980cc0467d0f507e42f82a0c87de77a06ca6f367104029e524f`

### 福ちゃん / b8ee7b3a5c30c32c

明日はノンアルで集まろう。
記録の整理も、まだ残ってるし。

- 使用箇所: event:ending:2
- 採用ファイル: `voice/b8ee7b3a5c30c32c.wav`
- 実測尺: 4.440042 秒
- 読み上げ入力: 明日はノンアルで集まろう。 記録の整理も、まだ残ってるし。
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。
- SHA-256: `bc5acc95c5f3eaf06ad65a5dc07d6facbb0033a0245f9547f88465e01b62f8da`

### たこさん / 5900b2463a63f3dd

……。それも仕入れておきます。

- 使用箇所: event:ending:3
- 採用ファイル: `voice/takosan_response.wav`
- 実測尺: 0.850000 秒
- 生成: `tools/build_hazard_soundscape.py` の非言語反応音

### やめ太郎 / 4aa750fa623336f6

え、また集まるの？

- 使用箇所: event:ending:4
- 採用ファイル: `voice/4aa750fa623336f6.wav`
- 実測尺: 2.640042 秒
- 読み上げ入力: えっ、また集まるの？
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 驚いて、短く聞き返す。
- SHA-256: `ba345a2998bbb2b7171f4338cdc8f2b2363570c09eb686fd28386d0aefe19e97`

### やめ太郎 / 08272ad77b153d57

福ちゃん！ よかった、生きてた！
広場がそば屋だらけなんだ。しかも全員、乾杯する気満々でさ。

- 使用箇所: dialogue:yametaro:intro:0
- 採用ファイル: `voice/08272ad77b153d57.wav`
- 実測尺: 7.720042 秒
- 読み上げ入力: 福ちゃん！ よかった、生きてた！ 広場がそば屋だらけなんだ。しかも全員、乾杯する気満々でさ。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `b00c31dfb163984e31cf3a83d2407390a1e6d8253d8893a5dad96bba0d400202`

### 福ちゃん / abc6898e1c395932

乾杯にしては、ジョッキの振りが大きすぎるだろ……。

- 使用箇所: dialogue:yametaro:intro:1
- 採用ファイル: `voice/abc6898e1c395932.wav`
- 実測尺: 3.640042 秒
- 読み上げ入力: 乾杯にしては、ジョッキの振りが大きすぎるだろ……。
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。
- SHA-256: `c9acab2fd5fb050694e5e38296e1052e3981ca5bafe87dc828677293b88b7b50`

### やめ太郎 / 048dbc77a640f072

農場へ抜けよう。北側の納屋に、門の鍵があるはず。
僕はここで、まだ来てないみんなを待つよ。

- 使用箇所: dialogue:yametaro:intro:2
- 採用ファイル: `voice/048dbc77a640f072.wav`
- 実測尺: 7.440042 秒
- 読み上げ入力: 農場へ抜けよう。北側の納屋に、門の鍵があるはず。 僕はここで、まだ来てないみんなを待つよ。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `6bc7626df0dc0466a3ef29796d43116f6695139292f5a8b270bc816fee43dfa2`

### やめ太郎 / 7035a52e8de4d6c2

必要なことがあれば聞いて。
あ、それから壁の貼り紙も見ておいた方がいいかも。

- 使用箇所: dialogue:yametaro:greeting:0
- 採用ファイル: `voice/7035a52e8de4d6c2.wav`
- 実測尺: 5.520042 秒
- 読み上げ入力: 必要なことがあれば聞いて。 あ、それから壁の貼り紙も見ておいた方がいいかも。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `bbc9d6595e126f031dd4c3b52fb651e67c53f2d13af6f598d06e58a63bed3598`

### やめ太郎 / 74d94d34a40123a6

村の奥、広場の北に大きな納屋がある。鍵はその中だよ。
北東の紋章がついた門を開ければ、農場へ行ける。

- 使用箇所: dialogue:yametaro:route:0
- 採用ファイル: `voice/74d94d34a40123a6.wav`
- 実測尺: 9.520042 秒
- 読み上げ入力: 村の奥、広場の北に大きな納屋がある。鍵はその中だよ。 北東の紋章がついた門を開ければ、農場へ行ける。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `f3c71c1da164c407f98250e1fd00c1106f816542f5c03df59de8d9755396a2ba`

### 福ちゃん / ceb4079460b2e1c3

まず鍵。余裕があれば民家も調べるか。

- 使用箇所: dialogue:yametaro:route:1
- 採用ファイル: `voice/ceb4079460b2e1c3.wav`
- 実測尺: 3.680042 秒
- 読み上げ入力: まず鍵。余裕があれば民家も調べるか。
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。
- SHA-256: `97ac07989b078f406472187cf65233fdf946e9fab7fdace978ba62786c4dbc3c`

### やめ太郎 / ba304ddf47829a71

右手の二階建ての家には、ショットガンが残ってる。
囲まれる前に、逃げる道も覚えておいてね。

- 使用箇所: dialogue:yametaro:route:2
- 採用ファイル: `voice/ba304ddf47829a71.wav`
- 実測尺: 7.320042 秒
- 読み上げ入力: 右手の二階建ての家には、ショットガンが残ってる。 囲まれる前に、逃げる道も覚えておいてね。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `22f4697c37db540842a581416081e33c4aafae52ed76800ae1768c47cb940a4d`

### やめ太郎 / e903446ece431552

ジョッキを振り上げたら、横へ避けて。Xで素早く踏み込めるよ。
頭を狙ってひるませたら、近づいてFで蹴り飛ばせる。

- 使用箇所: dialogue:yametaro:combat:0
- 採用ファイル: `voice/e903446ece431552.wav`
- 実測尺: 10.160042 秒
- 読み上げ入力: ジョッキを振り上げたら、横へ避けて。エックスで素早く踏み込めるよ。 頭を狙ってひるませたら、近づいてエフで蹴り飛ばせる。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `7967e70c9845f182ec77b8868723ce7f028a3a133e5266cf3471b39c864c95d3`

### 福ちゃん / 7865487a77a74866

一人ずつ相手にすれば、弾も節約できそうだな。

- 使用箇所: dialogue:yametaro:combat:1
- 採用ファイル: `voice/7865487a77a74866.wav`
- 実測尺: 3.920042 秒
- 読み上げ入力: 一人ずつ相手にすれば、弾も節約できそうだな。
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。
- SHA-256: `58523f63f1d841ed3a6f998c8da1c769155cbd0611ed6bf97d9a3bbbe7fc376f`

### やめ太郎 / c43aee6a545b25a6

家の壁に貼ってある、僕らの映画や事件の記録。
近づいてEで集めたら、Cでいつでも見られるよ。

- 使用箇所: dialogue:yametaro:records:0
- 採用ファイル: `voice/c43aee6a545b25a6.wav`
- 実測尺: 8.120042 秒
- 読み上げ入力: 家の壁に貼ってある、僕らの映画や事件の記録。 近づいてイーで集めたら、シーでいつでも見られるよ。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `508cd2b9c13503356ee14f2af7d2c334fc6b4e4d80e575666453069649f31361`

### 福ちゃん / 535568f2bf19d49e

入口の家に、お前の指名手配書もあったぞ。

- 使用箇所: dialogue:yametaro:records:1
- 採用ファイル: `voice/535568f2bf19d49e.wav`
- 実測尺: 3.720042 秒
- 読み上げ入力: 入口の家に、お前の指名手配書もあったぞ。
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。
- SHA-256: `eb7e51dbb59a12093d8ec7603ec15cd72951642a02fa86c043061dce14beddc8`

### やめ太郎 / a71e587b3245ef7d

それは……できれば回収してほしい。なるべく早く。

- 使用箇所: dialogue:yametaro:records:2
- 採用ファイル: `voice/a71e587b3245ef7d.wav`
- 実測尺: 4.280042 秒
- 読み上げ入力: それは……できれば回収してほしい。なるべく早く。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `2ad8d118ca6a8a872bc0f3b6909e43987b27083f38867275af4faeb06f444728`

### やめ太郎 / 544645864d918cf4

予備の弾、10発。持っていって。
僕の分まで、みんなを連れて帰ってきてよ。

- 使用箇所: dialogue:yametaro:supplies:0
- 採用ファイル: `voice/544645864d918cf4.wav`
- 実測尺: 6.000042 秒
- 読み上げ入力: 予備の弾、10発。持っていって。 僕の分まで、みんなを連れて帰ってきてよ。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `44f7ea89be6d279923cce6f7a0ba465c209226abad8a5bd4812d994823c6d349`

### やめ太郎 / 3bc1f131b9e6302a

ケースに空きがないみたい。整理したら、また声をかけて。
弾はちゃんと取っておくから。

- 使用箇所: dialogue:yametaro:full:0
- 採用ファイル: `voice/3bc1f131b9e6302a.wav`
- 実測尺: 6.240042 秒
- 読み上げ入力: ケースに空きがないみたい。整理したら、また声をかけて。 弾はちゃんと取っておくから。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `ae7ea2def1cbd23c1d8525f5b27246761b6cdec58291727b14753fcc42378ebb`

### たこさん / 5987fdc435962d4e

……。そば屋を倒して、ビールを拾いましたか。
弾やハーブと交換できます。

- 使用箇所: dialogue:takosan:intro:0
- 採用ファイル: `voice/takosan_response.wav`
- 実測尺: 0.850000 秒
- 生成: `tools/build_hazard_soundscape.py` の非言語反応音

### 福ちゃん / 0b2763d6e23ad1d3

こんな所で商売してるのか。
そのビール、どうするんだ？

- 使用箇所: dialogue:takosan:intro:1
- 採用ファイル: `voice/0b2763d6e23ad1d3.wav`
- 実測尺: 4.120042 秒
- 読み上げ入力: こんな所で商売してるのか。 そのビール、どうするんだ？
- 参照: `02_CHARACTERS/Fukuchan_voice.wav` / seed `100`
- Caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。
- SHA-256: `2038b51ac538062ea2435b351a6472eab840b19cfde30804555db7d7ef7005c0`

### たこさん / 786092808e6f8581

必要なことです。
持てる量だけ、お選びください。

- 使用箇所: dialogue:takosan:intro:2
- 採用ファイル: `voice/takosan_response.wav`
- 実測尺: 0.850000 秒
- 生成: `tools/build_hazard_soundscape.py` の非言語反応音

### たこさん / 3c3abe898678a76c

……。補給ですね。ビールはお持ちですか。

- 使用箇所: dialogue:takosan:greeting:0
- 採用ファイル: `voice/takosan_response.wav`
- 実測尺: 0.850000 秒
- 生成: `tools/build_hazard_soundscape.py` の非言語反応音

### やめ太郎 / 35c3ecec89730ce4

廃屋の前にいるそば屋が、帰り道を塞いでる。
ジョッキを大きく振り上げたら、横か後ろへ。振り終わりを狙おう。

- 使用箇所: dialogue:mountain:before
- 採用ファイル: `voice/35c3ecec89730ce4.wav`
- 実測尺: 8.840042 秒
- 読み上げ入力: 廃屋の前にいるそば屋が、帰り道を塞いでる。 ジョッキを大きく振り上げたら、横か後ろへ。振り終わりを狙おう。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `cea8015235ae29dad4bba780994f402f6609669154e70f0bf074424b3f7d30c3`

### やめ太郎 / 9490570c5c6a09c6

福ちゃん、やったね！ 東側の門から帰ろう。
今日はもう、乾杯は遠慮したいな。

- 使用箇所: dialogue:mountain:after
- 採用ファイル: `voice/9490570c5c6a09c6.wav`
- 実測尺: 6.240042 秒
- 読み上げ入力: 福ちゃん、やったね！ 東側の門から帰ろう。 今日はもう、乾杯は遠慮したいな。
- 参照: `02_CHARACTERS/Yametaro_voice.wav` / seed `7`
- Caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。
- SHA-256: `46a5a133da9a41e9e10f1753f4202ce8d3ceb4985f085b77f3da0b7cd2a75aff`
