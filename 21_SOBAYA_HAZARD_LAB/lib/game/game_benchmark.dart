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
    if (cases.isEmpty) {
      throw ArgumentError.value(
        const String.fromEnvironment('HAZARD_BENCHMARK_CASE'),
        'HAZARD_BENCHMARK_CASE',
        'No benchmark case matches this name',
      );
    }
    game.benchmarkMode = true;
    // Reproducible audible settings without writing the user's preferences.
    game.settings = HazardSettings(
      cinematicLighting: const bool.fromEnvironment(
        'HAZARD_CINEMATIC',
        defaultValue: true,
      ),
      graphicsPreset: benchmarkGraphics,
    );
    game.lighting.apply(
      game.scene,
      enabled: game.settings.cinematicLighting,
      preset: game.settings.graphicsPreset,
    );
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
  int pursuitTicks = 0, searchTicks = 0, beerPreviewTicks = 0;
  int maxConcurrentSearchers = 0, maxBeerGuideSprites = 0;
  final observedPursuers = <int>{},
      movingSearchers = <int>{},
      advancedSearchers = <int>{};
  final speechMorphTicks = <String, int>{};
  static final benchmarkGraphics = _graphics();
  static final overrideScale = _scale();
  static HazardGraphicsPreset _graphics() {
    const name = String.fromEnvironment(
      'HAZARD_GRAPHICS',
      defaultValue: 'quality',
    );
    if (!HazardGraphicsPreset.values.any((preset) => preset.name == name)) {
      throw ArgumentError.value(name, 'HAZARD_GRAPHICS');
    }
    return HazardGraphicsPreset.decode(name);
  }

  static double? _scale() {
    const raw = String.fromEnvironment('HAZARD_BENCHMARK_SCALE');
    if (raw.isEmpty) return null;
    final scale = double.tryParse(raw);
    if (scale == null || !scale.isFinite || scale < .5 || scale > 1) {
      throw ArgumentError.value(
        raw,
        'HAZARD_BENCHMARK_SCALE',
        'Expected a finite resolution scale between 0.5 and 1.0',
      );
    }
    return scale;
  }

  static final cases = allCases
      .where(
        (c) =>
            const String.fromEnvironment('HAZARD_BENCHMARK_CASE').isEmpty ||
            c.name == const String.fromEnvironment('HAZARD_BENCHMARK_CASE'),
      )
      .toList();
  static const allCases = [
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
      name: 'stealth-search',
      region: 'village',
      count: 6,
      scale: .85,
      contacts: true,
      event: null,
    ),
    (
      name: 'beer-preview',
      region: 'village',
      count: 0,
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
      e.alerted = false;
      e.x = baseX + (e.id % 4 - 1.5) * 1.5;
      e.z = baseZ + 6 + (e.id ~/ 4) * 2;
      e.heading = math.atan2(s.x - e.x, s.z - e.z);
      e.ambientDance = null;
    }
    // Align the saved-settings snapshot with the actual workload. The previous
    // full-resolution cases incorrectly logged the constructor's 85% setting.
    game.settings.renderScale = overrideScale ?? c.scale;
    game.scene.renderScale = game.settings.renderScale;
    game.contactShadows?.node.visible = c.contacts;
    windowMotionTicks = completedPassages = 0;
    playerWasVaulting = false;
    pursuitTicks = searchTicks = beerPreviewTicks = 0;
    maxConcurrentSearchers = maxBeerGuideSprites = 0;
    observedPursuers.clear();
    movingSearchers.clear();
    advancedSearchers.clear();
    if (c.name == 'stealth-search') {
      // A recorded sighting outside the barn, followed by the player hiding
      // inside its real west wall. AI must generate and visit its own guesses.
      s.x = -7.8;
      s.z = 11;
      s.yaw = math.pi / 2;
      s.invulnerable = 100000;
      for (final e in s.enemies.where((e) => e.active)) {
        e
          ..x = -10.8
          ..z = 6.5 + e.id * 1.2
          ..heading = 0
          ..alerted = true
          ..lastKnownX = -10.5
          ..lastKnownY = 0
          ..lastKnownZ = 11
          ..knowledgeSource = 'sight'
          ..knowledgeTime = s.time
          ..observedHeading = 0;
      }
    } else if (c.name == 'beer-preview') {
      s.beers = 10;
      s.equip('beer');
      s.aiming = true;
      s.pitch = -.15;
      s.invulnerable = 100000;
    } else if (c.event == null && !c.name.startsWith('window-')) {
      stageVisiblePursuers(baseX, baseZ);
    }
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
    final ready = semanticReady;
    if ((game.frames.count < 240 || !ready) &&
        watch.elapsedMilliseconds < 30000) {
      return;
    }
    debugPrintSynchronously(
      'HAZARD_GAME_BENCHMARK ${jsonEncode({
        'schemaVersion': 2,
        'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
        'runLabel': const String.fromEnvironment('HAZARD_BENCHMARK_RUN'),
        'case': cases[index].name,
        'settings': jsonDecode(game.settings.encode()),
        'lighting': game.lighting.inspect(game.scene),
        'audio': {'observedAmbience': heardAmbience, 'observedSpeech': heardSpeech, 'voice': game.voice.inspect(), 'soundscape': game.soundscape.inspect()},
        'region': cases[index].region,
        'contactShadows': cases[index].contacts,
        'profile': kProfileMode,
        'valid': kProfileMode && game.frames.count == 240 && !interrupted && game.foreground && game.state!.phase == expectedPhase && ready && game.voice.inspect()['errors'].isEmpty,
        'speechMorphTicks': speechMorphTicks,
        'eventShot': game.director?.index,
        'windowMotionTicks': windowMotionTicks,
        'completedWindowPassages': completedPassages,
        'workload': {'observedVisualPursuers': observedPursuers.toList()..sort(), 'pursuitTicks': pursuitTicks, 'searchTicks': searchTicks, 'maxConcurrentSearchers': maxConcurrentSearchers, 'movingSearchers': movingSearchers.toList()..sort(), 'advancedSearchers': advancedSearchers.toList()..sort(), 'beerPreviewTicks': beerPreviewTicks, 'maxBeerGuideSprites': maxBeerGuideSprites, 'activeEnemies': game.state!.enemies.where((e) => e.active && e.alive).length, 'currentSearchingEnemies': currentSearchers.length, 'beerGuideVisible': game.beerVisuals.dots.node.visible, 'semanticReady': ready},
        'interrupted': interrupted,
        'foreground': game.foreground,
        'gamePhase': game.state!.phase.name,
        'simulatedSeconds': game.state!.time,
        'renderScale': game.scene.renderScale,
        'viewport': [game.viewport.width, game.viewport.height],
        'devicePixelRatio': game.devicePixelRatio,
        'renderPixels': [(game.viewport.width * game.devicePixelRatio * game.scene.renderScale).ceil(), (game.viewport.height * game.devicePixelRatio * game.scene.renderScale).ceil()],
        'measurement': 'Flutter UI and raster thread durations; not GPU execution time or presented FPS',
        'elapsedMs': watch.elapsedMilliseconds,
        ...game.frames.toJson(),
      })}',
    );
    next();
  }

  PlayPhase get expectedPhase =>
      cases[index].event == null ? PlayPhase.playing : PlayPhase.cinematic;

  // Fast rendering can fill the frame buffer before a voiced shot or window
  // traversal finishes. Reuse the actual workload requirements for waiting
  // and validity, while poll's 30-second deadline still reports failures.
  bool get semanticReady {
    final c = cases[index];
    final ordinaryPursuit =
        c.event == null &&
        !c.name.startsWith('window-') &&
        c.name != 'stealth-search' &&
        c.name != 'beer-preview';
    return heardAmbience &&
        (c.event == null ? game.state!.time >= 6 : heardSpeech) &&
        (!ordinaryPursuit ||
            (pursuitTicks >= 60 &&
                game.state!.enemies
                    .where((e) => e.active)
                    .every((e) => observedPursuers.contains(e.id)))) &&
        (c.name != 'stealth-search' ||
            (searchTicks >= 120 &&
                movingSearchers.length >= 3 &&
                advancedSearchers.length >= 2 &&
                currentSearchers.length >= 2)) &&
        (c.name != 'beer-preview' ||
            (beerPreviewTicks >= 120 &&
                game.state!.aiming &&
                game.state!.weapon == 'beer' &&
                game.state!.beerPreview != null &&
                game.beerVisuals.dots.node.visible &&
                game.beerVisuals.held.visible)) &&
        (!c.name.startsWith('window-') ||
            (windowMotionTicks >= 60 && completedPassages > 0)) &&
        (c.event != 'opening' ||
            [
              '福ちゃん',
              'やめ太郎',
            ].every((name) => (speechMorphTicks[name] ?? 0) > 5));
  }

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
      final visualPursuers = s.enemies
          .where((e) => e.active && e.alive && e.alerted && e.seesPlayer)
          .toList();
      observedPursuers.addAll(visualPursuers.map((e) => e.id));
      if (visualPursuers.any((e) => e.moved > .00001)) pursuitTicks++;
      final searchers = currentSearchers;
      maxConcurrentSearchers = math.max(
        maxConcurrentSearchers,
        searchers.length,
      );
      if (searchers.length >= 2) searchTicks++;
      movingSearchers.addAll(
        searchers.where((e) => e.moved > .00001).map((e) => e.id),
      );
      advancedSearchers.addAll(
        searchers.where((e) => e.searchIndex > 0).map((e) => e.id),
      );
      if (name == 'beer-preview' &&
          s.aiming &&
          s.weapon == 'beer' &&
          (s.beerPreview?.points.length ?? 0) > 3 &&
          game.beerVisuals.held.visible &&
          game.beerVisuals.dots.node.visible &&
          game.beerVisuals.dots.geometry.instanceCount > 20) {
        beerPreviewTicks++;
        maxBeerGuideSprites = math.max(
          maxBeerGuideSprites,
          game.beerVisuals.dots.geometry.instanceCount,
        );
      }
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
      } else if (name == 'stealth-search') {
        s.yaw = math.pi / 2 + math.sin(s.time * .3) * .15;
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
        ..approachTimer = 0
        ..alerted = true
        // This traversal workload has a real last sighting on the far side.
        ..lastKnownX = s.x
        ..lastKnownY = s.y
        ..lastKnownZ = s.z
        ..knowledgeSource = 'sight'
        ..knowledgeTime = s.time
        ..searchDuration = 0
        ..searchRemaining = 0
        ..pursuitRemaining = 0
        ..memoryFlowTime = 0
        ..investigationTarget = null
        ..searchIndex = 0;
      s.enemies[i].searchPoints.clear();
    }
  }

  List<Enemy> get currentSearchers => game.state!.enemies
      .where(
        (e) =>
            e.active &&
            e.alive &&
            !e.boss &&
            e.alerted &&
            !e.seesPlayer &&
            e.awareness == EnemyAwareness.searching &&
            e.searchRemaining > 0 &&
            e.searchPoints.isNotEmpty &&
            e.memoryNavigation != null,
      )
      .toList();

  // Preserve the authored collision map. If a tree or new cover occupies an
  // old crowd slot, use a nearby free, genuinely visible staging slot.
  void stageVisiblePursuers(double baseX, double baseZ) {
    final s = game.state!;
    final placed = <Enemy>[];
    for (final e in s.enemies.where((e) => e.active)) {
      bool usable() =>
          !s.blocked(e.x, e.z, e.y, radius: e.collisionRadius) &&
          s.enemyCanSeePlayer(e) &&
          placed.every(
            (other) =>
                math.pow(other.x - e.x, 2) + math.pow(other.z - e.z, 2) >
                math.pow(other.collisionRadius + e.collisionRadius + .15, 2),
          );
      if (!usable()) {
        for (var i = 0; i < 60; i++) {
          e.x = baseX + (i % 7 - 3) * 1.5;
          e.z = baseZ + 4 + (i ~/ 7) * 1.2;
          e.y = s.floorHeight(e.x, e.z, 0);
          e.heading = math.atan2(s.x - e.x, s.z - e.z);
          if (usable()) break;
        }
      }
      placed.add(e);
    }
  }

  void dispose() {
    timer?.cancel();
    watch.stop();
  }
}
