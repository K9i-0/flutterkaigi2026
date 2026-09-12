import 'dart:math' as math;

/// Selects vsync callbacks for a bounded automatic animation/render cadence.
/// This clock never changes the elapsed time delivered to the scene.
class SceneFramePacer {
  Duration? _lastVsync;
  double? _rate;
  double _creditUs = 0;
  double _sinceAcceptedUs = 0;

  void reset() {
    _lastVsync = null;
    _rate = null;
    _creditUs = 0;
    _sinceAcceptedUs = 0;
  }

  bool shouldAdvance(Duration elapsed, double? maxFramesPerSecond) {
    assert(
      maxFramesPerSecond == null ||
          (maxFramesPerSecond.isFinite && maxFramesPerSecond > 0),
    );
    final previous = _lastVsync;
    _lastVsync = elapsed;
    if (maxFramesPerSecond == null || previous == null || elapsed < previous) {
      _rate = maxFramesPerSecond;
      _creditUs = _sinceAcceptedUs = 0;
      return true;
    }

    final deltaUs = (elapsed - previous).inMicroseconds.toDouble();
    _sinceAcceptedUs += deltaUs;
    if (_rate != maxFramesPerSecond) {
      // The new period starts at the last accepted frame, not the setting
      // change. This avoids an immediate extra frame or dropping elapsed time.
      _rate = maxFramesPerSecond;
      _creditUs = _sinceAcceptedUs;
    } else {
      _creditUs += deltaUs;
    }

    final periodUs = Duration.microsecondsPerSecond / maxFramesPerSecond;
    final toleranceUs = math.min(500.0, periodUs * .03);
    if (_creditUs + toleranceUs < periodUs) return false;

    if (deltaUs > periodUs * 1.5 || _creditUs >= periodUs * 2) {
      // A delayed callback produces one frame, never catch-up bursts.
      _creditUs = 0;
    } else {
      _creditUs -= periodUs;
      // Near-harmonic displays (119.88/59.94 Hz) should keep their smooth
      // divisor cadence, not occasionally emit a short frame to repay drift.
      // Preserve negative credit so slightly early frames cannot exceed the
      // requested average rate indefinitely.
      if (_creditUs > 0 && _creditUs <= math.min(100.0, periodUs * .003)) {
        _creditUs = 0;
      }
    }
    _sinceAcceptedUs = 0;
    return true;
  }
}
