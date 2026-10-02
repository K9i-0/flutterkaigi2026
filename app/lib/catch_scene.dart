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
  final planeScenery = <Node>[], beamScenery = <Node>[];
  List<Node>? scenery;
  final laneCans = <Node>[];
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
    scenery?.add(n);
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
    scenery = planeScenery;
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
    scenery = beamScenery;
    final steel = mat(.32, .13, .055, metal: .7),
        topSteel = mat(.46, .25, .09, metal: .65),
        bolt = mat(.18, .20, .21, metal: .85),
        yellow = mat(.85, .58, .08),
        concrete = mat(.12, .17, .21);
    // A single I-beam, top surface at foot height. No surrounding floor.
    box(9.6, .10, .95, 0, -.05, 0, topSteel);
    box(9.6, .52, .12, 0, -.36, 0, steel);
    box(9.6, .10, .95, 0, -.67, 0, steel);
    for (final side in [-1.0, 1.0]) {
      box(9.4, .009, .035, 0, .007, side * .43, yellow);
      box(1.8, .45, 2.5, side * 5.3, -.225, 0, concrete);
      box(1.3, 15, 1.8, side * 5.5, -7.8, 0, concrete);
      // Fixed end stops explain the longitudinal movement limit too.
      box(.16, .32, .94, side * 4.4, .16, 0, steel);
      for (var i = 0; i < 5; i++) {
        box(
          .09,
          .012,
          .7,
          side * (3.8 + i * .11),
          .012,
          0,
          i.isEven ? yellow : bolt,
        );
      }
    }
    for (var x = -3; x <= 3; x++) {
      for (final z in [-.32, .32]) {
        mesh(
          CylinderGeometry(
            topRadius: .045,
            bottomRadius: .045,
            height: .022,
            radialSegments: 6,
          ),
          bolt,
          vm.Vector3(x.toDouble(), .013, z),
        );
      }
    }
    // Street and roof tops are far below the playable beam.
    box(110, .4, 110, 0, -17, 0, mat(.025, .045, .065));
    for (var i = 0; i < 24; i++) {
      final x = ((i % 6) - 2.5) * 6.0,
          z = ((i ~/ 6) - 1.5) * 8.0,
          h = 2.0 + (i % 5) * .8;
      box(3.8, h, 4.8, x, -16.7 + h / 2, z, concrete);
      box(3.9, .12, 4.9, x, -16.6 + h, z, mat(.20, .25, .28));
      for (var w = 0; w < 3; w++) {
        box(
          .38,
          .55,
          .025,
          x - 1 + w,
          -16 + h / 2,
          z + 2.41,
          mat(.65, .49, .21),
        );
      }
    }
    for (var i = -6; i <= 6; i++) {
      box(.14, .015, 1.0, 0, -16.77, i * 3.0, yellow);
    }
    scenery = null;
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
    final lanePrototypes = <Node>[];
    for (final n in ['super_try', 'light', 'happoshu']) {
      lanePrototypes.add(await loadScene('assets/models/${n}_lane.glb'));
    }
    // At most ceil((6 + .65) / .5) = 14 simultaneously visible drops.
    for (var slot = 0; slot < 16; slot++) {
      for (var kind = 0; kind < 3; kind++) {
        final n = prototypes[kind].clone();
        scene.add(n);
        cans.add(n);
        final laneCan = lanePrototypes[kind].clone();
        scene.add(laneCan);
        laneCans.add(laneCan);
      }
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
    for (final n in planeScenery) {
      n.visible = !g.lane;
    }
    for (final n in beamScenery) {
      n.visible = g.lane;
    }
    final speed = math.sqrt(g.vx * g.vx + g.vz * g.vz);
    motion.controller.select(
      speed > .15
          ? (g.lane
                ? 'Walk'
                : speed > 2
                ? 'Run'
                : 'Walk')
          : 'Idle',
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
    halo.position = vm.Vector3(g.x, .04, g.z);
    halo.scale = vm.Vector3(
      g.balance['catchRadius'] / .7,
      1,
      g.lane ? .52 : g.balance['catchRadius'] / .7,
    );
    final zoom = 1 + .18 * math.sin(g.yaw * 2).abs();
    camera.position = vm.Vector3(
      math.sin(g.yaw) * 10.8 * zoom,
      (g.lane ? 7.6 : 9.6) * zoom,
      math.cos(g.yaw) * 10.8 * zoom,
    );
    camera.target = vm.Vector3(0, g.lane ? .65 : 1.6, 0);
    final visible = g.phase == Phase.ready
        ? <Drop>[]
        : g.drops.where((d) => d.visible(g.time)).toList();
    for (var i = 0; i < rings.length; i++) {
      final active = i < visible.length;
      for (var kind = 0; kind < 3; kind++) {
        cans[i * 3 + kind].visible =
            active && !g.lane && visible[i].kind.index == kind;
        laneCans[i * 3 + kind].visible =
            active && g.lane && visible[i].kind.index == kind;
      }
      rings[i].visible = active;
      dots[i].visible = active;
      if (!active) continue;
      final d = visible[i], age = g.time - d.spawn;
      final can = (g.lane ? laneCans : cans)[i * 3 + d.kind.index];
      can.position = vm.Vector3(
        d.x,
        g.lane && d.resolved && !d.caught
            ? 1.15 - math.pow((g.time - d.landing) * 5, 2).toDouble()
            : d.height(g.time),
        d.z,
      );
      can.rotation =
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            (g.lane ? d.facing : g.yaw) + math.pi + math.sin(age * 2) * .08,
          ) *
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            math.sin(age * 3 + d.id) * .10,
          );
      rings[i].position = vm.Vector3(d.x, .065, d.z);
      final ringSize = .8 + .2 * math.sin(age * 7);
      rings[i].scale = vm.Vector3(
        ringSize,
        1,
        g.lane ? ringSize * .65 : ringSize,
      );
      dots[i].position = vm.Vector3(d.x, .051, d.z);
      dots[i].scale = vm.Vector3.all(1 + (1 - d.height(g.time) / 6) * .9);
    }
  }
}
