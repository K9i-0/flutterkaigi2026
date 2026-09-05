import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'game_controller.dart';
import 'game_state.dart';

/// Opt-in profile run. Uses real rendered Flutter frames, never inferred FPS.
class GameBenchmark {
  GameBenchmark(this.game) {
    game.benchmarkMode = true;
    next();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => poll());
  }
  final HazardGameController game;
  Timer? timer;
  final watch = Stopwatch();
  int index = -1;
  bool interrupted = false;
  static const cases = [
    (
      name: 'village-four',
      region: 'village',
      count: 4,
      scale: .85,
      contacts: true,
    ),
    (
      name: 'village-eight',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: true,
    ),
    (
      name: 'village-eight-no-contact',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: false,
    ),
    (
      name: 'village-eight-full',
      region: 'village',
      count: 8,
      scale: 1.0,
      contacts: true,
    ),
    (name: 'farm-six', region: 'farm', count: 6, scale: .85, contacts: true),
    (
      name: 'mountain-six',
      region: 'mountain',
      count: 6,
      scale: .85,
      contacts: true,
    ),
    (
      name: 'mountain-six-full',
      region: 'mountain',
      count: 6,
      scale: 1.0,
      contacts: true,
    ),
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
    while (game.state!.zoneId != c.region) {
      final current = game.state!;
      current.exitRequested = Map<String, dynamic>.from(
        (current.map['exits'] as List).last,
      );
      current.phase = PlayPhase.transition;
      game.transitionRegion();
    }
    game.director = null;
    final s = game.state!;
    s.seenEvents.addAll(['opening', 'farm', 'last_order', 'ending']);
    s.checkpointRequested = false;
    s.phase = PlayPhase.playing;
    final baseX = c.region == 'mountain' ? 8.0 : 0.0;
    final baseZ = c.region == 'mountain'
        ? 1.0
        : c.region == 'farm'
        ? -8.0
        : -13.0;
    s.x = baseX;
    s.z = baseZ;
    s.health = 100000;
    for (final e in s.enemies) {
      e.active = e.id < c.count;
      e.alerted = true;
      e.x = baseX + (e.id % 4 - 1.5) * 1.5;
      e.z = baseZ + 6 + (e.id ~/ 4) * 2;
    }
    game.scene.renderScale = c.scale;
    game.contactShadows?.node.visible = c.contacts;
    game.frames.reset();
    interrupted = false;
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
        'region': cases[index].region,
        'contactShadows': cases[index].contacts,
        'profile': kProfileMode,
        'valid': kProfileMode && game.frames.count == 240 && !interrupted && game.foreground && game.state!.phase == PlayPhase.playing && game.state!.time >= 6,
        'interrupted': interrupted,
        'foreground': game.foreground,
        'gamePhase': game.state!.phase.name,
        'simulatedSeconds': game.state!.time,
        'renderScale': game.scene.renderScale,
        'viewport': [game.viewport.width, game.viewport.height],
        'devicePixelRatio': game.devicePixelRatio,
        'elapsedMs': watch.elapsedMilliseconds,
        ...game.frames.toJson(),
      })}',
    );
    next();
  }

  void tick() {
    if (index < cases.length) {
      final s = game.state!;
      if (!game.foreground || s.phase != PlayPhase.playing) interrupted = true;
      s.yaw = math.pi + math.sin(s.time * .3) * .25;
    }
  }

  void dispose() {
    timer?.cancel();
    watch.stop();
  }
}
