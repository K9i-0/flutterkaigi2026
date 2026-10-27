import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/fps_overlay.dart';

FrameTiming frame(int startUs, {int buildUs = 4000, int rasterUs = 8000}) =>
    FrameTiming(
      vsyncStart: startUs,
      buildStart: startUs,
      buildFinish: startUs + buildUs,
      rasterStart: startUs + buildUs,
      rasterFinish: startUs + buildUs + rasterUs,
      rasterFinishWallTime: startUs + buildUs + rasterUs,
    );

void main() {
  test('summarises fps, phase times and worst frame per window', () {
    final stats = FpsStats();
    // 31 frames 1/60 s apart span 0.5 s: one summary at 60 fps.
    final frames = [for (var i = 0; i < 31; i++) frame(i * 16667)];
    expect(stats.add(frames.sublist(0, 10)), false);
    frames[20] = frame(20 * 16667, rasterUs: 30000);
    expect(stats.add(frames.sublist(10)), true);
    expect(stats.fps, closeTo(60, .1));
    expect(stats.uiMs, closeTo(4, 1e-9));
    expect(stats.gpuMs, closeTo(8 + 22 / 31, 1e-6));
    expect(stats.worstMs, closeTo(34, 1e-9));
  });

  test('skipped frames lower fps', () {
    final stats = FpsStats();
    expect(stats.add([for (var i = 0; i < 17; i++) frame(i * 33333)]), true);
    expect(stats.fps, closeTo(30, .1));
  });
}
