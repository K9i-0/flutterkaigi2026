import 'dart:math' as math;

/// Authored ladder dimensions shared by traversal, navigation and checkpoints.
class HazardLadder {
  HazardLadder(Map<String, dynamic> tower)
    : x = (tower['x'] as num).toDouble(),
      z = (tower['z'] as num).toDouble(),
      top = (tower['top'] as num).toDouble();
  final double x, z, top;
  double get columnZ => z + .1;
  double get lowerZ => z - .3;
  double get upperZ => z + 1.15;
  bool atEntry(double px, double py, double pz, bool up) =>
      (py - (up ? 0 : top)).abs() < .12 &&
      math.pow(px - x, 2) + math.pow(pz - (up ? lowerZ : upperZ), 2) <
          1.8 * 1.8;
}

class LadderTraversal {
  LadderTraversal(this.ladder, this.up, this.startX, this.startZ);
  final HazardLadder ladder;
  final bool up;
  final double startX, startZ;
  double elapsed = 0;
  static const speed = .7, exitSeconds = .65;
  double get approachSeconds => math.max(
    .4,
    math.sqrt(
          math.pow(startX - ladder.x, 2) + math.pow(startZ - ladder.columnZ, 2),
        ) /
        1.4,
  );
  double get climbSeconds => ladder.top / speed;
  double get duration => approachSeconds + climbSeconds + exitSeconds;
  bool get done => elapsed >= duration;
  bool get onRungs =>
      elapsed >= approachSeconds && elapsed < approachSeconds + climbSeconds;
  double get climbProgress =>
      ((elapsed - approachSeconds) / climbSeconds).clamp(0, 1);
  double get clipTime =>
      ((up ? climbProgress : 1 - climbProgress) * climbSeconds) % 1;
  double get y => ladder.top * (up ? climbProgress : 1 - climbProgress);
  double get x =>
      startX + (ladder.x - startX) * (elapsed / approachSeconds).clamp(0, 1);
  double get z {
    if (elapsed < approachSeconds) {
      return startZ + (ladder.columnZ - startZ) * elapsed / approachSeconds;
    }
    return ladder.columnZ +
        ((up ? ladder.upperZ : ladder.lowerZ) - ladder.columnZ) *
            ((elapsed - approachSeconds - climbSeconds) / exitSeconds).clamp(
              0,
              1,
            );
  }

  void advance(double dt) => elapsed = math.min(duration, elapsed + dt);
  Map<String, Object> toJson() => {
    'up': up,
    'startX': startX,
    'startZ': startZ,
    'elapsed': elapsed,
  };

  static LadderTraversal? restore(
    dynamic data,
    HazardLadder? ladder,
    double x,
    double y,
    double z,
  ) {
    if (data == null) return null;
    if (data is! Map ||
        ladder == null ||
        data['up'] is! bool ||
        [
          'startX',
          'startZ',
          'elapsed',
        ].any((k) => data[k] is! num || !(data[k] as num).isFinite)) {
      throw const FormatException('Invalid ladder traversal');
    }
    final result = LadderTraversal(
      ladder,
      data['up'],
      (data['startX'] as num).toDouble(),
      (data['startZ'] as num).toDouble(),
    )..elapsed = (data['elapsed'] as num).toDouble();
    if (!ladder.atEntry(
          result.startX,
          result.up ? 0 : ladder.top,
          result.startZ,
          result.up,
        ) ||
        result.elapsed < 0 ||
        result.elapsed >= result.duration ||
        (result.x - x).abs() > .06 ||
        (result.y - y).abs() > .06 ||
        (result.z - z).abs() > .06) {
      throw const FormatException('Inconsistent ladder traversal');
    }
    return result;
  }
}
