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
  });
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

const hazardEvents = <String, List<EventShot>>{
  'opening': [
    EventShot(
      5,
      "",
      "アクシデンチュアの本番障害。その処分は、廃村ゆめみ村での「特別研修」。\n上陸した福ちゃん、やめ太郎、たこさんを残し、船は戻っていった。",
      (0, 7, -17),
      (0, 5, -14),
      (0, 1, 0),
    ),
    EventShot(
      7,
      "やめ太郎",
      "本番で全社員の配属を窓際にしてもうたんは、確かにワイらや。せやけど、ほんまに島流しにする会社ある？",
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
      "僕が実行して、やめさんが承認して、たこさんが確認した。三人とも、これで大丈夫だと思ったんですよね。",
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
    ),
    EventShot(
      7,
      "やめ太郎",
      "社長にまで窓際配属の通知が届いたんやで。大丈夫なわけあるかい。……あれ、そば屋さん？ なんで何人もおるん？",
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
      "迎えの担当者じゃ、なさそうですね。まず安全な場所と、帰る方法を探しましょう。",
      (-1.85, 1.58, -19.05),
      (-1.7, 1.55, -19.2),
      (0, 1.34, -21),
      actor: 'fukuchan',
      fov: .58,
    ),
    EventShot(
      6,
      "やめ太郎",
      "北の納屋に門の鍵がある。農場へ抜けよう。ワイら三人で帰るんや。打ち上げは、それからやで。",
      (-.85, 1.25, -19.55),
      (-.98, 1.23, -19.65),
      (-2.8, .94, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .64,
    ),
  ],
  'farm': [
    EventShot(
      5,
      "",
      "CHAPTER 02 — 撤収対象外\n農場を装った管理施設。残された台帳には、同じ顔の写真が並んでいた。",
      (-4, 7, -21),
      (-2, 5.8, -19),
      (6, 2, -9),
    ),
    EventShot(
      7,
      "たこさん",
      "そば屋エンジン。そば屋のクローンにビールを飲ませて、怪力で設備を動かす。ここは、その補給施設でした。",
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      6,
      "たこさん",
      "案件は炎上し、担当者が逃げ、ビールも尽きました。残されたクローンが村へ出た。それが、そば屋ハザードです。",
      (-13.5, 1.2, -19.7),
      (-13.8, 1.3, -20),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      7,
      "たこさん",
      "山に非常用の無線があります。ただ、エンジンが動く間は、運転命令の放送しか流せません。まず中枢を止めましょう。",
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
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
    ),
  ],
  'last_order': [
    EventShot(
      4,
      "",
      "LAST ORDER — そば屋エンジン中枢\n軸を回す大型クローン。案件が消えても、「検収まで運転継続」の命令だけが残っていた。",
      (8.3, 1.7, 1.7),
      (8.7, 1.65, 1.9),
      (12, 1.45, 4),
      actor: 'sobaya',
      motion: 'MugAttack',
      fov: .66,
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
      "検収が終わるまで止めるな。そう教えたのに、検収する人がいなくなった。ずっと、終わるのを待ってたんですね。",
      (2.0, 1.6, 2.4),
      (1.85, 1.55, 2.2),
      (0, 1.3, 0),
      actor: 'fukuchan',
      fov: .58,
      anchorToPlayer: true,
    ),
    EventShot(
      5,
      "福ちゃん",
      "この仕事は、もう終わりです。誰も終わらせに来ないなら、僕らが止めます。帰りましょう。",
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
      "中枢停止。運転命令の代わりに、非常無線から三人の救難信号が流れた。\n避難していた社員たちと合流し、証拠の記録を抱えて迎えの船を待つ。",
      (13.6, 2.1, .2),
      (13.6, 1.85, .7),
      (13.6, .95, 6.5),
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
      "僕らの失敗は、帰ってからちゃんと説明します。でも、ここに人を置いていったことまで、なかったことにはさせません。",
      (13.3, 1.6, 4.1),
      (13.15, 1.55, 4.25),
      (11.5, 1.32, 6),
      actor: 'fukuchan',
      fov: .60,
    ),
    EventShot(
      6,
      "やめ太郎",
      "せやな。ワイらがやらかした話も、この村で見た話も、両方持って帰ろ。次に誰かが送られてくる前に。",
      (12.3, 1.15, 4.8),
      (12.45, 1.1, 4.95),
      (14, .73, 7),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .66,
    ),
    EventShot(
      5,
      "たこさん",
      "ビールと飼育区画は封鎖しました。取り残された社員も、同じ船で帰します。",
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
      "引き継ぎは、人が帰れるところまで。今度は、三人でそこまで確認しましょう。",
      (13.3, 1.6, 4.1),
      (13.15, 1.55, 4.25),
      (11.5, 1.32, 6),
      actor: 'fukuchan',
      fov: .60,
    ),
    EventShot(
      6,
      "やめ太郎",
      "ええやん。ワイらも閉店や。……ところで、この椅子、段ボールやない？",
      (12.3, 1.15, 4.8),
      (12.45, 1.1, 4.95),
      (14, .73, 7),
      actor: 'yametaro',
      motion: 'Talk',
      fov: .66,
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
