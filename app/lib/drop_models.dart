import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'drop_kind.dart';
import 'cached_skin.dart';

/// The menu and the falling objects clone exactly the same game assets.
class DropModels {
  final prototypes = <CanKind, Node>{};
  Future<void> load() async {
    // Kinds sharing a model (chikuwa and its toxic look) load it once. A clone
    // keeps the materials selected when it was made, so each look is frozen.
    final scenes = <String, Node>{};
    for (final kind in CanKind.values) {
      final source = scenes[kind.asset()] ??= await loadScene(kind.asset());
      MaterialsVariantsComponent.of(source)?.select(kind.variant);
      prototypes[kind] = source.clone();
    }
  }

  DropModel create(CanKind kind) => DropModel(kind, prototypes[kind]!.clone());
}

class DropModel {
  DropModel(this.kind, this.model) {
    cacheSkinUploads(model);
    root.add(model);
    if (kind.isChikuwa) {
      model.scale = vm.Vector3.all(.46);
      model.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 0, 1), -1.05);
    } else if (!kind.isCan) {
      final scale = kind == CanKind.yumemin ? .85 : .75;
      model.scale = vm.Vector3.all(scale);
      model.position = vm.Vector3(0, -.48, 0);
      model.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
    }
    final animation = model.findAnimationByName(
      kind.isChikuwa ? 'Wiggle' : 'Idle',
    );
    if (animation != null) {
      clip = model.createAnimationClip(animation)
        ..loop = true
        ..playbackTimeScale = 0
        ..play();
    }
  }
  final CanKind kind;
  final Node model;
  final root = Node();
  AnimationClip? clip;
  void sample(double seconds) {
    clip?.seek(seconds % (kind.isChikuwa ? 1.6 : 3));
  }

  void display(double seconds) {
    sample(seconds * .55);
    root.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      math.sin(seconds * .55) * .35 +
          (kind.isCan
              ? math.pi
              : kind.isChikuwa
              ? -.35
              : 0),
    );
  }
}
