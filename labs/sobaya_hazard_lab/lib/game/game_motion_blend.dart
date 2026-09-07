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
