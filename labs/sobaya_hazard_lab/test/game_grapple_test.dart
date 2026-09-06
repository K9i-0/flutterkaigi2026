import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';

HazardGameState game() {
  final s = HazardGameState(
    jsonDecode(File('assets/village.json').readAsStringSync()),
  );
  for (final e in s.enemies) {
    e.active = false;
  }
  s.x = 0;
  s.z = -21;
  s.y = 0;
  s.heading = 0;
  s.yaw = math.pi;
  s.enemies.first
    ..active = true
    ..alerted = true
    ..x = 0
    ..y = 0
    ..z = -20.1
    ..heading = math.pi;
  return s;
}

void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

void capture(HazardGameState s) {
  for (var i = 0; i < 90 && s.grapple == null; i++) {
    s.tick(1 / 60);
  }
  expect(s.grapple, isNotNull);
}

void main() {
  test('a shot interrupts the grab tell and restores the mug attack state', () {
    final s = game();
    advance(s, .3);
    expect(s.enemies.first.grabPending, true);
    s.aiming = true;
    s.shoot(vm.Vector3(0, 1.6, -21), vm.Vector3(0, 0, 1));
    expect(s.hits, 1);
    expect(s.enemies.first.attackPending, false);
    expect(s.enemies.first.grabPending, false);
    advance(s, 1.1);
    expect(s.grapple, isNull);
    expect(s.health, 100);
  });

  test('checkpoint preserves the pending attack kind', () {
    final s = game();
    advance(s, .3);
    final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    expect(restored.enemies.first.grabPending, true);
    restored.invulnerable = 0;
    restored.phase = PlayPhase.playing;
    capture(restored);
    expect(restored.enemies.first.attackPending, false);
    expect(restored.enemies.first.grabPending, false);
  });

  test('grab damage follows difficulty without scaling enemy health', () {
    for (final difficulty in HazardDifficulty.values) {
      final settings = HazardSettings(difficulty: difficulty);
      final s = game()..damageScale = settings.damageScale;
      capture(s);
      advance(s, 1.1);
      expect(s.health, closeTo(100 - 8 * settings.damageScale, .001));
      expect(s.enemies.first.hp, 100);
    }
  });

  test('grab warns before contact and can be evaded', () {
    final s = game();
    advance(s, .3);
    expect(s.enemies.first.grabPending, true);
    expect(s.grapple, isNull);
    expect(s.health, 100);
    s.inputY = -1;
    s.evade();
    advance(s, 1.1);
    expect(s.grapple, isNull);
    expect(s.health, 100);
    expect(s.enemies.first.grabCooldown, greaterThan(0));
  });
  test('holding escape frees the player and gives a recovery window', () {
    final s = game();
    capture(s);
    final anchor = (s.x, s.y, s.z);
    s.struggling = true;
    s.inputX = s.inputY = 1;
    s.shoot(vm.Vector3(0, 1.3, -21), vm.Vector3(0, 0, 1));
    s.reload();
    s.evade();
    s.kick();
    s.interact();
    s.health = 90;
    final herbs = s.bag.where((i) => i.kind == 'green').length;
    s.useBag(s.bag.firstWhere((i) => i.kind == 'green').id);
    expect(s.health, 90);
    expect(s.bag.where((i) => i.kind == 'green').length, herbs);
    s.health = 100;
    s.toggle(PlayPhase.inventory);
    expect(s.phase, PlayPhase.playing);
    expect(s.shots, 0);
    expect(s.reloading, 0);
    expect(s.evadeTime, 0);
    expect(s.kickTime, 0);
    advance(s, 1.25);
    expect(s.grapple, isNull);
    expect((s.x, s.y, s.z), anchor);
    expect(s.health, 92);
    expect(s.breakFreeTime, greaterThan(0));
    expect(s.invulnerable, greaterThan(1));
    expect(s.enemies.first.stun, greaterThan(1));
  });
  test('unanswered grab applies three beats and releases without softlock', () {
    final s = game();
    capture(s);
    advance(s, 3.5);
    expect(s.grapple, isNull);
    expect(s.health, 76);
    expect(s.running, true);
    advance(s, .8);
    expect(s.actionLocked, false);
  });
  test('pause and checkpoint preserve effort, contact and damage clock', () {
    final s = game();
    capture(s);
    advance(s, .5);
    s.struggling = true;
    advance(s, .4);
    s.phase = PlayPhase.paused;
    final before = s.grapple!.toJson();
    advance(s, 4);
    expect(s.grapple!.toJson(), before);
    final data = s.checkpoint();
    final loaded = restoreHazardCheckpoint(data, s.map, {});
    expect(loaded.grapple!.toJson(), before);
    expect(loaded.struggling, false);
    loaded.struggling = true;
    s.phase = PlayPhase.playing;
    advance(s, .3);
    advance(loaded, .3);
    expect(loaded.health, 92);
    expect(loaded.health, s.health);
    expect(loaded.grapple!.effort, closeTo(s.grapple!.effort, .00001));
    data['player']['grapple']['playerX'] = 2;
    expect(
      () => restoreHazardCheckpoint(data, s.map, {}),
      throwsFormatException,
    );
  });
  test('a wall blocks capture and actor pull-in', () {
    final s = game();
    s.obstacles.add(
      Obstacle({'x': 0, 'z': -20.6, 'w': .7, 'd': .05, 'bottom': 0, 'top': 2}),
    );
    advance(s, 1.3);
    expect(s.grapple, isNull);
    expect(s.health, 100);
    expect(s.enemies.first.z, greaterThan(-20.3));
  });
  test('other enemy mugs cannot stack damage while attached', () {
    final s = game();
    capture(s);
    s.enemies[1]
      ..active = true
      ..alerted = true
      ..x = .8
      ..y = 0
      ..z = -21
      ..heading = -math.pi / 2
      ..attackPending = true
      ..windup = .05;
    advance(s, .3);
    expect(s.grapple, isNotNull);
    expect(s.health, 100);
  });
  test('a defeated grappler releases and still drops exactly one beer', () {
    final s = game();
    capture(s);
    s.enemies.first
      ..hp = 0
      ..alive = false;
    s.kills = 1;
    advance(s, 1);
    expect(s.grapple, isNull);
    expect(s.pickups.where((p) => p.id == 'beer_0').length, 1);
    advance(s, 2);
    expect(s.pickups.where((p) => p.id == 'beer_0').length, 1);
  });
  test('lethal restraint ends at death without leaving an attachment', () {
    final s = game();
    capture(s);
    s.health = 5;
    advance(s, 1.1);
    expect(s.phase, PlayPhase.dead);
    expect(s.health, 0);
    expect(s.grapple, isNull);
    expect(s.struggling, false);
  });
}
