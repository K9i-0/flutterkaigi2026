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
  });
  final double seconds;
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
      '',
      '連絡が途絶えた村。\n福ちゃんは、仲間の残した記録を探しに来た。',
      (0, 7, -17),
      (0, 5, -14),
      (0, 1, 0),
    ),
    EventShot(
      7,
      'やめ太郎',
      '福ちゃん！ 広場がそば屋だらけなんだ。\n全員、乾杯する気満々でさ。',
      (-3.8, 1.5, -23.5),
      (-3.4, 1.4, -23.1),
      (-2.8, .95, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
    ),
    EventShot(
      5,
      '福ちゃん',
      '乾杯にしては、ジョッキの振りが大きすぎるだろ。',
      (.8, 1.6, -18.8),
      (.5, 1.5, -19.2),
      (0, 1.25, -21),
      actor: 'fukuchan',
    ),
    EventShot(
      6,
      'やめ太郎',
      '北の納屋に門の鍵がある。農場へ抜けよう。\n壁の記録も、できるだけ回収しておいて。',
      (-2.9, 1.5, -23.6),
      (-2.6, 1.4, -23.2),
      (-2.8, .95, -21.2),
      actor: 'yametaro',
      motion: 'Talk',
    ),
  ],
  'farm': [
    EventShot(
      5,
      '',
      'CHAPTER 02 — 農場\n乾杯のあとに、補給を。',
      (-4, 7, -21),
      (-2, 5.8, -19),
      (6, 2, -9),
    ),
    EventShot(
      7,
      'たこさん',
      '……。東の門から山道へ進めます。\nビールは弾やハーブと交換できます。',
      (-13.8, 1.3, -20),
      (-13.5, 1.2, -19.7),
      (-13, .9, -17.8),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      6,
      'たこさん',
      '納屋の二階も、お調べください。\n青いメダリオンは七つ。全部落とせば、おまけもあります。',
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
      '',
      'LAST ORDER\n最後の乾杯。',
      (6, 1.7, 1),
      (7, 1.45, 1.5),
      (12, 1.35, 4),
      actor: 'sobaya',
      motion: 'MugAttack',
    ),
    EventShot(5, '福ちゃん', 'その一杯、遠慮させてもらう！', (3, 3.1, 7), (4, 2.6, 7), (
      12,
      1,
      4,
    ), actor: 'sobaya'),
  ],
  'ending': [
    EventShot(
      5,
      '',
      '村を抜ける前に、三人は落ち合った。\nジョッキの音は、もう聞こえない。',
      (13, 2.5, 6),
      (13, 2.0, 7),
      (13, 1.2, 12),
    ),
    EventShot(
      6,
      'やめ太郎',
      'おかえり、福ちゃん。\n……今日はもう、乾杯は遠慮したいな。',
      (14.3, 1.5, 15.2),
      (14.5, 1.4, 15.6),
      (16, .95, 17.5),
      actor: 'yametaro',
      motion: 'Talk',
    ),
    EventShot(
      5,
      '福ちゃん',
      '明日はノンアルで集まろう。\n記録の整理も、まだ残ってるし。',
      (12, 1.5, 15),
      (12.3, 1.45, 15.2),
      (14, 1.2, 16),
      actor: 'fukuchan',
    ),
    EventShot(
      5,
      'たこさん',
      '……。それも仕入れておきます。',
      (16.2, 1.35, 15.3),
      (16.5, 1.25, 15.7),
      (17.7, .9, 17.5),
      actor: 'takosan',
      motion: 'Talk',
    ),
    EventShot(
      4,
      'やめ太郎',
      'え、また集まるの？',
      (14.3, 1.5, 15.2),
      (14.3, 1.5, 15.2),
      (16, .95, 17.5),
      actor: 'yametaro',
      motion: 'Talk',
    ),
  ],
};

/// Rendering and input consume the same clock. Pausing never advances a shot.
class HazardDirector {
  HazardDirector(this.id)
    : shots = hazardEvents[id] ?? (throw ArgumentError.value(id));
  final String id;
  final List<EventShot> shots;
  int index = 0;
  double elapsed = 0;
  bool paused = false, done = false;
  EventShot get shot => shots[math.min(index, shots.length - 1)];
  double get progress => (elapsed / shot.seconds).clamp(0, 1);
  void tick(double dt) {
    if (done || paused) return;
    elapsed += dt.clamp(0, .05);
    if (elapsed >= shot.seconds) next();
  }

  void next() {
    if (done) return;
    index++;
    elapsed = 0;
    if (index >= shots.length) done = true;
  }

  void skip() => done = true;
}
