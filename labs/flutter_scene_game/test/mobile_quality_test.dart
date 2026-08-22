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
    expect(MobileQualityProfile.adaptiveWorld.renderScale, 1);
    expect(MobileQualityProfile.adaptiveVisual.renderScale, 0.88);
    expect(MobileQualityProfile.adaptiveVisual.bloom, isTrue);
    expect(MobileQualityProfile.adaptivePerformance.bloom, isFalse);
    expect(MobileQualityProfile.adaptiveWorld.ambientOcclusion, isTrue);
    expect(MobileQualityProfile.adaptiveVisual.ambientOcclusion, isFalse);
    expect(MobileQualityProfile.adaptivePerformance.ambientOcclusion, isFalse);
    expect(MobileQualityProfile.adaptivePerformance.contactShadows, isFalse);
    expect(
      MobileQualityProfile.adaptiveEmergency.renderScale,
      lessThan(MobileQualityProfile.adaptivePerformance.renderScale),
    );
    expect(
      MobileQualityProfile.adaptiveWorld.usesFullResourceDetail(100),
      isTrue,
    );
    expect(
      MobileQualityProfile.adaptiveWorld.usesFullResourceDetail(100.1),
      isFalse,
    );
  });

  test('auto quality drops quickly and raises only after healthy windows', () {
    final auto = AutoQualityController(evaluationIntervalSeconds: 1);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 38, p95FrameTimeMs: 27),
      isTrue,
    );
    expect(auto.pressureLevel, 1);
    expect(auto.renderScale, 1);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 60, p95FrameTimeMs: 16),
      isFalse,
    );
    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 60, p95FrameTimeMs: 16),
      isTrue,
    );
    expect(auto.pressureLevel, 0);
    expect(auto.renderScale, 1);
  });

  test('auto quality lowers resolution only after world and effect LOD', () {
    final auto = AutoQualityController(evaluationIntervalSeconds: 1);

    for (var window = 0; window < 2; window++) {
      expect(
        auto.update(deltaSeconds: 1, framesPerSecond: 50, p95FrameTimeMs: 24),
        isTrue,
      );
    }
    expect(auto.pressureLevel, 2);
    expect(auto.renderScale, 0.88);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 50, p95FrameTimeMs: 24),
      isTrue,
    );
    expect(auto.pressureLevel, 3);
    expect(auto.renderScale, 0.72);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 50, p95FrameTimeMs: 24),
      isTrue,
    );
    expect(auto.pressureLevel, 4);
    expect(auto.renderScale, 0.58);
  });

  test('severe frame pressure skips a fidelity tier', () {
    final auto = AutoQualityController(evaluationIntervalSeconds: 1);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 30, p95FrameTimeMs: 34),
      isTrue,
    );
    expect(auto.pressureLevel, 2);
    expect(auto.renderScale, 0.88);

    expect(
      auto.update(deltaSeconds: 1, framesPerSecond: 30, p95FrameTimeMs: 34),
      isTrue,
    );
    expect(auto.pressureLevel, 4);
    expect(auto.renderScale, 0.58);
  });
}
