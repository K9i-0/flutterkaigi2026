import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

import 'coastal_grid.dart';
import 'island_world.dart';
import 'shore_field.dart';

/// Thin translucent ground-conforming water/wet-sand patches. 4 m diagonals
/// match the source terrain exactly, avoiding floating sheets and z-fighting.
class BeachSwash {
  BeachSwash(Scene scene, IslandWorld world, ShoreField shore, this.material) {
    final p = <double>[], n = <double>[], dist = <double>[], idx = <int>[];
    for (double tz = -1024; tz < 1024; tz += 64) {
      for (double tx = -1024; tx < 1024; tx += 64) {
        for (double z = tz; z < tz + 64; z += 4) {
          for (double x = tx; x < tx + 64; x += 4) {
            final coords = [(x, z), (x + 4, z), (x, z + 4), (x + 4, z + 4)];
            final h = coords
                .map(
                  (v) => CoastalGrid.renderedTerrainHeight(world, v.$1, v.$2),
                )
                .toList();
            if (h.every((v) => v < -.6) || h.every((v) => v > 1.8)) continue;
            final ds = coords.map((v) => shore.distance(v.$1, v.$2)).toList();
            if (ds.every((v) => v > 9) || ds.every((v) => v < -8)) continue;
            final start = p.length ~/ 3;
            for (var i = 0; i < 4; i++) {
              p.addAll([coords[i].$1, h[i] + .026, coords[i].$2]);
              final dx =
                  world.heightAt(coords[i].$1 - 1, coords[i].$2) -
                  world.heightAt(coords[i].$1 + 1, coords[i].$2);
              final dz =
                  world.heightAt(coords[i].$1, coords[i].$2 - 1) -
                  world.heightAt(coords[i].$1, coords[i].$2 + 1);
              n.addAll([dx, 2, dz]);
              dist.add(ds[i]);
            }
            idx.addAll([
              start,
              start + 2,
              start + 1,
              start + 1,
              start + 2,
              start + 3,
            ]);
          }
        }
      }
    }
    // One scene-color reader: separate coastal tiles would require repeated
    // framebuffer snapshots and introduce seams at their compositing edges.
    if (idx.isEmpty) return;
    final g = MeshGeometry.fromArrays(
      positions: Float32List.fromList(p),
      normals: Float32List.fromList(n),
      indices: idx,
    );
    g.setCustomAttribute(
      'shore_distance',
      Float32List.fromList(dist),
      components: 1,
    );
    scene.add(
      Node(name: 'Beach swash', mesh: Mesh(g, material))
        ..castsShadows = false
        ..layers = 16,
    );
    triangles += idx.length ~/ 3;
    tiles = 1;
  }
  final PreprocessedMaterial material;
  int triangles = 0, tiles = 0;
  void update(double time, double wind, double day) {
    material.parameters.setFloat('daylight', day);
    material.parameters.setFloat('time', time);
    material.parameters.setFloat('wind', wind);
  }
}
