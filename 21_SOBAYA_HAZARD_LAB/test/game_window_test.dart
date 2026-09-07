import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';

HazardGameState game([String region = 'village']) {
  final s = HazardGameState(
    jsonDecode(File('assets/$region.json').readAsStringSync()),
  );
  for (final e in s.enemies) {
    e.active = false;
  }
  final w = s.windows.first;
  s.x = w.x;
  s.z = w.entryZ(true);
  s.y = 0;
  s.heading = 0;
  return s;
}

void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

void main() {
  test('every usable opening blocks walking and supports both directions', () {
    for (final region in ['village', 'farm', 'mountain']) {
      final s = game(region);
      for (final c in s.crates) {
        c.broken = true;
      }
      for (final w in s.usableWindows) {
        s.x = w.x;
        s.z = w.entryZ(true);
        s.y = 0;
        expect(s.blocked(w.x, w.z, 0), true);
        expect(s.blocked(w.x, w.entryZ(true), 0), false);
        expect(s.blocked(w.x, w.exitZ(true), 0), false);
        s.interact();
        expect(s.vault, isNotNull, reason: w.id);
        var height = 0.0;
        for (var i = 0; i < 140; i++) {
          final before = vm.Vector3(s.x, s.y, s.z);
          s.tick(1 / 60);
          expect((vm.Vector3(s.x, s.y, s.z) - before).length, lessThan(.05));
          if (s.y > height) height = s.y;
        }
        expect(height, greaterThan(.5));
        expect(s.vault, isNull);
        expect(s.z, closeTo(w.exitZ(true), .001));
        expect(s.y, 0);
        s.interact();
        expect(s.vault?.inward, false, reason: w.id);
        advance(s, 2.5);
        expect(s.z, closeTo(w.entryZ(true), .001));
        expect(s.y, 0);
      }
    }
  });
  test('vault pauses, resumes saved root and blocks other actions', () {
    final s = game()..interact();
    advance(s, .9);
    final before = (s.x, s.y, s.z, s.vault!.elapsed);
    s.phase = PlayPhase.paused;
    advance(s, 3);
    expect((s.x, s.y, s.z, s.vault!.elapsed), before);
    final data = s.checkpoint();
    final restored = restoreHazardCheckpoint(data, s.map, {});
    expect((
      restored.x,
      restored.y,
      restored.z,
      restored.vault!.elapsed,
    ), before);
    restored.aiming = true;
    restored.shoot(vm.Vector3.zero(), vm.Vector3(0, 0, 1));
    restored.pistolLoaded = 1;
    restored.reload();
    restored.evade();
    restored.kick();
    expect(restored.shots, 0);
    expect(restored.reloading, 0);
    expect(restored.evadeTime, 0);
    expect(restored.kickTime, 0);
    advance(restored, 2);
    expect(restored.vault, isNull);
    expect(restored.y, 0);
    data['player']['vault']['elapsed'] = 0;
    expect(
      () => restoreHazardCheckpoint(data, s.map, {}),
      throwsFormatException,
    );
  });
  test('blocked landing prevents player vault', () {
    final s = game();
    final w = s.windows.first;
    s.enemies.first
      ..active = true
      ..x = w.x
      ..z = w.exitZ(true);
    s.interact();
    expect(s.vault, isNull);
  });
  test('enemy follows through a window, queues, and can return outside', () {
    final s = game();
    final w = s.windows.first;
    s.z = w.exitZ(true) + 2;
    s.invulnerable = 1000;
    final e = s.enemies.first
      ..active = true
      ..alerted = true
      ..x = w.x
      ..z = w.entryZ(true);
    final other = s.enemies[1]
      ..active = true
      ..alerted = true
      ..x = w.x
      ..z = w.entryZ(true) - 1;
    var crossed = false, attacked = false;
    for (var i = 0; i < 900; i++) {
      s.tick(1 / 60);
      crossed |= e.vault != null;
      expect(
        s.enemies.where((e) => e.vault != null).length,
        lessThanOrEqualTo(1),
      );
      attacked |= e.attackPending;
      if (attacked) break;
    }
    expect(crossed, true);
    expect(attacked, true, reason: '${e.x},${e.z}');
    other.active = false;
    other.vault = null;
    s.z = w.entryZ(true) - 2;
    advance(s, 15);
    expect(e.z, lessThan(w.z));
  });
  test('a mid-window enemy resumes and drops one reachable beer without teleporting', () {
    final s = game();
    final w = s.windows.first;
    s.z = w.exitZ(true) + 2;
    final e = s.enemies.first
      ..active = true
      ..alerted = true
      ..x = w.x
      ..z = w.entryZ(true)
      ..hp = 1;
    advance(s, 1.0);
    expect(e.vault, isNotNull);
    final saved = s.checkpoint();
    final resumed = restoreHazardCheckpoint(saved, s.map, {});
    expect(resumed.enemies.first.vault!.elapsed, e.vault!.elapsed);
    final at = (e.x, e.y, e.z);
    s.aiming = true;
    s.shoot(vm.Vector3(e.x, e.y + 1.2, e.z - 2), vm.Vector3(0, 0, 1));
    expect(e.alive, false);
    expect((e.x, e.y, e.z), at);
    advance(s, 2);
    final beers = s.pickups.where((p) => p.id == 'beer_${e.id}').toList();
    expect(beers, hasLength(1));
    expect(beers.single.y, closeTo(.25, .001));
    expect(s.blocked(beers.single.x, beers.single.z, 0), false);
    final again = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    advance(again, 2);
    expect(again.pickups.where((p) => p.id == 'beer_${e.id}'), hasLength(1));
  });
  test('old checkpoints remain valid and corrupted vaults are rejected', () {
    final s = game();
    final old = s.checkpoint();
    old['player'].remove('vault');
    for (final e in old['enemies']) {
      e.remove('vault');
    }
    expect(restoreHazardCheckpoint(old, s.map, {}).vault, isNull);
    s.interact();
    advance(s, .8);
    final bad = s.checkpoint();
    bad['player']['vault']['window'] = 'unknown';
    expect(
      () => restoreHazardCheckpoint(bad, s.map, {}),
      throwsFormatException,
    );
  });
}
