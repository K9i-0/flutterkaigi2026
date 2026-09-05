class MotionSpec {
  const MotionSpec(this.name, this.label, this.loop, {this.mug = false});
  final String name, label;
  final bool loop, mug;
}

const motions = [
  MotionSpec('Idle', '待機', true),
  MotionSpec('Walk', '歩行', true),
  MotionSpec('Run', '走る', true),
  MotionSpec('ZombieWalk', 'ゾンビ歩行', true),
  MotionSpec('DanceStep', 'ダンス · ステップ', true),
  MotionSpec('DanceDisco', 'ダンス · ディスコ', true),
  MotionSpec('DanceVictory', 'ダンス · 勝利', true),
  MotionSpec('Toast', 'ジョッキで乾杯', false, mug: true),
  MotionSpec('MugAttack', 'ジョッキで攻撃', false, mug: true),
];

MotionSpec motionSpec(String name) => motions.firstWhere((m) => m.name == name);
