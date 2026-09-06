class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker, text;
}

const yametaroDialogue = <String, List<DialogueLine>>{
  "intro": [
    DialogueLine("やめ太郎", "本番を壊したんはワイらや。せやけど、廃村に三人置いて帰るんは、研修とちゃうやろ。"),
    DialogueLine("福ちゃん", "辞令には、現地の担当者から引き継ぎを受けるようにって。まず、その人を探しましょう。"),
    DialogueLine("やめ太郎", "人がおるならええけどな。さっきから見かけるん、全部そば屋さんなんや。"),
  ],
  "greeting": [
    DialogueLine("やめ太郎", "ワイ、ここで逃げてくる人を待っとくわ。そば屋さんを連れて戻ってくるのだけは勘弁な。"),
  ],
  "route": [
    DialogueLine("やめ太郎", "広場の北にある納屋で鍵を拾って、北東の門へ。右手の二階建てにはショットガンもあるで。"),
    DialogueLine("福ちゃん", "農場に管理棟があるそうです。船を呼べる無線か、ここで何があったか分かるものを探します。"),
    DialogueLine("やめ太郎", "この案件を片付けたら、ワイらも本社へ帰れるやろ。戻ったら、今度こそちゃんと休み取るわ。"),
  ],
  "combat": [
    DialogueLine("やめ太郎", "ジョッキを上げたら横へ避けるんや。Xで踏み込める。頭を狙ってひるませたら、近づいてFで蹴れるで。"),
    DialogueLine("福ちゃん", "落としたビールも拾っておいてください。補給所に預ければ、そば屋たちに飲まれずに済みます。"),
  ],
  "records": [
    DialogueLine(
      "やめ太郎",
      "壁のポスター、懐かしいやろ。島流しにされた社員が持ち込んだんや。裏の書き込みや日記も、Eで拾ってCで読めるで。",
    ),
    DialogueLine("福ちゃん", "僕らより前にここへ来た人たちの記録ですね。帰れたのかどうかも、書いてあるかな。"),
    DialogueLine("やめ太郎", "ワイの指名手配書だけ、まだ現役みたいなんやけど。あれ剥がしといてくれへん？"),
  ],
  "engine": [
    DialogueLine("福ちゃん", "この案内に、そば屋エンジンってあります。ビールを飲ませたクローンの怪力で、動力軸を回す設備だそうです。"),
    DialogueLine("やめ太郎", "ビールで動く夢のエンジンいうから、もっと機械みたいなん想像してたわ。"),
    DialogueLine("福ちゃん", "人の形をしたものが、ずっと回してたんですね。設計した人も、運用してた人も、今はどこにいるんだろう。"),
    DialogueLine("やめ太郎", "作ったやつも止め方知っとるやつもおらん。ワイらに何を引き継がせる気やったんや。"),
  ],
  "evidence": [
    DialogueLine("やめ太郎", "プロジェクト終了、現地要員は自主的に解散。……ワイら、海を泳いで帰れってことか？"),
    DialogueLine("福ちゃん", "中止通知には機材の撤収しか書いてない。クローンも、世話をしていた社員も、予算の外に置き去りです。"),
    DialogueLine("やめ太郎", "ワイらを人数で数えてたくせに、帰るときだけ誰も数えへんのやな。"),
  ],
  "supplies": [
    DialogueLine("やめ太郎", "弾十発、持っていき。ワイはここを見とく。大丈夫、この研修が終わったら、打ち上げの店はワイが予約するわ。"),
  ],
  "full": [DialogueLine("やめ太郎", "ケースがいっぱいや。荷物を整理して戻ってき。無茶して全部背負わんでもええんやで。")],
};

const takosanDialogue = <String, List<DialogueLine>>{
  "intro": [
    DialogueLine("たこさん", "ここに残っていた物資を集めました。拾ったビールを、弾やハーブと交換できます。"),
    DialogueLine("福ちゃん", "さっき着いたばかりなのに、もう補給所になってる。"),
    DialogueLine("たこさん", "待っていても、引き継ぎ担当者は来ません。まず、三人が帰る準備です。"),
  ],
  "greeting": [DialogueLine("たこさん", "お帰りなさい。ビールはこちらへ。今日はもう、誰にも軸を回させません。")],
  "engine": [
    DialogueLine("たこさん", "ここは、廃村を使った秘密案件の実験場です。名簿には、窓際社員の名前だけが並んでいます。"),
    DialogueLine("福ちゃん", "研修じゃなくて、人手の補充だったんだ。僕らの辞令にも、終了日が書いてない。"),
    DialogueLine("たこさん", "責任者は先に帰りました。残ったのは、空のビール樽と、仕事の終わらないそば屋たちです。"),
  ],
  "evidence": [
    DialogueLine(
      "たこさん",
      "この台帳、同じそば屋の顔に、別々の番号が付いています。二十四体。出庫はありますが、帰還の欄はありません。",
    ),
    DialogueLine("福ちゃん", "ビールから生まれたわけじゃない。ここで作ったクローンを、案件が炎上したあとも放置していたんですね。"),
    DialogueLine("たこさん", "山の中枢は、今も運転命令を繰り返しています。あそこを止めて、取り残された人を連れ帰りましょう。"),
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
