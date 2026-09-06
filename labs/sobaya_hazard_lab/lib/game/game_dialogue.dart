class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker, text;
}

const yametaroDialogue = <String, List<DialogueLine>>{
  'intro': [
    DialogueLine('やめ太郎', '福ちゃん！ 広場がそば屋だらけなんだ。\nこのプロジェクトが成功したら、僕、まとめて有休を取るんだ。'),
    DialogueLine('福ちゃん', '乾杯にしては、ジョッキの振りが大きすぎるだろ……。'),
    DialogueLine(
      'やめ太郎',
      '北の納屋に門の鍵がある。農場へ抜けよう。\nこの炎上は僕一人で何とかする。先に行って！ 朝までには全部直すから！',
    ),
  ],
  'greeting': [
    DialogueLine(
      'やめ太郎',
      '大丈夫、手元では動いてる。あとは本番に出すだけだよ。\nこのリリースが終わったら、みんなで打ち上げしよう。約束だよ。',
    ),
  ],
  'route': [
    DialogueLine('やめ太郎', '村の奥、広場の北に大きな納屋がある。鍵はその中だよ。\n北東の紋章がついた門を開ければ、農場へ行ける。'),
    DialogueLine('福ちゃん', 'まず鍵。余裕があれば民家も調べるか。'),
    DialogueLine(
      'やめ太郎',
      '右手の二階建ての家に、ショットガンが残ってる。持っていって。\n僕ならバックアップなしでも何とかなる。この修正、たった一行だから。',
    ),
  ],
  'combat': [
    DialogueLine(
      'やめ太郎',
      'ジョッキを振り上げたら、横へ避けて。Xで素早く踏み込めるよ。\n頭を狙ってひるませたら、近づいてFで蹴り飛ばせる。',
    ),
    DialogueLine('福ちゃん', '一人ずつ相手にすれば、弾も節約できそうだな。'),
  ],
  'records': [
    DialogueLine('やめ太郎', '家の壁に貼ってある、僕らの映画や事件の記録。\n近づいてEで集めたら、Cでいつでも見られるよ。'),
    DialogueLine('福ちゃん', '入口の家に、お前の指名手配書もあったぞ。'),
    DialogueLine(
      'やめ太郎',
      'もし僕に何かあったら、その指名手配書と未整理のチケットを頼む。\n引き継ぎ資料？ 戻ってから書けば間に合うよ。',
    ),
  ],
  'supplies': [
    DialogueLine('やめ太郎', '予備の弾、10発。全部持っていって。\n追加の応援は断っておいたよ。仕様は全部、僕の頭に入ってるから。'),
  ],
  'full': [
    DialogueLine(
      'やめ太郎',
      'ケースに空きがないね。整理したら戻ってきて。\n僕はここで本番を見てる。監視アラートは止めたし、もう静かなもんだよ。',
    ),
  ],
};

const takosanDialogue = <String, List<DialogueLine>>{
  'intro': [
    DialogueLine('たこさん', '……。そば屋を倒して、ビールを拾いましたか。\n弾やハーブと交換できます。'),
    DialogueLine('福ちゃん', 'こんな所で商売してるのか。\nそのビール、どうするんだ？'),
    DialogueLine('たこさん', '必要なことです。\n持てる量だけ、お選びください。'),
  ],
  'greeting': [DialogueLine('たこさん', '……。補給ですね。ビールはお持ちですか。')],
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
