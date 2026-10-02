import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class TiltInput {
  TiltInput({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  StreamSubscription<AccelerometerEvent>? subscription;
  DateTime? last;
  double gx = 0, gy = 0, gz = 9.8, zeroX = 0, zeroY = 0;
  bool received = false;
  bool get available =>
      received && last != null && _now().difference(last!).inMilliseconds < 600;
  // LandscapeLeft downhill response: +sensor Y -> right, -sensor X -> up.
  // Accelerometers report proper acceleration, opposite gravity.
  double get ax => math.atan2(gy, math.sqrt(gx * gx + gz * gz));
  double get ay => math.atan2(-gx, math.sqrt(gy * gy + gz * gz));
  double response(double angle) {
    final n = angle / .24;
    return n.abs() < .06
        ? 0
        : (n.sign * (n.abs() - .06) / .94).clamp(-1.0, 1.0);
  }

  double get x => available ? response(ax - zeroX) : 0;
  double get y => available ? response(ay - zeroY) : 0;
  void calibrate() {
    zeroX = ax;
    zeroY = ay;
  }

  void sample(double x, double y, double z) {
    if (![x, y, z].every((v) => v.isFinite) || x * x + y * y + z * z < 1) {
      return;
    }
    final now = _now(),
        dt = last == null ? 1.0 : now.difference(last!).inMicroseconds / 1e6;
    if (dt <= 0) return;
    final a = 1 - math.exp(-dt * 14);
    gx += (x - gx) * a;
    gy += (y - gy) * a;
    gz += (z - gz) * a;
    last = now;
    if (!received) {
      received = true;
      calibrate();
    }
  }

  void start() {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    subscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 16),
        ).listen(
          (e) => sample(e.x, e.y, e.z),
          onError: (Object e) {
            received = false;
          },
        );
  }

  void dispose() => subscription?.cancel();
}
