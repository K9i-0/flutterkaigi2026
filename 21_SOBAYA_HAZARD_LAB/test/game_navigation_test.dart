import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';

HazardGameState game(String region) =>
    HazardGameState(jsonDecode(File('assets/$region.json').readAsStringSync()));

void main() {
  for (final region in ['village', 'farm']) {
    test(
      '$region enemy uses stairs to pursue upstairs and return downstairs',
      () {
        final s = game(region);
        for (final enemy in s.enemies) {
          enemy.active = false;
        }
        final ramp = (s.map['ramps'] as List).first;
        final rx = (ramp['x'] as num).toDouble();
        final bottom = (ramp['z0'] as num).toDouble();
        final top = (ramp['z1'] as num).toDouble();
        s.x = rx - 2;
        s.z = top + .65;
        s.y = 3.03;
        s.invulnerable = 1000;
        final e = s.enemies.first
          ..x = rx
          ..z = bottom + .35
          ..y = s.floorHeight(rx, bottom + .35, 0)
          ..active = true
          ..alerted = true;
        var previousY = e.y;
        for (var i = 0; i < 2400 && e.y < 3; i++) {
          s.tick(1 / 60);
          expect(
            (e.y - previousY).abs(),
            lessThan(.34),
            reason: 'No floor teleport',
          );
          if (e.y > .1 && e.y < 2.8) {
            expect((e.x - rx).abs(), lessThan(ramp['w'] / 2));
          }
          previousY = e.y;
        }
        expect(e.y, closeTo(3.03, .05), reason: '${e.x},${e.y},${e.z}');
        s.x = rx - 2;
        s.z = bottom + .35;
        s.y = s.floorHeight(s.x, s.z, 0);
        for (var i = 0; i < 2400 && e.y > .2; i++) {
          s.tick(1 / 60);
        }
        expect(e.y, lessThan(.2), reason: '${e.x},${e.y},${e.z}');
      },
    );
  }
  test('upstairs bullets hit enemy and death drops one beer on that floor', () {
    final s = game('village')
      ..x = 7
      ..y = 3.03
      ..z = -5
      ..aiming = true;
    for (final e in s.enemies) {
      e.active = false;
    }
    final e = s.enemies.first
      ..x = 7
      ..y = 3.03
      ..z = -7
      ..active = true
      ..hp = 1;
    final origin = vm.Vector3(s.x, s.y + 1.1, s.z);
    s.shoot(origin, vm.Vector3(e.x, e.y + 1.1, e.z) - origin);
    expect(e.alive, false);
    for (var i = 0; i < 120; i++) {
      s.tick(1 / 60);
    }
    final beers = s.pickups.where((p) => p.id == 'beer_${e.id}').toList();
    expect(beers, hasLength(1));
    expect(beers.single.y, closeTo(3.28, .001));
  });
  test('player cannot enter a high stair tread sideways from ground', () {
    final s = game('village')
      ..x = 10
      ..z = -5
      ..y = 0;
    s.move(1, 0, 1);
    expect(s.y, 0);
    expect(s.x, lessThan(10.3));
  });
}
