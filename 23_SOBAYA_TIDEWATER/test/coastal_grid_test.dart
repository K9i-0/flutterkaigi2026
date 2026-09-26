import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_tidewater/coastal_grid.dart';
import 'package:sobaya_tidewater/island_world.dart';

void main() {
  // Four corners of a non-planar terrain quad, aligned to sample centres.
  final bytes = ByteData(36);
  bytes.setFloat32(4, 4, Endian.little);
  bytes.setFloat32(12, 8, Endian.little);
  bytes.setFloat32(16, 20, Endian.little);
  final world = IslandWorld({
    'heightfield': {'resolution': 3, 'origin': -2, 'texel': 4},
    'boxes': [],
    'cylinders': [],
  }, bytes);

  test('shore depth follows rendered triangle diagonal, not bilinear bed', () {
    expect(CoastalGrid.renderedTerrainHeight(world, 1, 1), 3);
    expect(CoastalGrid.renderedTerrainHeight(world, 3, 3), 13);
    expect(CoastalGrid.renderedTerrainHeight(world, 2, 2), 6);
    expect(world.heightAt(2, 2), 8);
  });

  test('coast grid has continuous upward triangles and fine bay sampling', () {
    final grid = CoastalGrid(world);
    for (var i = 1; i < grid.axis.length; i++) {
      expect(grid.axis[i], greaterThan(grid.axis[i - 1]));
      if (grid.axis[i].abs() < 140) {
        expect(grid.axis[i] - grid.axis[i - 1], 1.5);
      }
    }
    final edges = <(int, int), int>{};
    for (var i = 0; i < grid.indices.length; i += 3) {
      final tri = grid.indices.sublist(i, i + 3);
      final a = tri[0] * 3, b = tri[1] * 3, c = tri[2] * 3;
      final p = grid.positions;
      expect(
        (p[b + 2] - p[a + 2]) * (p[c] - p[a]) -
            (p[b] - p[a]) * (p[c + 2] - p[a + 2]),
        greaterThan(0),
      );
      for (var j = 0; j < 3; j++) {
        final u = tri[j], v = tri[(j + 1) % 3];
        final edge = u < v ? (u, v) : (v, u);
        edges.update(edge, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    expect(edges.values.every((n) => n == 1 || n == 2), true);
    expect(
      edges.values.where((n) => n == 1).length,
      4 * (grid.axis.length - 1),
    );
    expect(grid.bedHeights.every((h) => h.isFinite), true);
  });
}
