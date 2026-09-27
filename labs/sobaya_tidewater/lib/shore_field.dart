import 'dart:math' as math;

import 'coastal_grid.dart';
import 'island_world.dart';

/// Zero-height contour of the actual exported terrain triangles. Nearby
/// segments are indexed spatially; no all-coast search per water vertex.
class ShoreField {
  ShoreField(this.world, {this.extent = 1024}) {
    for (double z = -extent; z < extent; z += 4) {
      for (double x = -extent; x < extent; x += 4) {
        final a = (x, z, world.heightAt(x, z)),
            b = (x + 4, z, world.heightAt(x + 4, z));
        final c = (x, z + 4, world.heightAt(x, z + 4)),
            d = (x + 4, z + 4, world.heightAt(x + 4, z + 4));
        _triangle(a, b, c);
        _triangle(b, d, c);
      }
    }
  }
  final IslandWorld world;
  final double extent;
  final _buckets = <(int, int), List<(double, double, double, double)>>{};
  int segments = 0;
  void _triangle(
    (double, double, double) a,
    (double, double, double) b,
    (double, double, double) c,
  ) {
    final hits = <(double, double)>[];
    for (final e in [(a, b), (b, c), (c, a)]) {
      final p = e.$1, q = e.$2;
      if ((p.$3 > 0) == (q.$3 > 0)) continue;
      final t = p.$3 / (p.$3 - q.$3);
      hits.add((p.$1 + (q.$1 - p.$1) * t, p.$2 + (q.$2 - p.$2) * t));
    }
    if (hits.length != 2) return;
    final a0 = hits[0], b0 = hits[1];
    final segment = (a0.$1, a0.$2, b0.$1, b0.$2);
    // Insert by midpoint; segments are at most sqrt(32) metres long.
    final key = (
      ((a0.$1 + b0.$1) / 32).floor(),
      ((a0.$2 + b0.$2) / 32).floor(),
    );
    (_buckets[key] ??= []).add(segment);
    segments++;
  }

  /// Positive on land, negative at sea, capped at 40 m away from the coast.
  double distance(double x, double z) {
    final ix = (x / 16).floor(), iz = (z / 16).floor();
    var best = 1600.0;
    for (var j = -3; j <= 3; j++) {
      for (var i = -3; i <= 3; i++) {
        for (final s
            in _buckets[(ix + i, iz + j)] ??
                const <(double, double, double, double)>[]) {
          final dx = s.$3 - s.$1, dz = s.$4 - s.$2, len = dx * dx + dz * dz;
          final t = len < 1e-12
              ? 0.0
              : ((x - s.$1) * dx + (z - s.$2) * dz) / len;
          final q = t.clamp(0.0, 1.0),
              ex = x - s.$1 - dx * q,
              ez = z - s.$2 - dz * q;
          best = math.min(best, ex * ex + ez * ez);
        }
      }
    }
    return math.sqrt(best) *
        (CoastalGrid.renderedTerrainHeight(world, x, z) > 0 ? 1 : -1);
  }
}
