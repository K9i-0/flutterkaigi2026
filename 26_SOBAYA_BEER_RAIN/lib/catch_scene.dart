import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:madogiwa_engine/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'catch_game.dart';
import 'character.dart';
import 'studio_lighting.dart';
import 'okayaman_vision.dart';

class CatchScene {
  final scene = Scene();
  final vision = OkayamanVision();
  final camera = PerspectiveCamera(
    position: vm.Vector3(0, 9.6, 10.8),
    target: vm.Vector3(0, 1.6, 0),
    fovRadiansY: .69,
    fovNear: .1,
    fovFar: 100,
  );
  late Node halo;
  final characters = <CatchCharacter, Node>{};
  final motions = <CatchCharacter, CharacterMotionPlayer>{};
  CatchCharacter displayedCharacter = CatchCharacter.sobaya;
  Map<String, Object?> inspect() => {
    'displayedCharacter': displayedCharacter.id,
    'motion': motions[displayedCharacter]?.controller.inspect(),
    'facing': facing,
    'vision': vision.inspect(),
  };
  late Skybox twilight;
  final planeScenery = <Node>[], beamScenery = <Node>[];
  List<Node>? scenery;
  final laneCans = <Node>[];
  final cans = <Node>[], rings = <Node>[], dots = <Node>[];
  final itemCubes = <Node>[], itemMarkers = <Node>[];
  final itemCubeMats = <PhysicallyBasedMaterial>[];
  final itemMarkerMats = <PhysicallyBasedMaterial>[];
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
    final akasaka = await loadScene('assets/models/akasaka.glb');
    akasaka.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    scene.add(akasaka);
    beamScenery.add(akasaka);
    twilight = Skybox(
      GradientSkySource(
        zenithColor: vm.Vector3(.18, .13, .28),
        horizonColor: vm.Vector3(.85, .42, .25),
        groundColor: vm.Vector3(.18, .14, .21),
        sunColor: vm.Vector3.zero(),
      ),
    );
    scene.fog
      ..color = vm.Vector3(.40, .28, .32)
      ..start = 25
      ..end = 115;
    scenery = null;
    for (final character in CatchCharacter.values) {
      final node = await loadScene(character.modelAsset);
      characters[character] = node;
      scene.add(node);
      motions[character] = CharacterMotionPlayer(
        node,
        sources: const {'Idle': 'Idle', 'Walk': 'Walk', 'Run': 'Run'},
        groundSpeeds: const {'Walk': 1.5, 'Run': 3.5},
        syncGroups: const {'Walk': 'move', 'Run': 'move'},
      );
    }
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
    for (var slot = 0; slot < 3; slot++) {
      final cubeMat = mat(.15, .82, .72);
      final markerMat = mat(.15, .82, .72);
      itemCubeMats.add(cubeMat);
      itemMarkerMats.add(markerMat);
      final cube = Node(
        mesh: Mesh(CuboidGeometry(vm.Vector3(.42, .42, .42)), cubeMat),
      );
      scene.add(cube);
      itemCubes.add(cube);
      itemMarkers.add(
        mesh(
          CuboidGeometry(vm.Vector3(.55, .02, .55)),
          markerMat,
          vm.Vector3.zero(),
        ),
      );
    }
    await vision.load(scene);
    update(CatchGame(), 0);
  }

  vm.Vector4 itemColor(ItemEffect effect) => switch (effect) {
    ItemEffect.enlarge => vm.Vector4(.15, .82, .72, 1),
    ItemEffect.shrink => vm.Vector4(.95, .48, .12, 1),
    ItemEffect.speedUp => vm.Vector4(.45, .88, .22, 1),
    ItemEffect.speedDown => vm.Vector4(.20, .42, .95, 1),
  };

  void update(CatchGame g, double dt) {
    clock += dt;
    vision.update(dt, enabled: g.lane);
    scene.skybox = g.lane ? twilight : null;
    scene.fog.enabled = g.lane;
    for (final n in planeScenery) {
      n.visible = !g.lane;
    }
    for (final n in beamScenery) {
      n.visible = g.lane;
    }
    displayedCharacter = !g.lane
        ? CatchCharacter.sobaya
        : g.phase == Phase.ready || g.phase == Phase.result
        ? g.selectedCharacter
        : g.roundCharacter;
    for (final entry in characters.entries) {
      entry.value.visible = entry.key == displayedCharacter;
    }
    final character = characters[displayedCharacter]!;
    final motion = motions[displayedCharacter]!;
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
    character.position = vm.Vector3(g.x, 0, g.z);
    character.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), facing);
    final radius = g.lane && (g.phase == Phase.ready || g.phase == Phase.result)
        ? displayedCharacter.catchRadius
        : g.catchRadius;
    halo.position = vm.Vector3(g.x, .04, g.z);
    halo.scale = vm.Vector3(radius / .7, 1, g.lane ? .52 : radius / .7);
    final zoom = 1 + .18 * math.sin(g.yaw * 2).abs();
    camera.position = vm.Vector3(
      math.sin(g.yaw) * 10.8 * zoom,
      (g.lane ? 5.0 : 9.6) * zoom,
      math.cos(g.yaw) * 10.8 * zoom,
    );
    camera.target = vm.Vector3(0, g.lane ? 2.0 : 1.6, 0);
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
    final visibleItems = !g.lane || g.phase == Phase.ready
        ? <ItemDrop>[]
        : g.items.where((d) => d.visible(g.time)).toList();
    for (var i = 0; i < itemCubes.length; i++) {
      final active = i < visibleItems.length;
      itemCubes[i].visible = active;
      itemMarkers[i].visible = active;
      if (!active) continue;
      final d = visibleItems[i];
      final color = itemColor(d.effect);
      itemCubeMats[i].baseColorFactor = color;
      itemMarkerMats[i].baseColorFactor = color;
      final age = g.time - d.spawn;
      itemCubes[i].position = vm.Vector3(d.x, d.height(g.time), d.z);
      itemCubes[i].rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        age * 1.6 + d.id,
      );
      itemMarkers[i].position = vm.Vector3(d.x, .04, d.z);
      itemMarkers[i].rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        math.pi / 4,
      );
    }
  }
}
