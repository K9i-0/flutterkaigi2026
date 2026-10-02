import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:madogiwa_engine/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'catch_game.dart';
import 'studio_lighting.dart';

class CatchScene {
  final scene = Scene();
  final camera = PerspectiveCamera(
    position: vm.Vector3(0, 9.6, 10.8),
    target: vm.Vector3(0, 1.6, 0),
    fovRadiansY: .69,
    fovNear: .1,
    fovFar: 100,
  );
  late Node sobaya, halo;
  late CharacterMotionPlayer motion;
  final cans = <Node>[], rings = <Node>[], dots = <Node>[];
  double facing = math.pi, clock = 0;
  PhysicallyBasedMaterial mat(
    double r,
    double g,
    double b, {
    double metal = 0,
  }) => PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(r, g, b, 1)
    ..roughnessFactor = .6
    ..metallicFactor = metal;
  Node mesh(Geometry geo, Material material, vm.Vector3 pos) {
    final n = Node(mesh: Mesh(geo, material))..position = pos;
    scene.add(n);
    return n;
  }

  Node box(
    double w,
    double h,
    double d,
    double x,
    double y,
    double z,
    Material m,
  ) => mesh(CuboidGeometry(vm.Vector3(w, h, d)), m, vm.Vector3(x, y, z));
  Future<void> load() async {
    await Scene.initializeStaticResources();
    scene.environment = await beerStudioEnvironment();
    scene.environmentIntensity = 1.1;
    scene.exposure = 1.15;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.5, -1, -.3),
      intensity: 2.4,
    );
    final wood = mat(.18, .10, .055),
        edge = mat(.49, .32, .13, metal: .4),
        teal = mat(.055, .16, .15);
    box(70, .4, 70, 0, -1, 0, mat(.022, .041, .058));
    box(9, .32, 6.8, 0, -.19, 0, wood);
    for (var x = -4; x <= 4; x++) {
      for (var z = -3; z <= 3; z++) {
        box(
          .96,
          .03,
          .96,
          x.toDouble(),
          -.01,
          z.toDouble(),
          (x + z).isEven ? mat(.16, .24, .23) : mat(.125, .20, .20),
        );
      }
    }
    for (final z in [-3.36, 3.36]) {
      box(9, .09, .08, 0, .03, z, edge);
    }
    for (final x in [-4.46, 4.46]) {
      box(.08, .09, 6.8, x, .03, 0, edge);
    }
    for (final x in [-4.8, 4.8]) {
      for (final z in [-3.8, 3.8]) {
        box(.09, 2.7, .09, x, 1.2, z, teal);
        mesh(
          SphereGeometry(radius: .20, segments: 12, rings: 8),
          mat(.95, .62, .19),
          vm.Vector3(x, 2.6, z),
        );
      }
    }
    for (var i = 0; i < 16; i++) {
      final a = i * math.pi / 8,
          r = 18.0 + (i % 3) * 2,
          h = 2.0 + (i % 5) * 1.1;
      box(
        2.2,
        h,
        2.2,
        math.sin(a) * r,
        h / 2 - 1,
        math.cos(a) * r,
        mat(.055, .085, .11),
      );
    }
    box(.055, .015, .65, 0, .015, -2.65, edge);
    for (final s in [-1.0, 1.0]) {
      final n = box(.055, .015, .4, s * .13, .016, -2.87, edge);
      n.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), s * .75);
    }
    sobaya = await loadScene('assets/models/sobaya.glb');
    scene.add(sobaya);
    motion = CharacterMotionPlayer(
      sobaya,
      sources: const {'Idle': 'Idle', 'Walk': 'Walk', 'Run': 'Run'},
      groundSpeeds: const {'Walk': 1.5, 'Run': 3.5},
      syncGroups: const {'Walk': 'move', 'Run': 'move'},
    );
    halo = mesh(
      TorusGeometry(
        radius: .7,
        tubeRadius: .025,
        radialSegments: 40,
        tubularSegments: 6,
      ),
      mat(.28, .8, .7),
      vm.Vector3(0, .04, 0),
    );

    final prototypes = <Node>[];
    for (final n in ['super_try', 'light', 'happoshu']) {
      prototypes.add(await loadScene('assets/models/$n.glb'));
    }
    final demo = CatchGame()..start();
    for (final d in demo.drops) {
      final n = prototypes[d.kind.index].clone();
      scene.add(n);
      cans.add(n);
      final ring = mesh(
        TorusGeometry(
          radius: .45,
          tubeRadius: .018,
          radialSegments: 32,
          tubularSegments: 6,
        ),
        mat(.93, .76, .40),
        vm.Vector3.zero(),
      );

      rings.add(ring);
      dots.add(
        mesh(
          CylinderGeometry(
            topRadius: .18,
            bottomRadius: .18,
            height: .009,
            radialSegments: 20,
          ),
          mat(.045, .065, .06),
          vm.Vector3.zero(),
        ),
      );
    }
    update(CatchGame(), 0);
  }

  void update(CatchGame g, double dt) {
    clock += dt;
    final speed = math.sqrt(g.vx * g.vx + g.vz * g.vz);
    motion.controller.select(
      speed > .15 ? (speed > 2 ? 'Run' : 'Walk') : 'Idle',
    );
    motion.controller.advance(dt, groundSpeed: speed);
    motion.sample();
    if (speed > .12) {
      final desired = math.atan2(-g.vx, -g.vz),
          diff = math.atan2(
            math.sin(desired - facing),
            math.cos(desired - facing),
          );
      facing += diff * (1 - math.exp(-dt * 12));
    }
    sobaya.position = vm.Vector3(g.x, 0, g.z);
    sobaya.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), facing);
    halo.position = vm.Vector3(g.x, .045, g.z);
    final zoom = 1 + .18 * math.sin(g.yaw * 2).abs();
    camera.position = vm.Vector3(
      math.sin(g.yaw) * 10.8 * zoom,
      9.6 * zoom,
      math.cos(g.yaw) * 10.8 * zoom,
    );
    camera.target = vm.Vector3(0, 1.6, 0);
    for (var i = 0; i < cans.length; i++) {
      final active =
          i < g.drops.length &&
          g.drops[i].visible(g.time) &&
          g.phase != Phase.ready;
      cans[i].visible = active;
      rings[i].visible = active;
      dots[i].visible = active;
      if (!active) continue;
      final d = g.drops[i], age = g.time - d.spawn;
      cans[i].position = vm.Vector3(d.x, d.height(g.time), d.z);
      cans[i].rotation =
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            g.yaw + math.pi + math.sin(age * 2) * .18,
          ) *
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            math.sin(age * 3 + i) * .10,
          );
      rings[i].position = vm.Vector3(d.x, .035, d.z);
      rings[i].scale = vm.Vector3.all(.8 + .2 * math.sin(age * 7));
      dots[i].position = vm.Vector3(d.x, .021, d.z);
      dots[i].scale = vm.Vector3.all(1 + (1 - d.height(g.time) / 6) * .9);
    }
  }
}
