import 'dart:math' as math;

import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'motion_catalog.dart';

/// Each actor owns joint nodes and a player, while sharing immutable geometry.
class RigActor {
  RigActor(Node character, Node prop, String name)
    : model = character.clone(),
      mug = prop.clone(),
      root = Node(name: name) {
    root.add(model);
    for (final spec in motions) {
      final animation = model.findAnimationByName(spec.name);
      if (animation == null) {
        throw StateError('Missing animation ${spec.name}');
      }
      durations[spec.name] = animation.endTime;
      clips[spec.name] = model.createAnimationClip(animation)
        ..loop = spec.loop
        ..weight = 0;
    }
    final socket = model.getChildByName('PropSocket.R');
    final grip = mug.getChildByName('Grip');
    if (socket == null || grip == null) {
      throw StateError('Missing PropSocket.R or Grip anchor');
    }
    // Blender exports joint frames as Y-along-bone, while prop vertices
    // are converted to glTF Y-up. Undo that joint-frame quarter turn.
    // flutter_scene reflects Z, so glTF +90 X becomes -90 X here.
    final inverseGrip = vm.Matrix4.copy(grip.globalTransform)
      ..invert()
      ..multiply(mug.globalTransform);
    mug.localTransform = vm.Matrix4.rotationX(-math.pi / 2)
      ..multiply(inverseGrip);
    socket.add(mug);
    mug.visible = false;
    setMotion('Idle', immediate: true);
  }

  final Node root, model, mug;
  final Map<String, AnimationClip> clips = {};
  final Map<String, double> durations = {};
  final Map<String, double> _from = {};
  String current = 'Idle';
  double _fade = 1;
  double speed = 1;
  bool paused = false;
  AnimationClip get active => clips[current]!;
  double get duration => durations[current]!;
  bool get finished => !active.loop && active.playbackTime >= duration;

  void setMotion(String name, {bool replay = false, bool immediate = false}) {
    if (name == current && !replay && !immediate) return;
    const locomotion = {'Walk', 'Run', 'ZombieWalk'};
    final phase = locomotion.contains(name) && locomotion.contains(current)
        ? active.playbackTime / duration
        : 0.0;
    _from.clear();
    for (final e in clips.entries) {
      _from[e.key] = immediate ? 0 : e.value.weight;
    }
    current = name;
    active.seek(replay ? 0 : phase * duration);
    if (!paused) active.play();
    _fade = immediate ? 1 : 0;
    _applyWeights();
  }

  void _applyWeights() {
    final t = _fade * _fade * (3 - 2 * _fade);
    for (final e in clips.entries) {
      final target = e.key == current ? 1.0 : 0.0;
      e.value.weight = (_from[e.key] ?? 0) * (1 - t) + target * t;
      if (e.value.weight == 0 && e.key != current) e.value.pause();
    }
  }

  void update(double delta) {
    if (!paused) {
      _fade = (_fade + delta / .18).clamp(0, 1);
      _applyWeights();
    }
    for (final clip in clips.values) {
      clip.playbackTimeScale = speed;
    }
  }

  void setPaused(bool value) {
    paused = value;
    for (final e in clips.entries) {
      if (value) {
        e.value.pause();
      } else if (e.key == current || e.value.weight > 0) {
        e.value.play();
      }
    }
  }

  void seek(double seconds) {
    setPaused(true);
    _fade = 1;
    _applyWeights();
    active.seek(seconds);
  }

  Map<String, Object?> inspect() {
    final socket = model.getChildByName('PropSocket.R')!;
    final hand = model.getChildByName('Hand.R')!;
    return {
      'clip': current,
      'seconds': active.playbackTime,
      'duration': duration,
      'playing': active.playing,
      'loop': active.loop,
      'speed': speed,
      'mugVisible': mug.visible,
      'handWorld': hand.globalTransform.getTranslation().storage.toList(),
      'socketWorld': socket.globalTransform.getTranslation().storage.toList(),
      'gripWorld': mug
          .getChildByName('Grip')!
          .globalTransform
          .getTranslation()
          .storage
          .toList(),
      'mugUp': mug.globalTransform.getColumn(1).storage.toList(),
      'weights': {for (final e in clips.entries) e.key: e.value.weight},
    };
  }
}
