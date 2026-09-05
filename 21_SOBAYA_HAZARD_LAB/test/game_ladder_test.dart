import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';

HazardGameState game() {
  final s = HazardGameState(
    jsonDecode(File('assets/village.json').readAsStringSync()),
  );
  for (final e in s.enemies) {
    e.active = false;
  }
  return s
    ..x = -13.5
    ..y = 0
    ..z = -9.1;
}

void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

void main() {
  test('ladder is continuous, blocks combat, pauses and descends', () {
    final s = game()..interact();
    expect(s.climb, isNotNull);
    expect(s.y, 0);
    advance(s, 2);
    expect(s.y, inExclusiveRange(.1, 4));
    final before = (s.x, s.y, s.z, s.climb!.elapsed);
    s.phase = PlayPhase.paused;
    advance(s, 3);
    expect((s.x, s.y, s.z, s.climb!.elapsed), before);
    s.phase = PlayPhase.playing;
    s.aiming = true;
    s.shoot(vm.Vector3.zero(), vm.Vector3(0, 0, 1));
    s.pistolLoaded = 1;
    s.reload();
    s.evade();
    s.kick();
    expect(s.shots, 0);
    expect(s.reloading, 0);
    expect(s.evadeTime, 0);
    for (var i = 0; i < 600 && s.climb != null; i++) {
      final previous = vm.Vector3(s.x, s.y, s.z);
      s.tick(1 / 60);
      expect((vm.Vector3(s.x, s.y, s.z) - previous).length, lessThan(.04));
    }
    expect(s.climb, isNull);
    expect(s.y, closeTo(4.22, .001));
    s.interact();
    expect(s.climb?.up, false);
    advance(s, 10);
    expect(s.climb, isNull);
    expect(s.y, 0);
  });
  test(
    'mid-ladder checkpoint resumes precisely and rejects inconsistent data',
    () {
      final s = game()..interact();
      advance(s, 3);
      final saved = s.checkpoint();
      final resumed = restoreHazardCheckpoint(saved, s.map, {});
      expect(resumed.climb!.elapsed, s.climb!.elapsed);
      advance(resumed, 8);
      expect(resumed.y, closeTo(4.22, .001));
      saved['player']['climb']['elapsed'] = 0;
      expect(
        () => restoreHazardCheckpoint(saved, s.map, {}),
        throwsFormatException,
      );
    },
  );
  test('enemy follows up and down, one climber at a time', () {
    final s = game()
      ..y = 4.22
      ..z = -6.5
      ..invulnerable = 1000;
    final e = s.enemies.first
      ..x = -13.5
      ..y = 0
      ..z = -12
      ..active = true
      ..alerted = true;
    final other = s.enemies[1]
      ..x = -12.6
      ..y = 0
      ..z = -12
      ..active = true
      ..alerted = true;
    var climbed = false, attacked = false;
    for (var i = 0; i < 2400; i++) {
      s.tick(1 / 60);
      expect(
        s.enemies.where((e) => e.climb != null).length,
        lessThanOrEqualTo(1),
      );
      climbed |= e.climb != null;
      attacked |= s.enemies.any((e) => e.attackPending && e.y > 4);
      if (attacked) break;
    }
    expect(climbed, true);
    expect(
      attacked,
      true,
      reason: '${e.x},${e.y},${e.z} / ${other.x},${other.y},${other.z}',
    );
    other.active = false;
    other.climb = null;
    s.y = 0;
    s.z = -12;
    advance(s, 30);
    expect(e.y, 0);
  });
  test('falling off the tower reaches the ground after movement stops', () {
    final s = game()
      ..x = -15.4
      ..z = -6.5
      ..y = 3.2;
    advance(s, 1);
    expect(s.y, 0);
  });
  test(
    'enemy can hit at the bottom; hurt pauses attachment without a teleport',
    () {
      final s = game();
      final e = s.enemies.first
        ..active = true
        ..alerted = true
        ..x = -13.5
        ..z = -10
        ..attackPending = true
        ..windup = .08
        ..heading = 0;
      s.interact();
      advance(s, .1);
      expect(s.health, 85);
      expect(s.climb, isNotNull);
      final before = s.climb!.elapsed;
      advance(s, .1);
      expect(s.climb!.elapsed, before);
      e.active = false;
      advance(s, 10);
      expect(s.y, 4.22);
    },
  );
  test('old checkpoint and a restarted run have no ladder attachment', () {
    final s = game();
    final old = s.checkpoint();
    old['player'].remove('climb');
    for (final e in old['enemies']) {
      e.remove('climb');
      e.remove('fallingFromLadder');
    }
    expect(restoreHazardCheckpoint(old, s.map, {}).climb, isNull);
    s.interact();
    advance(s, 2);
    s.restart();
    expect(s.climb, isNull);
  });
  test('shooting a climbing enemy drops exactly one reachable beer', () {
    final s = game()
      ..y = 4.22
      ..z = -6.5;
    final e = s.enemies.first
      ..x = -13.5
      ..y = 0
      ..z = -9.1
      ..active = true
      ..alerted = true;
    advance(s, 3);
    expect(e.climb, isNotNull);
    s.x = -13.5;
    s.y = 0;
    s.z = -11;
    s.aiming = true;
    e.hp = 1;
    final origin = vm.Vector3(s.x, 1.1, s.z);
    s.shoot(origin, vm.Vector3(e.x, e.y + 1, e.z) - origin);
    expect(e.alive, false);
    final resumed = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    advance(resumed, 2);
    final beers = resumed.pickups.where((p) => p.id == 'beer_${e.id}');
    expect(beers, hasLength(1));
    expect(beers.single.y, .25);
  });
}
