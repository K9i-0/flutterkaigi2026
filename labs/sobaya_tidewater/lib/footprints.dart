import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

import 'coastal_grid.dart';
import 'island_world.dart';

/// Ground-conforming translucent sole meshes. Bounded count and lifetime.
class Footprints {
  Footprints(this.scene, this.world, this.material);
  final Scene scene;
  final IslandWorld world;
  final PreprocessedMaterial material;
  final marks = <(Node, double)>[];
  void update(double time) {
    material.parameters.setFloat('time', time);
    while (marks.isNotEmpty && time - marks.first.$2 >= 18) {
      scene.remove(marks.removeAt(0).$1);
    }
  }

  void add(double x, double z, double yaw, double time, bool left) {
    const nx = 4, nz = 8;
    final p = <double>[], n = <double>[], uv = <double>[], indices = <int>[];
    final rightX = -math.cos(yaw), rightZ = math.sin(yaw);
    final forwardX = -math.sin(yaw), forwardZ = -math.cos(yaw);
    x += rightX * (left ? -.10 : .10);
    z += rightZ * (left ? -.10 : .10);
    for (var iz = 0; iz <= nz; iz++) {
      for (var ix = 0; ix <= nx; ix++) {
        final u = ix / nx, v = iz / nz;
        final wx = x + rightX * (u - .5) * .18 + forwardX * (v - .5) * .31;
        final wz = z + rightZ * (u - .5) * .18 + forwardZ * (v - .5) * .31;
        p.addAll([
          wx,
          CoastalGrid.renderedTerrainHeight(world, wx, wz) + .012,
          wz,
        ]);
        n.addAll([0, 1, 0]);
        uv.addAll([u, v]);
      }
    }
    for (var iz = 0; iz < nz; iz++) {
      for (var ix = 0; ix < nx; ix++) {
        final a = iz * (nx + 1) + ix, b = a + nx + 1;
        indices.addAll([a, b, a + 1, a + 1, b, b + 1]);
      }
    }
    final geometry = MeshGeometry.fromArrays(
      positions: Float32List.fromList(p),
      normals: Float32List.fromList(n),
      texCoords: Float32List.fromList(uv),
      indices: indices,
    );
    geometry.setCustomAttribute(
      'birth',
      Float32List(p.length ~/ 3)..fillRange(0, p.length ~/ 3, time),
      components: 1,
    );
    final node = Node(name: 'Sand footprint', mesh: Mesh(geometry, material))
      ..castsShadows = false
      ..layers = 4;
    scene.add(node);
    marks.add((node, time));
    if (marks.length > 48) scene.remove(marks.removeAt(0).$1);
  }

  void clear() {
    for (final m in marks) {
      scene.remove(m.$1);
    }
    marks.clear();
  }
}
