import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'coastal_grid.dart';
import 'island_world.dart';
import 'nature_layout.dart';

class _Batch {
  final p = <double>[],
      n = <double>[],
      c = <double>[],
      flex = <double>[],
      idx = <int>[];
  void triangle(
    vm.Vector3 a,
    vm.Vector3 b,
    vm.Vector3 d,
    vm.Vector3 color,
    double fa,
    double fb,
    double fd,
  ) {
    final normal = (b - a).cross(d - a)..normalize();
    final i = p.length ~/ 3;
    for (final v in [a, b, d]) {
      p.addAll([v.x, v.y, v.z]);
      n.addAll([normal.x, normal.y, normal.z]);
      c.addAll([color.x, color.y, color.z, 1]);
    }
    flex.addAll([fa, fb, fd]);
    idx.addAll([i, i + 1, i + 2]);
  }

  void twig(vm.Vector3 a, vm.Vector3 b, double radius, vm.Vector3 color) {
    final axis = (b - a)..normalize();
    final u = axis.cross(vm.Vector3(0, 0, 1))..normalize();
    final v = axis.cross(u)..normalize();
    for (var j = 0; j < 6; j++) {
      vm.Vector3 ring(int k, double r) =>
          u * (math.cos(k * math.pi / 3) * r) +
          v * (math.sin(k * math.pi / 3) * r);
      final x = a + ring(j, radius),
          y = a + ring(j + 1, radius),
          z = b + ring(j, radius * .55),
          w = b + ring(j + 1, radius * .55);
      triangle(x, y, z, color, 0, 0, 0);
      triangle(y, w, z, color, 0, 0, 0);
    }
  }

  void leaf(
    vm.Vector3 center,
    double size,
    double angle,
    vm.Vector3 color,
    double bend,
  ) {
    final u =
        vm.Vector3(
          math.cos(angle),
          math.sin(angle * 1.7) * .7,
          math.sin(angle),
        ) *
        size;
    final v =
        vm.Vector3(
          -math.sin(angle) * .42,
          math.cos(angle * .9) * .65,
          math.cos(angle) * .42,
        ) *
        size;
    final a = center - u,
        b = center + u,
        m = center + vm.Vector3(0, size * .08, 0);
    triangle(a, center + v, m, color, bend, bend, bend);
    triangle(center + v, b, m, color * .94, bend, bend, bend);
    triangle(b, center - v, m, color, bend, bend, bend);
    triangle(center - v, a, m, color * .88, bend, bend, bend);
  }

  MeshGeometry geometry({bool sway = true}) {
    final g = MeshGeometry.fromArrays(
      positions: Float32List.fromList(p),
      normals: Float32List.fromList(n),
      colors: sway ? Float32List.fromList(c) : null,
      indices: idx,
    );
    if (sway) {
      g.setCustomAttribute('flex', Float32List.fromList(flex), components: 1);
    }
    return g;
  }
}

class IslandNature {
  IslandNature(this.scene, this.world, this.material)
    : layout = NatureLayout(world) {
    final tiles = <(int, int, String), _Batch>{};
    _Batch batch(Plant p, String type) => tiles.putIfAbsent((
      (p.x / 48).floor(),
      (p.z / 48).floor(),
      type,
    ), () => _Batch());
    for (final p in layout.grass) {
      final b = batch(p, 'grass'), rng = math.Random(p.seed);
      for (var j = 0; j < 30; j++) {
        final x = p.x + (rng.nextDouble() - .5) * 3,
            z = p.z + (rng.nextDouble() - .5) * 3;
        if (!layout.clear(x, z, .12)) continue;
        final y = CoastalGrid.renderedTerrainHeight(world, x, z) - .025;
        final a = rng.nextDouble() * math.pi * 2,
            h = (.22 + rng.nextDouble() * .55) * p.size,
            w = .025 + rng.nextDouble() * .035;
        final dir = vm.Vector3(math.cos(a), 0, math.sin(a)),
            root = vm.Vector3(x, y, z);
        final mid = root + vm.Vector3(0, h * .55, 0) + dir * h * .16,
            tip = root + vm.Vector3(0, h, 0) + dir * h * .4;
        final side = vm.Vector3(-dir.z, 0, dir.x) * w;
        final color =
            (p.kind == 'dune'
                ? vm.Vector3(.29, .34, .105)
                : vm.Vector3(.095, .23, .045)) *
            (.75 + rng.nextDouble() * .6);
        b.triangle(
          root - side,
          root + side,
          mid - side * .5,
          color * .65,
          0,
          0,
          .45,
        );
        b.triangle(
          root + side,
          mid + side * .5,
          mid - side * .5,
          color,
          0,
          .45,
          .45,
        );
        b.triangle(
          mid - side * .5,
          mid + side * .5,
          tip,
          color * 1.15,
          .45,
          .45,
          1,
        );
      }
    }
    for (final p in [...layout.trees, ...layout.shrubs]) {
      final rng = math.Random(p.seed),
          trunk = batch(p, 'trunk'),
          leaves = batch(p, 'leaves'),
          far = batch(p, 'far');
      final root = vm.Vector3(p.x, p.y - .08, p.z), height = p.size;
      final crown =
          root +
          vm.Vector3(
            (rng.nextDouble() - .5) * height * .13,
            height * .73,
            (rng.nextDouble() - .5) * height * .1,
          );
      trunk.twig(
        root,
        crown,
        height * (p.kind == 'tree' ? .038 : .035),
        vm.Vector3(.19, .145, .09),
      );
      final count = p.kind == 'tree' ? 9 : 5;
      for (var j = 0; j < count; j++) {
        final angle = j * 2.399 + rng.nextDouble() * .7;
        final radius = height * (.20 + rng.nextDouble() * .17);
        final center =
            root +
            vm.Vector3(
              math.cos(angle) * radius,
              height * (.54 + rng.nextDouble() * .42),
              math.sin(angle) * radius,
            );
        final stem = root + (crown - root) * (.45 + rng.nextDouble() * .35);
        trunk.twig(
          stem,
          center,
          height * .012,
          vm.Vector3(.22, math.cos(angle * .9) * .65, .115),
        );
        final cluster =
            height * ((p.kind == 'tree' ? .16 : .23) + rng.nextDouble() * .05);
        final green =
            (p.seed % 3 == 0
                ? vm.Vector3(.14, .255, .055)
                : vm.Vector3(.075, .20, .06)) *
            (.8 + rng.nextDouble() * .4);
        for (var k = 0; k < (p.kind == 'tree' ? 48 : 32); k++) {
          final az = rng.nextDouble() * math.pi * 2,
              vy = rng.nextDouble() * 2 - 1,
              r = math.sqrt(1 - vy * vy);
          final offset =
              vm.Vector3(math.cos(az) * r, vy * .65, math.sin(az) * r) *
              cluster;
          final leafSize = height * (p.kind == 'tree' ? .047 : .14);
          leaves.leaf(
            center + offset,
            leafSize * (.7 + rng.nextDouble() * .6),
            az,
            green * (.8 + rng.nextDouble() * .4),
            p.kind == 'tree' ? .75 : 1,
          );
        }
        // Broad intersecting sprays keep canopy silhouettes at long distance.
        for (var k = 0; k < 12; k++) {
          final a = k * 2.399;
          far.leaf(
            center +
                vm.Vector3(math.cos(a), math.sin(a * 2) * .4, math.sin(a)) *
                    cluster *
                    .55,
            cluster * .65,
            a,
            green,
            .3,
          );
        }
      }
    }
    final bark = PhysicallyBasedMaterial()
      ..roughnessFactor = .92
      ..baseColorFactor = vm.Vector4(.24, .17, .09, 1);
    for (final e in tiles.entries) {
      if (e.value.idx.isEmpty) continue;
      final node =
          Node(
              name: 'Vegetation ${e.key.$3}',
              mesh: Mesh(
                e.value.geometry(sway: e.key.$3 != 'trunk'),
                e.key.$3 == 'trunk' ? bark : material,
              ),
            )
            ..castsShadows = e.key.$3 != 'grass'
            ..shadowStatic = false;
      scene.add(node);
      _nodes.add((node, e.key.$1 * 48 + 24.0, e.key.$2 * 48 + 24.0, e.key.$3));
      triangles += e.value.idx.length ~/ 3;
    }
    layout.addColliders();
  }
  final Scene scene;
  final IslandWorld world;
  final PreprocessedMaterial material;
  final NatureLayout layout;
  final _nodes = <(Node, double, double, String)>[];
  int triangles = 0, visibleBatches = 0;
  double _next = 0;
  final _lastEye = vm.Vector3.all(double.infinity);
  bool? _lastQuality;
  void update(double time, vm.Vector3 eye, double wind, bool high) {
    material.parameters.setFloat('time', time);
    material.parameters.setFloat('wind', wind);
    if (time < _next &&
        time >= _next - .2 &&
        (eye - _lastEye).length2 < 4 &&
        high == _lastQuality) {
      return;
    }
    _lastEye.setFrom(eye);
    _lastQuality = high;
    _next = time + .2;
    visibleBatches = 0;
    for (final item in _nodes) {
      final d = math.sqrt(
        math.pow(eye.x - item.$2, 2) + math.pow(eye.z - item.$3, 2),
      );
      final lod = high ? 160.0 : 105.0;
      item.$1.visible = switch (item.$4) {
        'grass' => d < (high ? 110 : 70),
        'leaves' => d < lod,
        'far' => d >= lod && d < (high ? 650 : 420),
        _ => d < (high ? 650 : 420),
      };
      if (item.$1.visible) visibleBatches++;
    }
  }

  Map<String, Object> inspect() => {
    'trees': layout.trees.length,
    'shrubs': layout.shrubs.length,
    'grassPatches': layout.grass.length,
    'triangles': triangles,
    'batches': _nodes.length,
    'visibleBatches': visibleBatches,
  };
}
