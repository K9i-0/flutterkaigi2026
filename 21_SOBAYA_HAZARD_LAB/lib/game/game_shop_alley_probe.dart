import 'dart:async';
import 'dart:math' as math;

import 'package:vector_math/vector_math.dart' as vm;

import 'game_controller.dart';
import 'game_state.dart';

/// An authored-input check on the real chapter: no actor relocation, granted
/// items, forced perception, or teleportation after the chapter-start fixture.
Future<Map<String, Object?>> probeShopAlley(HazardGameController g) async {
  final s = g.state;
  if (s == null ||
      s.map['id'] != 'farm' ||
      !g.foreground ||
      s.phase != PlayPhase.paused ||
      !g.benchmarkMode ||
      (s.x + 19).abs() > .01 ||
      (s.z + 21).abs() > .01) {
    return {
      'success': false,
      'reason': 'Open shopAlley and keep the game foreground first',
    };
  }
  final epoch = g.runEpoch, watch = Stopwatch()..start();
  final trace = <Map<String, Object?>>[];
  final music = <String>{};
  bool sawEnemy = false, heardLure = false;
  vm.Vector3? preview, landing;
  final initialTicks = g.renderedTicks;
  var previousTicks = initialTicks, lastFrameMs = 0;
  var lastSecond = -1;
  void observe(String stage) {
    if (g.renderedTicks != previousTicks) {
      previousTicks = g.renderedTicks;
      lastFrameMs = watch.elapsedMilliseconds;
    }
    if (watch.elapsedMilliseconds - lastFrameMs > 5000) {
      throw StateError('No rendered frames for 5 seconds at $stage');
    }
    if (g.disposed ||
        g.runEpoch != epoch ||
        !identical(g.state, s) ||
        !g.foreground ||
        !s.running ||
        watch.elapsedMilliseconds > 85000) {
      throw StateError('Route interrupted at $stage');
    }
    sawEnemy |= s.enemies.any((e) => e.visibleToPlayer);
    heardLure |= s.enemies.any((e) => e.knowledgeSource == 'beer_lure');
    if (s.beerSplashes.isNotEmpty) {
      landing ??= s.beerSplashes.first.position.clone();
    }
    music.add(g.soundscape.inspect()['phase'] as String);
    if (s.time.floor() == lastSecond) return;
    lastSecond = s.time.floor();
    trace.add({
      'stage': stage,
      'time': s.time,
      'player': [s.x, s.y, s.z],
      'health': s.health,
      'phase': s.stealthFeedback.phase,
      'music': g.soundscape.inspect()['phase'],
      'ticks': g.renderedTicks,
      'enemies': [
        for (final e in s.enemies)
          {
            'id': e.id,
            'position': [e.x, e.y, e.z],
            'awareness': e.awareness.name,
            'source': e.knowledgeSource,
            'visible': e.visibleToPlayer,
            'target': e.investigationTarget?.storage.toList(),
          },
      ],
    });
  }

  Future<void> wait(double seconds, String stage) async {
    s.stopInput();
    final until = s.time + seconds;
    while (s.time < until) {
      observe(stage);
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
  }

  Future<void> walk(double x, double z, {bool run = false}) async {
    s.aiming = false;
    s.sneaking = !run;
    s.sprint = run;
    final deadline =
        s.time +
        math.sqrt(math.pow(x - s.x, 2) + math.pow(z - s.z, 2)) /
            (run ? 2.8 : .62) +
        5;
    while (true) {
      observe('walk:$x,$z');
      final dx = x - s.x, dz = z - s.z, distance = math.sqrt(dx * dx + dz * dz);
      if (distance < .10) break;
      if (s.time > deadline) {
        throw StateError('Blocked at ${s.x},${s.z} toward $x,$z');
      }
      s.yaw = 0;
      final magnitude = math.min(1.0, distance / .16);
      s.inputX = -dx / distance * magnitude;
      s.inputY = -dz / distance * magnitude;
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    s.stopInput();
  }

  g.posePreview = false;
  g.director = null;
  s.phase = PlayPhase.playing;
  g.refreshView();
  try {
    await walk(-18, -19);
    g.interact();
    await walk(-13, -19.4);
    await walk(-10, -18.8);
    g.interact();
    await walk(-5, -19);
    s.yaw = -2;
    s.pitch = .12;
    await wait(.2, 'lookout');
    final visibleBeforeThrow = s.enemies.any((e) => e.visibleToPlayer);
    s.equip('beer');
    s.aiming = true;
    final direction = vm.Vector3(.9, .2, .4).normalized();
    s.yaw = math.atan2(-direction.x, -direction.z);
    preview = s.planBeerThrow(direction).landing.clone();
    s.shoot(s.beerThrowOrigin, direction);
    s.aiming = false;
    await wait(1.2, 'impact');
    for (final p in [
      (-10.65, -18.8),
      (-10.65, -15.0),
      (-12.5, -15.0),
      (-12.5, -10.0),
      (-16.0, -10.0),
    ]) {
      await walk(p.$1, p.$2, run: true);
    }
    await wait(12, 'cover');
    return {
      'success':
          visibleBeforeThrow &&
          heardLure &&
          s.health == 100 &&
          s.beersThrown == 1 &&
          s.shots == 0 &&
          !s.enemies.any((e) => e.alerted) &&
          landing != null &&
          (landing! - preview).length < .08 &&
          g.renderedTicks - initialTicks > 100,
      'mode': 'native rendered controller inputs; not keyboard/touch or performance proof',
      'wallMs': watch.elapsedMilliseconds,
      'simulationSeconds': s.time,
      'health': s.health,
      'beersThrown': s.beersThrown,
      'shots': s.shots,
      'visibleBeforeThrow': visibleBeforeThrow,
      'sawEnemy': sawEnemy,
      'heardLure': heardLure,
      'preview': preview.storage.toList(),
      'landing': landing?.storage.toList(),
      'renderedTicks': g.renderedTicks - initialTicks,
      'musicPhases': music.toList(),
      'trace': trace,
    };
  } catch (error) {
    return {
      'success': false,
      'reason': error.toString(),
      'wallMs': watch.elapsedMilliseconds,
      'renderedTicks': g.renderedTicks - initialTicks,
      'trace': trace,
    };
  } finally {
    if (!g.disposed && g.runEpoch == epoch && identical(g.state, s)) {
      s.stopInput();
      if (s.phase != PlayPhase.paused) g.toggle(PlayPhase.paused);
    }
  }
}
