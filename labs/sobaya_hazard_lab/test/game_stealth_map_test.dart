import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:vector_math/vector_math.dart' as vm;

Map<String, dynamic> loadMap(String name) =>
    jsonDecode(File('assets/$name.json').readAsStringSync());

void clearRoute(
  HazardGameState s,
  List<(double, double)> path, {
  double radius = .29,
}) {
  for (var i = 1; i < path.length; i++) {
    final a = path[i - 1], b = path[i];
    final steps =
        (math.sqrt(math.pow(b.$1 - a.$1, 2) + math.pow(b.$2 - a.$2, 2)) / .1)
            .ceil();
    for (var j = 0; j <= steps; j++) {
      final t = steps == 0 ? 0.0 : j / steps;
      final x = a.$1 + (b.$1 - a.$1) * t;
      final z = a.$2 + (b.$2 - a.$2) * t;
      expect(
        s.blocked(x, z, 0, radius: radius),
        isFalse,
        reason: '${s.map["id"]}: segment $a → $b blocked at ($x, $z)',
      );
    }
  }
}

void main() {
  for (final name in ['village', 'farm']) {
    test('$name offers beer without defeating or breaking anything', () {
      final world = loadMap(name), s = HazardGameState(loadMap(name));
      final beer = (world['items'] as List).where((i) => i['kind'] == 'beer');
      final entry = beer.singleWhere(
        (i) => (i['id'] as String).endsWith('beer_entry'),
      );
      expect(entry['amount'], 2);
      expect(beer.length, greaterThanOrEqualTo(3));
      for (final pickup in beer.where((i) => i['y'] < 2)) {
        expect(
          s.blocked(
            (pickup['x'] as num).toDouble(),
            (pickup['z'] as num).toDouble(),
            0,
          ),
          isFalse,
          reason: '$name ${pickup["id"]} is accessible',
        );
      }
    });

    test(
      '$name rear doors pass a player and an enemy but walls hide flanks',
      () {
        final world = loadMap(name), s = HazardGameState(loadMap(name));
        final doors = (world['houses'] as List).where(
          (h) => h['rearDoor'] != null,
        );
        expect(doors.length, 2);
        for (final house in doors) {
          final d = house['rearDoor'];
          final x = (d['x'] as num).toDouble(), z = (d['z'] as num).toDouble();
          clearRoute(s, [(x, z - .7), (x, z + .7)], radius: .37);
          for (final dx in [0.0, -1.35, 1.35]) {
            final origin = vm.Vector3(x + dx, 1.15, z - .7);
            final distance = s.wallDistance(origin, vm.Vector3(0, 0, 1), 1.4);
            expect(
              distance < 1.35,
              dx != 0,
              reason: '$name ${house["id"]} opening/wall dx=$dx',
            );
          }
        }
      },
    );

    test('$name authored patrol segments fit enemy bodies and avoid props', () {
      final world = loadMap(name), s = HazardGameState(loadMap(name));
      final patrols = (world['enemies'] as List).where(
        (e) => e['patrol'] != null,
      );
      expect(patrols.length, 2);
      for (final e in patrols) {
        final points = (e['patrol'] as List)
            .map((p) => ((p[0] as num).toDouble(), (p[1] as num).toDouble()))
            .toList();
        clearRoute(s, [...points, points.first], radius: .37);
      }
    });
  }

  test(
    'village western key route remains physically connected without a kill',
    () {
      final s = HazardGameState(loadMap('village'))..gateOpen = true;
      clearRoute(s, [
        (0, -21),
        (-7.8, -19.4),
        (-8, -18.3),
        (-8, -11.8),
        (-11.5, -11.8),
        (-11.5, -15),
        (-18, -15),
        (-20.3, -10),
        (-20.3, 15.9),
        (-11, 15.9),
        (-7.8, 16),
        (-4, 15.9),
        (-4, 12),
        (-5, 12),
        (-4, 12),
        (-4, 15.9),
        (2.3, 15.9),
        (6, 19),
        (11.5, 21),
        (11.5, 27.2),
      ]);
    },
  );

  test('farm southern supply route reaches exit without breaking props', () {
    final s = HazardGameState(loadMap('farm'))..gateOpen = true;
    clearRoute(s, [
      (-19, -21),
      (-18, -19),
      (-10, -18.8),
      (-11, -20),
      (-4.8, -20),
      (-3, -21),
      (2, -21),
      (8, -17),
      (14.2, -15),
      (14.2, -10),
      (20, -10),
      (21.2, -10),
    ]);
  });

  test(
    'farm playable tree trunks interrupt sight only across their centre',
    () {
      final s = HazardGameState(loadMap('farm'));
      expect(
        s.wallDistance(vm.Vector3(-11.6, 1.2, -16), vm.Vector3(1, 0, 0), 1.2),
        lessThan(1.2),
      );
      expect(
        s.wallDistance(vm.Vector3(-11.6, 1.2, -16.6), vm.Vector3(1, 0, 0), 1.2),
        1.2,
      );
    },
  );
}
