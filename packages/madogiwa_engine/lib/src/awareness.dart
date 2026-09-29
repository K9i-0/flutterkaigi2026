import 'dart:math' as math;

import 'spatial.dart';

enum AwarenessMode { patrol, investigate, chase }

/// Perception memory owns no character identity, renderer or weapon rules.
class Awareness {
  double suspicion = 0, unseenSeconds = 0, memorySeconds = 0;
  Point2? lastKnown;
  AwarenessMode mode = AwarenessMode.patrol;
  void hear(Point2 source, {double memory = 5}) {
    lastKnown = source;
    memorySeconds = memory;
    if (mode != AwarenessMode.chase) mode = AwarenessMode.investigate;
  }

  void update(
    double dt, {
    required bool seesTarget,
    required Point2 target,
    double detectionSeconds = .7,
  }) {
    if (!dt.isFinite ||
        dt < 0 ||
        !detectionSeconds.isFinite ||
        detectionSeconds <= 0) {
      throw ArgumentError('Invalid perception time');
    }
    if (seesTarget) {
      suspicion = math.min(1, suspicion + dt / detectionSeconds);
      unseenSeconds = 0;
      lastKnown = target;
      memorySeconds = 6;
      if (suspicion >= 1) mode = AwarenessMode.chase;
    } else {
      suspicion = math.max(0, suspicion - dt * .3);
      unseenSeconds += dt;
      memorySeconds = math.max(0, memorySeconds - dt);
      if (mode == AwarenessMode.chase && unseenSeconds > 1.5) {
        mode = AwarenessMode.investigate;
      }
      if (memorySeconds == 0) {
        mode = AwarenessMode.patrol;
        lastKnown = null;
      }
    }
  }
}
