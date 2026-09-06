class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker, text;
}

const yametaroDialogue = <String, List<DialogueLine>>{
  "intro": [
    DialogueLine("やめ太郎", "ワイは未完成の画面を、完成しました言うて納品したんや。そしたら出向の手続きだけ、一日で完成したわ。"),
    DialogueLine("福ちゃん", "僕の障害より前に、もうここへ来てたんですね。ずっと一人で案内を？"),
    DialogueLine("やめ太郎", "最初は迎えの船を待っとっただけや。来る船が毎回、新入り置いて帰るから、放っとけんようになったんや。"),
  ],
  "greeting": [
    DialogueLine("やめ太郎", "ワイ、ここで逃げてくる人を待っとくわ。そば屋さんを連れて戻ってくるのだけは勘弁な。"),
  ],
  "route": [
    DialogueLine("やめ太郎", "広場の北にある納屋で鍵を拾って、北東の門へ。右手の二階建てにはショットガンもあるで。"),
    DialogueLine("福ちゃん", "たこさんは農場ですね。補給して、帰りの船を呼ぶ方法を探します。"),
    DialogueLine("やめ太郎", "ワイ、納品が終わったら長い休み取るつもりやってん。こんな長期滞在を頼んだ覚えはないで。"),
  ],
  "combat": [
    DialogueLine("やめ太郎", "ジョッキを上げたら横へ避けるんや。Xで踏み込める。頭を狙ってひるませたら、近づいてFで蹴れるで。"),
    DialogueLine("福ちゃん", "落としたビールも拾っておいてください。補給所に預ければ、そば屋たちに飲まれずに済みます。"),
    DialogueLine("やめ太郎", "銃の件はよーたんがええ言うたんやろ？ ほなええわ。ワイ、そういう確認は早いで。"),
  ],
  "records": [
    DialogueLine(
      "やめ太郎",
      "壁のポスター、懐かしいやろ。島流しにされた社員が持ち込んだんや。裏の書き込みや日記も、Eで拾ってCで読めるで。",
    ),
    DialogueLine("福ちゃん", "映画会の案内まである。待ってる間に、村で暮らす準備をしてたんですね。"),
    DialogueLine("やめ太郎", "ワイの指名手配書だけ、まだ現役みたいなんやけど。あれ剥がしといてくれへん？"),
  ],
  "engine": [
    DialogueLine("福ちゃん", "そば屋エンジンって、機械の名前かと思ってました。クローンにビールを飲ませて、腕力で回すんですね。"),
    DialogueLine("やめ太郎", "夢の新動力いうから見に行ったら、そば屋さんがぐるぐる歩いとった。そら力は強いやろけど。"),
    DialogueLine("福ちゃん", "止める担当者も必要だったはずです。資料をたどれば、帰った人が何を残したか分かるかもしれません。"),
    DialogueLine("やめ太郎", "納品した箱だけ数えて、あと知らんはあかんわな。……ワイも、帰ったら一件電話せなあかんわ。"),
  ],
  "evidence": [
    DialogueLine("やめ太郎", "撤収対象、端末、機材、契約書。人の名前、どこや。ワイらより箱のほうが大事なんか。"),
    DialogueLine("福ちゃん", "受入窓口だけ動いたままです。中止になった現場へ、別々の部署が新人を送り続けてたんですね。"),
    DialogueLine("やめ太郎", "迎えの船や思って手ぇ振ったら、福ちゃんが降りてきた理由、それかい。次の便は、誰も降ろさずに帰らせよな。"),
  ],
  "supplies": [
    DialogueLine(
      "やめ太郎",
      "弾十発、持っていき。ワイはここを見とく。この案件が片付いたら、打ち上げの店はワイが予約するわ。絶対やで。",
    ),
  ],
  "full": [DialogueLine("やめ太郎", "ケースがいっぱいや。荷物を整理して戻ってき。無茶して全部背負わんでもええんやで。")],
};

const takosanDialogue = <String, List<DialogueLine>>{
  "intro": [
    DialogueLine(
      "たこさん",
      "一週間で店らしくなりました。倉庫に残った弾とハーブです。ビールと交換すれば、回収と補給を一度にできます。",
    ),
    DialogueLine("福ちゃん", "どうして、たこさんまで島流しに？"),
    DialogueLine("たこさん", "見積もりの桁を一つ間違えました。安いほうです。今の価格は、三回確認しました。"),
  ],
  "greeting": [DialogueLine("たこさん", "お帰りなさい。ビールはこちらへ。帰りの人数も、忘れずに数えましょう。")],
  "engine": [
    DialogueLine("たこさん", "名目は特別研修。実際は、失敗しても表に出せない案件を、窓際社員にやらせる場所でした。"),
    DialogueLine("福ちゃん", "普通の辞令で来た人には、逃げる理由さえ分からない。僕も、やめさんがいなければ研修だと思ってました。"),
    DialogueLine(
      "たこさん",
      "私が着いたとき、責任者はもういませんでした。店を開けておくと人が来ます。そこで、少しずつ分かったんです。",
    ),
  ],
  "evidence": [
    DialogueLine(
      "たこさん",
      "四体から十二体、最後は二十四体。納期を縮めるたび、そば屋を増やしています。世話係の名前は、ずっと一人です。",
    ),
    DialogueLine("福ちゃん", "日記の人ですね。終われば帰れるって、何度も書いてた。ここで待ってる人が、ほかにもいるはずです。"),
    DialogueLine("たこさん", "宿舎に避難している社員がいます。中枢が止まったら、私が桟橋まで連れていきます。福ちゃんの席も残します。"),
  ],
};

const companionReactions = <String, List<DialogueLine>>{
  "yametaro": [
    DialogueLine("やめ太郎", "うわー！ そば屋さん、やめてくれー！"),
    DialogueLine("やめ太郎", "痛いって！ ワイ、ビール持ってへん！"),
    DialogueLine("やめ太郎", "福ちゃん……まだ、帰れてへんやん……。"),
  ],
  "takosan": [
    DialogueLine("たこさん", "いたっ！ そば屋さん、落ち着いて！"),
    DialogueLine("たこさん", "殴らないで。ビールは渡せません。"),
    DialogueLine("たこさん", "福ちゃん……補給所を、頼みます……。"),
  ],
};

class TradeOffer {
  const TradeOffer(this.id, this.kind, this.amount, this.price, this.stock);
  final String id, kind;
  final int amount, price, stock;
}

const tradeOffers = [
  TradeOffer('ammo', 'ammo', 10, 2, 3),
  TradeOffer('herb', 'green', 1, 3, 2),
  TradeOffer('shells', 'shells', 5, 3, 2),
];
