import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_stealth_routes_test.dart' show RouteProbe, routeWorld;

void main() {
  test('shop gap continues past the notice tree without a hidden sidestep', () {
    for (final oldPosition in [true, false]) {
      final map = routeWorld('farm');
      if (oldPosition) {
        for (final solid in map['solids'] as List) {
          if (solid['id'] == 'trunk' &&
              solid['x'] == -11.8 &&
              solid['z'] == -16) {
            solid['x'] = -11.0;
          }
        }
      }
      final s = HazardGameState(map);
      final blocked = [
        for (var i = 0; i <= 50; i++)
          if (s.blocked(-10.65, -17.5 + i * .05, 0)) -17.5 + i * .05,
      ];
      expect(blocked.isEmpty, !oldPosition);
    }
  });

  test('authored shop route sees a guard, lures with collected beer and reaches cover', () {
    final s = HazardGameState(routeWorld('farm'));
    s.useNavigation(s.prepareNavigation());
    final p = RouteProbe(s);
    expect(s.enemies.where((e) => e.active), hasLength(6));
    expect(s.beers, 0);
    expect(p.path([(-18, -19)], sneak: true), isTrue);
    s.interact();
    expect(p.path([(-13, -19.4), (-10, -18.8)], sneak: true), isTrue);
    s.interact();
    expect(s.beers, 3);
    expect(p.path([(-5, -19)], sneak: true), isTrue);
    s.yaw = -2;
    p.wait(.2);
    final visibleBeforeThrow = s.enemies.any((e) => e.visibleToPlayer);
    expect(visibleBeforeThrow, isTrue);
    final before = s.beers;
    final thrown = p.throwToward(vm.Vector3(.9, .2, .4).normalized());
    final plan = (thrown['landing'] as List).cast<num>();
    final deadline = s.time + 3;
    while (s.beerSplashes.isEmpty && s.time < deadline) {
      p.tick();
    }
    expect(s.beerSplashes, isNotEmpty);
    final landing = s.beerSplashes.single.position;
    expect(landing.x, closeTo(plan[0], .08));
    expect(landing.z, closeTo(plan[1], .08));
    final noise = (s.inspectStealth()['sounds'] as List).singleWhere(
      (n) => n['kind'] == 'beer_lure',
    );
    expect(noise['position'][0], closeTo(landing.x, .001));
    expect(noise['position'][2], closeTo(landing.z, .001));
    p.wait(.2);
    final lured = s.enemies
        .where((e) => e.knowledgeSource == 'beer_lure')
        .toList();
    expect(lured, isNotEmpty);
    for (final e in lured) {
      expect(e.investigationTarget!.x, closeTo(landing.x, .001));
      expect(e.investigationTarget!.z, closeTo(landing.z, .001));
    }
    expect(
      p.path([
        (-10.65, -18.8),
        (-10.65, -15),
        (-12.5, -15),
        (-12.5, -10),
        (-16, -10),
      ], run: true),
      isTrue,
    );
    p.wait(12);
    expect(p.failures, isEmpty);
    expect(s.health, 100);
    expect(s.beers, before - 1);
    expect(s.beersThrown, 1);
    expect(s.shots, 0);
    expect(s.enemies.any((e) => e.alerted), isFalse);
    expect(s.enemies.every((e) => e.alive && e.active), isTrue);
    if (Platform.environment['HAZARD_WRITE_ALLEY_QA'] == 'true') {
      final out = Directory('evidence/alley-20260914')
        ..createSync(recursive: true);
      File('${out.path}/state-route.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert({
          'method': '20 Hz state simulation on authored actors and pickups; no in-route teleport or granted items',
          'visibleBeforeThrow': visibleBeforeThrow,
          'perceptionMetrics': 'visibleBeforeThrow means the player sees a guard; discoveries/visibleSeconds in the route summary count guards detecting/seeing the player.',
          'throw': thrown,
          'landing': landing.storage.toList(),
          'noise': noise,
          'luredEnemies': lured.map((e) => e.id).toList(),
          ...p.result(),
        }),
      );
    }
  });
}
