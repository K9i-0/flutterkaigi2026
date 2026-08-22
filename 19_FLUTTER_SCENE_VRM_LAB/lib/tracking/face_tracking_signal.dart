import 'dart:math' as math;

import 'package:flutter_scene_vrm/flutter_scene_vrm.dart';

class FaceTrackingSignal {
  const FaceTrackingSignal({
    required this.yawDegrees,
    required this.pitchDegrees,
    required this.rollDegrees,
    required this.leftEyeOpen,
    required this.rightEyeOpen,
    required this.mouthOpen,
    this.confidence = 1,
  });

  const FaceTrackingSignal.neutral()
    : yawDegrees = 0,
      pitchDegrees = 0,
      rollDegrees = 0,
      leftEyeOpen = 1,
      rightEyeOpen = 1,
      mouthOpen = 0,
      confidence = 1;

  final double yawDegrees;
  final double pitchDegrees;
  final double rollDegrees;
  final double leftEyeOpen;
  final double rightEyeOpen;
  final double mouthOpen;
  final double confidence;
}

/// Calibrates and smooths detector output before it reaches the VRM layer.
class FaceTrackingPipeline {
  FaceTrackingSignal _neutral = const FaceTrackingSignal.neutral();
  VrmFaceTrackingFrame _filtered = const VrmFaceTrackingFrame(
    yawRadians: 0,
    pitchRadians: 0,
    rollRadians: 0,
    blinkLeft: 0,
    blinkRight: 0,
    mouthOpen: 0,
  );
  FaceTrackingSignal? _lastSignal;

  VrmFaceTrackingFrame get filtered => _filtered;

  void calibrate() {
    final signal = _lastSignal;
    if (signal != null) _neutral = signal;
  }

  void resetCalibration() {
    _neutral = const FaceTrackingSignal.neutral();
  }

  void reset() {
    _neutral = const FaceTrackingSignal.neutral();
    _lastSignal = null;
    _filtered = const VrmFaceTrackingFrame(
      yawRadians: 0,
      pitchRadians: 0,
      rollRadians: 0,
      blinkLeft: 0,
      blinkRight: 0,
      mouthOpen: 0,
    );
  }

  VrmFaceTrackingFrame ingest(
    FaceTrackingSignal signal, {
    required double deltaSeconds,
    bool smooth = true,
  }) {
    _lastSignal = signal;
    const degreesToRadians = math.pi / 180;
    // Front-camera UX is mirror-like, so yaw/roll are inverted while pitch
    // keeps ML Kit's positive-up convention.
    final target = VrmFaceTrackingFrame(
      yawRadians: -(signal.yawDegrees - _neutral.yawDegrees) * degreesToRadians,
      pitchRadians:
          (signal.pitchDegrees - _neutral.pitchDegrees) * degreesToRadians,
      rollRadians:
          -(signal.rollDegrees - _neutral.rollDegrees) * degreesToRadians,
      blinkLeft: 1 - signal.leftEyeOpen,
      blinkRight: 1 - signal.rightEyeOpen,
      mouthOpen: signal.mouthOpen,
      confidence: signal.confidence,
    ).clamped();
    final alpha = smooth
        ? 1 - math.exp(-12 * deltaSeconds.clamp(0.0, 0.1))
        : 1.0;
    _filtered = VrmFaceTrackingFrame(
      yawRadians: _lerp(_filtered.yawRadians, target.yawRadians, alpha),
      pitchRadians: _lerp(_filtered.pitchRadians, target.pitchRadians, alpha),
      rollRadians: _lerp(_filtered.rollRadians, target.rollRadians, alpha),
      blinkLeft: _lerp(_filtered.blinkLeft, target.blinkLeft, alpha),
      blinkRight: _lerp(_filtered.blinkRight, target.blinkRight, alpha),
      mouthOpen: _lerp(_filtered.mouthOpen, target.mouthOpen, alpha),
      confidence: target.confidence,
    );
    return _filtered;
  }

  static double _lerp(double from, double to, double t) =>
      from + (to - from) * t;
}
