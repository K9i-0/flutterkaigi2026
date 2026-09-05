import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';

HazardGameState game() =>
    HazardGameState(jsonDecode(File('assets/village.json').readAsStringSync()));
void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

void main() {
  test(
    'lethal shots remove an enemy and create exactly one beer without blood',
    () {
      final s = game();
      for (final e in s.enemies) {
        e.active = false;
      }
      final e = s.enemies.first
        ..active = true
        ..x = 0
        ..z = -17;
      s.x = 0;
      s.z = -21;
      s.aiming = true;
      for (var i = 0; i < 3; i++) {
        s.shoot(vm.Vector3(0, 1, -21), vm.Vector3(0, 0, 1));
        advance(s, .35);
      }
      expect(e.alive, false);
      advance(s, 2);
      expect(s.pickups.where((p) => p.id == 'beer_0').length, 1);
      expect(s.kills, 1);
      expect(s.inspect()['bloodEffects'], false);
    },
  );
  test('solid wall blocks the camera ray and consumes ammunition', () {
    final s = game();
    for (final e in s.enemies) {
      e.active = false;
    }
    final e = s.enemies.first
      ..active = true
      ..x = 8
      ..z = -6;
    s.aiming = true;
    s.x = 3;
    s.z = -6;
    s.shoot(vm.Vector3(3, 1, -6), vm.Vector3(1, 0, 0));
    expect(e.hp, 100);
    expect(s.pistolLoaded, 9);
    expect(s.hits, 0);
  });
  test('reload transfers only owned ammo and respects magazine capacity', () {
    final s = game();
    s.pistolLoaded = 2;
    s.reload();
    advance(s, 1.5);
    expect(s.pistolLoaded, 10);
    expect(s.reserve, 32);
  });
  test(
    'case rejects overlapping placement and full-case pickups stay on ground',
    () {
      final s = game();
      final first = s.bag.first, second = s.bag[1];
      expect(s.moveBag(second.id, first.col, first.row), false);
      while (s.addItem('green', 1)) {}
      final p = Pickup('test', 'shotgun', s.x, .2, s.z);
      s.pickups.insert(0, p);
      s.interact();
      expect(p.taken, false);
      expect(s.hasShotgun, false);
    },
  );
  test('collection is idempotent and preserved across a run restart', () {
    final s = game();
    s.x = -8;
    s.z = -18.8;
    s.interact();
    expect(s.collected, contains('wanted'));
    s.interact();
    expect(s.collected.length, 1);
    s.restart();
    expect(s.collected, contains('wanted'));
  });
  test('gate requires its key and crossing open gate completes chapter', () {
    final s = game();
    s.x = 11.5;
    s.z = 22;
    s.interact();
    expect(s.gateOpen, false);
    s.hasKey = true;
    s.interact();
    expect(s.gateOpen, true);
    s.z = 27;
    advance(s, .1);
    expect(s.phase, PlayPhase.clear);
  });
  test('stairs reach the real upper floor without teleporting', () {
    final s = game();
    s.x = 11;
    s.z = -10;
    s.y = 0;
    for (var i = 0; i < 360; i++) {
      s.move(0, 1, 1 / 60);
    }
    expect(s.y, greaterThan(2.9));
    expect(s.z, greaterThan(-3.5));
  });
  test('enemy attack has a windup and cannot damage from another floor', () {
    final s = game();
    for (final e in s.enemies) {
      e.active = false;
    }
    final e = s.enemies.first
      ..active = true
      ..x = 0
      ..z = -20.1;
    advance(s, .2);
    expect(e.attackPending, true);
    expect(s.health, 100);
    s.y = 3;
    advance(s, .7);
    expect(s.health, 100);
  });
  test('paused game does not advance attacks or reload', () {
    final s = game();
    s.pistolLoaded = 0;
    s.reload();
    s.phase = PlayPhase.paused;
    final before = s.reloading;
    advance(s, 3);
    expect(s.reloading, before);
    expect(s.time, 0);
  });
}
