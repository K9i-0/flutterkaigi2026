import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:madogiwa_engine/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'pour_game.dart';
import 'liquid_geometry.dart';
import 'studio_lighting.dart';

class PourScene {
  final scene = Scene();
  final camera = PerspectiveCamera(
    position: vm.Vector3(0, 1.55, 2.8),
    target: vm.Vector3(0, 1, 0),
    fovNear: .01,
    fovFar: 30,
  );
  final mug = Node(name: 'Pouring mug');
  late Node sobaya, liquid, head, stream, spout;
  late CharacterMotionPlayer motion;
  final reaction = SobayaReaction();
  late LiquidGeometry beerGeometry, foamGeometry;
  late PourJetGeometry jetGeometry;
  double jetAge = 0, lastJetFlow = .5, tailAge = 0;
  late PreprocessedMaterial foamMaterial, beerMaterial;
  final droplets = <Node>[];
  double clock = 0, zoom = 0;
  double _surfaceClock = -1, _beer = -1, _foam = -1;
  static const floor = 1.026, capacity = .180;

  PhysicallyBasedMaterial material(
    double r,
    double g,
    double b, {
    double roughness = .5,
    double metal = 0,
  }) => PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(r, g, b, 1)
    ..roughnessFactor = roughness
    ..metallicFactor = metal;
  Node mesh(
    Geometry geometry,
    Material material,
    vm.Vector3 position, {
    Node? parent,
  }) {
    final n = Node(mesh: Mesh(geometry, material))..position = position;
    (parent ?? scene.root).add(n);
    return n;
  }

  Node box(vm.Vector3 size, vm.Vector3 at, Material mat) =>
      mesh(CuboidGeometry(size), mat, at);

  Future<void> load() async {
    await Scene.initializeStaticResources();
    scene.environment = await beerStudioEnvironment();
    scene.environmentIntensity = .85;
    scene.exposure = .8;
    scene.postProcess.bloom
      ..enabled = true
      ..threshold = 2.0
      ..intensity = .045;
    scene.depthOfField
      ..enabled = true
      ..quality = DepthOfFieldQuality.medium
      ..fStop = 5.6
      ..focalLength = .050
      ..maxBackgroundBlur = 18
      ..maxForegroundBlur = 0;
    void softbox(
      vm.Vector3 at,
      double width,
      double height,
      double intensity,
      vm.Vector3 color,
    ) {
      final n = Node()
        ..position = at
        ..rotation = vm.Quaternion.fromTwoVectors(
          vm.Vector3(0, 0, 1),
          (vm.Vector3(0, 1.12, .37) - at).normalized(),
        );
      n.addComponent(
        RectAreaLightComponent(
          RectAreaLight(
            width: width,
            height: height,
            intensity: intensity,
            color: color,
          ),
        ),
      );
      scene.add(n);
    }

    softbox(vm.Vector3(-.5, 1.38, .72), .18, .55, 2.5, vm.Vector3(1, .94, .84));
    softbox(vm.Vector3(.48, 1.28, .20), .08, .60, 3.5, vm.Vector3(.80, .9, 1));
    softbox(vm.Vector3(0, 1.3, -.1), .35, .32, 2, vm.Vector3(1, .74, .38));
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.4, -.8, -.5),
      intensity: .75,
    );
    final wood = material(.115, .042, .018, roughness: .33);
    box(vm.Vector3(5, .12, 5), vm.Vector3(0, .94, .15), wood);
    box(
      vm.Vector3(7, 4, .15),
      vm.Vector3(0, 1, -1.5),
      material(.019, .033, .03),
    );
    for (var i = -5; i <= 5; i++) {
      box(
        vm.Vector3(.025, 3, .03),
        vm.Vector3(i * .48, 1.5, -1.40),
        material(.22, .12, .055),
      );
    }
    final gold = material(.72, .40, .095, metal: .72, roughness: .24);
    for (var row = 0; row < 2; row++) {
      box(
        vm.Vector3(4, .055, .24),
        vm.Vector3(0, 1.25 + row * .55, -1.25),
        wood,
      );
      for (var i = 0; i < 9; i++) {
        final x = (i - 4) * .37;
        mesh(
          CylinderGeometry(
            topRadius: .045,
            bottomRadius: .052,
            height: .22,
            radialSegments: 12,
          ),
          material(
            i.isEven ? .045 : .24,
            i.isEven ? .15 : .085,
            .04,
            roughness: .2,
          ),
          vm.Vector3(x, 1.38 + row * .55, -1.22),
        );
        mesh(
          CylinderGeometry(
            topRadius: .022,
            bottomRadius: .022,
            height: .08,
            radialSegments: 12,
          ),
          gold,
          vm.Vector3(x, 1.53 + row * .55, -1.22),
        );
      }
    }
    for (final x in [-.95, .95]) {
      mesh(
        SphereGeometry(radius: .13, segments: 16, rings: 10),
        material(1, .61, .19),
        vm.Vector3(x, 2.1, -.5),
      );
      box(vm.Vector3(.014, .9, .014), vm.Vector3(x, 2.65, -.5), gold);
    }
    sobaya = await loadScene('assets/models/sobaya.glb');
    sobaya.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    sobaya.position = vm.Vector3(0, 0, -.48);
    scene.add(sobaya);
    sobaya.getChildByName('Head')?.addComponent(reaction);
    motion = CharacterMotionPlayer(sobaya, sources: const {'Idle': 'Idle'});
    final glass = await loadScene('assets/models/beer_mug.glb');
    for (final name in ['BeerVolume', 'LiquidSurface', 'Foam', 'Carbonation']) {
      glass.getChildByName(name)?.visible = false;
    }
    mug.position = vm.Vector3(0, 1, .37);
    mug.add(glass);
    scene.add(mug);
    // Real dielectric interfaces: clear glass, water-like IOR beer and
    // wavelength-dependent absorption through the liquid path.
    for (final name in ['GlassBody', 'Handle']) {
      final node = glass.getChildByName(name);
      final glassMat = material(1, 1, 1, roughness: .045)
        ..transmission = 1
        ..ior = 1.52
        ..thickness = name == 'Handle' ? .018 : .007
        ..attenuationColor = vm.Vector4(.95, .985, .98, 1)
        ..attenuationDistance = 1.5;
      for (final primitive in node?.mesh?.primitives ?? <MeshPrimitive>[]) {
        primitive.material = glassMat;
      }
    }
    final beerMat = material(1, 1, 1, roughness: .085)
      ..transmission = .94
      ..ior = 1.333
      ..thickness = .105
      ..attenuationColor = vm.Vector4(.96, .52, .095, 1)
      ..attenuationDistance = .095;
    final wetGlass = material(1, 1, 1, roughness: .035)
      ..transmission = .8
      ..ior = 1.333
      ..thickness = .001;
    mesh(condensationGeometry(), wetGlass, vm.Vector3.zero(), parent: mug);
    beerGeometry = LiquidGeometry();
    foamGeometry = LiquidGeometry();
    foamMaterial = await loadFmatMaterial('assets/materials/beer_foam.fmat');
    beerMaterial = await loadFmatMaterial('assets/materials/beer_volume.fmat');
    liquid = mesh(
      beerGeometry.geometry,
      beerMaterial,
      vm.Vector3.zero(),
      parent: mug,
    );
    head = mesh(
      foamGeometry.geometry,
      foamMaterial,
      vm.Vector3.zero(),
      parent: mug,
    );
    final bubbleMesh = SphereGeometry(radius: 1, segments: 8, rings: 6);
    for (var i = 0; i < 18; i++) {
      droplets.add(mesh(bubbleMesh, beerMat, vm.Vector3.zero()));
    }
    jetGeometry = PourJetGeometry();
    final jetMaterial = material(.98, .68, .20, roughness: .055)
      ..transmission = .45
      ..ior = 1.333
      ..thickness = .006;
    stream = mesh(jetGeometry.geometry, jetMaterial, vm.Vector3.zero());
    // A brass tap keeps the view clear; its handle follows the phone angle.
    box(vm.Vector3(.055, .055, .24), vm.Vector3(.10, 1.50, .23), gold);
    spout = mesh(
      CylinderGeometry(
        topRadius: .021,
        bottomRadius: .021,
        height: .10,
        radialSegments: 20,
      ),
      gold,
      vm.Vector3(.10, 1.46, .35),
    );
    mesh(
      CylinderGeometry(
        topRadius: .055,
        bottomRadius: .055,
        height: .45,
        radialSegments: 20,
      ),
      gold,
      vm.Vector3(.32, 1.29, .1),
    );
    box(vm.Vector3(.012, .12, .012), vm.Vector3(.32, 1.59, .14), wood);
    box(vm.Vector3(.24, .055, .055), vm.Vector3(.21, 1.50, .1), gold);
    // Coaster and subtle 70% fill marker etched on the glass side.
    mesh(
      CylinderGeometry(
        topRadius: .092,
        bottomRadius: .092,
        height: .007,
        radialSegments: 48,
      ),
      material(.018, .023, .021, roughness: .82),
      vm.Vector3(0, 1.003, .37),
    );
    update(PourGame(), 0);
  }

  void advance(PourGame g, double dt) {
    clock += dt;
    if (g.flow > 0) {
      jetAge += dt;
      tailAge = 0;
      lastJetFlow = g.flow;
    } else {
      jetAge = 0;
      tailAge += dt;
    }
    reaction.game = g;
    motion.controller.advance(dt);
  }

  void update(PourGame g, double dt) {
    motion.sample();
    final close =
        g.phase == PourPhase.pouring ||
        g.phase == PourPhase.settling ||
        g.phase == PourPhase.approach;
    final targetZoom = close ? 1.0 : 0.0;
    zoom += (targetZoom - zoom) * (1 - math.exp(-dt * 3));
    // Wider portrait framing leaves the mug unobscured by top/bottom UI.
    camera.position = vm.Vector3(
      .035 * zoom,
      1.48 + (1.37 - 1.48) * zoom,
      2.7 + (1.14 - 2.7) * zoom,
    );
    camera.target = vm.Vector3(
      .035 * zoom,
      1.24 + (1.12 - 1.24) * zoom,
      .05 + (.37 - .05) * zoom,
    );
    scene.depthOfField.focusDistance =
        (camera.position - vm.Vector3(0, 1.13, .37)).length;
    if (g.phase == PourPhase.result && g.angry) {
      final pulse = math.exp(-g.phaseTime * 2);
      sobaya.position = vm.Vector3(
        math.sin(clock * 35) * .018 * pulse,
        0,
        -.48 + .18 * pulse,
      );
      camera.position.x += math.sin(clock * 43) * .008 * pulse;
    } else {
      sobaya.position = vm.Vector3(0, 0, -.48);
    }
    final b = g.beer.clamp(0, 1) * capacity, f = g.foam.clamp(0, 1) * capacity;
    liquid.visible = b > .0001;
    head.visible = f > .0001;
    if (g.surface.clock != _surfaceClock || b != _beer || f != _foam) {
      if (liquid.visible) {
        beerGeometry.update(
          g.surface,
          bottom: .027,
          top: .027 + b,
          foam: false,
        );
      }
      if (head.visible) {
        foamGeometry.update(
          g.surface,
          bottom: .027 + b,
          top: .027 + b + f,
          foam: true,
        );
      }
      _surfaceClock = g.surface.clock;
      _beer = b;
      _foam = f;
    }
    foamMaterial.parameters.setFloat('time', clock);
    beerMaterial.parameters.setFloat('time', clock);
    beerMaterial.parameters.setFloat('agitation', g.agitation);
    stream.visible = g.flow > 0 || g.airborne > .00001;
    final startT = g.flow > 0
        ? 0.0
        : (tailAge / PourGame.flightTime).clamp(0.0, 1.0);
    final endT = g.flow > 0
        ? (jetAge / PourGame.flightTime).clamp(.01, 1.0)
        : 1.0;
    if (stream.visible) {
      jetGeometry.update(
        1.029 + b + f,
        lastJetFlow,
        clock,
        math.min(startT, endT),
        endT,
      );
    }
    for (var i = 0; i < droplets.length; i++) {
      final spill = g.spilled && g.phaseTime < 1.3;
      final t = spill
          ? g.phaseTime + (i % 4) * .05
          : (clock * 1.8 + i * .137) % 1;
      final a = i * 2.39996;
      droplets[i]
        ..visible = spill || (g.arrival > .08 && i < 8)
        ..position = vm.Vector3(
          math.cos(a) * (.025 + t * .09),
          1.03 + b + f + t * .07 - t * t * .19,
          .37 + math.sin(a) * (.025 + t * .09),
        )
        ..scale = vm.Vector3(.0015, .003, .0015);
    }
  }
}

/// A restrained head gesture on the existing rig, after its parent animation
/// has sampled. The canonical mask and face geometry remain unchanged.
class SobayaReaction extends Component {
  PourGame? game;
  late vm.Quaternion rest;
  @override
  void onAttach() {
    rest = node.rotation.clone();
  }

  @override
  void update(double deltaSeconds) {
    final g = game;
    if (g == null || g.phase != PourPhase.result) return;
    final t = g.phaseTime;
    final angle = g.angry
        ? math.sin(t * 14) * .20 * math.exp(-t * .65)
        : math.sin(t * 5) * .13 * math.exp(-t * .7);
    node.rotation =
        rest *
        vm.Quaternion.axisAngle(
          g.angry ? vm.Vector3(0, 0, 1) : vm.Vector3(1, 0, 0),
          angle,
        );
  }
}
