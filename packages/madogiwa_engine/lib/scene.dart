import 'package:flutter_scene/scene.dart';

import 'madogiwa_engine.dart';

/// Use already retargeted clips on their own rig. This does not copy bone poses
/// between incompatible bind poses or implement VRM/VRMA import.
class CharacterMotionPlayer {
  CharacterMotionPlayer(
    this.model, {
    required Map<String, String> sources,
    Map<String, double> groundSpeeds = const {},
    Map<String, String> syncGroups = const {},
    Set<String> oneShots = const {},
    String initial = 'Idle',
    double? transitionSeconds,
  }) : sources = Map.unmodifiable(sources) {
    final specs = <String, MotionSpec>{};
    for (final entry in sources.entries) {
      final animation = model.findAnimationByName(entry.value);
      if (animation == null) {
        throw StateError('Missing ${entry.key}: ${entry.value}');
      }
      specs[entry.key] = MotionSpec(
        duration: animation.endTime,
        loop: !oneShots.contains(entry.key),
        groundSpeed: groundSpeeds[entry.key],
        syncGroup: syncGroups[entry.key],
      );
    }
    controller = MotionController(
      specs,
      initial: initial,
      transitionSeconds: transitionSeconds,
    );
    for (final entry in sources.entries) {
      clips[entry.key] =
          model.createAnimationClip(model.findAnimationByName(entry.value)!)
            ..loop = false
            ..playbackTimeScale = 0;
    }
    sample();
  }
  final Node model;
  final Map<String, String> sources;
  final clips = <String, AnimationClip>{};
  late final MotionController controller;

  void sample() {
    final weights = controller.weights, seconds = controller.seconds;
    for (final entry in clips.entries) {
      final clip = entry.value;
      clip.weight = weights[entry.key]!;
      clip.seek(seconds[entry.key]!);
      if (clip.weight > .0001) {
        clip.play();
      } else {
        clip.pause();
      }
    }
  }

  Map<String, Object?> inspect() => {
    ...controller.inspect(),
    'source': sources[controller.current],
  };
}
