import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'island_world.dart';

/// One instanceless quad batch, animated on the GPU and clipped at sampled roofs.
class IslandRain {
  IslandRain(this.scene, this.world, this.material) {
    node = Node(name: 'Local rainfall')
      ..castsShadows = false
      ..layers = 8;
    scene.add(node);
  }
  final Scene scene;
  final IslandWorld world;
  final PreprocessedMaterial material;
  late final Node node;
  final _floors = <(int, int), double>{};
  (int, int, int)? _cell;
  int count = 0;
  void update(
    vm.Vector3 eye,
    double yaw,
    double time,
    double amount,
    double wind,
    double day,
    bool high,
  ) {
    node.visible = amount > .001 || time == 0;
    if (!node.visible) return;
    final p = material.parameters;
    p.setFloat('time', time);
    p.setFloat('rain', amount);
    p.setFloat('wind', wind);
    p.setFloat('eye_y', eye.y);
    p.setFloat('brightness', .22 + day * .78);
    p.setVec3('right', vm.Vector3(-math.cos(yaw), 0, math.sin(yaw)));
    final cell = (
      (eye.x / 2).floor(),
      (eye.z / 2).floor(),
      (eye.y / 8).floor(),
    );
    final wanted = high ? 22 : 16;
    if (_cell == cell && count == wanted * wanted) return;
    _cell = cell;
    count = wanted * wanted;
    if (_floors.length > 4096) _floors.clear();
    final pos = <double>[],
        norm = <double>[],
        uv = <double>[],
        floor = <double>[],
        idx = <int>[];
    for (var i = -wanted ~/ 2; i < wanted ~/ 2; i++) {
      for (var j = -wanted ~/ 2; j < wanted ~/ 2; j++) {
        final x = cell.$1 + i, z = cell.$2 + j;
        final rng = math.Random((x * 73856093) ^ (z * 19349663));
        final wx = x * 2 + rng.nextDouble() * 1.8,
            wz = z * 2 + rng.nextDouble() * 1.8;
        final h = _floors.putIfAbsent((
          x,
          z,
        ), () => math.max(0, world.supportAt(wx, wz, 10000)));
        final seed = rng.nextDouble();
        final n = pos.length ~/ 3;
        for (final v in const [
          (0.0, 0.0),
          (1.0, 0.0),
          (1.0, 1.0),
          (0.0, 1.0),
        ]) {
          pos.addAll([wx, seed, wz]);
          norm.addAll([0, 0, 1]);
          uv.addAll([v.$1, v.$2]);
          floor.add(h);
        }
        idx.addAll([n, n + 1, n + 2, n, n + 2, n + 3]);
      }
    }
    final geometry = MeshGeometry.fromArrays(
      positions: Float32List.fromList(pos),
      normals: Float32List.fromList(norm),
      texCoords: Float32List.fromList(uv),
      indices: Uint16List.fromList(idx),
      bounds: vm.Aabb3.minMax(
        vm.Vector3(eye.x - 30, eye.y - 24, eye.z - 30),
        vm.Vector3(eye.x + 30, eye.y + 24, eye.z + 30),
      ),
    );
    geometry.setCustomAttribute(
      'floor_height',
      Float32List.fromList(floor),
      components: 1,
    );
    node.mesh = Mesh(geometry, material);
  }
}
