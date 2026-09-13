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
    this.readMemo = '',
    this.unreadText = '',
    this.unreadCuts,
    this.voiceUseSuffix = '',
  });
  final List<EventCut> cuts;
  final double seconds;
  final double fov;
  final bool anchorToPlayer;
  final String speaker, text, actor, motion;
  final String readMemo, unreadText, voiceUseSuffix;
  final List<EventCut>? unreadCuts;
  EventShot resolve(Set<String> foundMemos) =>
      readMemo.isNotEmpty && !foundMemos.contains(readMemo)
      ? EventShot(
          seconds,
          speaker,
          unreadText,
          from,
          to,
          target,
          actor: actor,
          motion: motion,
          fov: fov,
          anchorToPlayer: anchorToPlayer,
          cuts: unreadCuts ?? cuts,
          voiceUseSuffix: ':unread',
        )
      : this;
  bool get isNarration => speaker.isEmpty && text.isNotEmpty;
  String get voiceSpeaker => isNarration ? 'ナレーション' : speaker;

  // Allow time to find the subtitle, read Japanese, then take in the image.
  // This also protects unvoiced lines when their WAV is missing or unavailable.
  double get readingSeconds =>
      math.max(6, text.replaceAll(RegExp(r'\s'), '').runes.length / 6 + 2);
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
  'title_call': [
    EventShot(2.5, 'そば屋', 'そば屋ハザード。', (0, 3, -24), (0, 3, -24), (0, 1, -15)),
  ],
  'opening': [
    EventShot(
      5,
      '',
      '島流し先は、ゆめみ村。船長が福ちゃんに銃を渡すと、船はすぐに岸を離れた。',
      (0, 7, -17),
      (0, 5, -14),
      (0, 1, 0),
      cuts: [
        EventCut(0, image: 'harbor', label: '序章 — 帰るための研修'),
        EventCut(.72),
      ],
    ),
    EventShot(
      5,
      '福ちゃん',
      '辞令には、事件を解決したら帰れるとあります。研修のわりに、支給品が物騒ですね。',
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
      cuts: [
        EventCut(0, document: 'decree', label: '帰任条件：現地案件の完了'),
        EventCut(.5),
      ],
    ),
    EventShot(
      6,
      'やめ太郎',
      '村におるそば屋さん、全部クローンや。ビールが切れて暴れとる。まず生きて帰る練習や。ワイとやってみよか。',
      (-.65, 1.3, -19.4),
      (-.85, 1.25, -19.55),
      (-2.8, .94, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .64,
    ),
  ],
  'chapter1intro': [
    EventShot(
      6,
      'やめ太郎',
      '北の納屋で鍵を取って、北東の門から農場へ行くんや。たこさんが補給所をやっとる。ワイは、あとから来る社員をここで待つわ。',
      (-.65, 1.3, -19.4),
      (-.85, 1.25, -19.55),
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
        EventCut(.48),
      ],
    ),
    EventShot(
      4,
      '福ちゃん',
      '撃つ時も、隠れる時も、自分で決めるんですね。研修なのに、急に裁量が大きいですね。',
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
    ),
  ],
  'farm': [
    EventShot(
      5,
      '',
      'CHAPTER 02 — 撤収対象外\n補給所には、たこさんと、帰りを待つ社員たちが残されていた。',
      (-18, 3.4, -23),
      (-16.5, 2.7, -22),
      (-13, 1.05, -17.8),
      fov: .84,
      cuts: [EventCut(.4, image: 'shelter', label: '宿舎の避難者　応答あり')],
    ),
    EventShot(
      7,
      'たこさん',
      'いらっしゃいませ。一週間前に送られてきました。迎えの船は来ませんが、お客さんは来るので、店にしました。',
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      5,
      '福ちゃん',
      '船を呼ぶには、何が要ります？ 僕の帰任票、担当者ごと行方不明です。',
      (-11.8, 1.6, -18.8),
      (-12, 1.55, -18.9),
      (-13, 1.32, -20.8),
      actor: 'fukuchan',
      motion: 'Talk',
    ),
    EventShot(
      7,
      'たこさん',
      'この写真を見てください。そば屋のクローンにビールを飲ませて、怪力で軸を回す。そば屋エンジンの開発施設だったんです。',
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
      cuts: [EventCut(0, image: 'engine-archive', label: '開発記録　そば屋エンジン試運転')],
    ),
    EventShot(
      6,
      'たこさん',
      '台数だけ増やして、世話係は一人。案件が炎上すると、責任者は帰り、補給も止まりました。残されたクローンが、ビールを探して村へ出たんです。',
      (-13.5, 1.2, -19.7),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
      cuts: [
        EventCut(0, document: 'ledger', label: '増えたのは台数だけ'),
        EventCut(.4, document: 'withdrawal', label: '人は、撤収対象外'),
      ],
    ),
    EventShot(
      7,
      'たこさん',
      '帰任票より救難無線です。工具小屋の予備バッテリーと、納屋二階の避難者名簿を持ってきてください。誰も置いていかずに帰る準備です。',
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      5,
      '福ちゃん',
      '研修の成果物、全員の帰宅ですね。今度は、名簿を壊さず持ってきます。',
      (-11.8, 1.6, -18.8),
      (-12, 1.55, -18.9),
      (-13, 1.32, -20.8),
      actor: 'fukuchan',
      motion: 'Talk',
    ),
  ],
  'last_order': [
    EventShot(
      4,
      "",
      "CHAPTER 03 — 巨大そば屋\n山道の先、廃屋の前に巨大なそば屋がいる。あいつを倒せば、そば屋エンジンは止まる。",
      (5.0, 2.5, -.5),
      (5.7, 2.6, 0),
      (12, 3.5, 4),
      actor: 'sobaya',
      motion: 'MugAttack',
      fov: .66,
      cuts: [
        EventCut(
          0,
          framing: EventShot(1, '', '', (-20, 10, 1), (-17, 9, 3), (
            11,
            1.5,
            4,
          ), fov: .9),
        ),
        EventCut(.45),
      ],
    ),
    EventShot(
      5,
      "そば屋",
      "ビールが飲めて、仕事も終わらない。メリットです！ 乾杯！",
      (5.7, 2.6, 0),
      (6.3, 2.7, .5),
      (12, 3.5, 4),
      actor: 'sobaya',
      motion: 'MugAttack',
      fov: .66,
    ),
    EventShot(
      5,
      "福ちゃん",
      "あれが巨大そば屋さん……。停止ボタンのくせに、ずいぶん元気ですね。こっちが先に停止しそうです。",
      (2.0, 1.6, 2.4),
      (1.85, 1.55, 2.2),
      (0, 1.3, 0),
      actor: 'fukuchan',
      fov: .58,
      anchorToPlayer: true,
      cuts: [
        EventCut(0),
        EventCut(
          .62,
          framing: EventShot(1, '', '', (5.0, 2.5, -.5), (5.7, 2.6, 0), (
            12,
            3.5,
            4,
          ), fov: .66),
        ),
      ],
    ),
    EventShot(
      5,
      "福ちゃん",
      "よーたん、辞令どおり撃ちますからね。巨大そば屋さん、今日は定時で止まっていただきます。",
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
      "家の中で互いの無事を確かめた三人は、外へ出て最後の荷物をまとめた。桟橋には救助船が着いている。\n「帰任票は要りません。そこにいる人、全員乗せます」。避難者は、先に乗船した。",
      (13.6, 2.1, .2),
      (13.6, 1.85, .7),
      (13.6, .95, 6.5),
      cuts: [
        EventCut(0, document: 'rescue-radio', label: '救難回線　応答あり'),
        EventCut(.55, image: 'harbor', label: '救助船　接岸へ'),
      ],
    ),
    EventShot(
      6,
      "やめ太郎",
      "約束どおり、三人分の席や。全員生還で完了報告。こんな分かりやすい検収、初めてやで。",
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
      "打ち上げの出欠確認、全社員に送っておきますね。今度は間違えないように、全員返信で。",
      (13.3, 1.6, 4.1),
      (13.15, 1.55, 4.25),
      (11.5, 1.32, 6),
      actor: 'fukuchan',
      fov: .60,
    ),
    EventShot(
      6,
      "やめ太郎",
      "その機能、いったん止めよか。ワイ、店の予約より先に出向先の予約したないねん。",
      (12.3, 1.15, 4.8),
      (12.45, 1.1, 4.95),
      (14, .73, 7),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .66,
      cuts: [
        EventCut(0),
        EventCut(.32, document: 'decree', label: '前回の全社通知の結果'),
      ],
    ),
    EventShot(
      5,
      "たこさん",
      "台帳は私が持ちました。避難者は先に乗船済みです。あの世話係、船でおにぎりを二つ食べていました。おかわりは無料だそうです。",
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
      "あの日記の続き、おにぎりの感想だといいですね。業務日報だったら、僕が差し戻します。",
      (13.3, 1.6, 4.1),
      (13.15, 1.55, 4.25),
      (11.5, 1.32, 6),
      actor: 'fukuchan',
      fov: .60,
      readMemo: 'diary_end',
      unreadText: '二つも食べたなら、研修で一番いい成果ですね。報告書、そこだけ大きく書きましょう。',
      unreadCuts: [
        EventCut(0, document: 'rescue'),
        EventCut(.6),
      ],
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
  HazardDirector(
    this.id, {
    this.voiceSeconds = const {},
    Set<String> foundMemos = const {},
  }) : shots = (hazardEvents[id] ?? (throw ArgumentError.value(id)))
           .map((shot) => shot.resolve(foundMemos))
           .toList();
  final String id;
  final Map<String, double> voiceSeconds;
  double get duration {
    final voice = voiceSeconds['event:$id:$index${shot.voiceUseSuffix}'] ?? 0;
    final minimum = shot.isNarration || voice <= 0
        ? math.max(shot.seconds, shot.readingSeconds)
        : shot.seconds;
    return math.max(minimum, voice + (shot.isNarration ? 1.5 : .5));
  }

  final List<EventShot> shots;
  int index = 0;
  double elapsed = 0;
  bool paused = false, done = false;
  EventShot get shot => shots[math.min(index, shots.length - 1)];
  // Compare clock times directly: dividing a fractional duration can round an
  // exact cut boundary just below its authored normalized position.
  EventCut? get cut =>
      shot.cuts.where((c) => c.at * duration <= elapsed).lastOrNull;
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
