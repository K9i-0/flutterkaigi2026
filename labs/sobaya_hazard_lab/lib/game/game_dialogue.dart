class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker, text;
}

const yametaroDialogue = <String, List<DialogueLine>>{
  'intro': [
    DialogueLine('やめ太郎', '福ちゃん！ よかった、生きてた！\n広場がそば屋だらけなんだ。しかも全員、乾杯する気満々でさ。'),
    DialogueLine('福ちゃん', '乾杯にしては、ジョッキの振りが大きすぎるだろ……。'),
    DialogueLine('やめ太郎', '農場へ抜けよう。北側の納屋に、門の鍵があるはず。\n僕はここで、まだ来てないみんなを待つよ。'),
  ],
  'greeting': [DialogueLine('やめ太郎', '必要なことがあれば聞いて。\nあ、それから壁の貼り紙も見ておいた方がいいかも。')],
  'route': [
    DialogueLine('やめ太郎', '村の奥、広場の北に大きな納屋がある。鍵はその中だよ。\n北東の紋章がついた門を開ければ、農場へ行ける。'),
    DialogueLine('福ちゃん', 'まず鍵。余裕があれば民家も調べるか。'),
    DialogueLine('やめ太郎', '右手の二階建ての家には、ショットガンが残ってる。\n囲まれる前に、逃げる道も覚えておいてね。'),
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
    DialogueLine('やめ太郎', 'それは……できれば回収してほしい。なるべく早く。'),
  ],
  'supplies': [DialogueLine('やめ太郎', '予備の弾、10発。持っていって。\n僕の分まで、みんなを連れて帰ってきてよ。')],
  'full': [DialogueLine('やめ太郎', 'ケースに空きがないみたい。整理したら、また声をかけて。\n弾はちゃんと取っておくから。')],
};
