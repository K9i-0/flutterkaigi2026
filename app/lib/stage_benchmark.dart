import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// CPU UI/raster timings and vsync cadence, not GPU duration or presented FPS.
/// Explicitly started by automation; idle outside a bounded sample window.
class StageBenchmark {
  StageBenchmark() {
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }
  final _frames = <FrameTiming>[];
  int _warmup = 0;
  bool active = false;
  Map<String, Object?> metadata = {};
  Map<String, Object?>? result;
  void start(Map<String, Object?> data) {
    metadata = data;
    _frames.clear();
    _warmup = 0;
    result = null;
    active = true;
  }

  void _onTimings(List<FrameTiming> batch) {
    if (!active) return;
    for (final f in batch) {
      if (_warmup++ < 120) continue;
      _frames.add(f);
      if (_frames.length < 360) continue;
      Map<String, double> stats(Duration Function(FrameTiming) pick) {
        final v = _frames.map((f) => pick(f).inMicroseconds / 1000).toList()
          ..sort();
        return {'p50': v[179], 'p95': v[341], 'max': v.last};
      }

      final view = PlatformDispatcher.instance.views.first;
      final starts = _frames
          .map((f) => f.timestampInMicroseconds(FramePhase.vsyncStart))
          .toList();
      final intervals = [
        for (var i = 1; i < starts.length; i++)
          (starts[i] - starts[i - 1]) / 1000,
      ]..sort();
      result = {
        ...metadata,
        'mode': kProfileMode
            ? 'profile'
            : kDebugMode
            ? 'debug'
            : 'release',
        'frames': _frames.length,
        'warmupFrames': 120,
        'physicalSize': [view.physicalSize.width, view.physicalSize.height],
        'buildMs': stats((f) => f.buildDuration),
        'rasterMs': stats((f) => f.rasterDuration),
        'submittedFps':
            1000000 * (starts.length - 1) / (starts.last - starts.first),
        'frameIntervalMs': {
          'p50': intervals[intervals.length ~/ 2],
          'p95': intervals[(intervals.length * .95).floor()],
          'over20ms': intervals.where((t) => t > 20).length,
        },
      };
      active = false;
      debugPrint('STAGE_BENCHMARK ${jsonEncode(result)}');
      break;
    }
  }

  Map<String, Object?> inspect() => {
    'active': active,
    'samples': _frames.length,
    'result': result,
  };
  void dispose() => SchedulerBinding.instance.removeTimingsCallback(_onTimings);
}
