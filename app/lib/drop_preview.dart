import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'character.dart';
import 'drop_kind.dart';
import 'drop_models.dart';

/// Two isolated views keep both silhouettes equally sized on any screen ratio.
class DropPreview extends StatefulWidget {
  const DropPreview({
    super.key,
    required this.models,
    required this.environment,
    required this.character,
    required this.bad,
  });
  final DropModels models;
  final EnvironmentMap environment;
  final CatchCharacter character;
  final bool bad;
  @override
  State<DropPreview> createState() => _DropPreviewState();
}

class _DropPreviewState extends State<DropPreview> {
  final scene = Scene();
  final camera = PerspectiveCamera(
    position: vm.Vector3(0, .35, 3.5),
    target: vm.Vector3(0, 0, 0),
    fovRadiansY: .52,
  );
  final models = <CanKind, DropModel>{};
  double time = 0;
  @override
  void initState() {
    super.initState();
    scene.environment = widget.environment;
    scene.environmentIntensity = 1.4;
    scene.exposure = 1.15;
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.5, -1, -.6),
      intensity: 2.8,
    );
    for (final kind in CanKind.values) {
      final model = widget.models.create(kind);
      models[kind] = model;
      scene.add(model.root);
    }
    update();
  }

  void update() {
    final kinds = widget.bad
        ? [widget.character.badDrop]
        : widget.character.goodDrops;
    for (final entry in models.entries) {
      final index = kinds.indexOf(entry.key);
      entry.value.root.visible = index >= 0;
      if (index < 0) continue;
      // Multiple beer brands stay visible together; never silently cycle labels.
      entry.value.root.position = vm.Vector3(
        kinds.length > 1 ? (index - .5) * .72 : 0,
        0,
        0,
      );
      entry.value.root.scale = vm.Vector3.all(kinds.length > 1 ? .85 : 1.15);
      entry.value.display(time);
    }
  }

  @override
  void didUpdateWidget(covariant DropPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    update();
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, size) {
      final aspect = size.maxWidth / math.max(1, size.maxHeight);
      // Fit a bounding circle in both axes; the tilted, wiggling chikuwa needs
      // its own radius or its ends leave the view and look cut off.
      final chikuwa = widget.character == CatchCharacter.ctoOdatetsu;
      final radius = chikuwa ? .9 : .745, half = math.tan(.26);
      camera.position = vm.Vector3(
        0,
        .35,
        math.max(radius / half, (chikuwa ? .9 : .95) / (half * aspect)),
      );
      return SceneView(
        scene,
        camera: camera,
        key: ValueKey('drop_preview_${widget.bad ? 'bad' : 'good'}'),
        onTick: (_, dt) {
          time += dt.clamp(0, .1);
          update();
        },
      );
    },
  );
}
