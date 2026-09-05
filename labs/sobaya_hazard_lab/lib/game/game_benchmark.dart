import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'game_controller.dart';

/// Opt-in profile run. Uses real rendered Flutter frames, never inferred FPS.
class GameBenchmark {
  GameBenchmark(this.game) {
    next();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => poll());
  }
  final HazardGameController game;
  Timer? timer;
  final watch = Stopwatch();
  int index = -1;
  static const cases = [
    (name: 'village-four', count: 4, scale: .85),
    (name: 'village-eight', count: 8, scale: .85),
    (name: 'village-eight-full', count: 8, scale: 1.0),
  ];
  void next() {
    index++;
    if (index == cases.length) {
      dispose();
      debugPrintSynchronously('HAZARD_GAME_BENCHMARK_COMPLETE');
      return;
    }
    final c = cases[index];
    game.restart();
    final s = game.state!;
    s.x = 0;
    s.z = -13;
    s.health = 100000;
    for (final e in s.enemies) {
      e.active = e.id < c.count;
      e.x = (e.id % 4 - 1.5) * 1.5;
      e.z = -7 + (e.id ~/ 4) * 2;
    }
    game.scene.renderScale = c.scale;
    game.frames.reset();
    watch
      ..reset()
      ..start();
  }

  void poll() {
    if (watch.elapsedMilliseconds < 8000) return;
    if (game.frames.count < 240 && watch.elapsedMilliseconds < 30000) return;
    debugPrintSynchronously(
      'HAZARD_GAME_BENCHMARK ${jsonEncode({
        'case': cases[index].name,
        'profile': kProfileMode,
        'valid': kProfileMode && game.frames.count == 240,
        'renderScale': game.scene.renderScale,
        'viewport': [game.viewport.width, game.viewport.height],
        'elapsedMs': watch.elapsedMilliseconds,
        ...game.frames.toJson(),
      })}',
    );
    next();
  }

  void tick() {
    if (index < cases.length) {
      final s = game.state!;
      s.yaw = math.pi + math.sin(s.time * .3) * .25;
    }
  }

  void dispose() {
    timer?.cancel();
    watch.stop();
  }
}
