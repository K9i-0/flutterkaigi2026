import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'island_game.dart';

/// Opt-in, fixed-camera profile sample. FrameTiming is CPU-side UI/raster
/// work, not GPU execution time or presented FPS. Warm up shader/cache work.
class WaterBenchmark {
  WaterBenchmark(this.game, this.isActive) {
    SchedulerBinding.instance.addTimingsCallback(_timings);
  }

  final IslandGame game;
  final bool Function() isActive;
  final frames = <FrameTiming>[];
  int warmup = 0;
  bool done = false;

  void _timings(List<FrameTiming> batch) {
    if (done) return;
    if (!isActive()) {
      warmup = 0;
      frames.clear();
      return;
    }
    for (final frame in batch) {
      if (warmup++ < 120) continue;
      frames.add(frame);
      if (frames.length == 360) {
        done = true;
        final view = PlatformDispatcher.instance.views.first;
        Map<String, double> stats(Duration Function(FrameTiming) pick) {
          final values =
              frames.map((f) => pick(f).inMicroseconds / 1000).toList()..sort();
          return {'p50': values[179], 'p95': values[341], 'max': values.last};
        }

        debugPrint(
          'WATER_BENCHMARK ${jsonEncode({
            'profile': kProfileMode,
            'water': IslandGame.legacyWater ? 'legacy-material-same-grid' : 'coastal-v2',
            'reflection': game.reflector?.enabled ?? false,
            'scenario': const String.fromEnvironment('WATER_SCENARIO', defaultValue: 'overview'),
            'frames': frames.length,
            'warmupFrames': 120,
            'physicalSize': [view.physicalSize.width, view.physicalSize.height],
            'dpr': view.devicePixelRatio,
            'renderScale': game.scene.renderScale,
            'buildMs': stats((f) => f.buildDuration),
            'rasterMs': stats((f) => f.rasterDuration),
          })}',
        );
        dispose();
        return;
      }
    }
  }

  void dispose() => SchedulerBinding.instance.removeTimingsCallback(_timings);
}
