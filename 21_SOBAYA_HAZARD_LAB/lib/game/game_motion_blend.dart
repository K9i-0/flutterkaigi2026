import 'dart:math' as math;

const _gaits = {'Walk', 'Run', 'ZombieWalk'};

/// Transfer the normalized gait phase when changing speed, so the planted
/// leg does not jump back to the first frame. One-shot actions start at zero.
double transitionMotionTime(
  String from,
  String to,
  double seconds,
  double fromDuration,
  double toDuration,
) {
  if (!_gaits.contains(from) ||
      !_gaits.contains(to) ||
      fromDuration <= 0 ||
      toDuration <= 0) {
    return 0;
  }
  return (seconds / fromDuration).clamp(0.0, 1.0) * toDuration;
}

/// Time-step independent blend with an exact zero to stop evaluating old rigs.
double advanceMotionWeight(double weight, bool active, double dt) {
  final target = active ? 1.0 : 0.0;
  final next =
      weight + (target - weight) * (1 - math.exp(-12 * dt.clamp(0.0, .1)));
  return (next - target).abs() < .0001 ? target : next;
}

/// Synchronize foot speed with displacement after wall/terrain collision.
double locomotionPlaybackRate(double distance, double dt, double groundSpeed) {
  if (!distance.isFinite || !dt.isFinite || dt <= 0 || groundSpeed <= 0) {
    return 0;
  }
  return (distance / dt / groundSpeed).clamp(0.0, 3.0);
}

// Source names and fitted foot speeds from the shared motion catalog.
const playerMotionSources = {
  'Idle': 'Adopted_Library_Idle_A',
  'Walk': 'Adopted_Library_Walk',
  'Run': 'Adopted_Candidate_Mixamo_Run',
};
const sobayaMotionSources = {
  'Idle': 'Hybrid_MugHold',
  'Walk': 'Adopted_Library_Walk',
  'Run': 'Adopted_Candidate_Chase_Run',
  'MugAttack': 'Hybrid_MugSmash',
  'MugPunch': 'Hybrid_MugPunch',
  'MugHook': 'Hybrid_MugHook',
};
const fukuchanWalkSpeed = 0.6532815936952829;
const fukuchanRunSpeed = 2.0935137569904327;
const sobayaMugRunSpeed = 4.944039657711983;

/// The gameplay clock strikes at .77; every new mug clip contacts at 48%.
/// Map anticipation and recovery separately, keeping hit damage on its existing
/// clock even when the selected punch, hook and smash have different lengths.
double mugAttackTime(
  double clock,
  double duration, {
  required double recoveryClockDuration,
}) {
  final phase = clock <= .77
      ? .48 * (clock / .77).clamp(0.0, 1.0)
      : .48 + .52 * ((clock - .77) / recoveryClockDuration).clamp(0.0, 1.0);
  return duration * phase;
}

/// One cosmetic choice per spawn, independent of frame rate and AI detection.
String? chooseAmbientDance(double roll, int variant, {bool boss = false}) {
  if (boss || roll >= .20) return null;
  return const ['DanceStep', 'DanceDisco', 'DanceVictory'][variant % 3];
}

const sobayaWalkSpeed = 0.7230468839406967;
