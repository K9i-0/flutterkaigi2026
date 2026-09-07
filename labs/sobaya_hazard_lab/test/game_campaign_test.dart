import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

Map<String, Map<String, dynamic>> maps() => {
  for (final id in ['village', 'farm', 'mountain'])
    id: jsonDecode(File('assets/$id.json').readAsStringSync()),
};
void cross(HazardCampaign c, String id) {
  final s = c.state;
  final exit = (s.map['exits'] as List).firstWhere((e) => e['id'] == id);
  s.x = (exit['x'] as num).toDouble();
  s.z = (exit['z'] as num).toDouble();
  s.y = 0;
  s.tick(.01);
  expect(s.phase, PlayPhase.transition);
  expect(c.traverse(), true);
}

void main() {
  test('three-region round trip preserves local loot and carries current inventory', () {
    final c = HazardCampaign(maps());
    final v = c.state;
    v.hasKey = v.gateOpen = true;
    v.pickups.first.taken = true;
    v.beers = 4;
    v.health = 73;
    v.pistolLoaded = 3;
    v.collected.add('wanted');
    cross(c, 'forward');
    expect(c.state.zoneId, 'farm');
    expect(c.state.hasKey, false);
    expect(c.state.beers, 4);
    expect(c.state.health, 73);
    expect(c.state.pistolLoaded, 3);
    expect(c.state.gallery.length, 12);
    c.state.pickups.first.taken = true;
    c.state.beers = 2;
    c.state.tradePurchases['ammo'] = 1;
    c.state.medallions.add('farm_0');
    c.state.x = 18.5;
    c.state.z = -10;
    c.state.interact();
    expect(c.state.gateOpen, true);
    cross(c, 'forward');
    expect(c.state.zoneId, 'mountain');
    expect(c.state.medallions, {'farm_0'});
    expect(c.state.bossAlive, true);
    cross(c, 'back');
    expect(c.state.pickups.first.taken, true);
    expect(c.state.gateOpen, true);
    cross(c, 'back');
    expect(c.state.zoneId, 'village');
    expect(c.state.pickups.first.taken, true);
    expect(c.state.beers, 2);
    expect(c.state.tradePurchases['ammo'], 1);
    expect(c.state.hasKey, true);
    final restored = HazardCampaign.restore(
      jsonDecode(jsonEncode(c.checkpoint())),
      maps(),
      {'wanted'},
    );
    expect(restored.regions.length, 3);
    cross(restored, 'forward');
    expect(restored.state.pickups.first.taken, true);
    expect(restored.state.medallions, {'farm_0'});
    expect(restored.state.beers, 2);
  });

  test('old village checkpoint remains loadable', () {
    final old = HazardGameState(maps()['village']!);
    final c = HazardCampaign.restore(old.checkpoint(), maps(), {'wanted'});
    expect(c.state.zoneId, 'village');
    expect(c.state.collected, {'wanted'});
  });

  test('farm medals are shootable, award once and survive checkpoint', () {
    final s = HazardGameState(maps()['farm']!);
    for (final e in s.enemies) {
      e.active = false;
    }
    s.pistolLoaded =
        10; // Target geometry test, independent of starting supply.
    for (final t in s.targets) {
      s.x = (t['x'] as num).toDouble();
      s.z = (t['z'] as num).toDouble() - 1;
      s.y = (t['y'] as num).toDouble() - 1.25;
      s.aiming = true;
      s.fireCooldown = 0;
      s.shoot(vm.Vector3(s.x, s.y + 1.25, s.z), vm.Vector3(0, 0, 1));
    }
    expect(s.medallions.length, 7);
    expect(s.beers, 3);
    s.fireCooldown = 0;
    s.shoot(vm.Vector3(s.x, s.y + 1.25, s.z), vm.Vector3(0, 0, 1));
    expect(s.beers, 3);
    s.x = -19;
    s.z = -21;
    s.y = 0;
    final restored = restoreHazardCheckpoint(
      s.checkpoint(),
      maps()['farm']!,
      {},
    );
    expect(restored.medallions.length, 7);
    expect(restored.beers, 3);
  });

  test('the old eastern exit never clears, even with a saved open gate', () {
    final s = HazardGameState(maps()['mountain']!);
    for (final e in s.enemies) {
      e.active = false;
    }
    expect((s.map['exits'] as List).any((e) => e['target'] == 'ending'), false);
    for (final defeated in [false, true]) {
      final boss = s.enemies.firstWhere((e) => e.boss);
      boss
        ..hp = defeated ? 0 : boss.maxHp
        ..alive = !defeated;
      s
        ..kills = defeated ? 1 : 0
        ..gateOpen = true
        ..x = 21.2
        ..z = 15;
      s.tick(.01);
      expect(s.phase, PlayPhase.playing);
      expect(s.exitRequested, isNull);
      expect(s.refugeComplete, false);
    }
  });

  test(
    'boss telegraph allows movement to evade and heavy hit has recovery',
    () {
      final s = HazardGameState(maps()['mountain']!);
      for (final e in s.enemies) {
        e.active = false;
      }
      final boss = s.enemies.firstWhere((e) => e.boss)
        ..active = true
        ..alerted = true
        ..x = 10
        ..z = 4;
      s.x = 10;
      s.z = 5.5;
      s.tick(.01);
      expect(boss.attackPending, true);
      expect(boss.windup, greaterThan(.8));
      s.inputX = -1;
      s.sprint = true;
      for (var i = 0; i < 75; i++) {
        s.tick(1 / 60);
      }
      expect(s.health, 100);
      expect(boss.bossMove, BossMove.recovery);
      expect(boss.bossTimer, greaterThan(1));
      expect(boss.attackPending, false);
    },
  );

  test('region arrival points and both routes are physically connected', () {
    // Flood a 0.5m grid using collision, including the player's capsule radius.
    // This detects sealing a doorway/corridor when shared geometry changes.
    for (final entry in maps().entries) {
      final s = HazardGameState(entry.value)..gateOpen = true;
      // This audit measures post-combat access; the closed house is tested
      // separately and must not be treated as a permanently broken route.
      if (s.hasRefuge) {
        final boss = s.enemies.singleWhere((e) => e.boss);
        boss
          ..alive = false
          ..hp = 0;
        s.kills = 1;
        s.refreshRefuge();
      }
      final reached = <(int, int)>{};
      final queue = <(int, int)>[((s.x * 2).round(), (s.z * 2).round())];
      reached.add(queue.first);
      for (var i = 0; i < queue.length; i++) {
        final a = queue[i];
        for (final d in [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
          final n = (a.$1 + d.$1, a.$2 + d.$2);
          if (reached.contains(n) || s.blocked(n.$1 / 2, n.$2 / 2, 0)) continue;
          reached.add(n);
          queue.add(n);
        }
      }
      for (final e in s.map['exits']) {
        expect(
          reached.any(
            (p) =>
                math.pow(p.$1 / 2 - e['x'], 2) +
                    math.pow(p.$2 / 2 - e['z'], 2) <
                math.pow(e['radius'], 2),
          ),
          true,
          reason: '${entry.key} exit ${e['id']} unreachable',
        );
      }
      for (final image in s.images.where((p) => (p['y'] as num) < 1.5)) {
        expect(
          reached.any((cell) {
            final x = cell.$1 / 2, z = cell.$2 / 2;
            final d = vm.Vector3(
              (image['x'] as num).toDouble() - x,
              0,
              (image['z'] as num).toDouble() - z,
            );
            return d.length < 1.65 &&
                s.wallDistance(
                      vm.Vector3(x, .9, z),
                      d.normalized(),
                      d.length,
                    ) >=
                    d.length - .12;
          }),
          true,
          reason: 'Inaccessible wall collection ${entry.key}/${image['id']}',
        );
      }
      if (entry.key == 'farm') {
        for (final target in s.targets) {
          final aim = vm.Vector3(
            (target['x'] as num).toDouble(),
            (target['y'] as num).toDouble(),
            (target['z'] as num).toDouble(),
          );
          expect(
            reached.any((cell) {
              final origin = vm.Vector3(cell.$1 / 2, 1.35, cell.$2 / 2);
              final delta = aim - origin;
              final pitch = -math.atan2(
                delta.y,
                math.sqrt(delta.x * delta.x + delta.z * delta.z),
              );
              return delta.length < 25 &&
                  pitch >= -.25 &&
                  pitch <= .65 &&
                  s.wallDistance(origin, delta.normalized(), delta.length) >=
                      delta.length - .1;
            }),
            true,
            reason: 'Unshootable from walkable ground: ${target['id']}',
          );
        }
      }
      for (final n in s.npcs) {
        expect(
          reached.any(
            (p) =>
                math.pow(p.$1 / 2 - n['x'], 2) +
                    math.pow(p.$2 / 2 - n['z'], 2) <
                2.5,
          ),
          true,
          reason: '${entry.key} NPC ${n['id']} unreachable',
        );
      }
    }
  });
}
