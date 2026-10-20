import 'dart:math' as math;
import 'dart:ui' show FramePhase, FrameTiming;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Rolling frame statistics from the engine's [FrameTiming] reports.
///
/// fps counts presented frames between vsync starts, so it drops below the
/// display rate when frames are skipped. UI is the build phase and GPU the
/// raster phase; worst is the slowest whole frame in the window.
class FpsStats {
  FpsStats({this.window = const Duration(milliseconds: 500)});
  final Duration window;
  final _frames = <FrameTiming>[];
  double fps = 0, uiMs = 0, gpuMs = 0, worstMs = 0;

  /// Returns true when a new summary was produced.
  bool add(List<FrameTiming> timings) {
    _frames.addAll(timings);
    if (_frames.length < 2) return false;
    int vsync(FrameTiming t) =>
        t.timestampInMicroseconds(FramePhase.vsyncStart);
    final span = vsync(_frames.last) - vsync(_frames.first);
    if (span < window.inMicroseconds) return false;
    double ms(Duration d) => d.inMicroseconds / 1000;
    fps = (_frames.length - 1) * 1e6 / span;
    uiMs =
        _frames.map((t) => ms(t.buildDuration)).reduce((a, b) => a + b) /
        _frames.length;
    gpuMs =
        _frames.map((t) => ms(t.rasterDuration)).reduce((a, b) => a + b) /
        _frames.length;
    worstMs = _frames.map((t) => ms(t.totalSpan)).reduce(math.max);
    _frames.clear();
    return true;
  }

  Map<String, Object> toMap() => {
    'fps': fps,
    'uiMs': uiMs,
    'gpuMs': gpuMs,
    'worstMs': worstMs,
  };
}

/// Debug HUD showing [FpsStats]; only frames drawn while mounted count.
class FpsOverlay extends StatefulWidget {
  const FpsOverlay({super.key, this.onStats});
  final ValueChanged<FpsStats>? onStats;
  @override
  State<FpsOverlay> createState() => _FpsOverlayState();
}

class _FpsOverlayState extends State<FpsOverlay> {
  final stats = FpsStats();

  void _onTimings(List<FrameTiming> timings) {
    if (!stats.add(timings) || !mounted) return;
    setState(() {});
    widget.onStats?.call(stats);
  }

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_onTimings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = stats.fps >= 55
        ? const Color(0xff8ef0a8)
        : stats.fps >= 30
        ? const Color(0xfff4d36b)
        : const Color(0xffff8a7a);
    return IgnorePointer(
      child: Container(
        key: const ValueKey('fps_overlay'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: .62),
          borderRadius: BorderRadius.circular(6),
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${stats.fps.toStringAsFixed(1)} fps',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                'UI ${stats.uiMs.toStringAsFixed(1)} / '
                'GPU ${stats.gpuMs.toStringAsFixed(1)} ms',
              ),
              Text('worst ${stats.worstMs.toStringAsFixed(1)} ms'),
              if (kDebugMode)
                const Text(
                  'debugビルド（目安。計測はprofileで）',
                  style: TextStyle(fontSize: 9, color: Color(0xffcccccc)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
