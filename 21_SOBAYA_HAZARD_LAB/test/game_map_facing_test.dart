import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

void main() {
  for (final name in ['village', 'farm', 'mountain']) {
    Map<String, dynamic> map() =>
        jsonDecode(File('assets/$name.json').readAsStringSync());

    test(
      '$name authored guard facings load, restart and survive checkpoints',
      () {
        final world = map();
        final s = HazardGameState(world);
        final expected = (world['enemies'] as List)
            .map((row) => (row['heading'] as num).toDouble())
            .toList();
        expect(expected.every((heading) => heading.isFinite), isTrue);
        expect(expected.toSet().length, greaterThan(1));
        expect(s.enemies.map((e) => e.heading), expected);
        for (final enemy in s.enemies) {
          enemy.heading = .33;
        }
        s.restart();
        expect(s.enemies.map((e) => e.heading), expected);
        final restored = restoreHazardCheckpoint(
          jsonDecode(jsonEncode(s.checkpoint())),
          world,
          {},
        );
        expect(restored.enemies.map((e) => e.heading), expected);
        if (name == 'mountain') {
          expect(s.enemies.singleWhere((e) => e.boss).heading, 0);
        }
      },
    );

    for (final difficulty in HazardDifficulty.values) {
      test('$name entry and arrival positions are unseen on ${difficulty.name}', () {
        final world = map();
        final entries = <Map<String, dynamic>>[world['spawn']];
        for (final source in ['village', 'farm', 'mountain']) {
          final sourceMap = jsonDecode(
            File('assets/$source.json').readAsStringSync(),
          );
          for (final exit in sourceMap['exits'] as List) {
            if (exit['target'] == name) {
              entries.add(Map<String, dynamic>.from(exit['arrival']));
            }
          }
        }
        for (final entry in entries) {
          final s = HazardGameState(world, difficulty: difficulty)
            ..x = (entry['x'] as num).toDouble()
            ..z = (entry['z'] as num).toDouble()
            ..yaw = (entry['yaw'] as num).toDouble();
          // Entry remains safe for a standing player without an immediate
          // crouch or sprint button press, including return through a gate.
          expect(s.sneaking, isFalse);
          for (final enemy in s.enemies.where((e) => e.active && e.alive)) {
            final distance = math.sqrt(
              math.pow(s.x - enemy.x, 2) + math.pow(s.z - enemy.z, 2),
            );
            expect(
              s.enemyCanSeePlayer(enemy),
              isFalse,
              reason:
                  '$name guard ${enemy.id}, ${distance.toStringAsFixed(1)}m, entry $entry',
            );
          }
          for (var frame = 0; frame < 90; frame++) {
            s.tick(1 / 60);
          }
          expect(s.enemies.any((e) => e.alerted || e.seesPlayer), isFalse);
        }
      });
    }
  }
}
