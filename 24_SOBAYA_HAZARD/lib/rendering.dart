import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:madogiwa_engine/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game.dart';

class YardRenderer {
  final scene = Scene();
  final camera = PerspectiveCamera(
    position: vm.Vector3(0, 4, 18),
    target: vm.Vector3(0, 1, 12),
    fovNear: .08,
    fovFar: 90,
  );
  late Node yard;
  final roots = <Node>[];
  final players = <CharacterMotionPlayer>[];
  Future<void> load(HazardGame game) async {
    await Scene.initializeStaticResources();
    scene.environment = EnvironmentMap.constantDiffuse(
      vm.Vector3(.42, .48, .56),
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.5, -1, -.3),
      intensity: 2.4,
    );
    yard = await loadScene('assets/models/yard.glb');
    // Preprocessed imports bake the glTF Z reflection. The layout uses its authored Z.
    yard.localTransform = vm.Matrix4.diagonal3Values(1, 1, -1);
    scene.add(yard);
    final fuku = await loadScene('assets/models/fukuchan.glb'),
        soba = await loadScene('assets/models/sobaya.glb');
    for (var i = 0; i <= game.guards.length; i++) {
      final root = Node(), model = (i == 0 ? fuku : soba).clone();
      model.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
      root.add(model);
      scene.add(root);
      roots.add(root);
      players.add(
        CharacterMotionPlayer(
          model,
          sources: const {'Idle': 'Idle', 'Walk': 'Walk', 'Run': 'Run'},
          groundSpeeds: i == 0
              ? const {'Walk': 1.9075, 'Run': 2.8785}
              : const {'Walk': 2.1239, 'Run': 3.2109},
          syncGroups: const {'Walk': 'gait', 'Run': 'gait'},
        ),
      );
    }
  }

  Map<String, Object?> inspect() => {
    for (final name in ['Control cabinet', 'Extraction marker', 'Cargo 0'])
      name: yard
          .getChildByName(name)
          ?.globalTransform
          .getTranslation()
          .storage
          .toList(),
  };

  void update(HazardGame game, double dt) {
    for (var i = 0; i < roots.length; i++) {
      final g = i == 0 ? null : game.guards[i - 1];
      final p = g?.position ?? game.player, speed = g?.speed ?? game.speed;
      roots[i].visible = g == null || g.health > 0;
      roots[i].position = vm.Vector3(p.x, 0, p.z);
      roots[i].rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        g?.yaw ?? game.yaw,
      );
      final player = players[i];
      player.controller.select(
        speed < .05
            ? 'Idle'
            : speed > 2.2
            ? 'Run'
            : 'Walk',
      );
      player.controller.advance(dt, groundSpeed: speed);
      player.sample();
    }
    final f = game.facing,
        obstruct = game.world.ray(game.player, game.facing * -1, 4.5);
    final behind =
        game.player -
        f * (obstruct == null ? 4.5 : math.max(.6, obstruct - .3));
    camera.position = vm.Vector3(behind.x, 2.5, behind.z);
    camera.target = vm.Vector3(
      game.player.x + f.x * 4,
      1.3,
      game.player.z + f.z * 4,
    );
  }
}
