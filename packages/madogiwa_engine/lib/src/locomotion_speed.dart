/// Renderer-independent speed integration for locomotion transitions.
/// Distances integrate the ramp exactly, including frames crossing the target.
/// Collision resolution must feed its actual travelled distance to animation;
/// this class describes requested travel, not collision or foot contact.
class LocomotionSpeed {
  LocomotionSpeed({required this.acceleration, required this.braking}) {
    if (!acceleration.isFinite ||
        acceleration <= 0 ||
        !braking.isFinite ||
        braking <= 0) {
      throw ArgumentError(
        'Acceleration and braking must be finite and positive',
      );
    }
  }
  final double acceleration, braking;
  double _speed = 0;
  double get speed => _speed;
  void reset([double speed = 0]) {
    _validate(speed, 'speed');
    _speed = speed;
  }

  double advance(double seconds, {required double target}) {
    _validate(seconds, 'seconds');
    _validate(target, 'target');
    if (seconds == 0) return 0;
    final difference = target - _speed;
    final rate = difference >= 0 ? acceleration : braking;
    final timeToTarget = difference.abs() / rate;
    final reachesTarget = seconds >= timeToTarget;
    final rampSeconds = timeToTarget.clamp(0.0, seconds);
    final end = reachesTarget
        ? target
        : _speed + difference.sign * rate * rampSeconds;
    final distance =
        (_speed + end) * .5 * rampSeconds + target * (seconds - rampSeconds);
    _speed = end;
    return distance;
  }

  static void _validate(double value, String name) {
    if (!value.isFinite || value < 0) throw ArgumentError.value(value, name);
  }
}
