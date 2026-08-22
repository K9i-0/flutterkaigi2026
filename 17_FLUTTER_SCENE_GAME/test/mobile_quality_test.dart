import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_island_craft/game/mobile_quality.dart';

void main() {
  test('mobile profiles trade effects for GPU cost', () {
    expect(
      MobileQualityProfile.performance.renderScale,
      lessThan(MobileQualityProfile.balanced.renderScale),
    );
    expect(
      MobileQualityProfile.balanced.shadowResolution,
      lessThan(MobileQualityProfile.quality.shadowResolution),
    );
    expect(MobileQualityProfile.performance.screenSpaceReflections, isFalse);
    expect(MobileQualityProfile.quality.screenSpaceReflections, isTrue);
  });

  test('auto quality drops quickly and raises only after healthy windows', () {
    final auto = AutoQualityController(evaluationIntervalSeconds: 1);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 38, p95FrameTimeMs: 27),
      isTrue,
    );
    expect(auto.renderScale, 0.67);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 60, p95FrameTimeMs: 16),
      isFalse,
    );
    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 60, p95FrameTimeMs: 16),
      isTrue,
    );
    expect(auto.renderScale, 0.82);
  });
}
