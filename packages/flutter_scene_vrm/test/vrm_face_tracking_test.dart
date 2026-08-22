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
}
