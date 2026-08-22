import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_vrm_lab/tracking/face_tracking_signal.dart';

void main() {
  test(
    'maps camera Euler angles, eyes and mouth into a smoothed VRM frame',
    () {
      final pipeline = FaceTrackingPipeline();
      final frame = pipeline.ingest(
        const FaceTrackingSignal(
          yawDegrees: 30,
          pitchDegrees: 10,
          rollDegrees: -15,
          leftEyeOpen: 0.2,
          rightEyeOpen: 0.75,
          mouthOpen: 0.6,
        ),
        deltaSeconds: 0.1,
      );

      expect(frame.yawRadians, lessThan(0));
      expect(frame.pitchRadians, greaterThan(0));
      expect(frame.rollRadians, greaterThan(0));
      expect(frame.yawRadians.abs(), lessThanOrEqualTo(math.pi / 3));
      expect(frame.blinkLeft, closeTo(0.8 * (1 - math.exp(-1.2)), 0.001));
      expect(frame.blinkRight, lessThan(frame.blinkLeft));
      expect(frame.mouthOpen, greaterThan(0));
    },
  );

  test('calibration treats the latest head pose as neutral', () {
    final pipeline = FaceTrackingPipeline();
    const signal = FaceTrackingSignal(
      yawDegrees: 18,
      pitchDegrees: -7,
      rollDegrees: 4,
      leftEyeOpen: 1,
      rightEyeOpen: 1,
      mouthOpen: 0,
    );
    final before = pipeline.ingest(signal, deltaSeconds: 0.1);
    pipeline.calibrate();
    final after = pipeline.ingest(signal, deltaSeconds: 0.1);

    expect(after.yawRadians.abs(), lessThan(before.yawRadians.abs()));
    expect(after.pitchRadians.abs(), lessThan(before.pitchRadians.abs()));
    expect(after.rollRadians.abs(), lessThan(before.rollRadians.abs()));
  });

  test('deterministic input can bypass smoothing for MCP assertions', () {
    final pipeline = FaceTrackingPipeline();
    final frame = pipeline.ingest(
      const FaceTrackingSignal(
        yawDegrees: 30,
        pitchDegrees: -12,
        rollDegrees: 8,
        leftEyeOpen: 0.2,
        rightEyeOpen: 0.7,
        mouthOpen: 0.65,
      ),
      deltaSeconds: 1 / 60,
      smooth: false,
    );

    expect(frame.yawRadians, closeTo(-30 * math.pi / 180, 0.0001));
    expect(frame.pitchRadians, closeTo(-12 * math.pi / 180, 0.0001));
    expect(frame.rollRadians, closeTo(-8 * math.pi / 180, 0.0001));
    expect(frame.blinkLeft, closeTo(0.8, 0.0001));
    expect(frame.blinkRight, closeTo(0.3, 0.0001));
    expect(frame.mouthOpen, 0.65);
  });
}
