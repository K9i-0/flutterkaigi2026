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
    this.bodyYawDegrees = 0,
    this.bodyPitchDegrees = 0,
    this.bodyRollDegrees = 0,
    this.bodyYawConfidence = 0,
    this.bodyPitchConfidence = 0,
    this.bodyRollConfidence = 0,
    this.leftShoulderDegrees = -35,
    this.rightShoulderDegrees = 35,
    this.leftElbowDegrees = 0,
    this.rightElbowDegrees = 0,
    this.leftArmConfidence = 0,
    this.rightArmConfidence = 0,
    this.leftElbowConfidence = 0,
    this.rightElbowConfidence = 0,
  });

  const FaceTrackingSignal.neutral()
    : yawDegrees = 0,
      pitchDegrees = 0,
      rollDegrees = 0,
      leftEyeOpen = 1,
      rightEyeOpen = 1,
      mouthOpen = 0,
      confidence = 1,
      bodyYawDegrees = 0,
      bodyPitchDegrees = 0,
      bodyRollDegrees = 0,
      bodyYawConfidence = 0,
      bodyPitchConfidence = 0,
      bodyRollConfidence = 0,
      leftShoulderDegrees = -35,
      rightShoulderDegrees = 35,
      leftElbowDegrees = 0,
      rightElbowDegrees = 0,
      leftArmConfidence = 0,
      rightArmConfidence = 0,
      leftElbowConfidence = 0,
      rightElbowConfidence = 0;

  final double yawDegrees;
  final double pitchDegrees;
  final double rollDegrees;
  final double leftEyeOpen;
  final double rightEyeOpen;
  final double mouthOpen;
  final double confidence;
  final double bodyYawDegrees;
  final double bodyPitchDegrees;
  final double bodyRollDegrees;
  final double bodyYawConfidence;
  final double bodyPitchConfidence;
  final double bodyRollConfidence;
  final double leftShoulderDegrees;
  final double rightShoulderDegrees;
  final double leftElbowDegrees;
  final double rightElbowDegrees;
  final double leftArmConfidence;
  final double rightArmConfidence;
  final double leftElbowConfidence;
  final double rightElbowConfidence;
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
  VrmUpperBodyTrackingFrame _bodyFiltered =
      const VrmUpperBodyTrackingFrame.none();
  VrmArmTrackingFrame _armsFiltered = const VrmArmTrackingFrame(
    leftShoulderRollRadians: -35 * math.pi / 180,
    rightShoulderRollRadians: 35 * math.pi / 180,
    leftElbowRollRadians: 0,
    rightElbowRollRadians: 0,
    leftConfidence: 0,
    rightConfidence: 0,
    leftElbowConfidence: 0,
    rightElbowConfidence: 0,
  );

  VrmFaceTrackingFrame get filtered => _filtered;
  VrmUpperBodyTrackingFrame get upperBodyFiltered => _bodyFiltered;
  VrmArmTrackingFrame get armsFiltered => _armsFiltered;

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
    _bodyFiltered = const VrmUpperBodyTrackingFrame.none();
    _armsFiltered = const VrmArmTrackingFrame(
      leftShoulderRollRadians: -35 * math.pi / 180,
      rightShoulderRollRadians: 35 * math.pi / 180,
      leftElbowRollRadians: 0,
      rightElbowRollRadians: 0,
      leftConfidence: 0,
      rightConfidence: 0,
      leftElbowConfidence: 0,
      rightElbowConfidence: 0,
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
    final bodyAlpha = smooth
        ? 1 - math.exp(-6 * deltaSeconds.clamp(0.0, 0.1))
        : 1.0;
    final targetBody = VrmUpperBodyTrackingFrame(
      yawRadians:
          -(signal.bodyYawDegrees - _neutral.bodyYawDegrees) * degreesToRadians,
      pitchRadians:
          (signal.bodyPitchDegrees - _neutral.bodyPitchDegrees) *
          degreesToRadians,
      rollRadians:
          -(signal.bodyRollDegrees - _neutral.bodyRollDegrees) *
          degreesToRadians,
      yawConfidence: signal.bodyYawConfidence,
      pitchConfidence: signal.bodyPitchConfidence,
      rollConfidence: signal.bodyRollConfidence,
    ).clamped();
    _bodyFiltered = VrmUpperBodyTrackingFrame(
      yawRadians: _lerp(
        _bodyFiltered.yawRadians,
        targetBody.yawRadians,
        bodyAlpha,
      ),
      pitchRadians: _lerp(
        _bodyFiltered.pitchRadians,
        targetBody.pitchRadians,
        bodyAlpha,
      ),
      rollRadians: _lerp(
        _bodyFiltered.rollRadians,
        targetBody.rollRadians,
        bodyAlpha,
      ),
      yawConfidence: _lerp(
        _bodyFiltered.yawConfidence,
        targetBody.yawConfidence,
        bodyAlpha,
      ),
      pitchConfidence: _lerp(
        _bodyFiltered.pitchConfidence,
        targetBody.pitchConfidence,
        bodyAlpha,
      ),
      rollConfidence: _lerp(
        _bodyFiltered.rollConfidence,
        targetBody.rollConfidence,
        bodyAlpha,
      ),
    );
    const idleLeftShoulder = -35.0;
    const idleRightShoulder = 35.0;
    final targetArms = VrmArmTrackingFrame(
      leftShoulderRollRadians:
          _lerp(
            idleLeftShoulder,
            signal.leftShoulderDegrees,
            signal.leftArmConfidence.clamp(0.0, 1.0),
          ) *
          degreesToRadians,
      rightShoulderRollRadians:
          _lerp(
            idleRightShoulder,
            signal.rightShoulderDegrees,
            signal.rightArmConfidence.clamp(0.0, 1.0),
          ) *
          degreesToRadians,
      leftElbowRollRadians:
          signal.leftElbowDegrees *
          signal.leftElbowConfidence.clamp(0.0, 1.0) *
          degreesToRadians,
      rightElbowRollRadians:
          signal.rightElbowDegrees *
          signal.rightElbowConfidence.clamp(0.0, 1.0) *
          degreesToRadians,
      leftConfidence: signal.leftArmConfidence,
      rightConfidence: signal.rightArmConfidence,
      leftElbowConfidence: signal.leftElbowConfidence,
      rightElbowConfidence: signal.rightElbowConfidence,
    ).clamped();
    final armAlpha = smooth
        ? 1 - math.exp(-8 * deltaSeconds.clamp(0.0, 0.1))
        : 1.0;
    _armsFiltered = VrmArmTrackingFrame(
      leftShoulderRollRadians: _lerp(
        _armsFiltered.leftShoulderRollRadians,
        targetArms.leftShoulderRollRadians,
        armAlpha,
      ),
      rightShoulderRollRadians: _lerp(
        _armsFiltered.rightShoulderRollRadians,
        targetArms.rightShoulderRollRadians,
        armAlpha,
      ),
      leftElbowRollRadians: _lerp(
        _armsFiltered.leftElbowRollRadians,
        targetArms.leftElbowRollRadians,
        armAlpha,
      ),
      rightElbowRollRadians: _lerp(
        _armsFiltered.rightElbowRollRadians,
        targetArms.rightElbowRollRadians,
        armAlpha,
      ),
      leftConfidence: _lerp(
        _armsFiltered.leftConfidence,
        targetArms.leftConfidence,
        armAlpha,
      ),
      rightConfidence: _lerp(
        _armsFiltered.rightConfidence,
        targetArms.rightConfidence,
        armAlpha,
      ),
      leftElbowConfidence: _lerp(
        _armsFiltered.leftElbowConfidence,
        targetArms.leftElbowConfidence,
        armAlpha,
      ),
      rightElbowConfidence: _lerp(
        _armsFiltered.rightElbowConfidence,
        targetArms.rightElbowConfidence,
        armAlpha,
      ),
    );
    return _filtered;
  }

  static double _lerp(double from, double to, double t) =>
      from + (to - from) * t;
}
