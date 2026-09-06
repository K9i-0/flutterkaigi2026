import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'game_controller.dart';
import 'game_state.dart';
import 'game_settings.dart';

/// Opt-in profile run. Uses real rendered Flutter frames, never inferred FPS.
class GameBenchmark {
  GameBenchmark(this.game) {
    game.benchmarkMode = true;
    // Reproducible audible settings without writing the user's preferences.
    game.settings = HazardSettings();
    next();
    timer = Timer.periodic(const Duration(milliseconds: 500), (_) => poll());
  }
  final HazardGameController game;
  Timer? timer;
  final watch = Stopwatch();
  int index = -1;
  bool interrupted = false, heardAmbience = false, heardSpeech = false;
  int windowMotionTicks = 0, completedPassages = 0;
  bool playerWasVaulting = false;
  final speechMorphTicks = <String, int>{};
  static const cases = [
    (
      name: 'village-four',
      region: 'village',
      count: 4,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'village-eight',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'village-eight-no-contact',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: false,
      event: null,
    ),
    (
      name: 'village-eight-full',
      region: 'village',
      count: 8,
      scale: 1.0,
      contacts: true,
      event: null,
    ),
    (
      name: 'farm-six',
      region: 'farm',
      count: 6,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'mountain-six',
      region: 'mountain',
      count: 6,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'mountain-six-full',
      region: 'mountain',
      count: 6,
      scale: 1.0,
      contacts: true,
      event: null,
    ),
    (
      name: 'window-player',
      region: 'village',
      count: 0,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'window-enemies',
      region: 'village',
      count: 2,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'opening-voice',
      region: 'village',
      count: 8,
      scale: .85,
      contacts: true,
      event: 'opening',
    ),
    (
      name: 'boss-voice',
      region: 'mountain',
      count: 6,
      scale: .85,
      contacts: true,
      event: 'last_order',
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
    windowMotionTicks = completedPassages = 0;
    playerWasVaulting = false;
    if (c.name.startsWith('window-')) {
      final w = s.windows.first;
      s.x = w.x;
      s.y = 0;
      s.pitch = .12;
      s.invulnerable = 100000;
      if (c.name == 'window-player') {
        s.z = w.entryZ(true);
        s.yaw = math.pi;
      } else {
        s.z = w.exitZ(true) + 2;
        s.yaw = 0;
        resetWindowEnemies();
      }
    }
    if (c.event != null) {
      s.seenEvents.remove(c.event);
      if (c.event == 'opening') {
        // Reverse shots are authored at the actual entrance. The generic
        // crowd staging point left Fukuchan outside his own camera frame.
        s.x = (s.map['spawn']['x'] as num).toDouble();
        s.z = (s.map['spawn']['z'] as num).toDouble();
      }
      game.startEvent(c.event!);
      if (c.event == 'opening') game.director!.index = 1;
    }
    game.frames.reset();
    heardAmbience = heardSpeech = false;
    speechMorphTicks.clear();
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
        'settings': jsonDecode(game.settings.encode()),
        'audio': {'observedAmbience': heardAmbience, 'observedSpeech': heardSpeech, 'voice': game.voice.inspect(), 'soundscape': game.soundscape.inspect()},
        'region': cases[index].region,
        'contactShadows': cases[index].contacts,
        'profile': kProfileMode,
        'valid': kProfileMode && game.frames.count == 240 && !interrupted && game.foreground && game.state!.phase == expectedPhase && (cases[index].event == null ? game.state!.time >= 6 : heardSpeech) && heardAmbience && game.voice.inspect()['errors'].isEmpty && (!cases[index].name.startsWith('window-') || (windowMotionTicks >= 60 && completedPassages > 0)) && (cases[index].event != 'opening' || ['福ちゃん', 'やめ太郎'].every((name) => (speechMorphTicks[name] ?? 0) > 5)),
        'speechMorphTicks': speechMorphTicks,
        'eventShot': game.director?.index,
        'windowMotionTicks': windowMotionTicks,
        'completedWindowPassages': completedPassages,
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

  PlayPhase get expectedPhase =>
      cases[index].event == null ? PlayPhase.playing : PlayPhase.cinematic;

  // A paused SceneView has no tick callbacks. Observe UI/lifecycle changes too
  // so a pause cannot disappear from the benchmark's interruption history.
  void observeState() {
    if (index >= 0 &&
        index < cases.length &&
        (!game.foreground || game.state!.phase != expectedPhase)) {
      interrupted = true;
    }
  }

  void tick() {
    observeState();
    heardAmbience |= game.soundscape.ambience.speaking;
    heardSpeech |= game.voice.speaking;
    for (final entry in game.speechWeights.entries) {
      if (entry.value > .001) {
        speechMorphTicks.update(entry.key, (n) => n + 1, ifAbsent: () => 1);
      }
    }
    if (index < cases.length) {
      final s = game.state!;
      final name = cases[index].name;
      if (name == 'window-player') {
        if (s.vault?.crossing ?? false) windowMotionTicks++;
        if (playerWasVaulting && s.vault == null) completedPassages++;
        playerWasVaulting = s.vault != null;
        if (s.vault == null && s.interaction?.startsWith('window:') == true) {
          s.yaw = s.z < s.windows.first.z ? math.pi : 0;
          s.interact();
        }
      } else if (name == 'window-enemies') {
        final enemies = s.enemies.take(2);
        if (enemies.any((e) => e.vault?.crossing ?? false)) {
          windowMotionTicks++;
        }
        if (enemies.every(
          (e) => e.vault == null && e.z > s.windows.first.z + .8,
        )) {
          completedPassages += 2;
          resetWindowEnemies();
        }
      } else {
        s.yaw = math.pi + math.sin(s.time * .3) * .25;
      }
    }
  }

  // A repeated rendering workload, not evidence of normal route progression.
  // Only the opt-in benchmark relocates enemies after both have landed.
  void resetWindowEnemies() {
    final s = game.state!, w = s.windows.first;
    for (var i = 0; i < 2; i++) {
      s.enemies[i]
        ..x = w.x
        ..y = 0
        ..z = w.entryZ(true) - i
        ..heading = 0
        ..vault = null
        ..climb = null
        ..attackPending = false
        ..meleeRecovery = 0
        ..approachX = null
        ..approachZ = null
        ..approachTimer = 0;
    }
  }

  void dispose() {
    timer?.cancel();
    watch.stop();
  }
}
