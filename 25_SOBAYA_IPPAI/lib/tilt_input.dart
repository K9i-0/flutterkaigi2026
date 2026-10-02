import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

/// Gravity low-pass filtering removes most hand tremor. Calibration captures
/// the held pose; left and right rolls both work for either dominant hand.
class TiltInput {
  TiltInput({DateTime Function()? now}) : _now = now ?? DateTime.now;
  final DateTime Function() _now;
  StreamSubscription<AccelerometerEvent>? _subscription;
  double _x = 0, _y = 9.81, _z = 0, _zero = 0;
  bool _received = false;
  DateTime? _lastEvent;
  bool get available =>
      _received &&
      _lastEvent != null &&
      _now().difference(_lastEvent!).inMilliseconds < 600;
  double get angle => math.atan2(_x, math.sqrt(_y * _y + _z * _z));
  double get value =>
      available ? ((angle - _zero).abs() / (math.pi / 3)).clamp(0, 1) : 0;
  void calibrate() => _zero = angle;

  /// Also used by sensor tests; sample units are metres/second².
  void sample(double x, double y, double z) {
    if (![x, y, z].every((n) => n.isFinite) || x * x + y * y + z * z < 1) {
      return;
    }
    final now = _now();
    final dt = _lastEvent == null
        ? 1.0
        : now.difference(_lastEvent!).inMicroseconds / 1e6;
    if (dt <= 0) return;
    final a = 1 - math.exp(-dt * 18);
    _x += (x - _x) * a;
    _y += (y - _y) * a;
    _z += (z - _z) * a;
    _lastEvent = now;
    if (!_received) {
      _received = true;
      calibrate();
    }
  }

  void start() {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    _subscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 16),
        ).listen(
          (e) => sample(e.x, e.y, e.z),
          onError: (Object e) {
            _received = false;
          },
          cancelOnError: true,
        );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
