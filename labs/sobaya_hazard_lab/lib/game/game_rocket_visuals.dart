import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';

/// Reusable low-poly prop in GunSocket coordinates (barrel points along -Z).
Node buildRocketLauncher() {
  final root = Node(name: 'RocketLaunchua');
  PhysicallyBasedMaterial material(
    double r,
    double g,
    double b,
    double metal,
  ) => PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(r, g, b, 1)
    ..metallicFactor = metal
    ..roughnessFactor = .48;
  final olive = material(.24, .30, .14, .45);
  final steel = material(.13, .15, .16, .8);
  final black = material(.018, .021, .019, .1);
  final warning = material(.8, .55, .08, .2);
  void tube(double radius, double length, double z, Material mat) {
    root.add(
      Node(
          mesh: Mesh(
            CylinderGeometry(
              bottomRadius: radius,
              topRadius: radius,
              height: length,
              radialSegments: 16,
            ),
            mat,
          ),
        )
        ..position = vm.Vector3(0, .11, z)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(1, 0, 0), math.pi / 2),
    );
  }

  tube(.085, 1.05, -.24, olive);
  tube(.10, .08, -.80, steel);
  tube(.082, .004, -.844, black);
  tube(.10, .09, .30, steel);
  tube(.09, .045, -.58, warning);
  for (final z in [-.1, -.43]) {
    root.add(
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(.045, .14, .055)), black))
        ..position = vm.Vector3(0, -.015, z),
    );
  }
  root.add(
    Node(mesh: Mesh(CuboidGeometry(vm.Vector3(.06, .055, .24)), steel))
      ..position = vm.Vector3(0, .225, -.25),
  );
  return root;
}

class RocketVisuals {
  RocketVisuals(this.scene);
  final Scene scene;
  final _missiles = <HazardRocket, Node>{};
  final _blasts = <RocketBlast, Node>{};
  final _fire = UnlitMaterial()..baseColorFactor = vm.Vector4(1, .45, .045, 1);
  final _core = UnlitMaterial()..baseColorFactor = vm.Vector4(1, .88, .35, 1);
  void update(HazardGameState s) {
    for (final r in _missiles.keys.toList()) {
      if (!s.rockets.contains(r)) {
        scene.remove(_missiles.remove(r)!);
      }
    }
    for (final b in _blasts.keys.toList()) {
      if (!s.rocketBlasts.contains(b)) {
        scene.remove(_blasts.remove(b)!);
      }
    }
    for (final r in s.rockets) {
      final n = _missiles.putIfAbsent(r, () {
        final node = Node(mesh: Mesh(SphereGeometry(radius: .065), _core))
          ..castsShadows = false;
        for (var i = 1; i <= 5; i++) {
          node.add(
            Node(mesh: Mesh(SphereGeometry(radius: .05 - i * .005), _fire))
              ..position = vm.Vector3(0, 0, i * .12)
              ..castsShadows = false,
          );
        }
        scene.add(node);
        return node;
      });
      n.position = r.position;
      n.rotation = vm.Quaternion.fromTwoVectors(
        vm.Vector3(0, 0, -1),
        r.direction,
      );
    }
    for (final b in s.rocketBlasts) {
      final n = _blasts.putIfAbsent(b, () {
        final node = Node();
        for (var i = 0; i < 9; i++) {
          node.add(
            Node(
                mesh: Mesh(
                  SphereGeometry(radius: .16),
                  i.isEven ? _fire : _core,
                ),
              )
              ..position = vm.Vector3(
                math.cos(i * 2.4) * .4,
                math.sin(i * 1.7) * .35,
                math.sin(i * 2.4) * .4,
              )
              ..castsShadows = false,
          );
        }
        scene.add(node);
        return node;
      });
      n.position = b.position;
      n.scale = vm.Vector3.all((.4 + b.age * 4) * (1 - b.age / .55));
    }
  }
}
