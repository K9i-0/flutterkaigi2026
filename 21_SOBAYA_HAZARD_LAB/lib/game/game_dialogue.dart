class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker, text;
}

const yametaroDialogue = <String, List<DialogueLine>>{
  "intro": [
    DialogueLine("やめ太郎", "ワイは未完成の画面を、完成しました言うて納品したんや。そしたら出向の手続きだけ、一日で完成したわ。"),
    DialogueLine("福ちゃん", "僕がやらかす前から、ここにいたんですね。ずっと一人で案内を？"),
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
    DialogueLine("やめ太郎", "ジョッキを上げたら横へ避けるんや。Xで回避や。頭を狙ってひるませたら、近づいてFで蹴れるで。"),
    DialogueLine(
      "やめ太郎",
      "落としたビールは拾っとき。たこさんが農場で回収しとる。弾と交換して、そば屋さんに飲まれんよう封をするんや。",
    ),
    DialogueLine("やめ太郎", "銃の件はよーたんがええ言うたんやろ？ ほなええわ。ワイ、そういう確認は早いで。"),
  ],
  "records": [
    DialogueLine(
      "やめ太郎",
      "壁のポスター、懐かしいやろ。島流しにされた社員が持ち込んだんや。裏の書き込みや日記も、Eで拾えばその場で読める。あとから見るならCや。",
    ),
    DialogueLine("福ちゃん", "映画会の案内まである。待ってる間に、村で暮らす準備をしてたんですね。"),
    DialogueLine("やめ太郎", "ワイの指名手配書だけ、まだ現役みたいなんやけど。あれ剥がしといてくれへん？"),
  ],
  "engine": [
    DialogueLine("福ちゃん", "そば屋エンジンって、機械の名前かと思ってました。クローンにビールを飲ませて、腕力で回すんですね。"),
    DialogueLine("やめ太郎", "夢の新動力いうから見に行ったら、そば屋さんがぐるぐる歩いとった。そら力は強いやろけど。"),
    DialogueLine("福ちゃん", "ビールを飲んで歩くだけで仕事になるんですね。僕、志望動機が書けそうです。"),
    DialogueLine("やめ太郎", "帰す担当者がおらん仕事やぞ。応募するより、止めて帰るほうを考えてくれ。"),
  ],
  "evidence": [
    DialogueLine("やめ太郎", "撤収対象、端末、機材、契約書。人の名前、どこや。ワイらより箱のほうが大事なんか。"),
    DialogueLine("福ちゃん", "受入窓口だけ動いたままです。中止になった現場へ、別々の部署が着任者を送り続けてたんですね。"),
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
    DialogueLine("たこさん", "社員の画像を、フリー素材としてネットで配っていたのがバレました。商用利用も可にしていました。"),
    DialogueLine("福ちゃん", "僕の画像もありました？"),
    DialogueLine("たこさん", "はい。背景透過版が人気でした。"),
    DialogueLine("福ちゃん", "便利ですね。……いや、勝手に透過しないでください。"),
  ],
  "greeting": [DialogueLine("たこさん", "お帰りなさい。ビールはこちらへ。帰りの人数も、忘れずに数えましょう。")],
  "engine": [
    DialogueLine("たこさん", "名目は特別研修。実際は、失敗しても表に出せない案件を、窓際社員にやらせる場所でした。"),
    DialogueLine("福ちゃん", "僕も、実技の多い研修だと思ってました。支給品が銃でも、最近はそういう会社なのかなって。"),
    DialogueLine(
      "たこさん",
      "普通は筆記用具です。私が来た時には責任者も不在でした。お店には人が来るので、事情はお客さんから聞きました。",
    ),
  ],
  "evidence": [
    DialogueLine(
      "たこさん",
      "四体から十二体、最後は二十四体。納期を縮めるたび、そば屋を増やしています。世話係の名前は、ずっと一人です。",
    ),
    DialogueLine("福ちゃん", "日記にあった世話係ですね。一人で抱え込んだまま、置いていかれた。まだ、ここで待っているんでしょうか。"),
    DialogueLine(
      "たこさん",
      "宿舎に避難している社員がいます。巨大そば屋を倒したら、私が桟橋まで連れていきます。福ちゃんの席も残します。",
    ),
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

const unreadKeeperReply = DialogueLine(
  '福ちゃん',
  '二十四体の世話を、一人で？ その人も置いていかれたんですか。まだ、この村にいるんでしょうか。',
);

const rocketOffer = TradeOffer('rocket', 'rocket', 1, 10, 1);

const purchaseLines = <String, DialogueLine>{
  'rocket': DialogueLine(
    'たこさん',
    'お得意様だけに、ロケットランチュアです。弾は無限。そば屋を追いかけて吹き飛ばします。ビールも蒸発するので、返品はお断りです。',
  ),
  'ammo': DialogueLine('たこさん', 'ハンドガンの弾、十発です。これでそば屋を蜂の巣にしてください。領収書は研修費で切れます。'),
  'shells': DialogueLine('たこさん', 'ショットガンの弾、五発です。そば屋が近づいたら、景気よくどうぞ。壁の修理代は別です。'),
  'herb': DialogueLine(
    'たこさん',
    'グリーンハーブです。疲れも痛みも、すーっと消えますよ。何が入っているかは、聞かないほうが長生きできます。',
  ),
};

/// Successful herb purchases continue as a short two-person exchange.
const purchaseReplies = <String, List<DialogueLine>>{
  'herb': [
    DialogueLine('福ちゃん', 'それってギュンギュンってこと？'),
    DialogueLine('たこさん', 'ギュンギュンです。'),
  ],
};

const hardSuppliesLine = DialogueLine(
  'やめ太郎',
  '弾二十五発、持っていき。農場までこれでしのぐんや。ビールを拾っとけば、向こうでたこさんが弾と交換してくれる。打ち上げの店はワイが予約するわ。絶対やで。',
);

/// The mountain is a later encounter, never a replay of the village tutorial.
const mountainYametaroBefore = <String, List<DialogueLine>>{
  'intro': [
    DialogueLine(
      'やめ太郎',
      '裏道から先回りしたで。でっかいそば屋さんは、家の前や。ワイはここで帰り道を見とく。打ち上げの幹事が欠席するわけにいかんからな。',
    ),
  ],
  'greeting': [
    DialogueLine(
      'やめ太郎',
      'ワイはこの家で待っとる。そば屋さんを倒したら戻ってきてや。完了報告を本人から聞くまで、打ち上げは始めへんで。',
    ),
  ],
  'route': [
    DialogueLine(
      'やめ太郎',
      '家の前の巨大そば屋を倒すんや。玄関が開いたら中へ来て、ワイとたこさんの二人に声をかけてな。無事を確かめてから帰るで。',
    ),
  ],
  'combat': [
    DialogueLine(
      'やめ太郎',
      'あのジョッキが上がったら、横へ避けるんや。振り終わりに頭を狙う。乾杯の誘いに乗ったら、帰りは平らになるで。',
    ),
  ],
  'records': [
    DialogueLine(
      'やめ太郎',
      '家の壁にもポスターがあるで。回収するなら今のうちや。会社の備品か聞かれたら、ワイが「私物です」って先に言うとく。',
    ),
  ],
  'engine': [
    DialogueLine(
      'やめ太郎',
      'あのでかい一体が、最後まで機械を回しとる。止めたら誰も仕事せんで済む。ワイの理想の職場、一回撃たな実現せえへんのか。',
    ),
  ],
  'evidence': [
    DialogueLine('やめ太郎', '撤収リストに人の名前はないのに、ワイの手配書は残っとった。帰す気はないけど、捕まえる気はあるんやな。'),
  ],
};

const mountainYametaroAfter = <String, List<DialogueLine>>{
  'reunion': [
    DialogueLine('やめ太郎', '福ちゃん、生きとった！ ワイ、打ち上げの人数、減らさんと待ってたで。'),
    DialogueLine('福ちゃん', 'あんな大きな停止ボタン、初めて押しました。指じゃなくて経費で。'),
    DialogueLine('やめ太郎', 'そこ弾代って言うてくれ。会社ごと止めたみたいになるやろ。'),
    DialogueLine('やめ太郎', '出発前に、ワイとたこさん、二人の声を聞いてな。既読だけつけて帰るんはなしやで。'),
  ],
  'greeting': [DialogueLine('やめ太郎', '打ち上げ、三人席やで。ワイの名前で予約したら、店から会社に通報されへんかな。')],
  'route': [
    DialogueLine('やめ太郎', 'ワイとたこさん、二人の無事を確かめたら出発や。話を最後まで聞いてから、荷物まとめよか。'),
    DialogueLine('福ちゃん', 'これで、ようやく帰任申請ですね。'),
    DialogueLine('やめ太郎', '申請は船に乗ってからや。差し戻される前に圏外へ出るで。'),
  ],
  'engine': [
    DialogueLine('福ちゃん', '停止手順は一行なのに、やることは大きかったですね。'),
    DialogueLine('やめ太郎', '成功事例には「ボタンひとつで停止」って書かれるんやろな。サイズは載せへん。'),
  ],
  'evidence': [
    DialogueLine('やめ太郎', '記録は持って帰ろ。写真も日記も。ワイの指名手配書だけは、歴史資料として扱ってな。'),
    DialogueLine('福ちゃん', '賞金のところに、済って書いておきます？'),
    DialogueLine('やめ太郎', 'ワイが換金されたことになるやろ！'),
  ],
};

const mountainTakosanAfter = <String, List<DialogueLine>>{
  'reunion': [
    DialogueLine(
      'たこさん',
      'お疲れさまです。静かになったので、宿舎の人たちと裏道を通ってきました。皆さんはこの家の裏で待っています。',
    ),
    DialogueLine('福ちゃん', 'たこさんも来てたんですね。お店ごと？'),
    DialogueLine('たこさん', '避難先でも営業します。帰りの船は無料です。私も乗るので。'),
    DialogueLine('たこさん', '出発前に、私とやめ太郎の二人に声をかけてください。安否確認が済んだら、全員で船へ向かいます。'),
  ],
  'greeting': [DialogueLine('たこさん', '出張補給所です。残ったビール、持ち越しても有休にはなりませんよ。')],
  'route': [
    DialogueLine(
      'たこさん',
      '救助船には連絡済みです。私とやめ太郎、二人との話が済んだら出発します。帰任票は要りません。乗船名簿も作りました。',
    ),
    DialogueLine('福ちゃん', '僕の名前、ちゃんとあります？ 全社員の配属を変えた時、自分も名簿から消したかもしれなくて。'),
    DialogueLine('たこさん', 'ありますよ。窓際配属のままです。そこは責任を持って連れ帰ります。'),
  ],
  'engine': [
    DialogueLine('たこさん', '巨大そば屋が倒れて、エンジンと放送は止まりました。村に残ったクローンまで消えるわけではありません。'),
    DialogueLine('福ちゃん', '案件は終了、残作業は別料金というわけですね。'),
    DialogueLine('たこさん', '弾も別料金です。理解が早くて助かります。'),
  ],
  'evidence': [
    DialogueLine(
      'たこさん',
      '宿舎にいた人は全員、この家の裏にいます。世話係も無事です。私がネットで配った社員の画像と照合して、人数も確認しました。',
    ),
    DialogueLine('福ちゃん', '社員の画像、ネットで配ってたんですか。安否確認までできるフリー素材、便利ですね。'),
    DialogueLine('たこさん', '商用利用も可です。今回は本人にも確認しました。利用規約はあとで考えます。'),
  ],
};

const mountainRemainingLine = DialogueLine(
  'やめ太郎',
  'エンジンは止まったけど、まだそば屋さんが残っとる。この難度では全員倒すまで家の玄関は開かへん。弾が足りんかったら、農場のたこさんにビールを渡すんや。',
);
const mountainRemainingTakoLine = DialogueLine(
  'たこさん',
  '救助船には連絡しました。ただ、この難度では残ったそば屋を全員倒すまで家の玄関が開きません。私は農場で補給を続けます。ビールをお持ちください。追加のお仕事、お待ちしています。',
);
