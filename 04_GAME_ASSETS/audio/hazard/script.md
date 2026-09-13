# そば屋ハザード — 採用音声台本

全98本、合計525.1秒。正本台詞はゲームのDartコード、生成入力は voice-lines.json、採用条件は voice-manifest.json。

福ちゃん・やめ太郎・そば屋・ナレーションは Irodori-TTS v4.1-Small と正典参照音声。たこさんは VOICEVOX:Voidoll（style 89）。24kHz mono PCM16、-18LUFS/-2dBTP。

この台本は build_hazard_voice.py が採用manifestから生成する。使用箇所には章・話題・既読分岐を記録する。購入失敗時の文言は字幕と返答音。

## やめ太郎 — ca456e79bf590162

まず、黄色い目印まで歩いてみよか。周りを見ながらでええで。

4.920秒 / tutorial:move

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — ed633b2c4c6f9b93

銃を構えて、標的を狙うんや。ワイに向けたら研修中止やで。

5.440秒 / tutorial:aim

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 731634046066cbf3

狙いが合ったら、標的を撃ってみ。慌てんでええ、一発ずつや。

4.840秒 / tutorial:shoot

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 1974b12f6dbefe30

当たったな。次は弾を込め直そか。そば屋さん、装填中は待ってくれへんからな。

6.080秒 / tutorial:reload

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 59ad49ec0d74fd52

あっちを向いとる間に、背後を忍び足で通るんや。走ると足音で気づかれるで。

6.360秒 / tutorial:sneak

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — bd9088645e287815

見つかったら、物陰に隠れるんや。発見ゲージが消えるまで、顔を出さんといてな。

5.800秒 / tutorial:escape

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 18d1eee20f1d2369

よっしゃ。見つかっても、撃つだけが答えやない。ほな、村へ入ろか。

5.200秒 / tutorial:complete

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — ea4c5999b2887c11

弾二十五発、持っていき。商店街までこれでしのぐんや。ビールを拾っとけば、向こうでたこさんが弾と交換してくれる。打ち上げの店はワイが予約するわ。絶対やで。

12.480秒 / dialogue:yametaro:supplies:hard

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## そば屋 — 2b3687b44fb1d838

そば屋ハザード。

1.382秒 / event:title_call:0

参照 `02_CHARACTERS/Sobaya_voice.wav` / seed 42

caption: ゲームのタイトルコール。低く重厚に、そば屋ハザード、と一息ではっきり告げる。語尾は短く、乾いた威圧感。

## ナレーション — 4fbc6e556ea9c373

ゆめみ港。特別研修、帰任日未定。福ちゃんを降ろした船は、銃と辞令を残して岸を離れた。

10.907秒 / event:opening:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

## 福ちゃん — 5180cacf91d97f7e

着任受付へ行けばいいんですね。研修の支給品が銃なのは、少し気になります。

6.200秒 / event:opening:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 3da49cb50125e05a

村にそば屋さんがぎょうさんおってな。ビール言うて追いかけてくるんや。まず身を守る練習しよか。

7.040秒 / event:opening:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 8e040368adeff43c

どうせそば屋が、ビール置くのに邪魔や言うて呪いの祠でも壊したんやろ。

5.440秒 / event:opening:3

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — d37b31425b81552e

そんな理由で壊します？

2.960秒 / event:opening:4

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 503f193247783f16

そば屋やで？

4.960秒 / event:opening:5

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 85748e8614a6ae4f

北の漁具倉庫で鍵を取って、北東の門から商店街へ。たこさんが店をやっとる。ワイは次の船をここで待つわ。

9.280秒 / event:chapter1intro:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — ca7c8f98b424ff72

村の様子を見てきます。受付に誰かいるといいんですが。

4.200秒 / event:chapter1intro:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## ナレーション — 9e4a79ddcd340d25

CHAPTER 02 — 村の生活圏
閉じた商店街で、一軒だけ暖簾が出ている。

8.024秒 / event:farm:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

発話本文: 第二章。 村の生活圏 閉じた商店街で、一軒だけ暖簾が出ている。

## たこさん — f9bade3c3cb8638e

いらっしゃいませ。一週間前に送られてきました。迎えの船は来ませんが、お客さんは来るので、店にしました。

8.960秒 / event:farm:1

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 7d2ceeb79431d22d

空き店舗で営業してるんですね。村のそば屋さんたち、どうしたんですか？

4.840秒 / event:farm:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — b2cf65658626d5a8

私も分かりません。ビールばかり欲しがって、代金を払ってくれないんです。山の神社からも、大きな音がします。

9.696秒 / event:farm:3

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 704b04b807164cd4

ここではビールを弾やハーブと交換できます。参道の鍵と村の案内図を探して、山へ行く前に準備しましょう。

9.013秒 / event:farm:4

VOICEVOX:Voidoll / style 89 / speed 1.0

## ナレーション — 2025027d33721e90

CHAPTER 03 — 山の神社
境内で、巨大なそば屋が暴れている。

6.945秒 / event:last_order:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

発話本文: 第三章。 山の神社 境内で、巨大なそば屋が暴れている。

## そば屋 — 862d02e7f4aac0f7

ビール……よこせ……

2.761秒 / event:last_order:1

参照 `02_CHARACTERS/Sobaya_voice.wav` / seed 42

caption: 言葉をうまくつなげられない怪物。単語ごとに途切れ、息を漏らして低くうなる。ビールへの渇望。文章を流暢にせず、指定された単語だけを明瞭に言う。

## 福ちゃん — 5f00086c22b1f4bb

あれが音の正体ですか。祠より、そば屋さんの方が大きいですね。

5.280秒 / event:last_order:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## そば屋 — 1155a151b4624ecd

カイシャ……ビール……くれない……

3.965秒 / event:boss_confession:0

参照 `02_CHARACTERS/Sobaya_voice.wav` / seed 42

caption: 言葉をうまくつなげられない怪物。単語ごとに途切れ、息を漏らして低くうなる。ビールへの渇望。文章を流暢にせず、指定された単語だけを明瞭に言う。

## そば屋 — 04ed809a099493bb

アクシデンチュア……ビール……よこせ……

4.264秒 / event:boss_confession:1

参照 `02_CHARACTERS/Sobaya_voice.wav` / seed 42

caption: 言葉をうまくつなげられない怪物。単語ごとに途切れ、息を漏らして低くうなる。ビールへの渇望。文章を流暢にせず、指定された単語だけを明瞭に言う。

## 福ちゃん — 72ea8c42a79e6735

今、うちの会社の名前を……？

2.800秒 / event:boss_confession:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## 福ちゃん — 6f3bcdc3274ce6b5

祠は壊れていませんね。……裏手から、まだ機械の音がします。

5.040秒 / event:boss_defeated:0

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## ナレーション — ad778e9f775384a5

神社の裏手。木々と擁壁の陰に、通電した施設の搬入口があった。

6.724秒 / event:ending:0

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

## 福ちゃん — 9ec7a64e8c9a95d9

アクシデンチュア……。さっき、ここの名前を言っていましたね。

4.760秒 / event:ending:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 不審な施設を見つけ、静かに驚きながら独り言のように話す。疑問を残す抑制した声。

## 福ちゃん — bc6a0c41ae9f86fc

……研修先って、こっちですか？

3.200秒 / event:ending:2

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 不審な施設を見つけ、静かに驚きながら独り言のように話す。疑問を残す抑制した声。

## ナレーション — 43009f87531754bc

村の異変と、会社の施設。扉の向こうに、何が残されているのか。
そば屋ハザード — 体験版 終

11.026秒 / event:ending:3

参照 `02_CHARACTERS/YumeTeleAnchor_voice.wav` / seed 2026

caption: 落ち着いたアナウンサーの情景ナレーション。標準語で、明瞭に、ゆっくりと文章の区切りに間を取り、最後まで読み上げる。抑制された抑揚で真面目に話す。

発話本文: 村の異変と、会社の施設。扉の向こうに、何が残されているのか。 そば屋ハザード — 体験版、終わり。

## やめ太郎 — 57d4b34674e769d8

ワイは未完成の画面を、完成しました言うて納品したんや。そしたら出向の手続きだけ、一日で完成したわ。

8.960秒 / dialogue:yametaro:intro:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 74aa056e4735b228

僕は本番で全社員を窓際配属にしてしまって。社長にも通知が行きました。

6.320秒 / dialogue:yametaro:intro:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 942c628a74ef9a32

そら船も出るわ。帰りの船は、まだ来んけどな。

4.080秒 / dialogue:yametaro:intro:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 111ca5af4bf001ad

次の船をここで待っとくわ。そば屋さんを連れて戻ってくるのだけは勘弁な。

5.800秒 / dialogue:yametaro:greeting:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 29efb4d663e10221

北の漁具倉庫で鍵を拾って、北東の門から商店街へ。右手の二階建てにはショットガンもあるで。

8.080秒 / dialogue:yametaro:route:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 54416ee1c5d1c17f

たこさんの店で準備して、神社のことも聞いてみます。

3.960秒 / dialogue:yametaro:route:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 97f3936bfc49a0f7

ジョッキを上げたら横へ避けるんや。囲まれたら、先に逃げ道を探すんや。

5.720秒 / dialogue:yametaro:combat:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — e6de3cca5059516a

落としたビールは拾っとき。商店街のたこさんが弾と交換してくれる。

5.640秒 / dialogue:yametaro:combat:1

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 0fe8579679297011

よーたんが撃ってええ言うたんやろ？ ほなええわ。

3.560秒 / dialogue:yametaro:combat:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 5c7c66df88107d23

会社が来た頃は、店も社宅も人でいっぱいやったらしいで。貼り紙ばっかり残っとる。

6.440秒 / dialogue:yametaro:records:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — 9c869e80e3f4aa9b

退去の通知より、新しい着任の案内が目立ちますね。

4.600秒 / dialogue:yametaro:records:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — f0ce29287a4d13c6

原因はまだ分からん。神社に行ったら何か分かるやろ。

4.240秒 / dialogue:yametaro:engine:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — e0e9109fee214188

そば屋が呪いの祠でも壊したんやろ。ビール置くのに邪魔や言うて。

5.120秒 / dialogue:yametaro:evidence:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — f5439de22d726f1d

それ、考察というより悪口では？

3.120秒 / dialogue:yametaro:evidence:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — e2b84aa42c7ada3e

経験則や。

5.120秒 / dialogue:yametaro:evidence:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 572830e3046bd7b0

弾十発、持っていき。商店街までこれでしのぐんや。

4.720秒 / dialogue:yametaro:supplies:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 3fafce96ddb41fea

ケースがいっぱいや。荷物を整理して戻ってき。

3.840秒 / dialogue:yametaro:full:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## たこさん — 664d0421b3a67b59

空き店舗を借りて、店らしくしてみました。ビールと弾やハーブを交換します。

6.176秒 / dialogue:takosan:intro:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — ee4acb473eb1ca31

どうして、たこさんまで島流しに？

2.800秒 / dialogue:takosan:intro:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 33f621ce7a59d75f

社員の画像をフリー素材として配っていたのがバレました。背景透過版が人気でした。

6.741秒 / dialogue:takosan:intro:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — ef120ccebe706928

勝手に透過しないでください。

3.960秒 / dialogue:takosan:intro:3

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — dfcb1583916b2d7d

お帰りなさい。神社へ向かう前に、補給していってください。

4.800秒 / dialogue:takosan:greeting:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — f4490da275b4cf79

山の音の正体は、まだ分かりません。私は店を開けておきます。

5.515秒 / dialogue:takosan:engine:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — f69bc1b00d4ba7ea

会社が事業を引き揚げて、お店も人も減ったそうです。私たちの出向だけは続いていますけど。

7.605秒 / dialogue:takosan:evidence:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 5494d67e67fb2ed8

住む人を増やす方法が、独特ですね。

3.680秒 / dialogue:takosan:evidence:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 041a34bf9ebad824

旧管理室に参道の門の鍵、集会所の二階に村の案内図があるそうです。見つけたら、ここへ戻ってきてください。

9.557秒 / dialogue:farm_mission:request:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 65c5c61bb416e396

ビールは弾やハーブと交換できます。青いメダリオンは七つでビール三杯。腕試しはご自由にどうぞ。

8.139秒 / dialogue:farm_mission:request:1

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — ce8f5b03a3266bb8

これが参道の鍵ですね。案内図では、東の門の先に神社があります。山から大きな音がするのは、そのあたりです。

9.803秒 / dialogue:farm_mission:ready:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — 5ee814ff56e78b31

祠が無事か、確かめてきます。

3.040秒 / dialogue:farm_mission:ready:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## たこさん — 73f101a8e39c0ad9

壊れていても修理は受注しないでくださいね。帰りが遅くなります。

5.344秒 / dialogue:farm_mission:ready:2

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — acf15a0b2ff2a8e1

東の門から山の神社へ行けます。私はここで営業しています。足りなくなったら戻ってきてください。

8.085秒 / dialogue:farm_mission:complete:0

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

## やめ太郎 — a68cbccb25806805

神社の方で、えらい音がするな。祠の様子を見てきてくれへんか。

5.080秒 / dialogue:mountain_yametaro_before:intro:0, dialogue:mountain:before

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 41d01d97b74e57e0

ビールの奉納だけで済む祟りやったらええんやけどな。

4.040秒 / dialogue:mountain_yametaro_before:greeting:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 32c84af370de344a

境内の巨大そば屋を倒して、祠を調べるんや。

4.240秒 / dialogue:mountain_yametaro_before:route:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 88302bde12ae9bbe

ジョッキが上がったら横へ避ける。振り終わりに頭を狙うんや。

4.783秒 / dialogue:mountain_yametaro_before:combat:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 8ea6881552e57379

古い神社やな。会社が来る前から、ここにあったんやろ。

4.360秒 / dialogue:mountain_yametaro_before:records:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 3cb08ffe97ded93f

あの音が何か、まだ分からん。

3.200秒 / dialogue:mountain_yametaro_before:engine:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — fa47e9903c01ff2a

呪いの祠いうのはワイの予想やで。調査報告書にはまだ書かんといてな。

5.960秒 / dialogue:mountain_yametaro_before:evidence:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — ab412ba086aa13df

福ちゃん、無事やったか。祠、別に壊れてへんな。

4.080秒 / dialogue:mountain_yametaro_after:reunion:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## 福ちゃん — a0848b91b69f080d

巨大そば屋さん、会社の名前を言っていました。

3.600秒 / dialogue:mountain_yametaro_after:reunion:1

参照 `02_CHARACTERS/Fukuchan_voice.wav` / seed 100

caption: 友人に話しかける。少し呆れながらも明瞭に、言葉の最後まで自然に話す。

## やめ太郎 — 6edd8c0ccb7e89ab

祟りやなくて、うちの案件かいな。

3.200秒 / dialogue:mountain_yametaro_after:reunion:2

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 459a8d3091eaa4e4

裏手に道が続いとるな。あの機械の音、どこからやろ。

4.440秒 / dialogue:mountain_yametaro_after:greeting:0, dialogue:mountain:after

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 2ec8e3d4cc97c7de

神社の東側、管理道の先を調べてみよか。

4.320秒 / dialogue:mountain_yametaro_after:route:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — 60986ca5bf726784

会社の施設らしいけど、中で何しとるんやろな。

3.920秒 / dialogue:mountain_yametaro_after:engine:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## やめ太郎 — aa45047a352312cb

祠は普通やった。ワイの考察、差し戻しやな。

4.360秒 / dialogue:mountain_yametaro_after:evidence:0

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## たこさん — dabdbd2598c6a21b

ここにも機械の音が届いていますね。店の冷蔵庫より大きいです。

5.355秒 / dialogue:mountain_takosan_after:reunion:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 7db4b3ebf9e9e3b2

村の調査は、まだ終わりそうにありませんね。

3.456秒 / dialogue:mountain_takosan_after:greeting:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — a9b7453a44925d3a

神社の東の管理道に、何かあるようです。

3.787秒 / dialogue:mountain_takosan_after:route:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — dceb12f0e6676446

何の施設か、看板を確かめてみましょう。

3.360秒 / dialogue:mountain_takosan_after:engine:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## たこさん — 61a70a5366ff26d0

神社におかしなところは見つかりませんでした。

3.232秒 / dialogue:mountain_takosan_after:evidence:0

VOICEVOX:Voidoll / style 89 / speed 1.0

## やめ太郎 — 868a8bc2e404f063

巨大そば屋は倒した。神社の東の管理道を調べようや。

4.920秒 / dialogue:mountain:after:remaining

参照 `02_CHARACTERS/Yametaro_voice.wav` / seed 7

caption: 焦りを少し抑えて、友人へ道案内する。柔らかい関西イントネーションで、聞き取りやすく自然に話す。

## たこさん — 31676161ab01c8bd

店は開いています。調査の準備をしていってください。

4.149秒 / dialogue:mountain:after:remaining

VOICEVOX:Voidoll / style 89 / speed 1.0

## 福ちゃん — d3fe4158ab7f4d72

会社が撤退しても、着任者は送られてくるんですね。

4.040秒 / dialogue:takosan:evidence:unread

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
