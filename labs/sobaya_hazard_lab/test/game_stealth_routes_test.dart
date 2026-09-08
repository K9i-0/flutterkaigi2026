// The probe emits machine-readable summaries during explicit QA runs.
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_navigation.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:vector_math/vector_math.dart' as vm;

typedef Point = (double, double);

Map<String, dynamic> routeWorld(String name) =>
    jsonDecode(File('assets/$name.json').readAsStringSync());

/// Authored input at 20 Hz: no teleports after fixture setup, no direct noise,
/// health, awareness, pathfinding or enemy target writes while a run is active.
class RouteProbe {
  RouteProbe(this.state);
  final HazardGameState state;
  int discoveries = 0, reacquisitions = 0, grabs = 0;
  bool sawAlert = false, sawLoss = false, wasAlert = false, wasVisible = false;
  bool wasGrabbed = false;
  double? firstSeen, firstLost, firstRelease, healthAtRelease;
  double visibleSeconds = 0;
  final failures = <String>[];
  final trace = <Map<String, dynamic>>[];
  int _lastSecond = -1;

  void tick() {
    state.tick(.05);
    final alerted = state.enemies.any((e) => e.alive && e.alerted);
    final visible = state.enemies.any(
      (e) => e.alive && e.alerted && e.seesPlayer,
    );
    if (alerted && !wasAlert) discoveries++;
    if (visible) {
      firstSeen ??= state.time;
      visibleSeconds += .05;
      if (!wasVisible && sawLoss) reacquisitions++;
    }
    if (!visible && wasVisible) {
      sawLoss = true;
      firstLost ??= state.time;
    }
    if (sawAlert && !alerted && firstRelease == null) {
      firstRelease = state.time;
      healthAtRelease = state.health;
    }
    if (state.grapple != null && !wasGrabbed) grabs++;
    wasGrabbed = state.grapple != null;
    sawAlert |= alerted;
    wasAlert = alerted;
    wasVisible = visible;
    if (state.time.floor() != _lastSecond) {
      _lastSecond = state.time.floor();
      trace.add({
        'time': number(state.time),
        'player': [number(state.x), number(state.z)],
        'hp': state.health,
        'phase': state.stealthFeedback.phase,
        'remaining': number(state.stealthFeedback.remaining),
        'enemies': [
          for (final e in state.enemies.where((e) => e.active && e.alive))
            {
              'id': e.id,
              'position': [number(e.x), number(e.z)],
              'sees': e.seesPlayer,
              'state': e.awareness.name,
              'source': e.knowledgeSource,
            },
        ],
      });
    }
  }

  bool path(List<Point> points, {bool sneak = false, bool run = false}) {
    state.sneaking = sneak;
    state.sprint = run;
    state.aiming = false;
    for (final p in points) {
      final deadline =
          state.time +
          distance(p) /
              (sneak
                  ? .62
                  : run
                  ? 2.8
                  : 1.25) +
          5;
      while (distance(p) > .075 && state.running && state.time < deadline) {
        final dx = p.$1 - state.x, dz = p.$2 - state.z;
        final d = math.sqrt(dx * dx + dz * dz);
        // Fixed camera yaw with a directional movement stick, as in the UI.
        state.yaw = 0;
        final speed = sneak
            ? .62
            : run
            ? 2.8
            : 1.25;
        final magnitude = math.min(1.0, d / (speed * .05));
        state.inputX = -dx / d * magnitude;
        state.inputY = -dz / d * magnitude;
        tick();
      }
      stop();
      if (distance(p) > .10) {
        failures.add(
          'Could not reach $p at ${number(state.time)}s (${state.phase.name})',
        );
        return false;
      }
    }
    return true;
  }

  void stop() {
    state.inputX = state.inputY = 0;
  }

  void wait(double seconds) {
    stop();
    state.sprint = false;
    final until = state.time + seconds;
    while (state.running && state.time < until) {
      tick();
    }
  }

  double distance(Point p) =>
      math.sqrt(math.pow(p.$1 - state.x, 2) + math.pow(p.$2 - state.z, 2));

  Map<String, dynamic> throwToward(vm.Vector3 direction) {
    stop();
    state.yaw = math.atan2(-direction.x, -direction.z);
    state.equip('beer');
    state.aiming = true;
    final plan = state.planBeerThrow(direction);
    state.shoot(state.beerThrowOrigin, direction);
    state.aiming = false;
    return {
      'landing': [number(plan.landing.x), number(plan.landing.z)],
      'wallImpact': plan.wallHit,
      'throws': state.beersThrown,
    };
  }

  Map<String, dynamic> result() => {
    'elapsed': number(state.time),
    'hp': state.health,
    'survived': state.health > 0,
    'discoveries': discoveries,
    'reacquisitions': reacquisitions,
    'visibleSeconds': number(visibleSeconds),
    'grabs': grabs,
    'firstSeen': number(firstSeen),
    'firstLost': number(firstLost),
    'firstRelease': number(firstRelease),
    'healthAtRelease': healthAtRelease,
    'releaseAfterFirstLoss': firstRelease == null || firstLost == null
        ? null
        : number(firstRelease! - firstLost!),
    'currentlyAlerted': state.enemies.any((e) => e.alerted),
    'shots': state.shots,
    'beersThrown': state.beersThrown,
    'position': [number(state.x), number(state.z)],
    'failures': failures,
    'trace': trace,
  };
}

double? number(num? value) =>
    value == null ? null : (value * 1000).round() / 1000;

Map<String, dynamic> escapeRun(
  String zone,
  String strategy,
  double gap,
  EnemyNavigation geometry,
) {
  final world = routeWorld(zone);
  final start = zone == 'village' ? (-10.5, 12.5) : (2.4, -12.0);
  world['enemies'] = [
    {'id': 0, 'x': start.$1, 'z': start.$2 - gap, 'active': true, 'heading': 0},
  ];
  final state = HazardGameState(world)
    ..x = start.$1
    ..z = start.$2
    ..beers = 1;
  state.useNavigation(geometry);
  final p = RouteProbe(state);
  // Let a real visual observation create the chase, rather than assigning it.
  while (!p.sawAlert && state.time < 2) {
    p.tick();
  }
  final common = zone == 'village'
      ? <Point>[(-10.5, 15.7), (-8.6, 15.7)]
      : <Point>[(2.4, -2.8), (4.7, -2.8)];
  final reachedCorner = p.path(common, run: true);
  final cornerTime = state.time;
  Map<String, dynamic>? thrown;
  if (reachedCorner) {
    if (strategy == 'keep_running') {
      p.path(
        zone == 'village'
            ? [(3, 15.7), (20, 15.7), (20, 22), (-20, 22)]
            : [(2.4, -2.8), (2.4, 21), (17, 21)],
        run: true,
      );
    } else if (strategy != 'stop_at_first_corner') {
      if (strategy == 'beer_then_relocate') {
        thrown = p.throwToward(vm.Vector3(.5, .45, 1).normalized());
      }
      p.path(
        zone == 'village' ? [(-4, 15.7), (-4, 12.2)] : [(8, -2.8), (8, -6.2)],
        run: true,
      );
      p.path(zone == 'village' ? [(-6.4, 12.2)] : [(4.2, -6.2)], sneak: true);
    }
    if (strategy == 'leave_after_release') {
      p.stop();
      state.sprint = false;
      final deadline = state.time + 32;
      while (state.running && p.firstRelease == null && state.time < deadline) {
        p.tick();
      }
      if (p.firstRelease != null) {
        p.path([
          (4.2, -12.6),
          (8, -12.6),
          (8, -15.5),
          (14.2, -15.5),
          (14.2, -10),
          (18.6, -10),
        ], run: true);
        state.interact();
        p.path([(20.4, -10)], run: true);
      }
    } else {
      p.wait(32);
    }
  }
  return {
    'zone': zone,
    'strategy': strategy,
    'startingGap': gap,
    'controlledEnemies': 1,
    'cornerReached': reachedCorner,
    'cornerTime': number(cornerTime),
    'exitRequested': state.exitRequested?['target'],
    'throw': ?thrown,
    ...p.result(),
  };
}

void main() {
  test(
    'full authored guards: unarmed chapter exits with later discovery',
    () {
      final rows = <Map<String, dynamic>>[];
      for (final zone in ['village', 'farm'].where(
        (zone) =>
            Platform.environment['HAZARD_ROUTE_ZONE'] == null ||
            Platform.environment['HAZARD_ROUTE_ZONE'] == zone,
      )) {
        final s = HazardGameState(routeWorld(zone)),
            p = RouteProbe(HazardGameState(routeWorld(zone)));
        // Use the untouched authored actor/item setup for this separate test.
        final state = p.state;
        state.useNavigation(s.prepareNavigation());
        if (zone == 'village') {
          p.path([(-7.8, -19.4)], sneak: true);
          state.interact();
          p.path([
            (-8, -18.3),
            (-8, -11.8),
            (-11.5, -11.8),
            (-11.5, -15),
            (-18, -15),
            (-20.3, -10),
            (-20.3, 15.9),
            (-11, 15.9),
            (-7.8, 16),
          ], sneak: true);
          p.path([
            (-4, 15.9),
            (-4, 13.8),
            (-5.5, 13.8),
            (-5.5, 12.8),
          ], sneak: true);
          state.interact();
          p.path([(-5.5, 13.8), (-4, 13.8)], sneak: true);
          p.throwToward(vm.Vector3(.5, .5, 1).normalized());
          p.path([(-4, 15.9), (2.3, 15.9), (6, 19), (11.5, 21), (11.5, 22.3)]);
          state.interact();
          p.path([(11.5, 26.1)], sneak: true);
        } else {
          p.path([(-18, -19)], sneak: true);
          state.interact();
          p.path([(-10, -18.8)], sneak: true);
          state.interact();
          p.path([
            (-11, -20),
            (-4.8, -20),
            (-3, -21),
            (2, -21),
            (8, -17),
            (14.2, -15),
            (14.2, -10),
            (18.6, -10),
          ], sneak: true);
          state.interact();
          p.path([(20.4, -10)], sneak: true);
        }
        final row = {
          'zone': zone,
          'allAuthoredEnemies': state.enemies.length,
          'exitRequested': state.exitRequested?['target'],
          'hasKey': state.hasKey,
          'enemiesDefeated': state.enemies.where((e) => !e.alive).length,
          'beerCollected': state.beers,
          ...p.result(),
        };
        expect(row['enemiesDefeated'], 0);
        expect(state.shots, 0);
        expect(state.health, greaterThan(0));
        expect(
          state.exitRequested?['target'],
          zone == 'village' ? 'farm' : 'mountain',
        );
        rows.add(row);
        print(jsonEncode(Map.of(row)..remove('trace')));
      }
      File('evidence/stealth-authored-routes-full.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(rows)}\n',
      );
    },
    skip: Platform.environment['HAZARD_WRITE_ROUTE_QA'] != 'true',
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('authored cover escape comparison uses real movement and perception', () {
    final results = <Map<String, dynamic>>[];
    final full = Platform.environment['HAZARD_WRITE_ROUTE_QA'] == 'true';
    for (final zone in ['village', 'farm']) {
      final geometry = HazardGameState(routeWorld(zone)).prepareNavigation();
      for (final gap in full ? [4.5, 6.0, 7.5] : [6.0]) {
        for (final strategy in [
          'keep_running',
          'stop_at_first_corner',
          'relocate_quietly',
          'beer_then_relocate',
          if (zone == 'farm') 'leave_after_release',
        ]) {
          final r = escapeRun(zone, strategy, gap, geometry);
          results.add(r);
          expect(
            r['firstSeen'],
            isNotNull,
            reason: '$zone $strategy must begin from actual detection',
          );
          expect(r['shots'], 0);
          expect(r['hp'], lessThanOrEqualTo(100));
        }
      }
    }
    // These regressions assert the useful difference in the 6m comparison,
    // independently of the optional exploratory cases and final camp deaths.
    for (final zone in ['village', 'farm']) {
      final stop = results.singleWhere(
        (r) =>
            r['zone'] == zone &&
            r['startingGap'] == 6.0 &&
            r['strategy'] == 'stop_at_first_corner',
      );
      final relocate = results.singleWhere(
        (r) =>
            r['zone'] == zone &&
            r['startingGap'] == 6.0 &&
            r['strategy'] == 'relocate_quietly',
      );
      expect(stop['firstRelease'], isNull);
      expect(stop['reacquisitions'], greaterThan(0));
      expect(relocate['healthAtRelease'], 100);
      expect(relocate['releaseAfterFirstLoss'], inInclusiveRange(13.0, 18.0));
      if (zone == 'village') {
        expect(relocate['reacquisitions'], 0);
        expect(relocate['hp'], 100);
      }
    }
    final departure = results.singleWhere(
      (r) => r['startingGap'] == 6.0 && r['strategy'] == 'leave_after_release',
    );
    expect(departure['exitRequested'], 'mountain');
    expect(departure['hp'], 100);
    if (full) {
      File('evidence/stealth-routes-comparison-full.json').writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert({'method': 'Deterministic 20Hz state input on adopted geometry; standard difficulty; one controlled guard; carried beer=1; initial placement only; no teleport, HP reset, forced awareness or injected noise during runs.', 'scope': 'Geometry and AI escape probe, not a subjective horror evaluation or full campaign claim.', 'runs': results})}\n',
      );
    }
    for (final r in results) {
      // Compact console output allows an exploratory run without writing QA.
      print(jsonEncode(Map.of(r)..remove('trace')));
    }
  }, timeout: const Timeout(Duration(minutes: 3)));
}
