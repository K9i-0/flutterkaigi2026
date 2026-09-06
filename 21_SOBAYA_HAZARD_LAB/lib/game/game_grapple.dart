import 'dart:math' as math;

/// Shared clock and collision-checked attachment for one frontal grab.
class HazardGrapple {
  HazardGrapple({
    required this.enemyId,
    required this.playerX,
    required this.playerY,
    required this.playerZ,
    required this.heading,
    required this.startX,
    required this.startZ,
  });

  static const separation = .70, duration = 3.4, escapeSeconds = 1.2;
  final int enemyId;
  final double playerX, playerY, playerZ, heading, startX, startZ;
  double elapsed = 0, effort = 0;
  double get targetX => playerX - math.sin(heading) * separation;
  double get targetZ => playerZ - math.cos(heading) * separation;
  double get settle {
    final t = (elapsed / .25).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  double get enemyX => startX + (targetX - startX) * settle;
  double get enemyZ => startZ + (targetZ - startZ) * settle;
  bool get escaped => effort >= escapeSeconds;
  bool get expired => elapsed >= duration;

  /// Return newly crossed damage beats so pause/restore cannot repeat a beat.
  int advance(double dt, {required bool struggling}) {
    final before = elapsed.floor();
    elapsed = math.min(duration, elapsed + dt);
    effort = (effort + (struggling ? dt : -.08 * dt)).clamp(0.0, escapeSeconds);
    return elapsed.floor() - before;
  }

  Map<String, Object> toJson() => {
    'enemyId': enemyId,
    'playerX': playerX,
    'playerY': playerY,
    'playerZ': playerZ,
    'heading': heading,
    'startX': startX,
    'startZ': startZ,
    'elapsed': elapsed,
    'effort': effort,
  };

  static HazardGrapple? restore(dynamic data) {
    if (data == null) return null;
    if (data is! Map || data['enemyId'] is! int) {
      throw const FormatException('Invalid grapple');
    }
    double number(String key, double low, double high) {
      final value = data[key];
      if (value is! num || !value.isFinite || value < low || value > high) {
        throw const FormatException('Invalid grapple value');
      }
      return value.toDouble();
    }

    final result =
        HazardGrapple(
            enemyId: data['enemyId'],
            playerX: number('playerX', -30, 30),
            playerY: number('playerY', 0, 6),
            playerZ: number('playerZ', -30, 35),
            heading: number('heading', -math.pi, math.pi),
            startX: number('startX', -30, 30),
            startZ: number('startZ', -30, 35),
          )
          ..elapsed = number('elapsed', 0, duration)
          ..effort = number('effort', 0, escapeSeconds);
    if (result.escaped || result.expired) {
      throw const FormatException('Finished grapple cannot remain attached');
    }
    return result;
  }
}
