import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_island_craft/game/frame_performance_tracker.dart';

void main() {
  test('reports rolling FPS and frame times', () {
    final tracker = FramePerformanceTracker(refreshIntervalSeconds: 0.2);

    for (var frame = 0; frame < 13; frame++) {
      tracker.recordFrame(1 / 60);
    }

    expect(tracker.framesPerSecond, closeTo(60, 0.01));
    expect(tracker.averageFrameTimeMs, closeTo(16.67, 0.01));
    expect(tracker.p95FrameTimeMs, closeTo(16.67, 0.01));
    expect(tracker.onePercentLowFps, closeTo(60, 0.01));
  });

  test('p95 exposes intermittent slow frames', () {
    final tracker = FramePerformanceTracker(refreshIntervalSeconds: 0.25);

    for (var frame = 0; frame < 18; frame++) {
      tracker.recordFrame(0.01);
    }
    tracker.recordFrame(0.04);
    tracker.recordFrame(0.05);

    expect(tracker.averageFrameTimeMs, closeTo(13.5, 0.01));
    expect(tracker.p95FrameTimeMs, closeTo(40, 0.01));
    expect(tracker.onePercentLowFps, closeTo(20, 0.01));
  });

  test('records Flutter build and raster timings independently', () {
    final tracker = FramePerformanceTracker();
    tracker.recordFlutterFrame(buildTimeMs: 3, rasterTimeMs: 8);
    tracker.recordFlutterFrame(buildTimeMs: 5, rasterTimeMs: 12);

    expect(tracker.averageBuildTimeMs, 4);
    expect(tracker.averageRasterTimeMs, 10);
    expect(tracker.p95RasterTimeMs, 12);
  });
}
