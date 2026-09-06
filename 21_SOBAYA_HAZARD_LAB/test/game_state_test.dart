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
  test('selecting the equipped weapon does not cancel an ongoing reload', () {
    final s = game()..pistolLoaded = 0;
    s.reload();
    s.equip('handgun');
    advance(s, 1.4);
    expect(s.loaded, 8);
    expect(s.reserve, 0);
  });

  test(
    'nearby guide conversation pauses combat and grants supplies only once',
    () {
      final s = game();
      s.startDialogue('yametaro');
      expect(s.phase, PlayPhase.playing); // Too far away at spawn.
      s.x = -2.8;
      s.z = -23;
      s.interact();
      expect(s.phase, PlayPhase.dialogue);
      final time = s.time;
      s.inputY = 1;
      advance(s, 3);
      expect(s.time, time);
      expect(s.z, -23);
      while (!s.dialogueChoices) {
        s.advanceDialogue();
      }
      s.chooseDialogue('supplies');
      expect(s.reserve, 18);
      expect(s.receivedYametaroAmmo, true);
      s.chooseDialogue('supplies');
      expect(s.reserve, 18);
      s.endDialogue();
      expect(s.inputY, 0);
      s.interact();
      expect(s.dialogueTopic, 'greeting');
      s.chooseDialogue('supplies');
      expect(s.reserve, 18);
    },
  );
  test('guide keeps supplies until there is space in the case', () {
    final s = game()
      ..x = -2.8
      ..z = -23;
    s.bag.clear();
    s.bag.add(BagItem(100, 'ammo', 50, 0, 0, 10, 6));
    s.interact();
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    s.chooseDialogue('supplies');
    expect(s.dialogueTopic, 'full');
    expect(s.receivedYametaroAmmo, false);
    s.bag.clear();
    s.chooseDialogue('supplies');
    expect(s.reserve, 10);
    expect(s.receivedYametaroAmmo, true);
  });
  test('approaching alerted enemy prevents opening guide dialogue', () {
    final s = game()
      ..x = -2.8
      ..z = -23;
    s.enemies.first
      ..active = true
      ..alerted = true
      ..x = -2.8
      ..z = -24;
    s.interact();
    expect(s.phase, PlayPhase.playing);
    expect(s.metYametaro, false);
    expect(s.message, contains('そば屋が近い'));
  });
  test('simultaneous enemy attacks cannot erase all health in one frame', () {
    final s = game();
    for (final e in s.enemies) {
      e.active = false;
    }
    for (final e in s.enemies.take(3)) {
      e
        ..active = true
        ..alerted = true
        ..x = 0
        ..z = -20.1
        ..heading = 3.141592653589793;
    }
    advance(s, .95);
    expect(s.health, 85);
    expect(s.phase, PlayPhase.playing);
  });
  test('evasion avoids a committed swing and still respects a solid wall', () {
    final s = game();
    for (final e in s.enemies) {
      e.active = false;
    }
    final e = s.enemies.first
      ..active = true
      ..alerted = true
      ..x = 0
      ..z = -20.1;
    advance(s, .6);
    expect(e.attackPending, true);
    s.evade();
    advance(s, .4);
    expect(s.health, 100);
    expect(s.z, lessThan(-21.8));
    s.restart();
    for (final enemy in s.enemies) {
      enemy.active = false;
    }
    s.x = 3;
    s.z = -6;
    s.inputX = 1;
    s.evade();
    advance(s, .42);
    expect(s.x, lessThan(3.55));
    expect(s.blocked(s.x, s.z, s.y), false);
  });
  test('stagger then kick defeats an enemy and leaves exactly one beer', () {
    final s = game();
    for (final e in s.enemies) {
      e.active = false;
    }
    final e = s.enemies.first
      ..active = true
      ..x = 0
      ..z = -19.4;
    s.aiming = true;
    s.shoot(vm.Vector3(0, 1.65, -21), vm.Vector3(0, 0, 1));
    expect(e.hp, 40);
    expect(s.kickTarget, e);
    s.kick();
    expect(e.alive, true);
    advance(s, .45);
    expect(e.alive, false);
    advance(s, 1);
    expect(s.kills, 1);
    expect(s.pickups.where((p) => p.id == 'beer_0').length, 1);
    s.kick();
    advance(s, 1);
    expect(s.kills, 1);
  });
  test('enemy cannot see through a house wall but can hear a nearby shot', () {
    final s = game();
    for (final e in s.enemies) {
      e.active = false;
    }
    s.x = 3;
    s.z = -6;
    final e = s.enemies.first
      ..active = true
      ..x = 8
      ..z = -6;
    advance(s, 2);
    expect(e.alerted, false);
    s.aiming = true;
    s.shoot(vm.Vector3(3, 1, -6), vm.Vector3(-1, 0, 0));
    advance(s, .1);
    expect(e.alerted, true);
  });
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
      for (var i = 0; i < 4; i++) {
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
    expect(s.pistolLoaded, 5);
    expect(s.hits, 0);
  });
  test('reload transfers only owned ammo and respects magazine capacity', () {
    final s = game();
    s.pistolLoaded = 2;
    s.reload();
    advance(s, 1.5);
    expect(s.pistolLoaded, 10);
    expect(s.reserve, 0);
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
  test(
    'gate requires its key and crossing open gate requests farm transition',
    () {
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
      expect(s.phase, PlayPhase.transition);
      expect(s.exitRequested?['target'], 'farm');
    },
  );
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
    final s = game()
      ..x = 7
      ..z = -5;
    for (final e in s.enemies) {
      e.active = false;
    }
    final e = s.enemies.first
      ..active = true
      ..x = 7
      ..z = -4.1;
    advance(s, .2);
    expect(e.attackPending, true);
    expect(s.health, 100);
    // Use the actual upstairs floor; empty air now correctly falls.
    s.y = 3.03;
    advance(s, .7);
    expect(s.y, 3.03);
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
