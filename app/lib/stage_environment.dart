import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

import 'stage_time.dart';

/// Small, static city/sky IBL. No reflection camera or per-frame scene pass.
/// The 128px cubemaps are prefiltered once and reused for every building.
Future<Map<StageTime, EnvironmentMap>> cityEnvironments() async {
  final maps = <StageTime, EnvironmentMap>{};
  final previousSize = EnvironmentMap.radianceCubeSize;
  EnvironmentMap.radianceCubeSize = 128;
  try {
    for (final time in StageTime.values) {
      const w = 256, h = 128;
      final pixels = Float32List(w * h * 4);
      final night = time == StageTime.night;
      for (var y = 0; y < h; y++) {
        final elevation = math.cos(math.pi * (y + .5) / h);
        for (var x = 0; x < w; x++) {
          final a = x / w * math.pi * 2;
          final skyline =
              -.12 + .10 * math.sin(a * 13) + .07 * math.cos(a * 23);
          final sky = elevation > skyline;
          final cloud =
              math.pow(math.max(0, math.sin(a * 3 + elevation * 6)), 8) * .25;
          final up = elevation.clamp(0.0, 1.0);
          final window = !sky && elevation > -.6 && x % 5 < 2 && y % 4 == 0;
          final c = sky
              ? (night
                    ? (.06, .09, .16)
                    : (
                        .52 - .32 * up + cloud,
                        .70 - .32 * up + cloud,
                        .98 - .30 * up + cloud,
                      ))
              : (night
                    ? (window ? (.9, .49, .16) : (.03, .04, .065))
                    : (.16, .20, .25));
          final i = (y * w + x) * 4;
          pixels[i] = c.$1;
          pixels[i + 1] = c.$2;
          pixels[i + 2] = c.$3;
          pixels[i + 3] = 1;
        }
      }
      maps[time] = await EnvironmentMap.fromEquirectHdr(
        linearPixels: pixels,
        width: w,
        height: h,
      );
    }
  } finally {
    EnvironmentMap.radianceCubeSize = previousSize;
  }
  return maps;
}
