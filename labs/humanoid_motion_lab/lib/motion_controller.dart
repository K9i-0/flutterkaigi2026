import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'catalog.dart';

class MotionSlot {
  MotionSlot(this.profile, this.method, this.entry, Node template, double x)
    : root = Node(name: '${profile.id}-${method.name}'),
      model = template.clone() {
    root.position = vm.Vector3(x, 0, 0);
    root.add(model);
    // The imported characters face -Z; turn toward the front camera.
    model.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    if (entry != null) {
      final animation = model.findAnimationByName(entry!.name);
      if (animation == null) {
        throw StateError('Missing ${entry!.name} on ${profile.id}');
      }
      if ((animation.endTime - entry!.duration).abs() > .07) {
        throw StateError('Duration mismatch: ${entry!.name}');
      }
      clip = model.createAnimationClip(animation)..loop = false;
      clip!.pause();
    } else {
      model.visible = false;
    }
  }
  final BodyProfile profile;
  final MotionMethod method;
  final MotionEntry? entry;
  final Node root, model;
  AnimationClip? clip;
  final List<(Node, Node)> boneLines = [];
}

class MotionController extends ChangeNotifier {
  final scene = Scene();
  final actors = Node(name: 'Motion comparison');
  final poseSignal = ChangeNotifier();
  final clock = MotionClock();
  final templates = <String, Node>{};
  final List<String> _claimed = [];
  List<BodyProfile> profiles = [];
  List<MotionSlot> slots = [];
  MotionMethod method = MotionMethod.hybrid;
  String action = 'Walk', character = 'sobaya';
  bool compareMethods = false,
      skeleton = false,
      ready = false,
      disposed = false;
  bool syncPhase = true;
  double yaw = 0, pitch = .13, distance = 4.4, viewAngle = 0;

  BodyProfile get selectedBody => profiles.firstWhere((p) => p.id == character);
  MotionEntry get selected => selectedBody.find(method, action)!;
  double get duration => ready ? selected.duration : 1;
  List<MotionEntry> get entries =>
      ready ? selectedBody.clips.where((e) => e.method == method).toList() : [];

  Future<void> load() async {
    final raw = jsonDecode(
      await rootBundle.loadString('assets/catalog.json'),
    ) as Map<String, dynamic>;
    if (raw['preview'] == true) debugPrint('Motion lab: preview subset');
    profiles = (raw['characters'] as List)
        .map((e) => BodyProfile(e as Map<String, dynamic>))
        .toList();
    await Scene.initializeStaticResources();
    for (final profile in profiles) {
      final node = await loadScene(profile.asset);
      if (disposed) {
        await releaseScene(profile.asset);
        return;
      }
      _claimed.add(profile.asset);
      templates[profile.id] = node;
    }
    if (disposed) return;
    scene.environmentSettings = EnvironmentSettings(
      exposure: 1.05,
      ambientOcclusionEnabled: false,
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.5, -1, -.7),
      intensity: 1.7,
      castsShadow: true,
      shadowCascadeCount: 1,
      shadowMapResolution: 1024,
      shadowMaxDistance: 20,
      shadowDepthBias: .002,
      shadowNormalBias: .005,
      cacheStaticShadows: true,
    );
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: vm.Vector3(.055, .085, .12),
        horizonColor: vm.Vector3(.17, .22, .27),
        groundColor: vm.Vector3(.07, .09, .12),
        sunColor: vm.Vector3.zero(),
      ),
    );
    final floor = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.105, .13, .16, 1)
      ..roughnessFactor = .92;
    scene.add(
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(40, .08, 40)), floor))
        ..position = vm.Vector3(0, -.05, 0)
        ..shadowStatic = true,
    );
    final lines = InstancedMesh(
      geometry: CuboidGeometry(vm.Vector3(.007, .003, 20)),
      material: PhysicallyBasedMaterial()
        ..baseColorFactor = vm.Vector4(.23, .29, .34, 1),
    );
    for (var n = -20; n <= 20; n++) {
      lines.addInstance(vm.Matrix4.translationValues(n / 2, -.007, 0));
      lines.addInstance(
        vm.Matrix4.translationValues(0, -.007, n / 2)..rotateY(math.pi / 2),
      );
    }
    scene.add(
      Node()
        ..addComponent(InstancedMeshComponent(lines))
        ..castsShadows = false,
    );
    scene.add(actors);
    ready = true;
    rebuild();
  }

  void rebuild() {
    if (!ready) return;
    actors.removeAll();
    slots.clear();
    final choices = compareMethods
        ? [for (final m in MotionMethod.values) (selectedBody, m)]
        : [for (final p in profiles) (p, method)];
    for (var i = 0; i < choices.length; i++) {
      final (body, m) = choices[i];
      final slot = MotionSlot(
        body,
        m,
        body.find(m, action),
        templates[body.id]!,
        ((choices.length - 1) / 2 - i) * (compareMethods ? 1.45 : 1.7),
      );
      slot.model.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        math.pi + viewAngle,
      );
      slots.add(slot);
      actors.add(slot.root);
      final joints = body.boneMap.values.toSet();
      for (final name in joints) {
        final joint = slot.model.getChildByName(name);
        if (joint == null) throw StateError('Missing joint $name');
        final parent = joint.parent;
        if (parent == null || !joints.contains(parent.name)) continue;
        slot.boneLines.add((parent, joint));
      }
    }
    clock.seconds = 0;
    clock.repeat = selected.loop;
    pose();
    notifyListeners();
  }

  void chooseMethod(MotionMethod value) {
    method = value;
    if (selectedBody.find(method, action) == null) {
      action = selectedBody.clips.firstWhere((e) => e.method == method).action;
    }
    rebuild();
  }

  void choose(String value) {
    if (selectedBody.find(method, value) == null) {
      throw ArgumentError.value(value);
    }
    action = value;
    clock.paused = false;
    rebuild();
  }

  void layout(bool value) {
    compareMethods = value;
    distance = value ? 6.5 : 4.4;
    rebuild();
  }

  void setCharacter(String value) {
    if (!profiles.any((p) => p.id == value)) throw ArgumentError.value(value);
    character = value;
    if (selectedBody.find(method, action) == null) {
      action = entries.first.action;
    }
    rebuild();
  }

  void tick(Duration elapsed, double delta) {
    if (!ready || disposed) return;
    final wasPaused = clock.paused;
    clock.advance(delta, duration);
    pose();
    if (clock.paused != wasPaused) {
      scheduleMicrotask(() {
        if (!disposed) notifyListeners();
      });
    }
  }

  void pose() {
    for (final slot in slots) {
      final entry = slot.entry;
      if (entry != null) {
        slot.clip!.seek(
          syncPhase ? clock.seconds / duration * entry.duration : clock.seconds,
        );
      }
    }
    scene.update(0);
    poseSignal.notifyListeners();
  }

  void seek(double seconds) {
    clock.seek(seconds, duration);
    pose();
    notifyListeners();
  }

  void replay() {
    clock.seconds = 0;
    clock.paused = false;
    pose();
    notifyListeners();
  }

  void togglePause() {
    if (clock.paused && clock.seconds >= duration) clock.seconds = 0;
    clock.paused = !clock.paused;
    notifyListeners();
  }

  void setSkeleton(bool value) {
    skeleton = value;
    pose();
    notifyListeners();
  }

  void setView(String view) {
    viewAngle = switch (view) {
      'side' => math.pi / 2,
      'back' => math.pi,
      _ => 0,
    };
    yaw = 0;
    pitch = .13;
    for (final slot in slots) {
      slot.model.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        math.pi + viewAngle,
      );
    }
    pose();
    notifyListeners();
  }

  void orbit(double dx, double dy) {
    yaw -= dx * .007;
    pitch = (pitch + dy * .005).clamp(-.05, .9);
    if (clock.paused) {
      poseSignal.notifyListeners();
      notifyListeners();
    }
  }

  void zoom(double delta) {
    distance = (distance + delta * .006).clamp(2.8, 14);
    if (clock.paused) {
      poseSignal.notifyListeners();
      notifyListeners();
    }
  }

  PerspectiveCamera camera() => PerspectiveCamera(
    position: vm.Vector3(
      math.sin(yaw) * math.cos(pitch) * distance,
      1 + math.sin(pitch) * distance,
      math.cos(yaw) * math.cos(pitch) * distance,
    ),
    target: vm.Vector3(0, .95, 0),
    fovRadiansY: math.pi / 4,
    fovNear: .04,
    fovFar: 60,
  );

  Map<String, Object?> inspect() => {
    'ready': ready,
    'motionMethod': method.name,
    'action': action,
    'seconds': clock.seconds,
    'duration': duration,
    'paused': clock.paused,
    'repeat': clock.repeat,
    'speed': clock.speed,
    'compareMethods': compareMethods,
    'syncPhase': syncPhase,
    'skeleton': skeleton,
    'actors': [
      for (final s in slots)
        {
          'character': s.profile.id,
          'method': s.method.name,
          'clip': s.entry?.name,
          'sampleSeconds': s.clip?.playbackTime,
          'bones': s.profile.bones,
          'legM': s.profile.leg,
          'armM': s.profile.arm,
          'shoulderM': s.profile.shoulder,
          'ankles': {
            for (final side in ['l', 'r'])
              side: s.model
                  .getChildByName(s.profile.boneMap['foot_$side']!)!
                  .globalTransform
                  .getTranslation()
                  .storage
                  .toList(),
          },
        },
    ],
    'counts': {
      for (final m in MotionMethod.values)
        m.name: ready
            ? selectedBody.clips.where((e) => e.method == m).length
            : 0,
    },
  };

  @override
  void dispose() {
    disposed = true;
    scene.root.removeAll();
    for (final asset in _claimed) {
      unawaited(releaseScene(asset));
    }
    _claimed.clear();
    templates.clear();
    slots.clear();
    poseSignal.dispose();
    super.dispose();
  }
}
