import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'simulation.dart';

class LabController extends ChangeNotifier {
  static const asset = 'assets/models/sobaya.glb';
  final scene = Scene();
  final simulation = LabSimulation();
  final frames = FrameSamples();
  final world = Node(name: 'Test fixtures');
  final actors = Node(name: 'Sobaya instances');
  final outlines = Node(name: 'Collision footprint');
  Node? _template;
  bool ready = false, disposed = false;
  bool shadows = true, ao = false, showCollision = true, paused = false;
  bool turntable = false, crowdMotion = false, collisionTest = false;
  int count = 1, loadMs = 0, warmupFrames = 30;
  double yaw = 0, pitch = .16, distance = 3.8, renderScale = 1;
  double inputX = 0, inputY = 0, _time = 0, testRemaining = 0;
  bool sprint = false;
  double cameraCompression = 1;
  double viewportWidth = 0, viewportHeight = 0, devicePixelRatio = 1;
  String testResult = '未実行';
  LabMode get mode => simulation.mode;
  List<Node> get models => actors.children;

  Future<void> load() async {
    final watch = Stopwatch()..start();
    await Scene.initializeStaticResources();
    final template = await loadScene(asset);
    if (disposed) {
      await releaseScene(asset);
      return;
    }
    _template = template;
    scene.add(world);
    scene.add(actors);
    scene.add(outlines);
    ready = true;
    configure();
    open(LabMode.model);
    loadMs = watch.elapsedMilliseconds;
    notifyListeners();
  }

  PhysicallyBasedMaterial material(double r, double g, double b) =>
      PhysicallyBasedMaterial()
        ..baseColorFactor = vm.Vector4(r, g, b, 1)
        ..roughnessFactor = .85
        ..metallicFactor = 0;

  void configure() {
    if (!ready) return;
    scene.environmentSettings = EnvironmentSettings(
      exposure: .95,
      ambientOcclusionEnabled: ao,
      ambientOcclusionHalfResolution: true,
      ambientOcclusionIntensity: .55,
      ambientOcclusionRadius: .35,
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.6, -1, -.5),
      intensity: 1.5,
      castsShadow: shadows,
      shadowCascadeCount: 1,
      shadowMaxDistance: 25,
      shadowMapResolution: 1024,
      shadowDepthBias: .003,
      shadowNormalBias: .008,
      shadowSoftness: .04,
      cacheStaticShadows: true,
    );
    scene.renderScale = renderScale;
  }

  void resetMeasurement() {
    frames.reset();
    warmupFrames = 30;
  }

  void open(LabMode next) {
    if (!ready) return;
    simulation.reset(next);
    inputX = 0;
    inputY = 0;
    sprint = false;
    paused = false;
    turntable = false;
    collisionTest = false;
    testRemaining = 0;
    testResult = '未実行';
    _time = 0;
    yaw = next == LabMode.movement ? math.pi : 0;
    pitch = next == LabMode.crowd ? .38 : .16;
    distance = next == LabMode.crowd
        ? 12
        : next == LabMode.movement
        ? 4.2
        : 3.8;
    count = next == LabMode.crowd ? 4 : 1;
    rebuildWorld();
    rebuildActors();
    resetMeasurement();
    notifyListeners();
  }

  void rebuildWorld() {
    world.removeAll();
    outlines.removeAll();
    final floorMat = material(.12, .15, .15), lineMat = material(.21, .25, .24);
    world.add(
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(20, .1, 20)), floorMat))
        ..position = vm.Vector3(0, -.06, 0)
        ..shadowStatic = true,
    );
    final grid = InstancedMesh(
      geometry: CuboidGeometry(vm.Vector3(.012, .004, 20)),
      material: lineMat,
    );
    for (var n = -10; n <= 10; n++) {
      grid.addInstance(
        vm.Matrix4.identity()
          ..translateByVector3(vm.Vector3(n.toDouble(), -.007, 0)),
      );
      grid.addInstance(
        vm.Matrix4.identity()
          ..translateByVector3(vm.Vector3(0, -.007, n.toDouble()))
          ..rotateY(math.pi / 2),
      );
    }
    world.add(
      Node()
        ..addComponent(InstancedMeshComponent(grid))
        ..shadowStatic = true
        ..castsShadows = false,
    );
    if (mode == LabMode.movement) {
      final blockMat = material(.19, .24, .24), trim = material(.76, .49, .17);
      for (final b in arenaBlocks) {
        world.add(
          Node(
              mesh: Mesh(
                CuboidGeometry(vm.Vector3(b.width, b.height, b.depth)),
                blockMat,
              ),
            )
            ..position = vm.Vector3(b.x, b.height / 2, b.z)
            ..shadowStatic = true,
        );
        world.add(
          Node(
              mesh: Mesh(
                CuboidGeometry(vm.Vector3(b.width + .02, .04, b.depth + .02)),
                trim,
              ),
            )
            ..position = vm.Vector3(b.x, b.height + .01, b.z)
            ..shadowStatic = true,
        );
      }
    } else if (mode == LabMode.model) {
      world.add(
        Node(
            mesh: Mesh(
              RingGeometry(innerRadius: 1.16, outerRadius: 1.18, segments: 96),
              material(.42, .65, .57),
            ),
          )
          ..position = vm.Vector3(0, .002, 0)
          ..castsShadows = false,
      );
    }
    if (showCollision) {
      outlines.add(
        Node(
            mesh: Mesh(
              RingGeometry(
                innerRadius: LabSimulation.radius - .012,
                outerRadius: LabSimulation.radius + .012,
                segments: 48,
              ),
              material(.96, .63, .19),
            ),
          )
          ..position = vm.Vector3(0, .012, 0)
          ..castsShadows = false,
      );
    }
  }

  void rebuildActors() {
    actors.removeAll();
    for (var i = 0; i < count; i++) {
      final node = _template!.clone();
      node.name = 'Sobaya_${i + 1}';
      actors.add(node);
    }
    placeActors();
  }

  void placeActors() {
    for (var i = 0; i < models.length; i++) {
      final node = models[i];
      if (mode == LabMode.crowd) {
        final columns = count == 1 ? 1 : (count <= 4 ? 2 : 4);
        final rows = (count / columns).ceil();
        final cx = (i % columns - (columns - 1) / 2) * 1.8;
        final cz = (i ~/ columns - (rows - 1) / 2) * 2.1;
        node.position = vm.Vector3(
          cx + (crowdMotion ? math.sin(_time + i) * .25 : 0),
          0,
          cz,
        );
        node.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.pi + (crowdMotion ? math.sin(_time * .5 + i) * .3 : 0),
        );
      } else {
        node.position = vm.Vector3(simulation.x, 0, simulation.z);
        node.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          // flutter_scene imports the GLB facing -Z; gameplay forward is +Z.
          simulation.heading + math.pi,
        );
      }
    }
    outlines.position = vm.Vector3(simulation.x, 0, simulation.z);
  }

  void tick(Duration elapsed, double delta) {
    if (!ready || disposed || paused) return;
    final dt = delta.clamp(0.0, .05);
    _time += dt;
    if (mode == LabMode.model && turntable) {
      yaw += dt * .35;
    }
    if (collisionTest) {
      simulation.move(0, 1, dt, sprint: true);
      testRemaining -= dt;
      if (testRemaining <= 0) {
        collisionTest = false;
        testResult =
            simulation.collisionFrames > 0 && simulation.z <= -1.64 + 1e-8
            ? 'PASS · 壁の手前で停止'
            : 'FAIL · 衝突を確認できません';
        notifyListeners();
      }
    } else {
      final forwardX = -math.sin(yaw), forwardZ = -math.cos(yaw);
      simulation.move(
        inputY * forwardX + inputX * math.cos(yaw),
        inputY * forwardZ - inputX * math.sin(yaw),
        dt,
        sprint: sprint,
      );
    }
    placeActors();
  }

  PerspectiveCamera camera() {
    final target = vm.Vector3(
      simulation.x,
      mode == LabMode.model ? .93 : 1.08,
      simulation.z,
    );
    if (mode == LabMode.crowd) target.setValues(0, .9, 0);
    final offset = vm.Vector3(
      math.sin(yaw) * math.cos(pitch) * distance,
      math.sin(pitch) * distance,
      math.cos(yaw) * math.cos(pitch) * distance,
    );
    final desired = target + offset;
    cameraCompression = simulation.cameraFraction(
      target.x,
      target.y,
      target.z,
      desired.x,
      desired.y,
      desired.z,
    );
    return PerspectiveCamera(
      position: target + offset * cameraCompression,
      target: target,
      fovRadiansY: 45 * math.pi / 180,
      fovNear: .05,
      fovFar: 60,
    );
  }

  void orbit(double dx, double dy) {
    yaw -= dx * .007;
    pitch = (pitch + dy * .006).clamp(-.15, 1.15);
  }

  void zoom(double delta) {
    distance = (distance + delta).clamp(1.5, 18);
  }

  void setView(String view) {
    yaw = switch (view) {
      'back' => math.pi,
      'side' => math.pi / 2,
      _ => 0,
    };
    pitch = .16;
    distance = mode == LabMode.crowd ? 12 : 3.8;
    notifyListeners();
  }

  void setCount(int value) {
    if (![1, 4, 8, 12].contains(value)) {
      throw ArgumentError('count must be 1,4,8,12');
    }
    if (mode != LabMode.crowd) open(LabMode.crowd);
    count = value;
    rebuildActors();
    resetMeasurement();
    notifyListeners();
  }

  void option(String key, Object value) {
    switch (key) {
      case 'shadows':
        shadows = value as bool;
      case 'ao':
        ao = value as bool;
      case 'collision':
        showCollision = value as bool;
        rebuildWorld();
      case 'paused':
        paused = value as bool;
        inputX = 0;
        inputY = 0;
      case 'turntable':
        turntable = value as bool;
      case 'motion':
        crowdMotion = value as bool;
      case 'scale':
        renderScale = (value as num).toDouble().clamp(.5, 1);
      default:
        throw ArgumentError('Unknown option: $key');
    }
    configure();
    resetMeasurement();
    notifyListeners();
  }

  void runCollisionTest() {
    open(LabMode.movement);
    collisionTest = true;
    testRemaining = 2;
    testResult = 'RUNNING · 壁へ直進';
    notifyListeners();
  }

  Map<String, Object?> inspect() => {
    'ready': ready,
    'mode': mode.name,
    'model': asset,
    'rigged': false,
    'count': count,
    'placedTriangles': 21068 * count,
    'sourceTextureSize': 4096,
    'loadMs': loadMs,
    'position': {'x': simulation.x, 'z': simulation.z},
    'distanceM': simulation.distanceTravelled,
    'colliding': simulation.collided,
    'collisionFrames': simulation.collisionFrames,
    'cameraFraction': cameraCompression,
    'cameraYaw': yaw,
    'cameraDistance': distance,
    'shadows': shadows,
    'ao': ao,
    'renderScale': renderScale,
    'paused': paused,
    'test': testResult,
    'testRunning': collisionTest,
    'frameTimings': frames.toJson(),
    'buildMode': kDebugMode
        ? 'debug'
        : kProfileMode
        ? 'profile'
        : 'release',
    'viewport': {
      'logicalWidth': viewportWidth,
      'logicalHeight': viewportHeight,
      'devicePixelRatio': devicePixelRatio,
      'renderWidth': (viewportWidth * devicePixelRatio * renderScale).round(),
      'renderHeight': (viewportHeight * devicePixelRatio * renderScale).round(),
    },
    'capturedAt': DateTime.now().toIso8601String(),
  };

  @override
  void dispose() {
    disposed = true;
    scene.root.removeAll();
    if (_template != null) {
      _template = null;
      unawaited(releaseScene(asset));
    }
    super.dispose();
  }
}
