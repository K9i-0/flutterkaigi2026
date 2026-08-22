import 'dart:math' as math;

import 'package:flutter_scene_vrm/flutter_scene_vrm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('tracking frame clamps pose and expression ranges', () {
    const frame = VrmFaceTrackingFrame(
      yawRadians: 20,
      pitchRadians: -20,
      rollRadians: 20,
      blinkLeft: -1,
      blinkRight: 3,
      mouthOpen: 2,
      confidence: 4,
    );

    final clamped = frame.clamped();
    expect(clamped.yawRadians, math.pi / 3);
    expect(clamped.pitchRadians, -math.pi / 4);
    expect(clamped.rollRadians, math.pi / 3);
    expect(clamped.blinkLeft, 0);
    expect(clamped.blinkRight, 1);
    expect(clamped.mouthOpen, 1);
    expect(clamped.confidence, 1);
  });

  test('natural follow distributes rotation across the upper body', () {
    const frame = VrmFaceTrackingFrame(
      yawRadians: 0.5,
      pitchRadians: 0.4,
      rollRadians: 0.3,
      blinkLeft: 0,
      blinkRight: 0,
      mouthOpen: 0,
    );

    final rotations = computeVrmUpperBodyRotations(
      frame,
      bodyDeadZoneRadians: 0,
    );

    expect(rotations.keys, containsAll(['spine', 'chest', 'upperChest']));
    expect(rotations['head']!.yawRadians, closeTo(0.25, 1e-9));
    expect(rotations['neck']!.pitchRadians, closeTo(0.084, 1e-9));
    expect(rotations['upperChest']!.rollRadians, closeTo(0.024, 1e-9));
    expect(
      rotations.values.fold<double>(
        0,
        (sum, rotation) => sum + rotation.yawRadians,
      ),
      closeTo(0.5, 1e-9),
    );
  });

  test('anime follow reverses torso roll but keeps head roll direction', () {
    const frame = VrmFaceTrackingFrame(
      yawRadians: 0,
      pitchRadians: 0,
      rollRadians: 0.5,
      blinkLeft: 0,
      blinkRight: 0,
      mouthOpen: 0,
    );

    final rotations = computeVrmUpperBodyRotations(
      frame,
      mode: VrmBodyFollowMode.anime,
      bodyDeadZoneRadians: 0,
    );

    expect(rotations['spine']!.rollRadians, lessThan(0));
    expect(rotations['upperChest']!.rollRadians, lessThan(0));
    expect(rotations['neck']!.rollRadians, greaterThan(0));
    expect(rotations['head']!.rollRadians, greaterThan(0));
  });

  test('head-only mode preserves the original neck and head split', () {
    const frame = VrmFaceTrackingFrame(
      yawRadians: 0.4,
      pitchRadians: 0.2,
      rollRadians: -0.1,
      blinkLeft: 0,
      blinkRight: 0,
      mouthOpen: 0,
    );

    final rotations = computeVrmUpperBodyRotations(
      frame,
      mode: VrmBodyFollowMode.headOnly,
      bodyDeadZoneRadians: 0,
    );

    expect(rotations['spine']!.yawRadians, 0);
    expect(rotations['chest']!.pitchRadians, 0);
    expect(rotations['upperChest']!.rollRadians, 0);
    expect(rotations['neck']!.yawRadians, closeTo(0.1, 1e-9));
    expect(rotations['head']!.yawRadians, closeTo(0.3, 1e-9));
  });

  test('body intensity and dead zone do not reduce neck and head motion', () {
    const frame = VrmFaceTrackingFrame(
      yawRadians: 0.05,
      pitchRadians: 0,
      rollRadians: 0,
      blinkLeft: 0,
      blinkRight: 0,
      mouthOpen: 0,
    );

    final rotations = computeVrmUpperBodyRotations(frame, bodyIntensity: 0);

    expect(rotations['spine']!.yawRadians, 0);
    expect(rotations['chest']!.yawRadians, 0);
    expect(rotations['head']!.yawRadians, closeTo(0.025, 1e-9));
    expect(rotations['neck']!.yawRadians, closeTo(0.01, 1e-9));
  });

  test('tracked torso rotation can follow its target more slowly', () {
    const current = VrmTrackedBoneRotation.zero();
    const target = VrmTrackedBoneRotation(
      yawRadians: 0.4,
      pitchRadians: -0.2,
      rollRadians: 0.1,
    );

    final halfway = current.lerp(target, 0.5);

    expect(halfway.yawRadians, closeTo(0.2, 1e-9));
    expect(halfway.pitchRadians, closeTo(-0.1, 1e-9));
    expect(halfway.rollRadians, closeTo(0.05, 1e-9));
  });
}
