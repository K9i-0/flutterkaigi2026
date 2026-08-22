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
    expect(MobileQualityProfile.adaptiveVisual.bloom, isTrue);
    expect(MobileQualityProfile.adaptivePerformance.bloom, isFalse);
    expect(MobileQualityProfile.adaptiveVisual.ambientOcclusion, isTrue);
    expect(MobileQualityProfile.adaptivePerformance.ambientOcclusion, isFalse);
    expect(MobileQualityProfile.adaptivePerformance.contactShadows, isFalse);
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

  test('auto quality escalates to a visual-preserving mobile fallback', () {
    final auto = AutoQualityController(evaluationIntervalSeconds: 1);

    for (var window = 0; window < 3; window++) {
      expect(
        auto.update(deltaSeconds: 1, framesPerSecond: 30, p95FrameTimeMs: 34),
        isTrue,
      );
    }

    expect(auto.pressureLevel, 3);
    expect(auto.renderScale, 0.58);
  });
}
