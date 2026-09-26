import 'dart:math' as math;

import 'island_world.dart';

/// Precomputed coastline; audio searches it at 10 Hz, never per audio sample.
class CoastalAudioMix {
  CoastalAudioMix(IslandWorld world) {
    // Scan both axes: a shoreline parallel to rows has no nearby horizontal
    // crossing. Using only rows misses the middle of the bay's south beach.
    for (final vertical in [false, true]) {
      for (var v = -1008.0; v <= 1008; v += 8) {
        double height(double u) =>
            vertical ? world.heightAt(v, u) : world.heightAt(u, v);
        var previous = height(-1008);
        for (var u = -1000.0; u <= 1008; u += 8) {
          final h = height(u);
          if ((h >= 0) != (previous >= 0)) {
            final crossing = u - 8 + 8 * previous / (previous - h);
            coast.add(vertical ? (v, crossing) : (crossing, v));
          }
          previous = h;
        }
      }
    }
  }
  final coast = <(double, double)>[];

  ({double distance, double pan, double pier, double inland}) at(
    double x,
    double y,
    double z,
    double yaw,
  ) {
    var best = double.infinity, sx = x, sz = z;
    for (final p in coast) {
      final d = (x - p.$1) * (x - p.$1) + (z - p.$2) * (z - p.$2);
      if (d < best) {
        best = d;
        sx = p.$1;
        sz = p.$2;
      }
    }
    final distance = math.sqrt(best + y * y);
    final horizontal = math.max(1.0, math.sqrt(best));
    final pan =
        ((-(sx - x) * math.cos(yaw) + (sz - z) * math.sin(yaw)) / horizontal)
            .clamp(-.8, .8);
    final pierDistance = math.sqrt(
      (x - 53.6) * (x - 53.6) +
          (z - z.clamp(-40.0, 40.0)) * (z - z.clamp(-40.0, 40.0)) +
          y * y,
    );
    return (
      distance: distance,
      pan: pan,
      pier: math.exp(-pierDistance / 12),
      inland: (z < -65 ? (distance / 50).clamp(0.0, 1.0) : 0.0),
    );
  }

  static double gain(double targetLufs, double sourceLufs) => math
      .pow(10, (targetLufs - sourceLufs - 3) / 20)
      .toDouble()
      .clamp(0.0, 1.0);
  static double surfWeight(double distance) =>
      1 / (1 + math.pow(distance / 20, 1.5));
  // Same 1.05 rad/s clock as the coastal foam; a staged surf envelope,
  // not a full port of Tidewater's per-station shallow-water simulation.
  static int waveCycle(double seconds) =>
      ((seconds * 1.05 - math.pi / 2) / (2 * math.pi)).floor();
}
