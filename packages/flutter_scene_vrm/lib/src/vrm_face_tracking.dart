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

/// Computes local humanoid-bone rotations without depending on a renderer.
///
/// [bodyIntensity] affects spine/chest bones only. The body uses a dead zone
/// so small face-detector noise remains in the neck/head instead of making the
/// avatar's whole torso twitch.
Map<String, VrmTrackedBoneRotation> computeVrmUpperBodyRotations(
  VrmFaceTrackingFrame input, {
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

  return {
    for (final entry in weights.entries)
      entry.key: () {
        final isTorso = _torsoBones.contains(entry.key);
        final torsoScale = isTorso ? intensity : 1.0;
        final torsoRollDirection = isTorso && mode == VrmBodyFollowMode.anime
            ? -1.0
            : 1.0;
        return VrmTrackedBoneRotation(
          yawRadians: (isTorso ? bodyYaw : yaw) * entry.value.yaw * torsoScale,
          pitchRadians:
              (isTorso ? bodyPitch : pitch) * entry.value.pitch * torsoScale,
          rollRadians:
              (isTorso ? bodyRoll : roll) *
              entry.value.roll *
              torsoScale *
              torsoRollDirection,
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

  Map<String, VrmTrackedBoneRotation> get smoothedTorso =>
      Map.unmodifiable(_smoothedTorso);

  void apply(
    VrmFaceTrackingFrame input, {
    double deltaSeconds = 1 / 60,
    bool smoothBody = true,
  }) {
    final frame = input.clamped();
    final confidence = frame.confidence;
    final targetRotations = computeVrmUpperBodyRotations(
      frame,
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
    for (final bone in _torsoBones) {
      avatar.resetHumanBoneRotation(bone);
    }
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
