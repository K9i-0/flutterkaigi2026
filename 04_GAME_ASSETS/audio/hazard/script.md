# そば屋ハザード — 採用音声台本

全126本、合計931.4秒。正本台詞はゲームのDartコード、生成入力は voice-lines.json、採用条件は voice-manifest.json。

福ちゃん・やめ太郎・そば屋・ナレーションは Irodori-TTS v4.1-Small と正典参照音声。たこさんは VOICEVOX:Voidoll（style 89）。24kHz mono PCM16、-18LUFS/-2dBTP。

この台本は build_hazard_voice.py が採用manifestから生成する。使用箇所には章・話題・既読分岐を記録する。購入失敗時の文言は字幕と返答音。

## やめ太郎 — d18d36ac1f79cd02

弾二十五発、持っていき。農場までこれでしのぐんや。ビールを拾っとけば、向こうでたこさんが弾と交換してくれる。打ち上げの店はワイが予約するわ。絶対やで。

12.280秒 / dialogue:yametaro:supplies:hard

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## そば屋 — 2b3687b44fb1d838

そば屋ハザード。

1.382秒 / event:title_call:0

参照 `02_CHARACTERS/Sobaya_voice.wav` / seed 42

caption: ゲームのタイトルコール。低く重厚に、そば屋ハザード、と一息ではっきり告げる。語尾は短く、乾いた威圧感。

## ナレーション — 139f0c8d3089726f

アクシデンチュアからの辞令。赴任先は、廃村ゆめみ村。
福ちゃんを降ろすと、船はすぐに岸を離れた。迎えに立っていたのは、やめ太郎だった。

14.755秒 / event:opening:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

発話本文: アクシデンチュアからの辞令。赴任先は、廃村ゆめみ村。 福ちゃんを降ろすと、船はすぐに岸を離れた。迎えに立っていたのは、やめ太郎だった。

## やめ太郎 — be8634093ee5765c

福ちゃんまで送られてきたんか。ワイは二週間前や。迎えの担当者はおらんから、今はワイが案内しとる。

7.680秒 / event:opening:1

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 5b776a799c540aff

本番で全社員を窓際配属にしてしまって。テストデータだと思ったら、本社の名簿でした。社長にも通知が行きました。

8.920秒 / event:opening:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## 福ちゃん — 502a8695cbe14274

あれ、そば屋さんも研修ですか。……一人、二人。向こうの家にもいる。村じゅう、そば屋さんじゃないですか。

7.600秒 / event:opening:3

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 93287845b3ae8e93

あれ、全部クローンらしいで。近づいたらジョッキで殴ってくるんや。ワイの研修、初日から鬼ごっこやで。

7.840秒 / event:opening:4

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 4c8b151484f59f9d

船長に『村にはバケモノがいる。いざとなったら使え』って、この銃を渡されたんです。バケモノって、そば屋さんのことだったんですね。

9.400秒 / event:opening:5

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## 福ちゃん — 36ec74a55294d165

でも、そば屋さんを撃っていいんですかね。……辞令に追記がある。「村のそば屋は銃で撃ってOK。よーたん」。

7.960秒 / event:opening:6

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 815e5e6c5259838e

よーたんが言うならええか！ ほな、遠慮いらんな。ワイのことは撃たんといてや。

5.160秒 / event:opening:7

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — fa96dd57ac3a6807

よーたんが言うなら大丈夫ですね。帰りは……帰任票がないと乗船不可。銃はくれたのに、帰りの切符はくれないんですね。

9.240秒 / event:opening:8

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 6e5dc7cb76c0caa2

先週来たたこさんが、農場で店をやっとる。ワイは逃げてくる社員をここで待つわ。ワイだけ先に帰ったら、また指名手配やろ。

9.353秒 / event:opening:9

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 34c58b37069aed3c

北の納屋で鍵を取って、北東の門から農場へ行くんや。この案件を片付けたら、ワイ、今度こそ有休を全部使うで。

9.520秒 / event:opening:10

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## ナレーション — b2c09db6affb6543

CHAPTER 02 — 撤収対象外
農場の補給所には、たこさんがいた。棚に並ぶ物資の奥で、封をしたビール箱が積み上がっている。

12.902秒 / event:farm:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

発話本文: 第二章。 撤収対象外。農場の補給所には、たこさんがいた。棚に並ぶ物資の奥で、封をしたビール箱が積み上がっている。

## たこさん — f9bade3c3cb8638e

いらっしゃいませ。一週間前に送られてきました。迎えの船は来ませんが、お客さんは来るので、店にしました。

8.960秒 / event:farm:1

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — aac29cbba6d6c346

やめさんも、ここなら補給できるって。あと、よーたんの辞令に、村のそば屋は銃で撃ってOKとありました。

8.200秒 / event:farm:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 5c4c07bfc9e6614e

よーたんが言うなら、いいですね。落としたビールは弾やハーブと交換します。回収した分は封をしておきます。

8.651秒 / event:farm:3

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — a14b0dddf9a1d42f

この写真を見てください。そば屋のクローンにビールを飲ませて、怪力で軸を回す。そば屋エンジンの開発施設だったんです。

9.696秒 / event:farm:4

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 9e6a9215922a2c77

台数だけ増やして、世話係は一人。案件が炎上すると、責任者は帰り、補給も止まりました。残されたクローンが、ビールを探して村へ出たんです。

13.077秒 / event:farm:5

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — da90bfc3358b1959

研修生だけ、ずっと追加されるんですね。僕、受講者じゃなくて交換部品だったという説が濃厚です。

7.560秒 / event:farm:6

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 742886c4d54728cb

交換なら、古い人を帰します。ここは追加です。人事処理だけは止まりません。

6.667秒 / event:farm:7

VOICEVOX:Voidoll / style 89 / speed 1.0

## ナレーション — 209cb69c519d1e21

補給所の奥、閉じた宿舎の扉を、たこさんが二度たたく。内側から、二度返事があった。扉の前には、水と食事が置かれている。

12.313秒 / event:farm:8

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

## たこさん — 23f24895d822225f

山の廃屋の巨大そば屋を倒せば、エンジンと救難回線の督促放送が止まります。玄関が開いたら中へ。私とやめ太郎、二人に声をかけてください。船は私が呼びます。

15.019秒 / event:farm:9

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — f2dc1fcb175c1422

巨大そば屋さんを倒せばいいんですね。停止ボタンが、だいぶ大きいですね。

5.360秒 / event:farm:10

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 71eaaf694fab09a3

しかも、押そうとすると殴り返してきます。離れて撃ってください。

5.248秒 / event:farm:11

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — e4d630d89894b804

銃は、船でもらったばかりなんです。説明書より先に撃つことになりました。

5.680秒 / event:farm:12

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 63ba3dfb9909e401

山へ行く前に、その銃に慣れておきましょう。農場の青いメダリオンは、倉庫にあった射撃練習の的です。七つ全部落とせたら、ビール三杯分、お店の支払いをおまけします。

14.773秒 / event:farm:13

VOICEVOX:Voidoll / style 89 / speed 1.0

## ナレーション — 108e7bc26387c8e1

CHAPTER 03 — 巨大そば屋
山道の先、廃屋の前に巨大なそば屋がいる。あいつを倒せば、そば屋エンジンは止まる。

12.522秒 / event:last_order:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

発話本文: 第三章。 巨大そば屋 山道の先、廃屋の前に巨大なそば屋がいる。あいつを倒せば、そば屋エンジンは止まる。

## そば屋 — e1c5ac6a08b21be7

ビールが飲めて、仕事も終わらない。メリットです！ 乾杯！

5.011秒 / event:last_order:1

参照 `02_CHARACTERS/Sobaya_voice.wav` / seed 42

caption: 相手を誘うように、堂々と。最後の乾杯を呼びかける。

## 福ちゃん — b4954b949c7b79b6

あれが巨大そば屋さん……。停止ボタンのくせに、ずいぶん元気ですね。こっちが先に停止しそうです。

7.240秒 / event:last_order:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## 福ちゃん — ab2e295d70f7956a

よーたん、辞令どおり撃ちますからね。巨大そば屋さん、今日は定時で止まっていただきます。

5.920秒 / event:last_order:3

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## ナレーション — cf7ac4480acc5b72

家の中で互いの無事を確かめた三人は、外へ出て最後の荷物をまとめた。桟橋には救助船が着いている。
「帰任票は要りません。そこにいる人、全員乗せます」。避難者は、先に乗船した。

19.515秒 / event:ending:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

発話本文: 家の中で互いの無事を確かめた三人は、外へ出て最後の荷物をまとめた。桟橋には救助船が着いている。 「帰任票は要りません。そこにいる人、全員乗せます」。避難者は、先に乗船した。

## やめ太郎 — df730f5fa90ea440

約束どおり、三人分の席や。全員生還で完了報告。こんな分かりやすい検収、初めてやで。

8.120秒 / event:ending:1

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。

## 福ちゃん — 5b650e881fc83dcc

打ち上げの出欠確認、全社員に送っておきますね。今度は間違えないように、全員返信で。

6.920秒 / event:ending:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。

## やめ太郎 — 1278849e692ea715

その機能、いったん止めよか。ワイ、店の予約より先に出向先の予約したないねん。

6.560秒 / event:ending:3

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。

## たこさん — 9c5fd54c85830500

台帳は私が持ちました。避難者は先に乗船済みです。あの世話係、船でおにぎりを二つ食べていました。おかわりは無料だそうです。

11.051秒 / event:ending:4

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 5ad460966cacc894

あの日記の続き、おにぎりの感想だといいですね。業務日報だったら、僕が差し戻します。

6.840秒 / event:ending:5

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。

## 福ちゃん — 6b10ca9d264c1271

二つも食べたなら、研修で一番いい成果ですね。報告書、そこだけ大きく書きましょう。

6.720秒 / event:ending:5:unread

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。

## やめ太郎 — 23537f9ea9a7fdaf

せやな。……ところで、この椅子、段ボールやない？ ワイ、二週間ぶりにくつろいだんやけど。

7.560秒 / event:ending:6

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 関西弁で仲間へ話す。椅子が段ボールだと気づき、そのあと二週間ぶりにくつろいだとぼやく。二つの文を最後まで明瞭に話す。

発話本文: せやな。ところで、この椅子、段ボールやない？ ワイ、二週間ぶりにくつろいだんやけど。

## たこさん — 36564756ecd55008

アーロンチュアです。快適です。

2.379秒 / event:ending:7

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — d20d269ae8c2fbba

ぎゅぎゅんです。じゃあ今日は、お茶で乾杯しましょう。

3.960秒 / event:ending:8

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。

## やめ太郎 — 80e767790fc421c8

次の研修先、茶畑とか言わんといてな。

3.680秒 / event:ending:9

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: ほっとして、親しい仲間に軽い冗談を交えながら自然に話す。

## やめ太郎 — 57d4b34674e769d8

ワイは未完成の画面を、完成しました言うて納品したんや。そしたら出向の手続きだけ、一日で完成したわ。

8.960秒 / dialogue:yametaro:intro:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 7967323a13380607

僕がやらかす前から、ここにいたんですね。ずっと一人で案内を？

4.800秒 / dialogue:yametaro:intro:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — e73f01e4f08d5751

最初は迎えの船を待っとっただけや。来る船が毎回、新入り置いて帰るから、放っとけんようになったんや。

7.640秒 / dialogue:yametaro:intro:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 6798f73ad77fbf8f

ワイ、ここで逃げてくる人を待っとくわ。そば屋さんを連れて戻ってくるのだけは勘弁な。

6.360秒 / dialogue:yametaro:greeting:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 2bb233be91faa0cd

広場の北にある納屋で鍵を拾って、北東の門へ。右手の二階建てにはショットガンもあるで。

7.600秒 / dialogue:yametaro:route:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — fd9919a42dfd7f31

たこさんは農場ですね。補給して、帰りの船を呼ぶ方法を探します。

5.720秒 / dialogue:yametaro:route:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 44ad8da43128dcdd

ワイ、納品が終わったら長い休み取るつもりやってん。こんな長期滞在を頼んだ覚えはないで。

7.000秒 / dialogue:yametaro:route:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 085eb0a68ba76792

ジョッキを上げたら横へ避けるんや。Xで回避や。頭を狙ってひるませたら、近づいてFで蹴れるで。

8.480秒 / dialogue:yametaro:combat:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

発話本文: ジョッキを上げたら横へ避けるんや。エックスで回避や。頭を狙ってひるませたら、近づいてエフで蹴れるで。

## やめ太郎 — 048bb65a051f3121

落としたビールは拾っとき。たこさんが農場で回収しとる。弾と交換して、そば屋さんに飲まれんよう封をするんや。

8.480秒 / dialogue:yametaro:combat:1

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 6375d03c03ffd7b4

銃の件はよーたんがええ言うたんやろ？ ほなええわ。ワイ、そういう確認は早いで。

6.080秒 / dialogue:yametaro:combat:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — beabdad0ef0a8cf0

壁のポスター、懐かしいやろ。島流しにされた社員が持ち込んだんや。裏の書き込みや日記も、Eで拾えばその場で読める。あとから見るならCや。

11.120秒 / dialogue:yametaro:records:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

発話本文: 壁のポスター、懐かしいやろ。島流しにされた社員が持ち込んだんや。裏の書き込みや日記も、イーで拾えばその場で読める。あとから見るならCや。

## 福ちゃん — 9f04ee049e3ab910

映画会の案内まである。待ってる間に、村で暮らす準備をしてたんですね。

5.440秒 / dialogue:yametaro:records:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 5f457edd371151e7

ワイの指名手配書だけ、まだ現役みたいなんやけど。あれ剥がしといてくれへん？

5.760秒 / dialogue:yametaro:records:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — bf4af4dcd88fbadc

そば屋エンジンって、機械の名前かと思ってました。クローンにビールを飲ませて、腕力で回すんですね。

7.280秒 / dialogue:yametaro:engine:0

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — df0d0490d009b54f

夢の新動力いうから見に行ったら、そば屋さんがぐるぐる歩いとった。そら力は強いやろけど。

7.240秒 / dialogue:yametaro:engine:1

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 81e55d55086f403c

ビールを飲んで歩くだけで仕事になるんですね。僕、志望動機が書けそうです。

5.440秒 / dialogue:yametaro:engine:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 2b21dc185a9ac861

帰す担当者がおらん仕事やぞ。応募するより、止めて帰るほうを考えてくれ。

6.040秒 / dialogue:yametaro:engine:3

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 29fb98edc5481672

撤収対象、端末、機材、契約書。人の名前、どこや。ワイらより箱のほうが大事なんか。

7.800秒 / dialogue:yametaro:evidence:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 4044d552501dc844

受入窓口だけ動いたままです。中止になった現場へ、別々の部署が着任者を送り続けてたんですね。

7.880秒 / dialogue:yametaro:evidence:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — a4b6f7c44bafdc96

迎えの船や思って手ぇ振ったら、福ちゃんが降りてきた理由、それかい。次の便は、誰も降ろさずに帰らせよな。

8.400秒 / dialogue:yametaro:evidence:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — ab3329b2715a0782

弾十発、持っていき。ワイはここを見とく。この案件が片付いたら、打ち上げの店はワイが予約するわ。絶対やで。

9.000秒 / dialogue:yametaro:supplies:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — bee5b0af3bf3b993

ケースがいっぱいや。荷物を整理して戻ってき。無茶して全部背負わんでもええんやで。

6.240秒 / dialogue:yametaro:full:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## たこさん — fead7a6607cb0894

一週間で店らしくなりました。倉庫に残った弾とハーブです。ビールと交換すれば、回収と補給を一度にできます。

9.664秒 / dialogue:takosan:intro:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — ee4acb473eb1ca31

どうして、たこさんまで島流しに？

2.800秒 / dialogue:takosan:intro:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 4fc0e2fd6ebf6d98

社員の画像を、フリー素材としてネットで配っていたのがバレました。商用利用も可にしていました。

7.691秒 / dialogue:takosan:intro:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — d68f477767829f6b

僕の画像もありました？

3.200秒 / dialogue:takosan:intro:3

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — fae6cfbaa952e830

はい。背景透過版が人気でした。

3.136秒 / dialogue:takosan:intro:4

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — b108645a8a53065e

便利ですね。……いや、勝手に透過しないでください。

3.720秒 / dialogue:takosan:intro:5

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 7436b43dd3016e39

お帰りなさい。ビールはこちらへ。帰りの人数も、忘れずに数えましょう。

6.411秒 / dialogue:takosan:greeting:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 7dd43297b355e209

名目は特別研修。実際は、失敗しても表に出せない案件を、窓際社員にやらせる場所でした。

8.693秒 / dialogue:takosan:engine:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 06bcf092333b1ce2

僕も、実技の多い研修だと思ってました。支給品が銃でも、最近はそういう会社なのかなって。

7.360秒 / dialogue:takosan:engine:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 5ef4e1d69d932d14

普通は筆記用具です。私が来た時には責任者も不在でした。お店には人が来るので、事情はお客さんから聞きました。

9.792秒 / dialogue:takosan:engine:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 876bf58b1b598424

四体から十二体、最後は二十四体。納期を縮めるたび、そば屋を増やしています。世話係の名前は、ずっと一人です。

10.731秒 / dialogue:takosan:evidence:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 6d1d4fe4099989ae

日記にあった世話係ですね。一人で抱え込んだまま、置いていかれた。まだ、ここで待っているんでしょうか。

7.480秒 / dialogue:takosan:evidence:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — ba8a4a082372f984

宿舎に避難している社員がいます。巨大そば屋を倒したら、私が桟橋まで連れていきます。福ちゃんの席も残します。

9.525秒 / dialogue:takosan:evidence:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## やめ太郎 — 06e0d554149d0059

うわー！ そば屋さん、やめてくれー！

3.760秒 / dialogue:reaction:yametaro:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 突然殴られて痛がり、仲間に助けを求める。短く切迫して。声の同一性は保つ。

## やめ太郎 — c1f644501fa829c1

痛いって！ ワイ、ビール持ってへん！

3.440秒 / dialogue:reaction:yametaro:1

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 突然殴られて痛がり、仲間に助けを求める。短く切迫して。声の同一性は保つ。

## やめ太郎 — fba3cc4df67ccf1e

福ちゃん……まだ、帰れてへんやん……。

3.280秒 / dialogue:reaction:yametaro:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 突然殴られて痛がり、仲間に助けを求める。短く切迫して。声の同一性は保つ。

## たこさん — 58a1f8518fa007b0

いたっ！ そば屋さん、落ち着いて！

2.368秒 / dialogue:reaction:takosan:0

VOICEVOX:Voidoll / style 89 / speed 1.08

## たこさん — b11733a3e2a4acd4

殴らないで。ビールは渡せません。

2.677秒 / dialogue:reaction:takosan:1

VOICEVOX:Voidoll / style 89 / speed 1.08

## たこさん — 739e324a440e7cab

福ちゃん……補給所を、頼みます……。

2.848秒 / dialogue:reaction:takosan:2

VOICEVOX:Voidoll / style 89 / speed 1.08

## やめ太郎 — 356d3982a5add07d

裏道から先回りしたで。でっかいそば屋さんは、家の前や。ワイはここで帰り道を見とく。打ち上げの幹事が欠席するわけにいかんからな。

10.360秒 / dialogue:mountain_yametaro_before:intro:0, dialogue:mountain:before

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 4ee2ba97a5a36b78

ワイはこの家で待っとる。そば屋さんを倒したら戻ってきてや。完了報告を本人から聞くまで、打ち上げは始めへんで。

8.720秒 / dialogue:mountain_yametaro_before:greeting:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — fcc75cc458024fcf

家の前の巨大そば屋を倒すんや。玄関が開いたら中へ来て、ワイとたこさんの二人に声をかけてな。無事を確かめてから帰るで。

9.880秒 / dialogue:mountain_yametaro_before:route:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 82bf80e175f56c50

あのジョッキが上がったら、横へ避けるんや。振り終わりに頭を狙う。乾杯の誘いに乗ったら、帰りは平らになるで。

8.920秒 / dialogue:mountain_yametaro_before:combat:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — a043acc0d4ca80a3

家の壁にもポスターがあるで。回収するなら今のうちや。会社の備品か聞かれたら、ワイが「私物です」って先に言うとく。

8.800秒 / dialogue:mountain_yametaro_before:records:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — c3f3c77a2fbcff36

あのでかい一体が、最後まで機械を回しとる。止めたら誰も仕事せんで済む。ワイの理想の職場、一回撃たな実現せえへんのか。

10.200秒 / dialogue:mountain_yametaro_before:engine:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — cb0286e22ad17121

撤収リストに人の名前はないのに、ワイの手配書は残っとった。帰す気はないけど、捕まえる気はあるんやな。

8.120秒 / dialogue:mountain_yametaro_before:evidence:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 81244c11b2140ece

福ちゃん、生きとった！ ワイ、打ち上げの人数、減らさんと待ってたで。

5.080秒 / dialogue:mountain_yametaro_after:reunion:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 54d197adad9b43b5

あんな大きな停止ボタン、初めて押しました。指じゃなくて経費で。

4.760秒 / dialogue:mountain_yametaro_after:reunion:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 5f372dd3fe7284fa

そこ弾代って言うてくれ。会社ごと止めたみたいになるやろ。

4.600秒 / dialogue:mountain_yametaro_after:reunion:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 902c431cd3390c44

出発前に、ワイとたこさん、二人の声を聞いてな。既読だけつけて帰るんはなしやで。

6.880秒 / dialogue:mountain_yametaro_after:reunion:3

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — cfebec4b10883a0e

打ち上げ、三人席やで。ワイの名前で予約したら、店から会社に通報されへんかな。

6.360秒 / dialogue:mountain_yametaro_after:greeting:0, dialogue:mountain:after

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 0c3a820722b4a604

ワイとたこさん、二人の無事を確かめたら出発や。話を最後まで聞いてから、荷物まとめよか。

7.160秒 / dialogue:mountain_yametaro_after:route:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 5c23d7cb0116f282

これで、ようやく帰任申請ですね。

3.120秒 / dialogue:mountain_yametaro_after:route:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — e0c2f4251166b495

申請は船に乗ってからや。差し戻される前に圏外へ出るで。

5.120秒 / dialogue:mountain_yametaro_after:route:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — d8274ba570f657f8

停止手順は一行なのに、やることは大きかったですね。

4.320秒 / dialogue:mountain_yametaro_after:engine:0

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — b90189855dfff12f

成功事例には「ボタンひとつで停止」って書かれるんやろな。サイズは載せへん。

5.840秒 / dialogue:mountain_yametaro_after:engine:1

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 8239093a75eea459

記録は持って帰ろ。写真も日記も。ワイの指名手配書だけは、歴史資料として扱ってな。

7.280秒 / dialogue:mountain_yametaro_after:evidence:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 3e511fd104a333a2

賞金のところに、済って書いておきます？

3.360秒 / dialogue:mountain_yametaro_after:evidence:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

発話本文: 賞金のところに、すみって書いておきます？

## やめ太郎 — 4a005259a4f15a81

ワイが換金されたことになるやろ！

3.160秒 / dialogue:mountain_yametaro_after:evidence:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## たこさん — cf9969f9f94b92d3

お疲れさまです。静かになったので、宿舎の人たちと裏道を通ってきました。皆さんはこの家の裏で待っています。

9.088秒 / dialogue:mountain_takosan_after:reunion:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 8f97077680c4842e

たこさんも来てたんですね。お店ごと？

3.040秒 / dialogue:mountain_takosan_after:reunion:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 29dcd266bcc21402

避難先でも営業します。帰りの船は無料です。私も乗るので。

5.515秒 / dialogue:mountain_takosan_after:reunion:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 31fbc0d280afb112

出発前に、私とやめ太郎の二人に声をかけてください。安否確認が済んだら、全員で船へ向かいます。

8.960秒 / dialogue:mountain_takosan_after:reunion:3

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — f9d6c125c5b81e14

出張補給所です。残ったビール、持ち越しても有休にはなりませんよ。

5.781秒 / dialogue:mountain_takosan_after:greeting:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 5cdefdb11f272c50

救助船には連絡済みです。私とやめ太郎、二人との話が済んだら出発します。帰任票は要りません。乗船名簿も作りました。

10.891秒 / dialogue:mountain_takosan_after:route:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — e340caf8689405e5

僕の名前、ちゃんとあります？ 全社員の配属を変えた時、自分も名簿から消したかもしれなくて。

7.160秒 / dialogue:mountain_takosan_after:route:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — b3404370eda0e14d

ありますよ。窓際配属のままです。そこは責任を持って連れ帰ります。

5.845秒 / dialogue:mountain_takosan_after:route:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — d35b1703af408590

巨大そば屋が倒れて、エンジンと放送は止まりました。村に残ったクローンまで消えるわけではありません。

7.893秒 / dialogue:mountain_takosan_after:engine:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — be4a4f337a7ad493

案件は終了、残作業は別料金というわけですね。

4.360秒 / dialogue:mountain_takosan_after:engine:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 2e2cb3007f004775

弾も別料金です。理解が早くて助かります。

4.171秒 / dialogue:mountain_takosan_after:engine:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — bbdd6c3ed7dafc9e

宿舎にいた人は全員、この家の裏にいます。世話係も無事です。私がネットで配った社員の画像と照合して、人数も確認しました。

11.659秒 / dialogue:mountain_takosan_after:evidence:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 300d99ed9fee4a69

社員の画像、ネットで配ってたんですか。安否確認までできるフリー素材、便利ですね。

6.600秒 / dialogue:mountain_takosan_after:evidence:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 1032316928eaa923

商用利用も可です。今回は本人にも確認しました。利用規約はあとで考えます。

7.285秒 / dialogue:mountain_takosan_after:evidence:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## やめ太郎 — 81c35585a5303b14

エンジンは止まったけど、まだそば屋さんが残っとる。この難度では全員倒すまで家の玄関は開かへん。弾が足りんかったら、農場のたこさんにビールを渡すんや。

11.760秒 / dialogue:mountain:after:remaining

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## たこさん — 79557dac21666448

救助船には連絡しました。ただ、この難度では残ったそば屋を全員倒すまで家の玄関が開きません。私は農場で補給を続けます。ビールをお持ちください。追加のお仕事、お待ちしています。

16.672秒 / dialogue:mountain:after:remaining

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — cead3f8a8bf2a541

二十四体の世話を、一人で？ その人も置いていかれたんですか。まだ、この村にいるんでしょうか。

6.680秒 / dialogue:takosan:evidence:unread

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — fc7a61d856412a06

お得意様だけに、ロケットランチュアです。弾は無限。そば屋を追いかけて吹き飛ばします。ビールも蒸発するので、返品はお断りです。

11.424秒 / dialogue:purchase:rocket

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 927eee0a51a7ebe5

ハンドガンの弾、十発です。これでそば屋を蜂の巣にしてください。領収書は研修費で切れます。

7.829秒 / dialogue:purchase:ammo

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 162a9842e4d28573

ショットガンの弾、五発です。そば屋が近づいたら、景気よくどうぞ。壁の修理代は別です。

7.723秒 / dialogue:purchase:shells

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — c1007bc9b0b80dd3

グリーンハーブです。疲れも痛みも、すーっと消えますよ。何が入っているかは、聞かないほうが長生きできます。

8.725秒 / dialogue:purchase:herb

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — a042352914f8da89

それってギュンギュンってこと？

2.720秒 / dialogue:purchase:herb:reply:0

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — e3ea96c86cc000aa

ギュンギュンです。

1.077秒 / dialogue:purchase:herb:reply:1

VOICEVOX:Voidoll / style 89 / speed 1.0
