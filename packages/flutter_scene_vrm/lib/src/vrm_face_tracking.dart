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

/// Camera-independent torso pose that can be supplied by an upper-body
/// detector. Confidence is per axis because a cropped 2D view can estimate
/// shoulder roll much more reliably than forward pitch.
class VrmUpperBodyTrackingFrame {
  const VrmUpperBodyTrackingFrame({
    required this.yawRadians,
    required this.pitchRadians,
    required this.rollRadians,
    required this.yawConfidence,
    required this.pitchConfidence,
    required this.rollConfidence,
  });

  const VrmUpperBodyTrackingFrame.none()
    : yawRadians = 0,
      pitchRadians = 0,
      rollRadians = 0,
      yawConfidence = 0,
      pitchConfidence = 0,
      rollConfidence = 0;

  final double yawRadians;
  final double pitchRadians;
  final double rollRadians;
  final double yawConfidence;
  final double pitchConfidence;
  final double rollConfidence;

  VrmUpperBodyTrackingFrame clamped() => VrmUpperBodyTrackingFrame(
    yawRadians: yawRadians.clamp(-math.pi / 4, math.pi / 4),
    pitchRadians: pitchRadians.clamp(-math.pi / 6, math.pi / 6),
    rollRadians: rollRadians.clamp(-math.pi / 4, math.pi / 4),
    yawConfidence: yawConfidence.clamp(0.0, 1.0),
    pitchConfidence: pitchConfidence.clamp(0.0, 1.0),
    rollConfidence: rollConfidence.clamp(0.0, 1.0),
  );
}

/// In-plane arm rotations derived from shoulder/elbow/wrist landmarks.
/// Shoulder rotations are applied to the complete shoulder subtree so VRM
/// helper bones beneath it remain aligned.
class VrmArmTrackingFrame {
  const VrmArmTrackingFrame({
    required this.leftShoulderRollRadians,
    required this.rightShoulderRollRadians,
    required this.leftElbowRollRadians,
    required this.rightElbowRollRadians,
    required this.leftConfidence,
    required this.rightConfidence,
    required this.leftElbowConfidence,
    required this.rightElbowConfidence,
  });

  final double leftShoulderRollRadians;
  final double rightShoulderRollRadians;
  final double leftElbowRollRadians;
  final double rightElbowRollRadians;
  final double leftConfidence;
  final double rightConfidence;
  final double leftElbowConfidence;
  final double rightElbowConfidence;

  VrmArmTrackingFrame clamped() => VrmArmTrackingFrame(
    leftShoulderRollRadians: leftShoulderRollRadians.clamp(
      -110 * math.pi / 180,
      110 * math.pi / 180,
    ),
    rightShoulderRollRadians: rightShoulderRollRadians.clamp(
      -110 * math.pi / 180,
      110 * math.pi / 180,
    ),
    leftElbowRollRadians: leftElbowRollRadians.clamp(
      -140 * math.pi / 180,
      140 * math.pi / 180,
    ),
    rightElbowRollRadians: rightElbowRollRadians.clamp(
      -140 * math.pi / 180,
      140 * math.pi / 180,
    ),
    leftConfidence: leftConfidence.clamp(0.0, 1.0),
    rightConfidence: rightConfidence.clamp(0.0, 1.0),
    leftElbowConfidence: leftElbowConfidence.clamp(0.0, 1.0),
    rightElbowConfidence: rightElbowConfidence.clamp(0.0, 1.0),
  );
}

/// Controls how face rotation is distributed through the upper body.
enum VrmBodyFollowMode { headOnly, natural, anime }

/// Euler rotation assigned to one humanoid bone by upper-body tracking.
class VrmTrackedBoneRotation {
  const VrmTrackedBoneRotation({
    required this.yawRadians,
    required this.pitchRadians,
    required this.rollRadians,
  });

  const VrmTrackedBoneRotation.zero()
    : yawRadians = 0,
      pitchRadians = 0,
      rollRadians = 0;

  final double yawRadians;
  final double pitchRadians;
  final double rollRadians;

  VrmTrackedBoneRotation lerp(VrmTrackedBoneRotation target, double amount) =>
      VrmTrackedBoneRotation(
        yawRadians: _lerp(yawRadians, target.yawRadians, amount),
        pitchRadians: _lerp(pitchRadians, target.pitchRadians, amount),
        rollRadians: _lerp(rollRadians, target.rollRadians, amount),
      );

  static double _lerp(double from, double to, double amount) =>
      from + (to - from) * amount;
}

class _BoneFollowWeight {
  const _BoneFollowWeight(this.yaw, this.pitch, this.roll);

  final double yaw;
  final double pitch;
  final double roll;
}

const _naturalWeights = <String, _BoneFollowWeight>{
  'spine': _BoneFollowWeight(0.06, 0.03, 0.02),
  'chest': _BoneFollowWeight(0.10, 0.06, 0.04),
  'upperChest': _BoneFollowWeight(0.14, 0.10, 0.08),
  'neck': _BoneFollowWeight(0.20, 0.21, 0.20),
  'head': _BoneFollowWeight(0.50, 0.60, 0.66),
};

const _headOnlyWeights = <String, _BoneFollowWeight>{
  'spine': _BoneFollowWeight(0, 0, 0),
  'chest': _BoneFollowWeight(0, 0, 0),
  'upperChest': _BoneFollowWeight(0, 0, 0),
  'neck': _BoneFollowWeight(0.25, 0.25, 0.25),
  'head': _BoneFollowWeight(0.75, 0.75, 0.75),
};

const _detectedBodyWeights = <String, _BoneFollowWeight>{
  'spine': _BoneFollowWeight(0.20, 0.15, 0.20),
  'chest': _BoneFollowWeight(0.35, 0.35, 0.35),
  'upperChest': _BoneFollowWeight(0.45, 0.50, 0.45),
};

/// Computes local humanoid-bone rotations without depending on a renderer.
///
/// [bodyIntensity] affects spine/chest bones only. The body uses a dead zone
/// so small face-detector noise remains in the neck/head instead of making the
/// avatar's whole torso twitch.
Map<String, VrmTrackedBoneRotation> computeVrmUpperBodyRotations(
  VrmFaceTrackingFrame input, {
  VrmUpperBodyTrackingFrame? upperBody,
  VrmBodyFollowMode mode = VrmBodyFollowMode.natural,
  double bodyIntensity = 1,
  double bodyDeadZoneRadians = 4 * math.pi / 180,
}) {
  final frame = input.clamped();
  final confidence = frame.confidence;
  final yaw = frame.yawRadians * confidence;
  final pitch = frame.pitchRadians * confidence;
  final roll = frame.rollRadians * confidence;
  final bodyYaw = _removeDeadZone(yaw, bodyDeadZoneRadians);
  final bodyPitch = _removeDeadZone(pitch, bodyDeadZoneRadians);
  final bodyRoll = _removeDeadZone(roll, bodyDeadZoneRadians);
  final intensity = bodyIntensity.clamp(0.0, 1.5);
  final weights = mode == VrmBodyFollowMode.headOnly
      ? _headOnlyWeights
      : _naturalWeights;
  final detected = mode == VrmBodyFollowMode.headOnly
      ? null
      : upperBody?.clamped();

  return {
    for (final entry in weights.entries)
      entry.key: () {
        final isTorso = _torsoBones.contains(entry.key);
        final torsoScale = isTorso ? intensity : 1.0;
        final torsoRollDirection = isTorso && mode == VrmBodyFollowMode.anime
            ? -1.0
            : 1.0;
        final detectedWeight = _detectedBodyWeights[entry.key];
        final faceYaw = (isTorso ? bodyYaw : yaw) * entry.value.yaw;
        final facePitch = (isTorso ? bodyPitch : pitch) * entry.value.pitch;
        final faceRoll = (isTorso ? bodyRoll : roll) * entry.value.roll;
        final resolvedYaw = isTorso && detected != null
            ? _mix(
                faceYaw,
                detected.yawRadians * detectedWeight!.yaw,
                detected.yawConfidence,
              )
            : faceYaw;
        final resolvedPitch = isTorso && detected != null
            ? _mix(
                facePitch,
                detected.pitchRadians * detectedWeight!.pitch,
                detected.pitchConfidence,
              )
            : facePitch;
        final resolvedRoll = isTorso && detected != null
            ? _mix(
                faceRoll,
                detected.rollRadians * detectedWeight!.roll,
                detected.rollConfidence,
              )
            : faceRoll;
        return VrmTrackedBoneRotation(
          yawRadians: resolvedYaw * torsoScale,
          pitchRadians: resolvedPitch * torsoScale,
          rollRadians: resolvedRoll * torsoScale * torsoRollDirection,
        );
      }(),
  };
}

const _torsoBones = {'spine', 'chest', 'upperChest'};

double _removeDeadZone(double value, double deadZone) {
  final magnitude = value.abs();
  if (magnitude <= deadZone) return 0;
  return (magnitude - deadZone) * value.sign;
}

double _mix(double from, double to, double amount) =>
    from + (to - from) * amount;

/// Converts semantic arm angles into local humanoid-bone rotations.
Map<String, VrmTrackedBoneRotation> computeVrmArmRotations(
  VrmArmTrackingFrame input,
) {
  final frame = input.clamped();
  return {
    'leftShoulder': VrmTrackedBoneRotation(
      yawRadians: 0,
      pitchRadians: 0,
      rollRadians: frame.leftShoulderRollRadians,
    ),
    'rightShoulder': VrmTrackedBoneRotation(
      yawRadians: 0,
      pitchRadians: 0,
      rollRadians: frame.rightShoulderRollRadians,
    ),
    'leftLowerArm': VrmTrackedBoneRotation(
      yawRadians: 0,
      pitchRadians: 0,
      rollRadians: frame.leftElbowRollRadians,
    ),
    'rightLowerArm': VrmTrackedBoneRotation(
      yawRadians: 0,
      pitchRadians: 0,
      rollRadians: frame.rightElbowRollRadians,
    ),
  };
}

/// Maps normalized tracking values onto VRM humanoid bones and expressions.
class VrmFaceTrackingDriver {
  VrmFaceTrackingDriver(
    this.avatar, {
    this.bodyFollowMode = VrmBodyFollowMode.natural,
    this.bodyFollowIntensity = 1,
  });

  final VrmAvatar avatar;
  VrmBodyFollowMode bodyFollowMode;
  double bodyFollowIntensity;
  final Map<String, VrmTrackedBoneRotation> _smoothedTorso = {};
  final Map<String, VrmTrackedBoneRotation> _smoothedArms = {};

  Map<String, VrmTrackedBoneRotation> get smoothedTorso =>
      Map.unmodifiable(_smoothedTorso);
  Map<String, VrmTrackedBoneRotation> get smoothedArms =>
      Map.unmodifiable(_smoothedArms);

  void apply(
    VrmFaceTrackingFrame input, {
    VrmUpperBodyTrackingFrame? upperBody,
    VrmArmTrackingFrame? arms,
    double deltaSeconds = 1 / 60,
    bool smoothBody = true,
  }) {
    final frame = input.clamped();
    final confidence = frame.confidence;
    final targetRotations = computeVrmUpperBodyRotations(
      frame,
      upperBody: upperBody,
      mode: bodyFollowMode,
      bodyIntensity: bodyFollowIntensity,
    );
    final bodyAlpha = smoothBody
        ? 1 - math.exp(-4.5 * deltaSeconds.clamp(0.0, 0.1))
        : 1.0;
    for (final entry in targetRotations.entries) {
      var rotation = entry.value;
      if (_torsoBones.contains(entry.key)) {
        rotation =
            (_smoothedTorso[entry.key] ?? const VrmTrackedBoneRotation.zero())
                .lerp(rotation, bodyAlpha);
        _smoothedTorso[entry.key] = rotation;
      }
      avatar.setHumanBoneRotation(
        entry.key,
        Quaternion.euler(
          rotation.yawRadians,
          rotation.pitchRadians,
          rotation.rollRadians,
        ),
      );
    }
    if (arms != null) {
      final armAlpha = smoothBody
          ? 1 - math.exp(-7 * deltaSeconds.clamp(0.0, 0.1))
          : 1.0;
      for (final entry in computeVrmArmRotations(arms).entries) {
        final previous = _smoothedArms[entry.key];
        final rotation = previous == null
            ? entry.value
            : previous.lerp(entry.value, armAlpha);
        _smoothedArms[entry.key] = rotation;
        avatar.setHumanBoneRotation(
          entry.key,
          Quaternion.euler(
            rotation.yawRadians,
            rotation.pitchRadians,
            rotation.rollRadians,
          ),
        );
      }
    }

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
    _smoothedTorso.clear();
    _smoothedArms.clear();
    for (final bone in _torsoBones) {
      avatar.resetHumanBoneRotation(bone);
    }
    avatar.resetHumanBoneRotation('neck');
    avatar.resetHumanBoneRotation('head');
    for (final bone in const [
      'leftShoulder',
      'rightShoulder',
      'leftLowerArm',
      'rightLowerArm',
    ]) {
      avatar.resetHumanBoneRotation(bone);
    }
    final expressions = <String, double>{};
    for (final expression in const ['blinkLeft', 'blinkRight', 'blink', 'aa']) {
      if (avatar.document.expressions.containsKey(expression)) {
        expressions[expression] = 0;
      }
    }
    if (expressions.isNotEmpty) avatar.setExpressions(expressions);
  }
}
