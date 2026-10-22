import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'stage_time.dart';
import 'graphics_settings.dart';

/// Traffic groups exported by `tool/build_akasaka_stage.py`. Each mesh repeats
/// with [period] along [axis], so scrolling by `(clock * speed) mod period`
/// never shows a seam. Axes are (x, z) in the imported node space, where the
/// importer flips the exporter's z.
const _traffic = {
  'traffic_zpos': (axis: (0.0, -1.0), speed: 3.2, period: 24.0),
  'traffic_zneg': (axis: (0.0, 1.0), speed: 2.9, period: 24.0),
  'traffic_xpos': (axis: (1.0, 0.0), speed: 2.4, period: 30.0),
  'traffic_xneg': (axis: (-1.0, 0.0), speed: 2.2, period: 30.0),
  'traffic_hwy_xpos': (axis: (1.0, 0.0), speed: 5.2, period: 27.0),
  'traffic_hwy_xneg': (axis: (-1.0, 0.0), speed: 4.8, period: 27.0),
};

/// Emission per stage material: (red, green, blue) tint times strength.
typedef _Glow = (double, double, double, double);

class _Preset {
  const _Preset({
    required this.zenith,
    required this.horizon,
    required this.ground,
    required this.fog,
    required this.fogStart,
    required this.fogEnd,
    required this.sun,
    required this.sunColor,
    required this.sunIntensity,
    required this.shadows,
    required this.environment,
    required this.exposure,
    required this.bloom,
    required this.workLight,
  });
  final (double, double, double) zenith, horizon, ground, fog, sun, sunColor;
  final double fogStart, fogEnd, sunIntensity, environment, exposure;
  final double bloom, workLight;
  final bool shadows;
}

const _signs = ['akasaka', 'izakaya', 'soba', 'shika', 'bengoshi', 'fudosan'];
const _ads = [
  'ad_exam',
  'ad_accidenchua',
  'ad_safety',
  'ad_yumemin',
  'ad_recruit',
];

Map<String, _Glow> _glow({
  required double windows,
  required double signs,
  required double ads,
  required double lamps,
  required double cars,
  required double crown,
  required double skyline,
  required _Glow tower,
  required _Glow towerWhite,
  required _Glow deck,
  double markings = 0,
}) => {
  for (var i = 0; i < 6; i++) 'facade$i': (1, 1, 1, windows),
  for (final n in _signs) n: (1, 1, 1, signs),
  for (final n in _ads) n: (1, 1, 1, ads),
  for (final n in _traffic.keys) n: (1, 1, 1, cars),
  'lamp': (1, .78, .45, lamps),
  'crown': (.95, .9, .8, crown),
  'skyline': (1, 1, 1, skyline),
  'tower': tower,
  'white': towerWhite,
  'light': deck,
  'marking': (.85, .84, .8, markings),
  'yellowline': (.95, .66, .18, markings),
};

const _presets = {
  StageTime.day: _Preset(
    zenith: (.10, .32, .78),
    horizon: (.62, .78, .95),
    ground: (.34, .36, .38),
    fog: (.70, .80, .93),
    fogStart: 60,
    fogEnd: 220,
    sun: (.62, -.58, -.52),
    sunColor: (1, .95, .86),
    sunIntensity: 4.2,
    shadows: true,
    environment: .55,
    exposure: 1.0,
    bloom: 0,
    workLight: 0,
  ),
  StageTime.night: _Preset(
    zenith: (.008, .012, .035),
    horizon: (.05, .045, .10),
    ground: (.02, .02, .03),
    fog: (.045, .045, .085),
    fogStart: 30,
    fogEnd: 125,
    sun: (-.3, -1, -.45),
    sunColor: (.62, .72, 1),
    sunIntensity: .8,
    shadows: false,
    environment: .5,
    exposure: 1.25,
    bloom: .20,
    workLight: 10,
  ),
};

Map<String, _Glow> _glowFor(StageTime t) => switch (t) {
  StageTime.day => _glow(
    windows: 0,
    signs: .12,
    ads: .08,
    lamps: 0,
    cars: .3,
    crown: 0,
    skyline: 0,
    tower: (0, 0, 0, 0),
    towerWhite: (0, 0, 0, 0),
    deck: (1, .62, .24, .1),
  ),
  // Night light-up: windows, crowns and the tower's orange landmark lighting.
  StageTime.night => _glow(
    windows: 1.25,
    signs: 1.3,
    ads: 1.2,
    lamps: 3,
    cars: 2.6,
    crown: 3.2,
    skyline: 1.6,
    tower: (1, .34, .075, 1.7),
    towerWhite: (1, .80, .52, 1.5),
    deck: (1, .72, .42, 2.3),
    markings: .05,
  ),
};

vm.Vector3 _v((double, double, double) c) => vm.Vector3(c.$1, c.$2, c.$3);

/// Switches sky, fog, sun, shadows and emissive light-up of the Akasaka GLB,
/// and scrolls its traffic groups.
class StageLighting {
  StageLighting(
    this.stage,
    this.workLights,
    this.studioEnvironment,
    this.cityMaps,
  ) {
    void visit(Node node) {
      final mesh = node.mesh;
      if (mesh != null) {
        for (final p in mesh.primitives) {
          final m = p.material;
          if (m is PhysicallyBasedMaterial) {
            (_materials[node.name] ??= []).add(m);
            _surfaces[m] = (
              normal: m.normalTexture,
              mr: m.metallicRoughnessTexture,
              metal: m.metallicFactor,
              rough: m.roughnessFactor,
            );
          }
        }
        if (_traffic.containsKey(node.name)) {
          _trafficNodes[node] = _traffic[node.name]!;
        } else {
          // Lets the shadow cache keep the 30k-face city out of every frame.
          node.shadowStatic = true;
          if (node.name == 'street') {
            node.shadowCastingMode = ShadowCastingMode.off;
          }
        }
      }
      node.children.forEach(visit);
    }

    visit(stage);
  }

  final Node stage;
  final List<PointLight> workLights;
  final _materials = <String, List<PhysicallyBasedMaterial>>{};
  final _trafficNodes =
      <Node, ({(double, double) axis, double speed, double period})>{};
  final EnvironmentMap studioEnvironment;
  final Map<StageTime, EnvironmentMap> cityMaps;
  final _surfaces =
      <
        PhysicallyBasedMaterial,
        ({TextureSource? normal, TextureSource? mr, double metal, double rough})
      >{};
  GraphicsSettings graphics = GraphicsSettings.standard;
  (StageTime, bool, GraphicsSettings)? _applied;
  StageTime time = StageTime.day;
  double viewportLongestSide = 1440;
  double get renderScale => graphics.renderScaleFor(viewportLongestSide);

  void configureRenderer(Scene scene) {
    scene
      ..renderScale = renderScale
      ..antiAliasingMode = graphics.fullResolution
          ? AntiAliasingMode.auto
          : AntiAliasingMode.fxaa;
  }

  Map<String, Object?> inspect() => {
    'timeOfDay': time.id,
    'graphics': graphics.toMap(),
    'renderScale': renderScale,
    'reflectionMode': graphics.reflections ? 'static-city-ibl' : 'matte',
    'stageNodes': _materials.keys.toList()..sort(),
    'traffic': {
      for (final e in _trafficNodes.entries)
        e.key.name: [
          e.key.localTransform.getTranslation().x,
          e.key.localTransform.getTranslation().z,
        ],
    },
  };

  void _setGlow(String name, _Glow g) {
    for (final m in _materials[name] ?? const <PhysicallyBasedMaterial>[]) {
      m.emissiveFactor = vm.Vector4(g.$1 * g.$4, g.$2 * g.$4, g.$3 * g.$4, 1);
      m.emissiveStrength = 1;
    }
  }

  /// Applies [time] once per change; [lane] false restores the plane rig.
  void apply(Scene scene, {required bool lane}) {
    if (_applied == (time, lane, graphics)) return;
    _applied = (time, lane, graphics);
    configureRenderer(scene);
    // Individual car shadows are subpixel from the 200m-high play area.
    // Cars still move and receive city shadows; keep their casting in high quality.
    for (final node in _trafficNodes.keys) {
      node.shadowCastingMode = graphics.fullResolution
          ? ShadowCastingMode.on
          : ShadowCastingMode.off;
    }
    // Sources remain shared/loaded, but the disabled textures are no longer
    // sampled by the material. No per-frame allocations or reflection pass.
    for (final e in _surfaces.entries) {
      final m = e.key, saved = e.value;
      m.normalTexture = graphics.surfaceDetail ? saved.normal : null;
      m.metallicRoughnessTexture = graphics.reflections ? saved.mr : null;
      m.metallicFactor = graphics.reflections ? saved.metal : 0;
      m.roughnessFactor = graphics.reflections ? saved.rough : .9;
    }
    if (!lane) {
      scene.environment = studioEnvironment;
      scene.skybox = null;
      scene.fog.enabled = false;
      scene.directionalLight = DirectionalLight(
        direction: vm.Vector3(-.5, -1, -.3),
        intensity: 2.4,
      );
      scene.environmentIntensity = 1.1;
      scene.exposure = 1.15;
      scene.postProcess.bloom.enabled = false;
      for (final l in workLights) {
        l.intensity = 0;
      }
      return;
    }
    scene.environment = cityMaps[time];
    final p = _presets[time]!;
    final sun = _v(p.sun).normalized();
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: _v(p.zenith),
        horizonColor: _v(p.horizon),
        groundColor: _v(p.ground),
        sunDirection: -sun,
        sunColor: p.shadows ? vm.Vector3(9, 8.4, 7.4) : vm.Vector3.zero(),
        sunSharpness: 900,
      ),
    );
    scene.fog
      ..enabled = true
      ..color = _v(p.fog)
      ..start = p.fogStart
      ..end = p.fogEnd;
    scene.directionalLight = DirectionalLight(
      direction: sun,
      color: _v(p.sunColor),
      intensity: p.sunIntensity,
      castsShadow: p.shadows && graphics.shadows,
      shadowCascadeCount: graphics.shadowCascades,
      shadowMaxDistance: graphics.shadowDistance,
      shadowMapResolution: 1024,
      shadowSoftness: .12,
    );
    scene.environmentIntensity = p.environment;
    scene.exposure = p.exposure;
    scene.postProcess.bloom
      ..enabled = graphics.bloom && p.bloom > 0
      ..intensity = p.bloom
      ..threshold = .9;
    for (final l in workLights) {
      l.intensity = p.workLight;
    }
    _glowFor(time).forEach(_setGlow);
  }

  /// Scrolls traffic and blinks the aviation obstruction lights.
  void setTrafficVisible(bool visible) {
    for (final node in _trafficNodes.keys) {
      node.visible = visible;
    }
  }

  void update(double clock) {
    for (final e in _trafficNodes.entries) {
      final o = (clock * e.value.speed) % e.value.period;
      e.key.position = vm.Vector3(e.value.axis.$1 * o, 0, e.value.axis.$2 * o);
    }
    final on = math.sin(clock * math.pi * 1.2) > -.2;
    final base = switch (time) {
      StageTime.day => .5,
      StageTime.night => 3.2,
    };
    _setGlow('redlight', (1, .08, .05, on ? base : base * .08));
  }
}
