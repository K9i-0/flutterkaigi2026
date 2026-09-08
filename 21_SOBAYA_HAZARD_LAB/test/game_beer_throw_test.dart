import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:vector_math/vector_math.dart' as vm;

Map<String, dynamic> beerArenaMap() {
  final map = jsonDecode(
    File('assets/village.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final key in [
    'solids',
    'houses',
    'ramps',
    'npcs',
    'items',
    'crates',
    'collection',
    'windows',
    'exits',
  ]) {
    map[key] = <dynamic>[];
  }
  map['tower'] = null;
  map['enemies'] = [
    {'id': 0, 'x': 10, 'z': 20, 'active': false},
  ];
  map['spawn'] = {'x': 0, 'z': -4, 'yaw': math.pi};
  return map;
}

HazardGameState beerArena({Map<String, dynamic>? map}) =>
    HazardGameState(map ?? beerArenaMap())
      ..beers = 3
      ..weapon = 'beer'
      ..aiming = true;

void fireBeer(HazardGameState s, vm.Vector3 direction) =>
    s.shoot(vm.Vector3(s.x, s.y + 1.5, s.z), direction);

Map<String, dynamic> saved(HazardGameState s) =>
    jsonDecode(jsonEncode(s.checkpoint())) as Map<String, dynamic>;

List<dynamic> lureSounds(HazardGameState s) =>
    (s.inspectStealth()['sounds'] as List)
        .where((sound) => sound['kind'] == 'beer_lure')
        .toList();

void main() {
  test(
    'throw consumes one beer, leaves gun ammunition and combat totals intact',
    () {
      final s = beerArena();
      final pistol = s.pistolLoaded, shells = s.shotgunLoaded;
      final ammunition = s.bag.map((item) => item.toJson()).toList();
      s.drainSounds();
      fireBeer(s, vm.Vector3(0, 0, 1));
      expect(s.beers, 2);
      expect(s.beersThrown, 1);
      expect(s.beerFlights, hasLength(1));
      expect(s.reloading, 0);
      expect(s.pistolLoaded, pistol);
      expect(s.shotgunLoaded, shells);
      expect(s.bag.map((item) => item.toJson()).toList(), ammunition);
      expect([s.shots, s.hits, s.kills], [0, 0, 0]);
      expect(
        lureSounds(s),
        isEmpty,
        reason: 'The lure is at impact, not the player.',
      );
      expect(s.drainSounds().map((sound) => sound.name), ['beer_throw']);
      fireBeer(s, vm.Vector3(0, 0, 1));
      expect(
        s.beers,
        2,
        reason: 'Repeated input respects the throwing interval.',
      );
    },
  );

  test('empty beer trigger and manual reload cannot consume gun ammunition or reload', () {
    final s = beerArena()..beers = 0;
    final pistol = s.pistolLoaded;
    s.drainSounds();
    fireBeer(s, vm.Vector3(0, 0, 1));
    expect(s.beers, 0);
    expect(s.beerFlights, isEmpty);
    expect(s.beersThrown, 0);
    expect(s.reloading, 0);
    expect(s.pistolLoaded, pistol);
    expect(s.drainSounds().map((sound) => sound.name), ['empty']);
    s.reload();
    expect(s.reloading, 0);
    s.cycleWeapon();
    expect(
      s.weapon,
      'handgun',
      reason: 'An empty selected bottle can be switched away.',
    );
    s.equip('beer');
    expect(
      s.weapon,
      'handgun',
      reason: 'An empty unselected bottle is unavailable.',
    );
  });

  test('pause and action locks stop throws; paused flights resume from the same position', () {
    for (final lock in [
      'paused',
      'notAiming',
      'recovering',
      'reloading',
      'hurt',
    ]) {
      final s = beerArena();
      switch (lock) {
        case 'paused':
          s.phase = PlayPhase.paused;
        case 'notAiming':
          s.aiming = false;
        case 'recovering':
          s.breakFreeTime = .3;
        case 'reloading':
          s.reloading = .3;
        case 'hurt':
          s.hurtTime = .3;
      }
      fireBeer(s, vm.Vector3(0, 0, 1));
      expect(s.beers, 3, reason: lock);
      expect(s.beerFlights, isEmpty, reason: lock);
    }
    final s = beerArena();
    fireBeer(s, vm.Vector3(0, 0, 1));
    s.tick(.05);
    final position = s.beerFlights.single.position.clone();
    final age = s.beerFlights.single.age;
    s.phase = PlayPhase.paused;
    for (var i = 0; i < 100; i++) {
      s.tick(.05);
    }
    expect(s.beerFlights.single.position, position);
    expect(s.beerFlights.single.age, age);
    expect(lureSounds(s), isEmpty);
    s.phase = PlayPhase.playing;
    s.tick(.05);
    expect(s.beerFlights.single.age, greaterThan(age));
  });

  test(
    'arc preview matches live landing at different aim heights and frame times',
    () {
      for (final vertical in [-.8, 0.0, .8]) {
        for (final dt in [1 / 120, 1 / 60, .033, .05]) {
          final s = beerArena();
          final direction = vm.Vector3(.25, vertical, 1).normalized();
          final plan = s.planBeerThrow(direction);
          expect(plan.wallHit, false);
          fireBeer(s, direction);
          for (var i = 0; i < 400 && s.beerFlights.isNotEmpty; i++) {
            s.tick(dt);
          }
          expect(s.beerFlights, isEmpty);
          expect(s.beerSplashes, hasLength(1));
          expect(
            (s.beerSplashes.single.position - plan.landing).length,
            lessThan(.005),
            reason: 'pitch $vertical, dt $dt',
          );
          expect(s.beerSplashes.single.position.y, closeTo(.06, .0001));
        }
      }
    },
  );

  test(
    'wall impact agrees with preview and emits exactly one lure at the wall',
    () {
      final map = beerArenaMap();
      map['solids'] = [
        {'x': 0, 'z': -1, 'w': 8, 'd': .25, 'bottom': 0, 'top': 5},
      ];
      final s = beerArena(map: map);
      final direction = vm.Vector3(0, 0, 1);
      final plan = s.planBeerThrow(direction);
      expect(plan.wallHit, true);
      s.drainSounds();
      fireBeer(s, direction);
      var impacts = 0;
      for (var i = 0; i < 180; i++) {
        s.tick(1 / 60);
        final sounds = s.drainSounds().where(
          (sound) => sound.name == 'beer_land',
        );
        impacts += sounds.length;
        if (sounds.isNotEmpty) {
          final sound = sounds.single;
          expect(
            (vm.Vector3(sound.x!, sound.y, sound.z!) - plan.landing).length,
            lessThan(.001),
          );
          final lure = lureSounds(s).single;
          final where = lure['position'] as List;
          expect(where[0], closeTo(plan.landing.x, .001));
          expect(where[1], closeTo(plan.landing.y + .15, .001));
          expect(where[2], closeTo(plan.landing.z, .001));
          expect(lure['radius'], 8);
          expect(lureSounds(s), hasLength(1));
        }
      }
      expect(impacts, 1);
      expect(s.beerFlights, isEmpty);
      expect(
        lureSounds(s),
        isEmpty,
        reason: 'The single lure expires; it does not re-emit.',
      );
      expect(s.beersThrown, 1);
    },
  );

  test('a wall between body and throwing hand rejects the throw without losing beer', () {
    final map = beerArenaMap();
    map['solids'] = [
      {'x': 0, 'z': -3.8, 'w': 8, 'd': .06, 'bottom': 0, 'top': 3},
    ];
    final s = beerArena(map: map);
    fireBeer(s, vm.Vector3(0, 0, 1));
    expect(s.beers, 3);
    expect(s.beerFlights, isEmpty);
    expect(s.beersThrown, 0);
  });

  test(
    'saving in midair preserves one consumed beer and resumes the same impact',
    () {
      final map = beerArenaMap();
      final s = beerArena(map: map);
      fireBeer(s, vm.Vector3(.2, .4, 1).normalized());
      for (var i = 0; i < 12; i++) {
        s.tick(1 / 60);
      }
      final restored = restoreHazardCheckpoint(saved(s), map, {});
      expect(restored.weapon, 'beer');
      expect(restored.beers, 2);
      expect(restored.beersThrown, 1);
      expect(restored.beerFlights, hasLength(1));
      expect(restored.beerFlights.single.age, s.beerFlights.single.age);
      expect(
        (restored.beerFlights.single.position - s.beerFlights.single.position)
            .length,
        lessThan(.0001),
      );
      for (final game in [s, restored]) {
        game.drainSounds();
        var impacts = 0;
        while (game.beerFlights.isNotEmpty) {
          game.tick(1 / 60);
          impacts += game
              .drainSounds()
              .where((sound) => sound.name == 'beer_land')
              .length;
        }
        expect(impacts, 1);
        expect(game.beers, 2);
      }
      expect(
        (s.beerSplashes.single.position - restored.beerSplashes.single.position)
            .length,
        lessThan(.0001),
      );
      final afterLanding = restoreHazardCheckpoint(saved(restored), map, {});
      expect(afterLanding.beerFlights, isEmpty);
      expect(afterLanding.beers, 2);
    },
  );

  test('reloading an airborne checkpoint cannot bypass the throw interval or overflow flights', () {
    final map = beerArenaMap();
    var s = beerArena(map: map)..beers = 8;
    fireBeer(s, vm.Vector3(0, .8, 1).normalized());
    for (var reload = 0; reload < 6; reload++) {
      s = restoreHazardCheckpoint(saved(s), map, {})..aiming = true;
      fireBeer(s, vm.Vector3(0, .8, 1).normalized());
      expect(s.beers, 7);
      expect(s.beerFlights, hasLength(1));
      expect(s.beerThrowTime, closeTo(.45, .0001));
    }
    for (var tick = 0; tick < 54; tick++) {
      s.tick(1 / 60);
    }
    fireBeer(s, vm.Vector3(0, .8, 1).normalized());
    expect(s.beers, 6);
    expect(s.beersThrown, 2);
  });

  test('old saves receive new authored beer once and preserve taken and dynamic pickup IDs', () {
    final oldMap = beerArenaMap();
    final old = beerArena(map: oldMap)..beers = 0;
    old.pickups.add(Pickup('enemy_beer', 'beer', 5, .25, 5)..taken = true);
    final data = saved(old)
      ..remove('beerFlights')
      ..remove('beersThrown');
    final map = beerArenaMap();
    map['items'] = [
      {
        'id': 'new_entrance_beer',
        'kind': 'beer',
        'x': 0,
        'z': -3.5,
        'y': .28,
        'amount': 2,
      },
    ];
    var restored = restoreHazardCheckpoint(data, map, {});
    expect(restored.beerFlights, isEmpty);
    expect(restored.beersThrown, 0);
    expect(restored.pickups.map((item) => item.id).toSet(), {
      'enemy_beer',
      'new_entrance_beer',
    });
    restored.interact();
    expect(restored.beers, 2);
    for (var i = 0; i < 3; i++) {
      restored = restoreHazardCheckpoint(saved(restored), map, {});
      expect(
        restored.pickups.where((item) => item.id == 'new_entrance_beer'),
        hasLength(1),
      );
      expect(restored.pickups.every((item) => item.taken), true);
      restored.interact();
      expect(restored.beers, 2);
    }
  });

  test('broken crates cease to block low vision rays while standing head rays remain clear', () {
    final map = beerArenaMap();
    map['crates'] = [
      {'id': 'cover', 'kind': 'crate', 'x': 0, 'z': -2},
    ];
    final s = beerArena(map: map);
    final direction = vm.Vector3(0, 0, 1);
    expect(s.sightDistance(vm.Vector3(0, .5, -4), direction, 4), lessThan(2));
    expect(s.sightDistance(vm.Vector3(0, 1.2, -4), direction, 4), 4);
    s.breakCrate(s.crates.single);
    expect(s.sightDistance(vm.Vector3(0, .5, -4), direction, 4), 4);
  });
}
