import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:vector_math/vector_math.dart' as vm;

HazardGameState armedGame(String weapon, {int reserve = 12}) {
  final s = HazardGameState(
    jsonDecode(File('assets/village.json').readAsStringSync()),
  );
  for (final enemy in s.enemies) {
    enemy.active = false;
  }
  s.bag.clear();
  if (weapon == 'shotgun') s.addItem('shotgun', 1);
  if (reserve > 0) s.addItem(weapon == 'handgun' ? 'ammo' : 'shells', reserve);
  s.weapon = weapon;
  s.pistolLoaded = s.shotgunLoaded = 0;
  s.aiming = true;
  s.drainSounds();
  return s;
}

void fire(HazardGameState s) =>
    s.shoot(vm.Vector3(s.x, s.y + 1.4, s.z), vm.Vector3(0, 0, 1));

void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).round(); i++) {
    s.tick(1 / 60);
  }
}

void main() {
  for (final weapon in ['handgun', 'shotgun']) {
    final duration = weapon == 'handgun' ? 1.3 : 2.0;
    test('$weapon empty trigger performs a timed reload without firing', () {
      final s = armedGame(weapon);
      fire(s);
      expect(s.reloading, duration);
      expect(s.loaded, 0);
      expect(s.reserve, 12);
      expect(s.shots, 0);
      expect(s.playerNoiseRadius, 0);
      expect(s.drainSounds().map((sound) => sound.name), ['reload']);

      // Repeated trigger attempts cannot restart or skip the reload delay.
      advance(s, .5);
      final remaining = s.reloading;
      fire(s);
      expect(s.reloading, remaining);
      expect(s.loaded, 0);
      expect(s.drainSounds(), isEmpty);
      advance(s, duration - .6);
      expect(s.loaded, 0);
      advance(s, .2);
      expect(s.reloading, 0);
      expect(s.loaded, s.capacity);
      expect(s.reserve, 12 - s.capacity);
      expect(s.shots, 0);

      // Finishing a reload does not queue the original trigger as a shot.
      advance(s, .5);
      expect(s.shots, 0);
      fire(s);
      expect(s.loaded, s.capacity - 1);
      expect(s.shots, 1);
    });

    test('$weapon empty trigger uses only the reserve that is available', () {
      final s = armedGame(weapon, reserve: 2);
      fire(s);
      advance(s, duration + .1);
      expect(s.loaded, 2);
      expect(s.reserve, 0);
      expect(s.shots, 0);
    });

    test(
      '$weapon manual reload remains available before the magazine empties',
      () {
        final s = armedGame(weapon)..aiming = false;
        if (weapon == 'handgun') {
          s.pistolLoaded = 3;
        } else {
          s.shotgunLoaded = 3;
        }
        s.reload();
        expect(s.reloading, duration);
        expect(s.loaded, 3);
        advance(s, duration + .1);
        expect(s.loaded, s.capacity);
        expect(s.reserve, 12 - (s.capacity - 3));
      },
    );
  }

  test(
    'empty trigger without reserve stays empty and reports no ammunition',
    () {
      final s = armedGame('handgun', reserve: 0);
      fire(s);
      expect(s.reloading, 0);
      expect(s.loaded, 0);
      expect(s.shots, 0);
      expect(s.message, '予備の弾がない。');
      expect(s.drainSounds().map((sound) => sound.name), ['empty']);
      fire(s);
      expect(s.drainSounds(), isEmpty);
      advance(s, .3);
      expect(s.loaded, 0);
    },
  );

  test('empty trigger respects aim, phase, hurt, action and firing locks', () {
    final guards = <void Function(HazardGameState)>[
      (s) => s.aiming = false,
      (s) => s.phase = PlayPhase.paused,
      (s) => s.phase = PlayPhase.inventory,
      (s) => s.phase = PlayPhase.cinematic,
      (s) => s.phase = PlayPhase.dead,
      (s) => s.hurtTime = .3,
      (s) => s.breakFreeTime = .4,
      (s) => s.fireCooldown = .2,
    ];
    for (final setGuard in guards) {
      final s = armedGame('handgun');
      setGuard(s);
      fire(s);
      expect(s.reloading, 0);
      expect(s.loaded, 0);
      expect(s.reserve, 12);
      expect(s.shots, 0);
      expect(s.drainSounds(), isEmpty);
    }
  });

  test('the final round does not start reload until a later valid trigger', () {
    final s = armedGame('shotgun')..shotgunLoaded = 1;
    fire(s);
    expect(s.loaded, 0);
    expect(s.shots, 1);
    expect(s.reloading, 0);
    fire(s);
    expect(s.reloading, 0);
    advance(s, 1);
    expect(s.reloading, 0);
    fire(s);
    expect(s.reloading, 2);
    expect(s.shots, 1);
  });

  test('automatic reload holds movement and pauses its remaining time', () {
    final s = armedGame('handgun');
    fire(s);
    s.aiming = false;
    s.inputY = 1;
    final startX = s.x, startZ = s.z;
    advance(s, .5);
    expect(s.x, startX);
    expect(s.z, startZ);
    final remaining = s.reloading;
    s.phase = PlayPhase.paused;
    advance(s, 2);
    expect(s.reloading, remaining);
    expect(s.loaded, 0);
    s.phase = PlayPhase.playing;
    advance(s, .9);
    expect(s.reloading, 0);
    expect(s.loaded, s.capacity);
    expect(s.shots, 0);
  });
}
