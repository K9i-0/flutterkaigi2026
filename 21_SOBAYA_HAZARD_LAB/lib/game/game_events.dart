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
    EventShot(
      6,
      "そば屋",
      "そば屋ハザード。",
      (0, 3, -24),
      (0, 3, -24),
      (0, 1, -15),
      actor: "",
      anchorToPlayer: false,
    ),
  ],
  'opening': [
    EventShot(
      6,
      "",
      "ゆめみ港。特別研修、帰任日未定。福ちゃんを降ろした船は、銃と辞令を残して岸を離れた。",
      (0, 5, -38),
      (0, 5, -38),
      (0, 1, -14),
      actor: "",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "着任受付へ行けばいいんですね。研修の支給品が銃なのは、少し気になります。",
      (-1.85, 1.58, -19.05),
      (-1.85, 1.58, -19.05),
      (0, 1.34, -21),
      actor: "fukuchan",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "やめ太郎",
      "村にそば屋さんがぎょうさんおってな。ビール言うて追いかけてくるんや。まず身を守る練習しよか。",
      (-.65, 1.3, -19.4),
      (-.65, 1.3, -19.4),
      (-2.8, .94, -21.2),
      actor: "yametaro",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "やめ太郎",
      "どうせそば屋が、ビール置くのに邪魔や言うて呪いの祠でも壊したんやろ。",
      (-.65, 1.3, -19.4),
      (-.65, 1.3, -19.4),
      (-2.8, .94, -21.2),
      actor: "yametaro",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "そんな理由で壊します？",
      (-1.85, 1.58, -19.05),
      (-1.85, 1.58, -19.05),
      (0, 1.34, -21),
      actor: "fukuchan",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "やめ太郎",
      "そば屋やで？",
      (-.65, 1.3, -19.4),
      (-.65, 1.3, -19.4),
      (-2.8, .94, -21.2),
      actor: "yametaro",
      anchorToPlayer: false,
    ),
  ],
  'chapter1intro': [
    EventShot(
      6,
      "やめ太郎",
      "北の漁具倉庫で鍵を取って、北東の門から商店街へ。たこさんが店をやっとる。ワイは次の船をここで待つわ。",
      (-.65, 1.3, -19.4),
      (-.65, 1.3, -19.4),
      (-2.8, .94, -21.2),
      actor: "yametaro",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "村の様子を見てきます。受付に誰かいるといいんですが。",
      (-1.85, 1.58, -19.05),
      (-1.85, 1.58, -19.05),
      (0, 1.34, -21),
      actor: "fukuchan",
      anchorToPlayer: false,
    ),
  ],
  'farm': [
    EventShot(
      6,
      "",
      "CHAPTER 02 — 村の生活圏\n閉じた商店街で、一軒だけ暖簾が出ている。",
      (-18, 3.4, -23),
      (-18, 3.4, -23),
      (-13, .9, -17.8),
      actor: "",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "たこさん",
      "いらっしゃいませ。一週間前に送られてきました。迎えの船は来ませんが、お客さんは来るので、店にしました。",
      (-13.8, 1.3, -20),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: "takosan",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "空き店舗で営業してるんですね。村のそば屋さんたち、どうしたんですか？",
      (-11.8, 1.6, -18.8),
      (-11.8, 1.6, -18.8),
      (-13, 1.32, -20.8),
      actor: "fukuchan",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "たこさん",
      "私も分かりません。ビールばかり欲しがって、代金を払ってくれないんです。山の神社からも、大きな音がします。",
      (-13.8, 1.3, -20),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: "takosan",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "たこさん",
      "ここではビールを弾やハーブと交換できます。参道の鍵と村の案内図を探して、山へ行く前に準備しましょう。",
      (-13.8, 1.3, -20),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: "takosan",
      anchorToPlayer: false,
    ),
  ],
  'last_order': [
    EventShot(
      6,
      "",
      "CHAPTER 03 — 山の神社\n境内で、巨大なそば屋が暴れている。",
      (-3, 5, -4),
      (-3, 5, -4),
      (9, 2.5, 8),
      actor: "sobaya",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "そば屋",
      "ビール……よこせ……",
      (5.7, 2.6, 0),
      (5.7, 2.6, 0),
      (12, 3.5, 4),
      actor: "sobaya",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "あれが音の正体ですか。祠より、そば屋さんの方が大きいですね。",
      (2, 1.6, 2.4),
      (2, 1.6, 2.4),
      (0, 1.3, 0),
      actor: "fukuchan",
      anchorToPlayer: true,
    ),
  ],
  'boss_confession': [
    EventShot(
      6,
      "そば屋",
      "カイシャ……ビール……くれない……",
      (5.7, 2.6, 0),
      (5.7, 2.6, 0),
      (12, 3.5, 4),
      actor: "sobaya",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "そば屋",
      "アクシデンチュア……ビール……よこせ……",
      (5.7, 2.6, 0),
      (5.7, 2.6, 0),
      (12, 3.5, 4),
      actor: "sobaya",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "今、うちの会社の名前を……？",
      (2, 1.6, 2.4),
      (2, 1.6, 2.4),
      (0, 1.3, 0),
      actor: "fukuchan",
      anchorToPlayer: true,
    ),
  ],
  'boss_defeated': [
    EventShot(
      6,
      "福ちゃん",
      "祠は壊れていませんね。……裏手から、まだ機械の音がします。",
      (2, 1.6, 2.4),
      (2, 1.6, 2.4),
      (0, 1.3, 0),
      actor: "fukuchan",
      anchorToPlayer: true,
    ),
  ],
  'ending': [
    EventShot(
      6,
      "",
      "神社の裏手。木々と擁壁の陰に、通電した施設の搬入口があった。",
      (21.5, 2.4, 12),
      (21.5, 2.4, 12),
      (21.1, 3, 18.2),
      actor: "",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "アクシデンチュア……。さっき、ここの名前を言っていましたね。",
      (21.5, 2.4, 12),
      (21.5, 2.4, 12),
      (21.1, 3, 18.2),
      actor: "",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "福ちゃん",
      "……研修先って、こっちですか？",
      (21.5, 2.1, 13),
      (21.5, 2.1, 13),
      (21.1, 3, 18.2),
      actor: "",
      anchorToPlayer: false,
    ),
    EventShot(
      6,
      "",
      "村の異変と、会社の施設。扉の向こうに、何が残されているのか。\nそば屋ハザード — 体験版 終",
      (21.5, 2.1, 13),
      (21.5, 2.1, 13),
      (21.1, 3, 18.2),
      actor: "",
      anchorToPlayer: false,
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
