import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

import 'vrm_document.dart';

/// A runtime-loaded VRM avatar backed by flutter_scene's generic glTF scene.
class VrmAvatar {
  VrmAvatar._({
    required this.root,
    required this.document,
    required Map<int, Node> nodesBySourceIndex,
  }) : _nodesBySourceIndex = nodesBySourceIndex;

  static Future<VrmAvatar> fromBytes(Uint8List bytes) async {
    final document = VrmDocument.fromGlbBytes(bytes);
    final root = await Node.fromGlbBytes(bytes);
    final nodes = <int, Node>{};
    void visit(Node node) {
      final source = node.getComponent<GltfSourceComponent>();
      if (source != null) nodes[source.nodeIndex] = node;
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(root);
    return VrmAvatar._(
      root: root,
      document: document,
      nodesBySourceIndex: nodes,
    );
  }

  final Node root;
  final VrmDocument document;
  final Map<int, Node> _nodesBySourceIndex;
  final Map<String, double> _expressionWeights = {};

  Map<String, double> get expressionWeights =>
      Map.unmodifiable(_expressionWeights);

  /// Sets one VRM expression and reapplies all active morph bindings.
  void setExpression(String name, double weight) {
    final expression = document.expressions[name];
    if (expression == null) throw ArgumentError.value(name, 'name');
    final clamped = weight.clamp(0.0, 1.0);
    _expressionWeights[name] = expression.isBinary
        ? (clamped >= 0.5 ? 1.0 : 0.0)
        : clamped;
    _applyExpressions();
  }

  void resetExpressions() {
    _expressionWeights.clear();
    _applyExpressions();
  }

  void _applyExpressions() {
    final controllerWeights = <MorphTargetController, List<double>>{};

    for (final node in _nodesBySourceIndex.values) {
      final mesh = node.mesh;
      if (mesh == null) continue;
      for (final primitive in mesh.primitives) {
        final controller = primitive.geometry.morphTargets;
        if (controller != null) {
          controllerWeights[controller] = List<double>.filled(
            controller.targetCount,
            0.0,
          );
        }
      }
    }

    for (final active in _expressionWeights.entries) {
      if (active.value == 0.0) continue;
      final expression = document.expressions[active.key]!;
      for (final bind in expression.morphTargetBinds) {
        final node = _nodesBySourceIndex[bind.node];
        final mesh = node?.mesh;
        if (mesh == null) continue;
        for (final primitive in mesh.primitives) {
          final controller = primitive.geometry.morphTargets;
          final weights = controllerWeights[controller];
          if (controller == null ||
              weights == null ||
              bind.index >= weights.length) {
            continue;
          }
          weights[bind.index] += bind.weight * active.value;
        }
      }
    }

    for (final entry in controllerWeights.entries) {
      entry.key.setWeights(entry.value);
    }
  }
}
