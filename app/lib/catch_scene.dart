import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:madogiwa_engine/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'catch_game.dart';
import 'cached_skin.dart';
import 'character.dart';
import 'drop_models.dart';
import 'studio_lighting.dart';
import 'okayaman_vision.dart';
import 'stage_lighting.dart';
import 'stage_environment.dart';

/// What a pinch zooms toward on the beam stage.
enum ZoomPivot {
  bridge,
  character;

  String get id => name;
}

class CatchScene {
  final scene = Scene();
  final vision = OkayamanVision();
  final camera = PerspectiveCamera(
    position: vm.Vector3(0, 9.6, 10.8),
    target: vm.Vector3(0, 1.6, 0),
    fovRadiansY: .78,
    fovNear: .1,
    fovFar: 100,
  );
  late Node halo;
  final characters = <CatchCharacter, Node>{};
  final motions = <CatchCharacter, CharacterMotionPlayer>{};
  CatchCharacter displayedCharacter = CatchCharacter.sobaya;
  Map<String, Object?> inspect() => {
    'renderer': {
      'aa': scene.effectiveAntiAliasingMode.name,
      'scale': scene.renderScale,
      'shadowCascades': scene.directionalLight?.shadowCascadeCount,
      'shadowDistance': scene.directionalLight?.shadowMaxDistance,
      'stageVisible': lighting.stage.visible,
      'mountedRoots': scene.root.children.length,
    },
    'displayedCharacter': displayedCharacter.id,
    'motion': motions[displayedCharacter]?.controller.inspect(),
    'facing': facing,
    'zoom': zoom,
    'zoomPivot': zoomPivot.id,
    'vision': vision.inspect(),
    'stage': lighting.inspect(),
    'visibleDropModels': [
      for (final slot in dropSlots)
        for (final d in slot)
          if (d.root.visible) d.kind.name,
    ],
  };
  late StageLighting lighting;
  late EnvironmentMap previewEnvironment;
  final dropModels = DropModels();
  final dropSlots = <List<DropModel>>[];
  final _preparedDropKinds = <CanKind>{};
  double facing = math.pi, clock = 0;

  /// Pinch magnification; 1 is the standard view, larger is closer.
  double zoom = 1;
  ZoomPivot zoomPivot = ZoomPivot.bridge;
  double _pivotX = 0;
  // Hidden rigged models still incur a scene-tree walk. Keep reusable models
  // off the live graph until needed; geometry, textures and animation survive.
  void _show(Node node, bool visible) {
    node.visible = visible;
    if (visible && node.parent == null) {
      scene.add(node);
    } else if (!visible && identical(node.parent, scene.root)) {
      scene.remove(node);
    }
  }

  void applyRenderProbe(Map<String, String> p) {
    lighting.configureRenderer(scene);
    scene.antiAliasingMode = switch (p['aa']) {
      'fxaa' => AntiAliasingMode.fxaa,
      'none' => AntiAliasingMode.none,
      'msaa' => AntiAliasingMode.auto,
      _ => scene.antiAliasingMode,
    };
    scene.renderScale =
        double.tryParse(p['scale'] ?? '') ?? lighting.renderScale;
    scene.directionalLight
      ?..shadowCascadeCount =
          int.tryParse(p['cascades'] ?? '') ?? lighting.graphics.shadowCascades
      ..shadowMaxDistance =
          double.tryParse(p['shadowDistance'] ?? '') ??
          lighting.graphics.shadowDistance
      ..shadowMapResolution = int.tryParse(p['shadowSize'] ?? '') ?? 1024;
  }

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

  Future<void> load() async {
    await Scene.initializeStaticResources();
    previewEnvironment = await beerStudioEnvironment();
    final cityMaps = await cityEnvironments();
    final akasaka = await loadScene('assets/models/akasaka.glb');
    akasaka.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    // Night work lights on the support-building roofs keep the beam readable.
    final workLights = <PointLight>[];
    for (final x in [-4.9, 4.9]) {
      final light = PointLight(
        color: vm.Vector3(1, .86, .66),
        intensity: 0,
        range: 14,
        falloffExponent: 1.2,
      );
      workLights.add(light);
      final node = Node()..position = vm.Vector3(x, 3.2, 2.4);
      node.addComponent(PointLightComponent(light));
      scene.add(node);
    }
    // Flag static shadow casters before mounting so they enter the cache.
    lighting = StageLighting(akasaka, workLights, cityMaps);
    scene.add(akasaka);
    for (final character in CatchCharacter.values) {
      final node = await loadScene(character.modelAsset);
      cacheSkinUploads(node);
      characters[character] = node;
      scene.add(node);
      motions[character] = CharacterMotionPlayer(
        node,
        sources: const {'Idle': 'Idle', 'Walk': 'Walk'},
        groundSpeeds: const {'Walk': 1.5},
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

    await dropModels.load();
    // At most ceil((6 + .65) / .5) = 14 simultaneously visible drops. Clones
    // are created on first use, then reused. Do not preallocate every
    // character/item combination for all 16 slots.
    for (var slot = 0; slot < 16; slot++) {
      dropSlots.add(<DropModel>[]);
    }
    await vision.load(scene);
    update(CatchGame(), 0);
  }

  void update(CatchGame g, double dt) {
    clock += dt;
    lighting.time = g.timeOfDay;
    lighting.apply(scene);
    lighting.update(clock);
    displayedCharacter = g.phase == Phase.ready || g.phase == Phase.result
        ? g.selectedCharacter
        : g.roundCharacter;
    for (final entry in characters.entries) {
      _show(entry.value, entry.key == displayedCharacter);
    }
    final character = characters[displayedCharacter]!;
    // Prepare only this player's two/three item types on selection, before
    // the countdown. Avoid first-spawn cloning during the round.
    for (final kind in [
      ...displayedCharacter.goodDrops,
      displayedCharacter.badDrop,
    ]) {
      if (_preparedDropKinds.add(kind)) {
        for (final slot in dropSlots) {
          slot.add(dropModels.create(kind));
        }
      }
    }
    final motion = motions[displayedCharacter]!;
    final speed = g.vx.abs();
    motion.controller.select(speed > .15 ? 'Walk' : 'Idle');
    motion.controller.advance(dt, groundSpeed: speed);
    motion.sample();
    if (speed > .12) {
      final desired = math.atan2(-g.vx, 0),
          diff = math.atan2(
            math.sin(desired - facing),
            math.cos(desired - facing),
          );
      facing += diff * (1 - math.exp(-dt * 12));
    }
    character.position = vm.Vector3(g.x, 0, 0);
    character.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), facing);
    final radius = g.phase == Phase.ready || g.phase == Phase.result
        ? displayedCharacter.catchRadius
        : g.catchRadius;
    halo.position = vm.Vector3(g.x, .04, 0);
    halo.scale = vm.Vector3(radius / .7, 1, .52);
    final widen = 1 + .18 * math.sin(g.yaw * 2).abs();
    final base = vm.Vector3(
      math.sin(g.yaw) * 10.8 * widen,
      5.0 * widen,
      math.cos(g.yaw) * 10.8 * widen,
    );
    // Leave sky between the 333m landmark tip and the HUD on wide iPhones.
    final baseTarget = vm.Vector3(0, 2.9, 0);
    final m = zoom;
    // Smoothed so the end stops and quick reversals don't jolt the view.
    final followX = zoomPivot == ZoomPivot.character ? g.x : 0.0;
    _pivotX += (followX - _pivotX) * (dt <= 0 ? 1 : 1 - math.exp(-dt * 6));
    // Closer views aim lower, toward the beam and the character's body.
    final close = ((m - 1) / math.max(.01, g.balance['zoomMax'] - 1)).clamp(
      0.0,
      1.0,
    );
    final target = vm.Vector3(
      _pivotX,
      baseTarget.y + (1.0 - baseTarget.y) * close,
      0,
    );
    camera.target = target;
    camera.position = target + (base - baseTarget) / m;
    final visible = g.phase == Phase.ready
        ? <Drop>[]
        : g.drops.where((d) => d.visible(g.time)).toList();
    for (var i = 0; i < dropSlots.length; i++) {
      final active = i < visible.length;
      if (active && !dropSlots[i].any((m) => m.kind == visible[i].kind)) {
        dropSlots[i].add(dropModels.create(visible[i].kind));
      }
      for (final model in dropSlots[i]) {
        _show(model.root, active && visible[i].kind == model.kind);
      }
      if (!active) continue;
      final d = visible[i], age = g.time - d.spawn;
      final drop = dropSlots[i].firstWhere((m) => m.kind == d.kind);
      drop.sample(age);
      drop.root.position = vm.Vector3(
        d.x,
        d.resolved && !d.caught
            ? 1.15 - math.pow((g.time - d.landing) * 5, 2).toDouble()
            : d.height(g.time),
        0,
      );
      // Every drop keeps its own heading instead of facing the camera.
      drop.root.rotation =
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            d.facing +
                (d.kind.isCan ? math.pi : .25 * math.sin(age)) +
                math.sin(age * 2) * .08,
          ) *
          vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            math.sin(age * 3 + d.id) * .10,
          );
    }
  }
}
