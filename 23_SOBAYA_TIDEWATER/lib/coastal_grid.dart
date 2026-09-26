import 'dart:math' as math;
import 'dart:typed_data';

import 'island_world.dart';

/// Fixed, continuous grid: 1.5 m cells around the bay, logarithmic far spacing.
/// No overlapping rings or per-frame CPU remeshing. The fragment stage supplies
/// sub-metre waves. Heights match the exported 4 m terrain triangles.
class CoastalGrid {
  CoastalGrid(IslandWorld world) {
    const innerSteps = 96, outerSteps = 32, innerRadius = 144.0;
    const farRadius = 1800.0;
    final half = <double>[
      for (var i = 0; i <= innerSteps; i++) i * innerRadius / innerSteps,
      for (var i = 1; i <= outerSteps; i++)
        innerRadius * math.pow(farRadius / innerRadius, i / outerSteps),
    ];
    axis = [...half.skip(1).toList().reversed.map((x) => -x), ...half];
    final count = axis.length * axis.length;
    positions = Float32List(count * 3);
    normals = Float32List(count * 3);
    bedHeights = Float32List(count);
    for (var z = 0; z < axis.length; z++) {
      for (var x = 0; x < axis.length; x++) {
        final i = z * axis.length + x;
        final wx = axis[x] + 40, wz = axis[z] - 20;
        positions[i * 3] = wx;
        positions[i * 3 + 2] = wz;
        normals[i * 3 + 1] = 1;
        bedHeights[i] = renderedTerrainHeight(world, wx, wz);
      }
    }
    indices = <int>[];
    for (var z = 0; z < axis.length - 1; z++) {
      for (var x = 0; x < axis.length - 1; x++) {
        final i = z * axis.length + x, j = i + axis.length;
        indices.addAll([i, j, i + 1, i + 1, j, j + 1]);
      }
    }
  }
  late final List<double> axis;
  late final Float32List positions, normals, bedHeights;
  late final List<int> indices;

  static double renderedTerrainHeight(IslandWorld world, double x, double z) {
    const step = 4.0;
    final x0 = (x / step).floor() * step;
    final z0 = (z / step).floor() * step;
    final fx = (x - x0) / step, fz = (z - z0) / step;
    final a = world.heightAt(x0, z0);
    final b = world.heightAt(x0 + step, z0);
    final c = world.heightAt(x0, z0 + step);
    final d = world.heightAt(x0 + step, z0 + step);
    if (fx + fz <= 1) return a + (b - a) * fx + (c - a) * fz;
    return d + (c - d) * (1 - fx) + (b - d) * (1 - fz);
  }
}
