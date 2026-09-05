import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// Soft vertex-alpha ground patches. All actors share one instanced render item;
/// these supplement directional shadows without a screen-space post pass.
class ContactShadows {
  ContactShadows(int capacity) {
    final positions = <double>[], colors = <double>[], indices = <int>[];
    const segments = 24;
    // The center is a small disk so the feet have a stable contact area.
    for (final ring in [(0.0, .23), (.35, .20), (.7, .08), (1.0, 0.0)]) {
      for (var i = 0; i < segments; i++) {
        final a = i * math.pi * 2 / segments;
        positions.addAll([math.cos(a) * ring.$1, 0, math.sin(a) * ring.$1]);
        colors.addAll([.035, .032, .025, ring.$2]);
      }
    }
    for (var ring = 0; ring < 3; ring++) {
      for (var i = 0; i < segments; i++) {
        final a = ring * segments + i,
            b = ring * segments + (i + 1) % segments,
            c = a + segments,
            d = b + segments;
        indices.addAll([a, d, c, a, b, d]);
      }
    }
    final geometry = MeshGeometry.fromArrays(
      positions: Float32List.fromList(positions),
      colors: Float32List.fromList(colors),
      indices: Uint16List.fromList(indices),
    );
    final material = UnlitMaterial()..alphaMode = AlphaMode.blend;
    mesh = InstancedMesh(
      geometry: geometry,
      material: material,
      sortTransparentInstances: false,
    );
    for (var i = 0; i < capacity; i++) {
      mesh.addInstance(vm.Matrix4.diagonal3Values(.00001, .00001, .00001));
    }
    node = Node()
      ..castsShadows = false
      ..addComponent(InstancedMeshComponent(mesh));
  }
  late final InstancedMesh mesh;
  late final Node node;
  void update(List<({Node actor, double width, double depth})> actors) {
    mesh.updateInstanceTransforms((transforms) {
      for (var i = 0; i < transforms.length; i++) {
        final m = transforms[i]..setIdentity();
        if (i >= actors.length || !actors[i].actor.visible) {
          m.setDiagonal(vm.Vector4(.00001, .00001, .00001, 1));
          continue;
        }
        final a = actors[i], p = a.actor.position;
        final size = a.actor.scale.x;
        m.setDiagonal(vm.Vector4(a.width * size, 1, a.depth * size, 1));
        m.setTranslation(vm.Vector3(p.x, p.y + .024, p.z));
      }
    }, recomputeWinding: false);
  }
}
