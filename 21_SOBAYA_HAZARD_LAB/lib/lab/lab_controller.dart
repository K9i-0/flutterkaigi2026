import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'simulation.dart';
import 'motion_catalog.dart';
import 'rig_actor.dart';

class LabController extends ChangeNotifier {
  static const asset = 'assets/models/sobaya.glb';
  static const propAsset = 'assets/models/beer_mug.glb';
  final scene = Scene();
  final simulation = LabSimulation();
  final frames = FrameSamples();
  final world = Node(name: 'Test fixtures');
  final actors = Node(name: 'Sobaya instances');
  final outlines = Node(name: 'Collision footprint');
  Node? _template;
  Node? _propTemplate;
  final List<RigActor> rigs = [];
  String selectedMotion = 'Idle';
  bool animationPaused = false, mugEquipped = false, zombieLocomotion = false;
  double animationSpeed = 1, beerFill = 1;
  String focusView = 'body', backdropStyle = 'studio';
  final backdrop = Node(name: 'Transmission backdrop');
  String? movementAction;
  RigActor? get firstRig => rigs.isEmpty ? null : rigs.first;
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
    final prop = await loadScene(propAsset);
    if (disposed) {
      await releaseScene(asset);
      await releaseScene(propAsset);
      return;
    }
    _template = template;
    _propTemplate = prop;
    scene.add(world);
    scene.add(backdrop);
    scene.add(actors);
    scene.add(outlines);
    ready = true;
    // Transmission samples the 3D color buffer, not the Flutter widget behind
    // it. Draw a real background so glass above the floor does not turn black.
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: vm.Vector3(.12, .16, .17),
        horizonColor: vm.Vector3(.28, .33, .32),
        groundColor: vm.Vector3(.08, .10, .10),
        sunColor: vm.Vector3.zero(),
      ),
    );
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
    focusView = 'body';
    inputX = 0;
    inputY = 0;
    sprint = false;
    paused = false;
    animationPaused = false;
    movementAction = null;
    if (next == LabMode.movement) mugEquipped = false;
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
    rigs.clear();
    for (var i = 0; i < count; i++) {
      final rig = RigActor(_template!, _propTemplate!, 'Sobaya_${i + 1}');
      rig.setMotion(
        mode == LabMode.movement ? 'Idle' : selectedMotion,
        immediate: true,
      );
      rig.mug.visible = mugEquipped;
      rig.beer.fill = beerFill;
      rig.speed = animationSpeed;
      rig.setPaused(animationPaused);
      // Separate phases exercise independently cloned skeletons in the crowd.
      if (mode == LabMode.crowd && rig.active.loop) {
        rig.active.seek(i * .13 % rig.duration);
      }
      rigs.add(rig);
      actors.add(rig.root);
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
    final beforeX = simulation.x, beforeZ = simulation.z;
    _time += dt;
    for (final rig in rigs) {
      rig.update(dt);
    }
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
    } else if (movementAction == null) {
      final forwardX = -math.sin(yaw), forwardZ = -math.cos(yaw);
      // Flutter Scene's view uses right = up × forward.
      // Match that basis so right input stays screen-right at every orbit angle.
      simulation.move(
        (inputY * forwardX - inputX * math.cos(yaw)) *
            (zombieLocomotion ? .25 : 1),
        (inputY * forwardZ + inputX * math.sin(yaw)) *
            (zombieLocomotion ? .25 : 1),
        dt,
        sprint: sprint,
      );
    }
    if (mode == LabMode.movement && firstRig != null) {
      if (movementAction != null && firstRig!.finished) {
        movementAction = null;
        mugEquipped = false;
        for (final rig in rigs) {
          rig.mug.visible = false;
        }
      }
      if (movementAction == null) {
        final travelled = math.sqrt(
          math.pow(simulation.x - beforeX, 2) +
              math.pow(simulation.z - beforeZ, 2),
        );
        final moving = travelled > .00001;
        final name = !moving
            ? 'Idle'
            : zombieLocomotion
            ? 'ZombieWalk'
            : sprint || collisionTest
            ? 'Run'
            : 'Walk';
        for (final rig in rigs) {
          rig.setMotion(name);
          const groundSpeed = {
            'Walk': 1.007474632,
            'Run': 2.381708109,
            'ZombieWalk': .196078431,
          };
          rig.speed = moving && dt > 0
              ? (travelled / dt) / groundSpeed[name]!
              : 1;
        }
      }
    }
    placeActors();
  }

  void selectMotion(String name) {
    final spec = motionSpec(name);
    selectedMotion = name;
    animationPaused = false;
    mugEquipped = spec.mug;
    if (mode == LabMode.movement) {
      if (['Idle', 'Walk', 'Run', 'ZombieWalk'].contains(name)) {
        zombieLocomotion = name == 'ZombieWalk';
        movementAction = null;
      } else {
        // Emotes play once in the movement test; the preview preserves loops.
        movementAction = name;
      }
    }
    for (final rig in rigs) {
      rig.setPaused(false);
      rig.setMotion(name, replay: true);
      rig.active.loop = mode == LabMode.movement && movementAction != null
          ? false
          : spec.loop;
      rig.mug.visible = mugEquipped;
      rig.beer.fill = beerFill;
    }
    resetMeasurement();
    notifyListeners();
  }

  void pauseAnimation(bool value) {
    animationPaused = value;
    for (final rig in rigs) {
      rig.setPaused(value);
    }
    notifyListeners();
  }

  void seekAnimation(double seconds) {
    animationPaused = true;
    for (final rig in rigs) {
      rig.seek(seconds);
    }
    notifyListeners();
  }

  void setAnimationSpeed(double speed) {
    if (!speed.isFinite || speed < .25 || speed > 2) {
      throw ArgumentError('speed=.25..2');
    }
    animationSpeed = speed;
    for (final rig in rigs) {
      rig.speed = speed;
    }
    notifyListeners();
  }

  void equipMug(bool value) {
    mugEquipped = value;
    for (final rig in rigs) {
      rig.mug.visible = value;
    }
    notifyListeners();
  }

  PerspectiveCamera camera() {
    final target = vm.Vector3(
      simulation.x,
      mode == LabMode.model ? .93 : 1.08,
      simulation.z,
    );
    if (mode == LabMode.crowd) target.setValues(0, .9, 0);
    if (mode == LabMode.model && focusView == 'face') target.y = 1.66;
    if (mode == LabMode.model && focusView == 'grip' && firstRig != null) {
      target.setFrom(
        firstRig!.mug.getChildByName('Grip')!.globalTransform.getTranslation(),
      );
    }
    for (final rig in rigs) {
      rig.beer.detail = distance < 5;
    }
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
    distance = (distance + delta).clamp(.3, 18);
  }

  void setView(String view) {
    focusView = ['face', 'grip'].contains(view) ? view : 'body';
    yaw = switch (view) {
      'back' => math.pi,
      'side' => math.pi / 2,
      _ => 0,
    };
    pitch = .16;
    distance = focusView == 'face'
        ? .6
        : focusView == 'grip'
        ? .7
        : mode == LabMode.crowd
        ? 12
        : 3.8;
    notifyListeners();
  }

  void setBackdrop(String style) {
    if (!['studio', 'dark', 'light', 'pattern'].contains(style)) {
      throw ArgumentError('Invalid backdrop');
    }
    backdropStyle = style;
    backdrop.removeAll();
    if (style != 'studio') {
      final light = style == 'light';
      final color = light ? .75 : .015;
      backdrop.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(6, 5, .02)),
            material(color, color, color),
          ),
        )..position = vm.Vector3(0, 2, -1),
      );
      if (style == 'pattern') {
        final tiles = InstancedMesh(
          geometry: CuboidGeometry(vm.Vector3(.24, .24, .025)),
          material: material(.8, .65, .32),
        );
        for (var x = -12; x <= 12; x++) {
          for (var y = 0; y < 20; y++) {
            if ((x + y).isEven) {
              tiles.addInstance(
                vm.Matrix4.translation(vm.Vector3(x * .25, y * .25, -.98)),
              );
            }
          }
        }
        backdrop.add(Node()..addComponent(InstancedMeshComponent(tiles)));
      }
    }
    notifyListeners();
  }

  void setBeerFill(double value) {
    beerFill = value.clamp(0, 1);
    for (final rig in rigs) {
      rig.beer.fill = beerFill;
      rig.beer.reset();
    }
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
        pauseAnimation(paused);
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
    'rigged': true,
    'boneCount': 45,
    'motion': firstRig?.inspect(),
    'actorMotions': [for (final rig in rigs) rig.inspect()],
    'availableMotions': motions.map((m) => m.name).toList(),
    'propAsset': propAsset,
    'count': count,
    'placedTriangles': (28576 + (mugEquipped ? 8276 : 0)) * count,
    'sourceTextureSize': 4096,
    'loadMs': loadMs,
    'position': {'x': simulation.x, 'z': simulation.z},
    'distanceM': simulation.distanceTravelled,
    'colliding': simulation.collided,
    'collisionFrames': simulation.collisionFrames,
    'cameraFraction': cameraCompression,
    'cameraYaw': yaw,
    'focusView': focusView,
    'backdrop': backdropStyle,
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
    rigs.clear();
    if (_template != null) {
      _template = null;
      unawaited(releaseScene(asset));
    }
    if (_propTemplate != null) {
      _propTemplate = null;
      unawaited(releaseScene(propAsset));
    }
    super.dispose();
  }
}
