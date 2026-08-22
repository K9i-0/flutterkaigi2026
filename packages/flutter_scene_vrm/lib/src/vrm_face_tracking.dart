import 'dart:math' as math;

import 'package:vector_math/vector_math.dart';

import 'vrm_avatar.dart';

/// Engine-independent face tracking values normalized for avatar driving.
class VrmFaceTrackingFrame {
  const VrmFaceTrackingFrame({
    required this.yawRadians,
    required this.pitchRadians,
    required this.rollRadians,
    required this.blinkLeft,
    required this.blinkRight,
    required this.mouthOpen,
    this.confidence = 1,
  });

  final double yawRadians;
  final double pitchRadians;
  final double rollRadians;
  final double blinkLeft;
  final double blinkRight;
  final double mouthOpen;
  final double confidence;

  VrmFaceTrackingFrame clamped() => VrmFaceTrackingFrame(
    yawRadians: yawRadians.clamp(-math.pi / 3, math.pi / 3),
    pitchRadians: pitchRadians.clamp(-math.pi / 4, math.pi / 4),
    rollRadians: rollRadians.clamp(-math.pi / 3, math.pi / 3),
    blinkLeft: blinkLeft.clamp(0.0, 1.0),
    blinkRight: blinkRight.clamp(0.0, 1.0),
    mouthOpen: mouthOpen.clamp(0.0, 1.0),
    confidence: confidence.clamp(0.0, 1.0),
  );
}

/// Maps normalized tracking values onto VRM humanoid bones and expressions.
class VrmFaceTrackingDriver {
  VrmFaceTrackingDriver(this.avatar);

  final VrmAvatar avatar;

  void apply(VrmFaceTrackingFrame input) {
    final frame = input.clamped();
    final confidence = frame.confidence;
    final yaw = frame.yawRadians * confidence;
    final pitch = frame.pitchRadians * confidence;
    final roll = frame.rollRadians * confidence;

    avatar.setHumanBoneRotation(
      'neck',
      Quaternion.euler(yaw * 0.25, pitch * 0.25, roll * 0.25),
    );
    avatar.setHumanBoneRotation(
      'head',
      Quaternion.euler(yaw * 0.75, pitch * 0.75, roll * 0.75),
    );

    final expressions = <String, double>{};
    if (avatar.document.expressions.containsKey('blinkLeft') &&
        avatar.document.expressions.containsKey('blinkRight')) {
      expressions['blinkLeft'] = frame.blinkLeft * confidence;
      expressions['blinkRight'] = frame.blinkRight * confidence;
    } else if (avatar.document.expressions.containsKey('blink')) {
      expressions['blink'] =
          (frame.blinkLeft + frame.blinkRight) * 0.5 * confidence;
    }
    if (avatar.document.expressions.containsKey('aa')) {
      expressions['aa'] = frame.mouthOpen * confidence;
    }
    if (expressions.isNotEmpty) avatar.setExpressions(expressions);
  }

  void reset() {
    avatar.resetHumanBoneRotation('neck');
    avatar.resetHumanBoneRotation('head');
    final expressions = <String, double>{};
    for (final expression in const ['blinkLeft', 'blinkRight', 'blink', 'aa']) {
      if (avatar.document.expressions.containsKey(expression)) {
        expressions[expression] = 0;
      }
    }
    if (expressions.isNotEmpty) avatar.setExpressions(expressions);
  }
}
