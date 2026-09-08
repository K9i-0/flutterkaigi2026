import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';

/// Small analytic opacity masks. These upload once; no frame-time texture work,
/// noise simulation, screen copy, depth prepass, or extra shadow map is needed.
Uint8List hazardParticlePixels({bool flame = false, int size = 64}) {
  final pixels = Uint8List(size * size * 4);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final u = (x + .5) / size * 2 - 1;
      final v = (y + .5) / size * 2 - 1;
      final taper = flame ? .32 + .68 * ((v + 1) / 2) : 1.0;
      final bend = flame ? .12 * math.sin(v * 6) * (1 - v) : 0.0;
      final radius = math.sqrt(math.pow((u - bend) / taper, 2) + v * v);
      final edge = (1 - radius).clamp(0.0, 1.0);
      final alpha = edge * edge * (3 - 2 * edge);
      final offset = (y * size + x) * 4;
      pixels[offset] = pixels[offset + 1] = pixels[offset + 2] = 255;
      pixels[offset + 3] = (alpha * 255).round();
    }
  }
  return pixels;
}

/// Bounded, GPU-instanced particle batch shared by fire and weapon effects.
class HazardSpriteBatch {
  HazardSpriteBatch({
    required int capacity,
    bool flame = false,
    bool smoke = false,
  }) {
    final texture = flame
        ? (_flameTexture ??= Texture2D.fromPixels(
            hazardParticlePixels(flame: true),
            64,
            64,
          ))
        : (_softTexture ??= Texture2D.fromPixels(
            hazardParticlePixels(),
            64,
            64,
          ));
    geometry = BillboardGeometry(capacity: capacity)
      ..facing = flame ? BillboardFacing.axisLocked : BillboardFacing.spherical;
    final material = SpriteMaterial(colorTexture: texture)
      ..blendMode = smoke ? SpriteBlendMode.alpha : SpriteBlendMode.additive
      ..cameraNearFade = .35;
    node = Node(mesh: Mesh(geometry, material))
      ..castsShadows = false
      ..visible = false;
  }
  static Texture2D? _softTexture, _flameTexture;
  late final BillboardGeometry geometry;
  late final Node node;
  int _count = 0;

  void begin() => _count = 0;
  void add({
    required vm.Vector3 position,
    required double width,
    required double height,
    required vm.Vector4 color,
    double rotation = 0,
  }) {
    if (_count >= geometry.capacity || width <= 0 || height <= 0) return;
    geometry.setInstance(
      _count++,
      center: position,
      width: width,
      height: height,
      color: color,
      rotation: rotation,
    );
  }

  void end() {
    // Empty weapon/smoke batches are common. Keep their bounds revision stable
    // instead of invalidating the scene's spatial bookkeeping every frame.
    if (_count == 0 && geometry.instanceCount == 0) return;
    geometry.commit(_count);
    node.visible = _count > 0;
  }
}

/// Independent frequencies keep the hearth organic without touching AI RNG.
double hazardFireIntensity(double time) =>
    1 + .12 * math.sin(time * 7.1) + .08 * math.sin(time * 13.7 + 1.8);

/// Keep the near-field lighting, then smoothly stop submitting the point light
/// between 10 and 13 metres. The fire and ember sprites remain visible farther.
double hazardFireLightDistanceGain(double distance) {
  final t = ((13 - distance) / 3).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}

class HazardWorldEffects {
  HazardWorldEffects(this.scene, {required Map<String, Node> environments}) {
    // Preserve the authored logs, stone ring and collision footprint.
    for (var i = 0; i < 6; i++) {
      environments['village']?.getChildByName('Flame_$i')?.visible = false;
    }
    environments['farm']?.add(_buildMerchantShelf());
    for (final batch in [_flames, _smoke, _glow]) {
      scene.add(batch.node);
    }
    for (var i = 0; i < 3; i++) {
      final light = PointLight(
        color: vm.Vector3(1, .38, .09),
        range: i == 0 ? 7 : 4,
      );
      final node = Node()
        ..visible = false
        ..addComponent(PointLightComponent(light));
      _lights.add((node: node, light: light));
      scene.add(node);
    }
  }

  /// The shop's narrated stock sits on the existing solid front facade of
  /// SaveHut. All details are inside the wall's player-clearance margin, away
  /// from its doorway and Takosan's interaction point. One static cube batch.
  static Node _buildMerchantShelf() {
    final material = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4.all(1)
      ..roughnessFactor = .84;
    final mesh = InstancedMesh(
      geometry: CuboidGeometry(vm.Vector3.all(1)),
      material: material,
    );
    void box(
      double x,
      double y,
      double z,
      double w,
      double h,
      double d,
      vm.Vector4 color,
    ) {
      mesh.addInstance(
        vm.Matrix4.diagonal3Values(w, h, d)
          ..setTranslation(vm.Vector3(x, y, z)),
        color: color,
      );
    }

    final oak = vm.Vector4(.26, .16, .085, 1);
    final board = vm.Vector4(.43, .29, .14, 1);
    final cardboard = vm.Vector4(.58, .40, .19, 1);
    final tape = vm.Vector4(.83, .73, .51, 1);
    final amber = vm.Vector4(.92, .50, .09, 1);
    final green = vm.Vector4(.16, .37, .12, 1);
    for (final x in [-.64, .64]) {
      box(x, .96, -.06, .07, 1.65, .15, oak);
    }
    for (final y in [.32, .86, 1.39, 1.79]) {
      box(0, y, -.04, 1.38, .06, .28, board);
    }
    for (var row = 0; row < 2; row++) {
      for (final x in [-.32, .32]) {
        final y = .58 + row * .54;
        box(x, y, -.03, .55, .43, .25, cardboard);
        // Sealed lid and a broad amber shipment band distinguish beer cases.
        box(x, y + .218, -.03, .09, .008, .26, tape);
        box(x, y, -.159, .09, .44, .008, tape);
        box(x, y - .07, -.166, .39, .09, .01, amber);
      }
    }
    for (final x in [-.43, -.22, .02]) {
      box(x, 1.47, -.06, .13, .10, .12, cardboard);
      box(x, 1.57, -.06, .16, .13, .14, green);
      box(x + .025, 1.64, -.055, .11, .08, .11, green);
    }
    box(.36, 1.54, -.05, .35, .22, .21, vm.Vector4(.52, .08, .045, 1));
    box(.36, 1.54, -.16, .25, .09, .008, tape);
    return Node(name: 'TakosanSupplyShelf')
      ..position = vm.Vector3(-14.25, 0, -16.62)
      ..shadowStatic = true
      ..addComponent(InstancedMeshComponent(mesh));
  }

  final Scene scene;
  final _flames = HazardSpriteBatch(capacity: 18, flame: true);
  final _smoke = HazardSpriteBatch(capacity: 7, smoke: true);
  final _glow = HazardSpriteBatch(capacity: 64);
  final _lights = <({Node node, PointLight light})>[];
  final _lanterns = <vm.Vector3>[];
  final _shatterOrigins = <Enemy, vm.Vector3>{};
  String _zone = '';
  double _clock = 0;

  Map<String, Object?> inspect() => {
    'zone': _zone,
    'clock': _clock,
    'flameSprites': _flames.geometry.instanceCount,
    'smokeSprites': _smoke.geometry.instanceCount,
    'glowSprites': _glow.geometry.instanceCount,
    'localLights': _lights.where((entry) => entry.node.visible).length,
    'batchBudget': 3,
    'shadowLights': 0,
  };

  void update(
    HazardGameState s, {
    required double dt,
    required bool active,
    required bool enhanced,
  }) {
    if (active) _clock += dt.clamp(0.0, .05);
    if (_zone != s.zoneId) {
      _zone = s.zoneId;
      _lanterns.clear();
      _shatterOrigins.clear();
      // Lanterns already exist on each house facade in the canonical GLB.
      for (final h in s.map['houses'] as List) {
        _lanterns.add(
          vm.Vector3(
            (h['x'] as num).toDouble() + 1.22,
            2.01,
            (h['z'] as num).toDouble() - (h['d'] as num).toDouble() / 2 - .37,
          ),
        );
      }
    }
    for (final batch in [_flames, _smoke, _glow]) {
      batch.begin();
    }
    for (final entry in _lights) {
      entry.light.intensity = 0;
    }
    final flicker = hazardFireIntensity(_clock);
    if (_zone == 'village') {
      _bonfire(
        enhanced,
        flicker,
        hazardFireLightDistanceGain(math.sqrt(s.x * s.x + s.z * s.z)),
      );
    }
    final nearest = _lanterns.toList()
      ..sort((a, b) => _distance(a, s).compareTo(_distance(b, s)));
    for (var i = 0; i < nearest.length; i++) {
      final p = nearest[i];
      if (_distance(p, s) > 38 * 38) continue;
      _glow.add(
        position: p,
        width: .42,
        height: .55,
        color: vm.Vector4(1.8, .65, .13, .48 + .04 * math.sin(_clock * 4 + i)),
      );
      if (enhanced && i < 2 && _distance(p, s) < 13 * 13) {
        _lights[i + 1].node.position = p;
        _lights[i + 1].light.intensity =
            2.3 * (1 + .04 * math.sin(_clock * 4 + i));
      }
    }
    // The destroyed mug has no collectible beer: give the quiet E action a
    // visible glass/amber burst using the same batch and the real mug socket.
    _shatterOrigins.removeWhere(
      (enemy, _) =>
          !s.enemies.contains(enemy) || enemy.alive || enemy.vanish >= .7,
    );
    for (final e
        in s.enemies
            .where(
              (e) => !e.alive && e.suppressBeer && !e.dropped && e.vanish < .7,
            )
            .take(2)) {
      final origin = _shatterOrigins.putIfAbsent(
        e,
        () => e.mugCentre?.clone() ?? vm.Vector3(e.x, e.y + 1.05, e.z),
      );
      final age = e.vanish;
      for (var i = 0; i < (enhanced ? 12 : 7); i++) {
        final angle = i * 2.399;
        final speed = .55 + i % 4 * .16;
        _glow.add(
          position: vm.Vector3(
            origin.x + math.cos(angle) * age * speed,
            math.max(
              e.y + .04,
              origin.y + age * (.55 + i % 3 * .2) - age * age * 3,
            ),
            origin.z + math.sin(angle) * age * speed,
          ),
          width: i.isEven ? .045 : .07,
          height: i.isEven ? .09 : .06,
          color: i.isEven
              ? vm.Vector4(.85, 1.5, 1.7, 1 - age / .7)
              : vm.Vector4(2.2, 1.0, .12, 1 - age / .7),
          rotation: angle + age * 5,
        );
      }
    }
    // Scene filters hidden light nodes before packing/culling. A zero-intensity
    // visible light would still allocate/upload light textures and shade pixels.
    for (final entry in _lights) {
      entry.node.visible = entry.light.intensity > .001;
    }
    for (final batch in [_flames, _smoke, _glow]) {
      batch.end();
    }
  }

  double _distance(vm.Vector3 p, HazardGameState s) =>
      (p.x - s.x) * (p.x - s.x) + (p.z - s.z) * (p.z - s.z);

  void _bonfire(bool enhanced, double flicker, double lightDistanceGain) {
    final flameCount = enhanced ? 18 : 10;
    for (var i = 0; i < flameCount; i++) {
      final life = (_clock * (.68 + i % 3 * .09) + i * .618) % 1;
      final angle = i * 2.399;
      final radius = .44 * (1 - life * .55);
      final envelope = math.sin(life * math.pi);
      _flames.add(
        position: vm.Vector3(
          math.cos(angle) * radius + .16 * math.sin(_clock * 3 + i) * life,
          .45 + life * 1.25,
          math.sin(angle) * radius + life * .13,
        ),
        width: (.5 - life * .24) * flicker,
        height: (.9 - life * .35) * flicker,
        color: vm.Vector4(2.8, 1.35 * (1 - life) + .18, .08, envelope * .82),
        rotation: .14 * math.sin(_clock * 4 + i),
      );
    }
    _glow.add(
      position: vm.Vector3(0, .5, 0),
      width: 1.35,
      height: .75,
      color: vm.Vector4(2.5, 1.0, .08, .45 * flicker),
    );
    for (var i = 0; i < (enhanced ? 16 : 8); i++) {
      final life = (_clock * (.24 + i % 4 * .035) + i * .618) % 1;
      final angle = i * 2.399;
      _glow.add(
        position: vm.Vector3(
          math.cos(angle) * (.25 + life * .5) + life * .4,
          .65 + life * 3.0,
          math.sin(angle) * (.25 + life * .5) + .15 * math.sin(life * 8 + i),
        ),
        width: .025 + .016 * (1 - life),
        height: .055 + .025 * (1 - life),
        color: vm.Vector4(3, 1.3, .16, math.sin(life * math.pi) * .9),
      );
    }
    for (var i = 0; i < (enhanced ? 7 : 4); i++) {
      final life = (_clock * .18 + i / 7) % 1;
      final size = .8 + life * 1.65;
      _smoke.add(
        position: vm.Vector3(.1 + life * .8, 1.5 + life * 3.4, life * .4),
        width: size,
        height: size * 1.3,
        color: vm.Vector4(.22, .24, .25, math.sin(life * math.pi) * .25),
        rotation: i * 1.8 + _clock * .05,
      );
    }
    _lights[0].node.position = vm.Vector3(
      0,
      .9 + .08 * math.sin(_clock * 5),
      0,
    );
    _lights[0].light.intensity = enhanced ? 7 * flicker * lightDistanceGain : 0;
  }
}
