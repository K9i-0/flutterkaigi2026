import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Three GPU morphs keep the liquid inside the authored inner cylinder.
/// A damped plane is a visual approximation; this does not simulate spilling.
class BeerMugComponent extends Component {
  BeerMugComponent({required this.isPaused});
  final bool Function() isPaused;
  double fill = 1;
  bool detail = true;
  final List<Node> _liquid = [];
  Node? _bubbles, _basis;
  final Map<MeshPrimitive, Material> _nearMaterials = {};
  final Map<MeshPrimitive, Material> _farMaterials = {};
  bool? _appliedDetail;
  vm.Vector3? _lastPosition;
  vm.Vector3 _lastVelocity = vm.Vector3.zero();
  final vm.Vector2 _slope = vm.Vector2.zero();
  final vm.Vector2 _velocity = vm.Vector2.zero();
  double _time = 0;

  @override
  void onAttach() {
    _basis = node.getChildByName('BeerMugRoot') ?? node;
    for (final name in ['BeerVolume', 'LiquidSurface', 'Foam']) {
      final part = node.getChildByName(name);
      if (part == null || part.morphTargetCount != 3) {
        throw StateError('Beer mug v2 missing $name liquid morphs');
      }
      _liquid.add(part);
    }
    _bubbles = node.getChildByName('Carbonation');
    final farGlass = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.85, .94, .96, .18)
      ..alphaMode = AlphaMode.blend
      ..metallicFactor = 0
      ..roughnessFactor = .12;
    final farBeer = PhysicallyBasedMaterial()
      ..baseColorFactor = vm.Vector4(.64, .25, .015, 1)
      ..metallicFactor = 0
      ..roughnessFactor = .24;
    for (final name in ['GlassBody', 'Handle', 'BeerVolume', 'LiquidSurface']) {
      final mesh = node.getChildByName(name)!.mesh!;
      for (final primitive in mesh.primitives) {
        _nearMaterials[primitive] = primitive.material;
        _farMaterials[primitive] = name == 'GlassBody' || name == 'Handle'
            ? farGlass
            : farBeer;
      }
    }
    // Mount/warm-up may render before the first asynchronous component tick.
    // Establish the requested material tier before registering render items.
    _applyMaterialDetail();
    _bubbles?.visible = detail && fill > .7;
    for (final part in _liquid) {
      part.visible = fill > .001 && (detail || part.name != 'LiquidSurface');
    }
  }

  void _applyMaterialDetail() {
    if (_appliedDetail == detail) return;
    final materials = detail ? _nearMaterials : _farMaterials;
    for (final entry in materials.entries) {
      entry.key.material = entry.value;
    }
    _appliedDetail = detail;
  }

  void reset() {
    _lastPosition = null;
    _lastVelocity.setZero();
    _velocity.setZero();
  }

  @override
  void update(double deltaSeconds) {
    if (!node.visible) {
      reset();
      return;
    }
    _applyMaterialDetail();
    final dt = deltaSeconds.clamp(0.0, 1 / 30);
    final transform = _basis!.globalTransform;
    final position = transform.getTranslation();
    final rotation = transform.getRotation();
    final inverseRotation = vm.Matrix3.copy(rotation)..transpose();
    final acceleration = vm.Vector3.zero();
    if (_lastPosition != null && dt > 0 && !isPaused()) {
      final velocity = (position - _lastPosition!) / dt;
      acceleration.setFrom((velocity - _lastVelocity) / dt);
      _lastVelocity = velocity;
    }
    _lastPosition = position;
    final normal = inverseRotation.transform(
      vm.Vector3(
        -acceleration.x.clamp(-12.0, 12.0) * .18,
        9.81,
        -acceleration.z.clamp(-12.0, 12.0) * .18,
      ),
    );
    final denominator = math.max(normal.y, 2.0);
    final target = vm.Vector2(-normal.x / denominator, -normal.z / denominator);
    // Foam top is 0.194 m, rim 0.211 m, liquid bottom 0.027 m.
    final height = .18 - .13 * (1 - fill.clamp(0.0, 1.0));
    final maxSlope = math.min(.207 - (height + .014), height - .033) / .063;
    if (target.length > maxSlope) target.scale(maxSlope / target.length);
    if (isPaused() || deltaSeconds > .15) {
      _slope.setFrom(target);
      _velocity.setZero();
    } else {
      // Substeps make the spring stable across 30/60/120 Hz frame delivery.
      var remaining = dt;
      while (remaining > 0) {
        final step = math.min(remaining, 1 / 120);
        _velocity.add(
          (target - _slope) * (65 * step) - _velocity * (12 * step),
        );
        _slope.add(_velocity * step);
        remaining -= step;
      }
    }
    if (_slope.length > maxSlope) {
      _slope.scale(maxSlope / _slope.length);
      _velocity.scale(.5);
    }
    for (final part in _liquid) {
      part.visible = fill > .001 && (detail || part.name != 'LiquidSurface');
      final names = part.morphTargetNames;
      part.setMorphWeight(names.indexOf('TiltX'), _slope.x / .46875);
      part.setMorphWeight(names.indexOf('TiltZ'), _slope.y / .46875);
      part.setMorphWeight(names.indexOf('Fill'), 1 - fill.clamp(0.0, 1.0));
    }
    if (!isPaused()) _time += dt;
    _bubbles?.visible = detail && fill > .7;
    _bubbles?.position = vm.Vector3(0, (_time * .012) % .015, 0);
  }

  Map<String, Object> inspect() => {
    'fill': fill,
    'slope': [_slope.x, _slope.y],
    'detail': detail,
    'surfaceHeight': .18 - .13 * (1 - fill),
    'morphs': {
      for (final part in _liquid) part.name: part.morphWeights?.toList() ?? [],
    },
  };
}
