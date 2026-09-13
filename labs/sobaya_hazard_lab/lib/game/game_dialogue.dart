class DialogueLine {
  const DialogueLine(this.speaker, this.text);
  final String speaker, text;
}

const yametaroDialogue = <String, List<DialogueLine>>{
  "intro": [
    DialogueLine("やめ太郎", "ワイは未完成の画面を、完成しました言うて納品したんや。そしたら出向の手続きだけ、一日で完成したわ。"),
    DialogueLine("福ちゃん", "僕は本番で全社員を窓際配属にしてしまって。社長にも通知が行きました。"),
    DialogueLine("やめ太郎", "そら船も出るわ。帰りの船は、まだ来んけどな。"),
  ],
  "greeting": [DialogueLine("やめ太郎", "次の船をここで待っとくわ。そば屋さんを連れて戻ってくるのだけは勘弁な。")],
  "route": [
    DialogueLine("やめ太郎", "北の漁具倉庫で鍵を拾って、北東の門から商店街へ。右手の二階建てにはショットガンもあるで。"),
    DialogueLine("福ちゃん", "たこさんの店で準備して、神社のことも聞いてみます。"),
  ],
  "combat": [
    DialogueLine("やめ太郎", "ジョッキを上げたら横へ避けるんや。囲まれたら、先に逃げ道を探すんや。"),
    DialogueLine("やめ太郎", "落としたビールは拾っとき。商店街のたこさんが弾と交換してくれる。"),
    DialogueLine("やめ太郎", "よーたんが撃ってええ言うたんやろ？ ほなええわ。"),
  ],
  "records": [
    DialogueLine("やめ太郎", "会社が来た頃は、店も社宅も人でいっぱいやったらしいで。貼り紙ばっかり残っとる。"),
    DialogueLine("福ちゃん", "退去の通知より、新しい着任の案内が目立ちますね。"),
  ],
  "engine": [DialogueLine("やめ太郎", "原因はまだ分からん。神社に行ったら何か分かるやろ。")],
  "evidence": [
    DialogueLine("やめ太郎", "そば屋が呪いの祠でも壊したんやろ。ビール置くのに邪魔や言うて。"),
    DialogueLine("福ちゃん", "それ、考察というより悪口では？"),
    DialogueLine("やめ太郎", "経験則や。"),
  ],
  "supplies": [DialogueLine("やめ太郎", "弾十発、持っていき。商店街までこれでしのぐんや。")],
  "full": [DialogueLine("やめ太郎", "ケースがいっぱいや。荷物を整理して戻ってき。")],
};

const takosanDialogue = <String, List<DialogueLine>>{
  "intro": [
    DialogueLine("たこさん", "空き店舗を借りて、店らしくしてみました。ビールと弾やハーブを交換します。"),
    DialogueLine("福ちゃん", "どうして、たこさんまで島流しに？"),
    DialogueLine("たこさん", "社員の画像をフリー素材として配っていたのがバレました。背景透過版が人気でした。"),
    DialogueLine("福ちゃん", "勝手に透過しないでください。"),
  ],
  "greeting": [DialogueLine("たこさん", "お帰りなさい。神社へ向かう前に、補給していってください。")],
  "engine": [DialogueLine("たこさん", "山の音の正体は、まだ分かりません。私は店を開けておきます。")],
  "evidence": [
    DialogueLine("たこさん", "会社が事業を引き揚げて、お店も人も減ったそうです。私たちの出向だけは続いていますけど。"),
    DialogueLine("福ちゃん", "住む人を増やす方法が、独特ですね。"),
  ],
};

/// Chapter two has an actionable rescue-preparation objective. The state owns
/// item flags and only commits radio_ready after the ready dialogue is closed.
const farmMissionDialogue = <String, List<DialogueLine>>{
  "request": [
    DialogueLine("たこさん", "旧管理室に参道の門の鍵、集会所の二階に村の案内図があるそうです。見つけたら、ここへ戻ってきてください。"),
    DialogueLine("たこさん", "ビールは弾やハーブと交換できます。青いメダリオンは七つでビール三杯。腕試しはご自由にどうぞ。"),
  ],
  "ready": [
    DialogueLine(
      "たこさん",
      "これが参道の鍵ですね。案内図では、東の門の先に神社があります。山から大きな音がするのは、そのあたりです。",
    ),
    DialogueLine("福ちゃん", "祠が無事か、確かめてきます。"),
    DialogueLine("たこさん", "壊れていても修理は受注しないでくださいね。帰りが遅くなります。"),
  ],
  "complete": [
    DialogueLine("たこさん", "東の門から山の神社へ行けます。私はここで営業しています。足りなくなったら戻ってきてください。"),
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

const unreadKeeperReply = DialogueLine('福ちゃん', '会社が撤退しても、着任者は送られてくるんですね。');

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
  '弾二十五発、持っていき。商店街までこれでしのぐんや。ビールを拾っとけば、向こうでたこさんが弾と交換してくれる。打ち上げの店はワイが予約するわ。絶対やで。',
);

/// The mountain is a later encounter, never a replay of the village tutorial.
const mountainYametaroBefore = <String, List<DialogueLine>>{
  "intro": [DialogueLine("やめ太郎", "神社の方で、えらい音がするな。祠の様子を見てきてくれへんか。")],
  "greeting": [DialogueLine("やめ太郎", "ビールの奉納だけで済む祟りやったらええんやけどな。")],
  "route": [DialogueLine("やめ太郎", "境内の巨大そば屋を倒して、祠を調べるんや。")],
  "combat": [DialogueLine("やめ太郎", "ジョッキが上がったら横へ避ける。振り終わりに頭を狙うんや。")],
  "records": [DialogueLine("やめ太郎", "古い神社やな。会社が来る前から、ここにあったんやろ。")],
  "engine": [DialogueLine("やめ太郎", "あの音が何か、まだ分からん。")],
  "evidence": [DialogueLine("やめ太郎", "呪いの祠いうのはワイの予想やで。調査報告書にはまだ書かんといてな。")],
};

const mountainYametaroAfter = <String, List<DialogueLine>>{
  "reunion": [
    DialogueLine("やめ太郎", "福ちゃん、無事やったか。祠、別に壊れてへんな。"),
    DialogueLine("福ちゃん", "巨大そば屋さん、会社の名前を言っていました。"),
    DialogueLine("やめ太郎", "祟りやなくて、うちの案件かいな。"),
  ],
  "greeting": [DialogueLine("やめ太郎", "裏手に道が続いとるな。あの機械の音、どこからやろ。")],
  "route": [DialogueLine("やめ太郎", "神社の東側、管理道の先を調べてみよか。")],
  "engine": [DialogueLine("やめ太郎", "会社の施設らしいけど、中で何しとるんやろな。")],
  "evidence": [DialogueLine("やめ太郎", "祠は普通やった。ワイの考察、差し戻しやな。")],
};

const mountainTakosanAfter = <String, List<DialogueLine>>{
  "reunion": [DialogueLine("たこさん", "ここにも機械の音が届いていますね。店の冷蔵庫より大きいです。")],
  "greeting": [DialogueLine("たこさん", "村の調査は、まだ終わりそうにありませんね。")],
  "route": [DialogueLine("たこさん", "神社の東の管理道に、何かあるようです。")],
  "engine": [DialogueLine("たこさん", "何の施設か、看板を確かめてみましょう。")],
  "evidence": [DialogueLine("たこさん", "神社におかしなところは見つかりませんでした。")],
};

const mountainRemainingLine = DialogueLine('やめ太郎', '巨大そば屋は倒した。神社の東の管理道を調べようや。');
const mountainRemainingTakoLine = DialogueLine(
  'たこさん',
  '店は開いています。調査の準備をしていってください。',
);
