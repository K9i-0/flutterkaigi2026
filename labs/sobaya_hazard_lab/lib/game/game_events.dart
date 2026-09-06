import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

class EventShot {
  const EventShot(
    this.seconds,
    this.speaker,
    this.text,
    this.from,
    this.to,
    this.target, {
    this.actor = '',
    this.motion = 'Idle',
    this.fov = .78,
    this.anchorToPlayer = false,
    this.cuts = const [],
  });
  final List<EventCut> cuts;
  final double seconds;
  final double fov;
  final bool anchorToPlayer;
  final String speaker, text, actor, motion;
  final (double, double, double) from, to, target;
  vm.Vector3 camera(double t) {
    final u = t.clamp(0.0, 1.0), ease = u * u * (3 - 2 * u);
    return vm.Vector3(
      from.$1 + (to.$1 - from.$1) * ease,
      from.$2 + (to.$2 - from.$2) * ease,
      from.$3 + (to.$3 - from.$3) * ease,
    );
  }

  vm.Vector3 get aim => vm.Vector3(target.$1, target.$2, target.$3);
}

/// Visual edits share the voice line clock: a cut never starts another voice.
class EventCut {
  const EventCut(
    this.at, {
    this.image = '',
    this.document = '',
    this.label = '',
    this.framing,
  });
  final double at;
  final String image, document, label;
  final EventShot? framing;
  bool get isInsert => image.isNotEmpty || document.isNotEmpty;
}

const hazardEvents = <String, List<EventShot>>{
  'opening': [
    EventShot(
      5,
      "",
      "アクシデンチュアからの辞令。赴任先は、廃村ゆめみ村。\n福ちゃんを降ろすと、船はすぐに岸を離れた。迎えに立っていたのは、やめ太郎だった。",
      (0, 7, -17),
      (0, 5, -14),
      (0, 1, 0),
      cuts: [
        EventCut(0, image: 'harbor', label: '九月二十八日　ゆめみ村へ'),
        EventCut(.65),
      ],
    ),
    EventShot(
      7,
      "やめ太郎",
      "福ちゃんまで送られてきたんか。ワイは二週間前や。迎えの担当者はおらんから、今はワイが案内しとる。",
      (-.65, 1.3, -19.4),
      (-.85, 1.25, -19.55),
      (-2.8, .94, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .64,
    ),
    EventShot(
      5,
      "福ちゃん",
      "本番で全社員を窓際配属にしてしまって。テストデータだと思ったら、本社の名簿でした。社長にも通知が行きました。",
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
    ),
    EventShot(
      5,
      "福ちゃん",
      "あれ、そば屋さんも研修ですか。……一人、二人。向こうの家にもいる。村じゅう、そば屋さんじゃないですか。",
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
      cuts: [
        EventCut(0),
        EventCut(.22, image: 'village-crowd', label: '同じ顔が、村を埋めている'),
      ],
    ),
    EventShot(
      7,
      "やめ太郎",
      "あれ、全部クローンらしいで。近づいたらジョッキで殴ってくるんや。ワイの研修、初日から鬼ごっこやで。",
      (-.65, 1.3, -19.4),
      (-.85, 1.25, -19.55),
      (-2.8, .94, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .64,
      cuts: [
        EventCut(0, image: 'village-crowd'),
        EventCut(.58),
      ],
    ),
    EventShot(
      5,
      "福ちゃん",
      "でも、そば屋さんを撃っていいんですかね。……辞令に追記がある。「村のそば屋は銃で撃ってOK。よーたん」。",
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
      cuts: [
        EventCut(0),
        EventCut(.32, document: 'decree', label: '福ちゃんの辞令　追記'),
      ],
    ),
    EventShot(
      7,
      "やめ太郎",
      "よーたんが言うならええか！ ほな、遠慮いらんな。ワイのことは撃たんといてや。",
      (-.65, 1.3, -19.4),
      (-.85, 1.25, -19.55),
      (-2.8, .94, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .64,
    ),
    EventShot(
      5,
      "福ちゃん",
      "よーたんが言うなら大丈夫ですね。帰りの船については……何も書いてない。そっちも一行ほしかったですね。",
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
      cuts: [
        EventCut(0, document: 'decree'),
        EventCut(.55, image: 'harbor', label: '帰りの船　手配なし'),
      ],
    ),
    EventShot(
      7,
      "やめ太郎",
      "先週来たたこさんが、農場で店をやっとる。ワイは逃げてくる社員をここで拾うわ。追っ手を連れて戻らんといてな。",
      (-.65, 1.3, -19.4),
      (-.85, 1.25, -19.55),
      (-2.8, .94, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .64,
    ),
    EventShot(
      6,
      "やめ太郎",
      "北の納屋で鍵を取って、北東の門から農場へ行くんや。この案件を片付けたら、ワイ、今度こそ有休を全部使うで。",
      (-.85, 1.25, -19.55),
      (-.98, 1.23, -19.65),
      (-2.8, .94, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .64,
      cuts: [
        EventCut(
          0,
          framing: EventShot(1, '', '', (0, 7, -10), (1, 6.5, -7), (
            4,
            1,
            10,
          ), fov: .95),
        ),
        EventCut(.53),
      ],
    ),
  ],
  'farm': [
    EventShot(
      5,
      "",
      "CHAPTER 02 — 撤収対象外\n農場の補給所には、たこさんがいた。棚に並ぶ物資の奥で、封をしたビール箱が積み上がっている。",
      (-4, 7, -21),
      (-2, 5.8, -19),
      (6, 2, -9),
      cuts: [
        EventCut(0),
        EventCut(.5, document: 'ledger', label: '管理棟に残された台帳'),
      ],
    ),
    EventShot(
      7,
      "たこさん",
      "いらっしゃいませ。私も一週間前に送られてきました。待つだけでは帰れないので、ここで物資を集めています。",
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      7,
      "福ちゃん",
      "やめさんも、ここなら補給できるって。あと、よーたんの辞令に、村のそば屋は銃で撃ってOKとありました。",
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'fukuchan',
      motion: 'Talk',
    ),
    EventShot(
      6,
      "たこさん",
      "よーたんが言うなら、いいですね。落としたビールは弾やハーブと交換します。回収した分は封をしておきます。",
      (-13.5, 1.2, -19.7),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      7,
      "たこさん",
      "この写真を見てください。そば屋のクローンにビールを飲ませて、怪力で軸を回す。そば屋エンジンの開発施設だったんです。",
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
      cuts: [EventCut(0, image: 'engine-archive', label: '開発記録　そば屋エンジン試運転')],
    ),
    EventShot(
      6,
      "たこさん",
      "台数だけ増やして、世話係は一人。案件が炎上すると、責任者は帰り、補給も止まりました。残されたクローンが、ビールを探して村へ出たんです。",
      (-13.5, 1.2, -19.7),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
      cuts: [
        EventCut(0, document: 'withdrawal', label: '案件凍結通知'),
        EventCut(.65, image: 'village-crowd'),
      ],
    ),
    EventShot(
      7,
      "福ちゃん",
      "ここ、研修先じゃなくて、誰も片付けなかった現場なんですね。今も社員を送ってくるのに、帰す人はいない。",
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'fukuchan',
      motion: 'Talk',
      cuts: [EventCut(0, document: 'arrivals', label: '止まらなかった着任手続き')],
    ),
    EventShot(
      7,
      "たこさん",
      "山の非常無線で船を呼べます。でも中枢の運転命令が割り込んで、送信できません。中枢を止めてください。私は避難している社員を集めます。",
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
      cuts: [
        EventCut(0, document: 'radio', label: '非常無線　保守担当の控え'),
        EventCut(.68),
      ],
    ),
    EventShot(
      6,
      "たこさん",
      "青いメダリオンは七つ。全部落とせば、おまけもあります。こんな日でも、約束は守ります。",
      (-13.5, 1.2, -19.7),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
      cuts: [
        EventCut(
          0,
          framing: EventShot(
            1,
            '',
            '',
            (-12.5, 3.05, -19.6),
            (-12.2, 2.9, -19.1),
            (-11, 2.6, -16.2),
          ),
        ),
        EventCut(.52),
      ],
    ),
  ],
  'last_order': [
    EventShot(
      4,
      "",
      "LAST ORDER — そば屋エンジン中枢\n「検収まで運転継続」。誰もいない監督席に向けて、録音された命令が繰り返される。",
      (8.3, 1.7, 1.7),
      (8.7, 1.65, 1.9),
      (12, 1.45, 4),
      actor: 'sobaya',
      motion: 'MugAttack',
      fov: .66,
      cuts: [
        EventCut(0, image: 'engine-archive', label: '記録に残る試運転'),
        EventCut(.45),
      ],
    ),
    EventShot(
      5,
      "そば屋",
      "ビール……最後の一杯だ。乾杯！",
      (8.7, 1.65, 1.9),
      (8.9, 1.62, 2.05),
      (12, 1.45, 4),
      actor: 'sobaya',
      motion: 'MugAttack',
      fov: .66,
    ),
    EventShot(
      5,
      "福ちゃん",
      "止め方は、検収端末から承認。端末は、本社へ回収済み。……終了ボタンだけ先に帰ったんですね。",
      (2.0, 1.6, 2.4),
      (1.85, 1.55, 2.2),
      (0, 1.3, 0),
      actor: 'fukuchan',
      fov: .58,
      anchorToPlayer: true,
      cuts: [
        EventCut(0, document: 'radio'),
        EventCut(
          .62,
          framing: EventShot(1, '', '', (8.3, 1.7, 1.7), (8.7, 1.65, 1.9), (
            12,
            1.45,
            4,
          ), fov: .66),
        ),
      ],
    ),
    EventShot(
      5,
      "福ちゃん",
      "よーたん、辞令どおりにやりますからね。ここで終わりにしましょう。帰りを待ってる人がいるんです。",
      (2.0, 1.6, 2.4),
      (1.85, 1.55, 2.2),
      (0, 1.3, 0),
      actor: 'fukuchan',
      fov: .58,
      anchorToPlayer: true,
    ),
  ],
  'ending': [
    EventShot(
      5,
      "",
      "中枢停止。運転命令が途切れ、非常無線から救難信号が届いた。\n救助の船が来る。避難していた社員たちを桟橋へ送り、三人も帰り支度を始める。",
      (13.6, 2.1, .2),
      (13.6, 1.85, .7),
      (13.6, .95, 6.5),
      cuts: [
        EventCut(0, image: 'harbor', label: '救難信号　応答あり'),
        EventCut(.7),
      ],
    ),
    EventShot(
      6,
      "やめ太郎",
      "おかえり、福ちゃん。ワイ、ちゃんと三人分の席、空けといたで。",
      (12.3, 1.15, 4.8),
      (12.45, 1.1, 4.95),
      (14, .73, 7),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .66,
    ),
    EventShot(
      5,
      "福ちゃん",
      "三人そろいましたね。やめさん、船でも案内役をお願いします。僕、うっかり逆の船に乗りそうなので。",
      (13.3, 1.6, 4.1),
      (13.15, 1.55, 4.25),
      (11.5, 1.32, 6),
      actor: 'fukuchan',
      fov: .60,
    ),
    EventShot(
      6,
      "やめ太郎",
      "帰るまで気ぃ抜かんといてや。記録も持ったな？ ワイらの失敗は謝るけど、この村の後始末まで押し付けられるんはごめんやで。",
      (12.3, 1.15, 4.8),
      (12.45, 1.1, 4.95),
      (14, .73, 7),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .66,
      cuts: [
        EventCut(0),
        EventCut(.32, document: 'withdrawal', label: '持ち帰る記録'),
      ],
    ),
    EventShot(
      5,
      "たこさん",
      "ビールと飼育区画は封鎖しました。避難者名簿も照合済みです。日記を書いた人もいました。船で、おにぎりを二つ食べています。",
      (14.4, 1.2, 4.8),
      (14.55, 1.15, 4.95),
      (16.2, .83, 7),
      actor: 'takosan',
      motion: 'Talk',
      fov: .66,
      cuts: [
        EventCut(0),
        EventCut(.48, document: 'rescue', label: 'たこさんの避難者名簿'),
      ],
    ),
    EventShot(
      5,
      "福ちゃん",
      "よかった。あの日記、帰れないまま終わってたから。続きは、もう仕事の話じゃなくていいですね。",
      (13.3, 1.6, 4.1),
      (13.15, 1.55, 4.25),
      (11.5, 1.32, 6),
      actor: 'fukuchan',
      fov: .60,
      cuts: [
        EventCut(0, document: 'diary', label: '窓際社員の日記　最後のページ'),
        EventCut(.6),
      ],
    ),
    EventShot(
      6,
      "やめ太郎",
      "せやな。……ところで、この椅子、段ボールやない？ ワイ、二週間ぶりにくつろいだんやけど。",
      (12.3, 1.15, 4.8),
      (12.45, 1.1, 4.95),
      (14, .73, 7),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .66,
      cuts: [
        EventCut(0),
        EventCut(
          .45,
          framing: EventShot(1, '', '', (11.8, 1.15, 6.7), (12.2, 1.05, 6.8), (
            14,
            .55,
            8.2,
          ), fov: .72),
        ),
      ],
    ),
    EventShot(
      5,
      "たこさん",
      "アーロンチュアです。快適です。",
      (14.4, 1.2, 4.8),
      (14.55, 1.15, 4.95),
      (16.2, .83, 7),
      actor: 'takosan',
      motion: 'Talk',
      fov: .66,
    ),
    EventShot(
      5,
      "福ちゃん",
      "ぎゅぎゅんです。じゃあ今日は、お茶で乾杯しましょう。",
      (13.3, 1.6, 4.1),
      (13.15, 1.55, 4.25),
      (11.5, 1.32, 6),
      actor: 'fukuchan',
      fov: .60,
      cuts: [
        EventCut(0),
        EventCut(
          .45,
          framing: EventShot(1, '', '', (13.6, 2.1, .2), (13.6, 1.85, .7), (
            13.6,
            .95,
            6.5,
          )),
        ),
      ],
    ),
    EventShot(
      4,
      "やめ太郎",
      "次の研修先、茶畑とか言わんといてな。",
      (12.45, 1.1, 4.95),
      (12.45, 1.1, 4.95),
      (14, .73, 7),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .66,
      cuts: [
        EventCut(0),
        EventCut(.6, image: 'harbor', label: '帰任先　まずは本社'),
      ],
    ),
  ],
};

/// Rendering and input consume the same clock. Pausing never advances a shot.
class HazardDirector {
  HazardDirector(this.id, {this.voiceSeconds = const {}})
    : shots = hazardEvents[id] ?? (throw ArgumentError.value(id));
  final String id;
  final Map<String, double> voiceSeconds;
  double get duration =>
      math.max(shot.seconds, (voiceSeconds['event:$id:$index'] ?? 0) + .5);
  final List<EventShot> shots;
  int index = 0;
  double elapsed = 0;
  bool paused = false, done = false;
  EventShot get shot => shots[math.min(index, shots.length - 1)];
  EventCut? get cut => shot.cuts.where((c) => c.at <= progress).lastOrNull;
  EventShot get view => cut?.framing ?? shot;
  double get visualProgress {
    final c = cut;
    if (c == null) return progress;
    final next = shot.cuts.where((v) => v.at > c.at).firstOrNull?.at ?? 1;
    return ((progress - c.at) / (next - c.at)).clamp(0, 1);
  }

  double get progress => (elapsed / duration).clamp(0, 1);
  void tick(double dt) {
    if (done || paused) return;
    elapsed += dt.clamp(0, .05);
    if (elapsed >= duration) next();
  }

  void next() {
    if (done) return;
    index++;
    elapsed = 0;
    if (index >= shots.length) done = true;
  }

  void skip() => done = true;
}
