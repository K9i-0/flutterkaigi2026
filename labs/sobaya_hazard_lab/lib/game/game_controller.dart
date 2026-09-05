import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';
import '../lab/beer_mug_component.dart';
import '../lab/simulation.dart' show FrameSamples;

class CharacterPlayer {
  CharacterPlayer(Node template, this.names) : node = template.clone() {
    for (final name in names) {
      final animation = node.findAnimationByName(name);
      if (animation == null) throw StateError('Missing $name');
      clips[name] = node.createAnimationClip(animation)
        ..loop = true
        ..weight = 0;
    }
    setMotion('Idle');
  }
  final Node node;
  final List<String> names;
  final clips = <String, AnimationClip>{};
  String current = '';
  void setMotion(String name) {
    if (current == name) return;
    current = name;
    clips[name]!.seek(0);
    clips[name]!.play();
  }

  void update(double dt, bool playing, {double speed = 1}) {
    for (final e in clips.entries) {
      final target = e.key == current ? 1.0 : 0.0;
      e.value.weight += (target - e.value.weight) * (dt * 12).clamp(0, 1);
      e.value.playbackTimeScale = speed;
      if (playing && (e.key == current || e.value.weight > .005)) {
        e.value.play();
      } else {
        e.value.pause();
      }
    }
  }
}

class HazardGameController extends ChangeNotifier {
  final scene = Scene();
  final frames = FrameSamples();
  HazardGameState? state;
  bool ready = false, disposed = false, muted = false;
  late Node village, itemsTemplate, beerTemplate, fukuTemplate, sobayaTemplate;
  late CharacterPlayer player;
  final enemies = <CharacterPlayer>[],
      pickupNodes = <String, Node>{},
      crateNodes = <String, Node>{};
  late Node pistol, shotgun, impact;
  final fxPools = <String, AudioPool>{};
  final ambience = AudioPlayer();
  SharedPreferences? preferences;
  ui.Size viewport = const ui.Size(1280, 800);
  double _notifyTime = 0, _stepDistance = 0;
  String? error;
  Future<void> load() async {
    preferences = await SharedPreferences.getInstance();
    final map = jsonDecode(
      await rootBundle.loadString('assets/village.json'),
    ) as Map<String, dynamic>;
    state = HazardGameState(
      map,
      savedCollection: preferences!
          .getStringList('hazard.collection.v1')
          ?.toSet(),
    )..phase = PlayPhase.title;
    await Scene.initializeStaticResources();
    final loaded = await Future.wait(
      [
        'village',
        'items',
        'beer_mug',
        'sobaya',
        'fukuchan',
      ].map((n) => loadScene('assets/models/$n.glb')),
    );
    if (disposed) return;
    village = loaded[0];
    itemsTemplate = loaded[1];
    beerTemplate = loaded[2];
    sobayaTemplate = loaded[3];
    fukuTemplate = loaded[4];
    scene.add(village);
    _static(village);
    // Roofs are hidden when the player enters a house; those casters are dynamic.
    for (final h in state!.map['houses']) {
      final roof = village.getChildByName('Roof_${h['id']}');
      if (roof != null) _static(roof, value: false);
    }
    _static(village.getChildByName('FarmGate')!, value: false);
    for (final row in state!.images) {
      _static(village.getChildByName(row['node'])!, value: false);
    }
    scene.environmentSettings = EnvironmentSettings(
      exposure: 1.05,
      ambientOcclusionEnabled: false,
      fogEnabled: true,
      fogColor: vm.Vector3(.38, .39, .33),
      fogDensity: .012,
      fogStart: 16,
      fogMaxOpacity: .80,
      vignetteEnabled: true,
      vignetteIntensity: .30,
    );
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: vm.Vector3(.23, .26, .24),
        horizonColor: vm.Vector3(.53, .51, .42),
        groundColor: vm.Vector3(.16, .17, .12),
        sunColor: vm.Vector3(.8, .65, .4),
      ),
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.6, -1, .3),
      intensity: 2,
      castsShadow: true,
      shadowCascadeCount: 1,
      shadowMapResolution: 1024,
      shadowMaxDistance: 35,
      cacheStaticShadows: true,
      shadowDepthBias: .003,
      shadowNormalBias: .01,
    );
    scene.renderScale = .85;
    player = CharacterPlayer(fukuTemplate, [
      'Idle',
      'Walk',
      'Run',
      'Aim',
      'AimShotgun',
    ]);
    scene.add(player.node);
    for (var i = 0; i < state!.enemies.length; i++) {
      final actor = CharacterPlayer(sobayaTemplate, [
        'Idle',
        'Walk',
        'Run',
        'ZombieWalk',
        'MugAttack',
      ]);
      enemies.add(actor);
      scene.add(actor.node);
    }
    pistol = _prop('Handgun');
    shotgun = _prop('Shotgun');
    scene.add(pistol);
    scene.add(shotgun);
    final mat = UnlitMaterial()..baseColorFactor = vm.Vector4(1, .82, .4, 1);
    impact = Node(mesh: Mesh(SphereGeometry(radius: .065), mat))
      ..castsShadows = false
      ..visible = false;
    scene.add(impact);
    _resetNodes();
    for (final name in [
      'shot',
      'shotgun',
      'pickup',
      'collect',
      'heal',
      'clear',
      'enemy',
      'hurt',
      'reload',
      'equip',
      'empty',
      'gate',
      'break',
      'step',
      'defeat',
    ]) {
      fxPools[name] = await AudioPool.createFromAsset(
        path: 'audio/$name.wav',
        maxPlayers: 3,
      );
    }
    ready = true;
    await ambience.setReleaseMode(ReleaseMode.loop);
    await ambience.setVolume(.24);
    unawaited(ambience.play(AssetSource('audio/ambient.wav')));
    notifyListeners();
  }

  void _static(Node node, {bool value = true}) {
    node.shadowStatic = value;
    for (final child in node.children) {
      _static(child, value: value);
    }
  }

  Node _prop(String name) {
    final template = itemsTemplate.getChildByName(name);
    if (template == null) throw StateError('Missing prop $name');
    return template.clone();
  }

  void _resetNodes() {
    for (final node in pickupNodes.values) {
      scene.remove(node);
    }
    pickupNodes.clear();
    for (final node in crateNodes.values) {
      scene.remove(node);
    }
    crateNodes.clear();
    for (final c in state!.crates) {
      final n = _prop(c.kind == 'crate' ? 'Crate' : 'Barrel')
        ..position = vm.Vector3(c.x, 0, c.z);
      scene.add(n);
      crateNodes[c.id] = n;
    }
  }

  void restart() {
    state!.restart();
    _resetNodes();
    notifyListeners();
  }

  void toggle(PlayPhase phase) {
    state!.toggle(phase);
    notifyListeners();
  }

  void rotate(double dx, double dy) {
    final s = state!;
    if (!s.running) return;
    s.yaw -= dx * .006;
    s.pitch = (s.pitch + dy * .004).clamp(-.25, .65);
  }

  PerspectiveCamera camera() {
    final s = state!;
    final right = vm.Vector3(-math.cos(s.yaw), 0, math.sin(s.yaw));
    final target =
        vm.Vector3(s.x, s.y + 1.35, s.z) + right * (s.aiming ? .43 : .22);
    final distance = s.aiming ? 2.0 : 3.4;
    final offset = vm.Vector3(
      math.sin(s.yaw) * math.cos(s.pitch) * distance,
      math.sin(s.pitch) * distance + .18,
      math.cos(s.yaw) * math.cos(s.pitch) * distance,
    );
    final length = s.wallDistance(target, offset.normalized(), offset.length);
    final actual = math.max(.35, math.min(offset.length, length - .18));
    return PerspectiveCamera(
      position: target + offset.normalized() * actual,
      target: target,
      fovRadiansY: (s.aiming ? 42 : 53) * math.pi / 180,
      fovNear: .07,
      fovFar: 85,
    );
  }

  void fire() {
    if (!ready) return;
    final s = state!;
    final ray = camera().screenPointToRay(
      ui.Offset(viewport.width / 2, viewport.height / 2),
      viewport,
    );
    s.shoot(ray.origin, ray.direction);
    _sound();
    notifyListeners();
  }

  void _sound() {
    final s = state!, sound = s.lastSound;
    s.lastSound = null;
    if (sound == null || muted) return;
    final pool = fxPools[sound];
    if (pool != null) {
      unawaited(
        pool.start(volume: sound == 'shotgun' ? .75 : .55).then((_) {}),
      );
    }
  }

  void tick(Duration elapsed, double delta) {
    if (!ready || disposed) return;
    final s = state!, dt = delta.clamp(0.0, .05);
    final bx = s.x, bz = s.z;
    s.tick(dt);
    final moved = math.sqrt(math.pow(s.x - bx, 2) + math.pow(s.z - bz, 2));
    final motion = s.aiming
        ? s.weapon == 'shotgun'
              ? 'AimShotgun'
              : 'Aim'
        : moved > .0001
        ? s.sprint
              ? 'Run'
              : 'Walk'
        : 'Idle';
    player.setMotion(motion);
    player.update(
      dt,
      s.running,
      speed: motion == 'Walk'
          ? 1.25 / .91610738
          : motion == 'Run'
          ? 2.8 / 2.16571248
          : 1,
    );
    player.node.position = vm.Vector3(s.x, s.y, s.z);
    player.node.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      s.heading + math.pi,
    );
    for (var i = 0; i < enemies.length; i++) {
      final e = s.enemies[i], actor = enemies[i];
      actor.node.visible = e.active && (!e.dropped);
      actor.node.position = vm.Vector3(e.x, 0, e.z);
      actor.node.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        e.heading + math.pi,
      );
      final scale = e.alive ? 1.0 : math.max(.001, 1 - e.vanish / .65);
      actor.node.scale = vm.Vector3.all(scale);
      actor.setMotion(
        e.attackPending
            ? 'MugAttack'
            : e.stun > 0
            ? 'Idle'
            : 'Walk',
      );
      actor.update(
        dt,
        s.running && e.alive && e.active,
        speed: e.attackPending ? 1.5 : .8,
      );
    }
    for (final h in s.map['houses']) {
      final inside =
          (s.x - h['x']).abs() < h['w'] / 2 &&
          (s.z - h['z']).abs() < h['d'] / 2;
      village.getChildByName('Roof_${h['id']}')!.visible = !inside;
    }
    village.getChildByName('FarmGate')!.visible = !s.gateOpen;
    for (final p in s.images) {
      village.getChildByName(p['node'])!.visible = !s.collected.contains(
        p['id'],
      );
    }
    for (final c in s.crates) {
      crateNodes[c.id]!.visible = !c.broken;
    }
    const models = {
      'shotgun': 'Shotgun',
      'ammo': 'AmmoBox',
      'shells': 'ShellBox',
      'green': 'GreenHerb',
      'red': 'RedHerb',
      'yellow': 'YellowHerb',
      'key': 'Key',
    };
    for (final p in s.pickups) {
      final n = pickupNodes.putIfAbsent(p.id, () {
        final node = p.kind == 'beer'
            ? beerTemplate.clone()
            : _prop(models[p.kind]!);
        if (p.kind == 'beer') {
          node.addComponent(
            BeerMugComponent(isPaused: () => !s.running)..detail = false,
          );
        }
        scene.add(node);
        return node;
      });
      n.visible = !p.taken;
      n.position = vm.Vector3(
        p.x,
        p.y + math.sin(s.time * 2 + p.x) * .035,
        p.z,
      );
      n.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), s.time * .5);
    }
    // Authored GunSocket is baked with the two-handed aiming pose.
    final socket = player.node.getChildByName('GunSocket');
    if (socket != null) {
      pistol.localTransform = vm.Matrix4.copy(socket.globalTransform);
      shotgun.localTransform = vm.Matrix4.copy(socket.globalTransform);
    } else {
      final forward = vm.Vector3(math.sin(s.heading), 0, math.cos(s.heading));
      final right = vm.Vector3(math.cos(s.heading), 0, -math.sin(s.heading));
      final position =
          vm.Vector3(s.x, s.y + 1.22, s.z) + forward * .28 + right * .18;
      pistol.position = position;
      shotgun.position = position;
      pistol.rotation = player.node.rotation;
      shotgun.rotation = player.node.rotation;
    }
    pistol.visible = s.aiming && s.weapon == 'handgun';
    shotgun.visible = s.aiming && s.weapon == 'shotgun';
    impact.visible = s.hitFlash > 0 && s.shotEnd != null;
    if (impact.visible) impact.position = s.shotEnd!;
    _stepDistance += moved;
    if (_stepDistance > .9) {
      _stepDistance = 0;
      s.lastSound ??= 'step';
    }
    _sound();
    if (s.collectionDirty) {
      s.collectionDirty = false;
      unawaited(
        preferences!
            .setStringList('hazard.collection.v1', s.collected.toList())
            .then((ok) {
              if (!ok) s.say('記録の保存に失敗しました。');
            }),
      );
    }
    _notifyTime += dt;
    if (_notifyTime > .07) {
      _notifyTime = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disposed = true;
    for (final a in fxPools.values) {
      unawaited(a.dispose());
    }
    unawaited(ambience.dispose());
    for (final name in ['village', 'items', 'beer_mug', 'sobaya', 'fukuchan']) {
      unawaited(releaseScene('assets/models/$name.glb'));
    }
    super.dispose();
  }
}
