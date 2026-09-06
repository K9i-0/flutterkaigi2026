import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_dialogue.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';

Map<String, dynamic> world([String id = 'village']) =>
    jsonDecode(File('assets/$id.json').readAsStringSync());
HazardGameState state({bool hard = false, String id = 'village'}) {
  final s = HazardGameState(
    world(id),
    difficulty: hard ? HazardDifficulty.tense : HazardDifficulty.standard,
  )..phase = PlayPhase.playing;
  for (final e in s.enemies) {
    e.active = false;
  }
  s.obstacles.clear();
  return s;
}

void shop(HazardGameState s) {
  s.endDialogue();
  final npc = s.npcs.firstWhere((n) => n['id'] == 'takosan');
  s.x = (npc['x'] as num).toDouble();
  s.z = (npc['z'] as num).toDouble() + .8;
  s.startDialogue('takosan');
  while (!s.dialogueChoices) {
    s.advanceDialogue();
  }
}

Enemy target(HazardGameState s, {bool boss = false}) {
  s.x = 0;
  s.z = -21;
  s.y = 0;
  s.aiming = true;
  return s.enemies.firstWhere((e) => e.boss == boss)
    ..active = true
    ..x = 0
    ..y = 0
    ..z = -15
    ..stun = 10;
}

void lock(HazardGameState s) => s.updateRocketLock(
  vm.Vector3(0, 1.25, -21),
  vm.Vector3(0, 0, 1),
  fovY: .8,
  aspect: 1.5,
);
void flight(HazardGameState s, [double seconds = 1]) {
  for (var i = 0; i < seconds * 60; i++) {
    s.tickRockets(1 / 60);
  }
}

void main() {
  test('secret offer checks beer at conversation entry; successful exchange persists and cannot repeat', () {
    final s = state(id: 'farm')..beers = 9;
    shop(s);
    expect(s.visibleTradeOffers, isNot(contains(rocketOffer)));
    s.beers = 10;
    s.buySupplies('rocket');
    expect(s.hasRocket, false);
    shop(s);
    expect(s.visibleTradeOffers, contains(rocketOffer));
    s.buySupplies('rocket');
    expect(s.beers, 0);
    expect(s.hasRocket, true);
    expect(s.weapon, 'rocket');
    s.beers = 30;
    s.buySupplies('rocket');
    expect(s.beers, 30);
    s.endDialogue();
    final r = restoreHazardCheckpoint(
      jsonDecode(jsonEncode(s.checkpoint())),
      world('farm'),
      {},
    );
    expect(r.hasRocket, true);
    expect(r.weapon, 'rocket');
    expect(r.tradePurchases['rocket'], 1);
  });
  test('full case does not charge for secret item', () {
    final s = state(id: 'farm')..beers = 10;
    while (s.addItem('green', 1)) {}
    shop(s);
    s.buySupplies('rocket');
    expect(s.beers, 10);
    expect(s.hasRocket, false);
    expect(s.tradePurchases, isEmpty);
  });
  test(
    'lock respects camera frustum, wall visibility and centred target priority',
    () {
      final s = state();
      s.addItem('rocket', 1);
      s.equip('rocket');
      final e = target(s);
      lock(s);
      expect(s.rocketLockId, e.id);
      e.x = 20;
      lock(s);
      expect(s.rocketLockId, isNull);
      e.x = 0;
      e.z = -24;
      lock(s);
      expect(s.rocketLockId, isNull);
      e.z = -15;
      s.obstacles.add(
        Obstacle({'x': 0, 'z': -18, 'w': 3, 'd': .4, 'bottom': 0, 'top': 3}),
      );
      lock(s);
      expect(s.rocketLockId, isNull);
    },
  );
  test('rocket travels, follows moving target, kills once and suppresses beer across save', () {
    final s = state();
    s.addItem('rocket', 1);
    s.equip('rocket');
    final e = target(s);
    lock(s);
    s.shoot(vm.Vector3.zero(), vm.Vector3(0, 0, 1));
    expect(e.hp, 100);
    expect(s.rockets, hasLength(1));
    e.x = 2;
    flight(s);
    expect(e.alive, false);
    expect(s.kills, 1);
    expect(e.suppressBeer, true);
    expect(s.loaded, 1);
    expect(s.shots, 1);
    expect(s.hits, 1);
    // Restore before the delayed disappearance/drop pass.
    final restored = restoreHazardCheckpoint(
      jsonDecode(jsonEncode(s.checkpoint())),
      world(),
      {},
    );
    for (var i = 0; i < 60; i++) {
      restored.tick(1 / 60);
    }
    expect(restored.pickups.any((p) => p.id == 'beer_${e.id}'), false);
  });
  test('tracking missile collides with newly entered cover instead of damaging through it', () {
    final s = state();
    s.addItem('rocket', 1);
    s.equip('rocket');
    final e = target(s);
    lock(s);
    s.launchRocket();
    s.obstacles.add(
      Obstacle({'x': 0, 'z': -18, 'w': 4, 'd': .5, 'bottom': 0, 'top': 3}),
    );
    flight(s);
    expect(e.hp, 100);
    expect(s.rockets, isEmpty);
  });
  test('full health boss takes exactly three infinite rockets', () {
    final s = state(id: 'mountain');
    s.addItem('rocket', 1);
    s.equip('rocket');
    final e = target(s, boss: true);
    for (final hp in [600, 300, 0]) {
      lock(s);
      s.fireCooldown = 0;
      s.shoot(vm.Vector3.zero(), vm.Vector3(0, 0, 1));
      flight(s);
      expect(e.hp, hp);
    }
    expect(e.alive, false);
    expect(s.kills, 1);
    expect(s.shots, 3);
    expect(s.loaded, 1);
    expect(s.pistolLoaded, 6);
  });
  test('legacy boss health is migrated proportionally', () {
    final s = state(id: 'mountain');
    final data = s.checkpoint()..remove('bossBalanceVersion');
    final b = (data['enemies'] as List).firstWhere(
      (j) => j['id'] == s.enemies.firstWhere((e) => e.boss).id,
    );
    b['hp'] = 175.0;
    final r = restoreHazardCheckpoint(data, world('mountain'), {});
    expect(r.enemies.firstWhere((e) => e.boss).hp, 450);
  });
  test('hard mode requires supplies and exchanges even with accurate fire', () {
    final s = state(hard: true);
    final free =
        s.loaded +
        s.reserve +
        s.pickups
            .where((p) => p.kind == 'ammo')
            .fold<int>(0, (n, p) => n + s.pickupAmount(p));
    expect(free, 3);
    expect(s.shotgunLoaded, 0);
    expect(
      s.pickups
          .where((p) => p.kind == 'shells')
          .every((p) => s.pickupAmount(p) == 0),
      true,
    );
    final cost = (100 / s.bulletDamage(ShotPart.mug)).ceil();
    expect(
      free ~/ cost,
      1,
    ); // One beer cannot buy the two-beer ammunition pack.
    expect((free + 25) ~/ cost, greaterThanOrEqualTo(s.enemies.length));
    expect((free + 25) ~/ cost, lessThan(19));
    for (final c in s.crates) {
      s.breakCrate(c);
    }
    expect(
      s.pickups.where((p) => p.id.endsWith('_loot') && p.kind == 'ammo'),
      isEmpty,
    );
    // All 19 ordinary enemies + nine boss headshots: available earned beer
    // funds the ammo deficit and 10 shells, without a rocket or medallions.
    const ordinary = 19, loose = 3, yame = 25, initial = 2;
    final purchases = ((ordinary * cost - loose - yame - initial) / 10).ceil();
    expect(purchases * 2 + 2 * 3, lessThanOrEqualTo(ordinary));
  });
  test('hard shotgun needs precise head hit; mug is a separate animated weak point', () {
    for (final part in ShotPart.values) {
      final s = state(hard: true);
      s.addItem('shotgun', 1);
      s.equip('shotgun');
      s.shotgunLoaded = 1;
      final e = target(s)..mugCentre = vm.Vector3(.7, 1.1, -15);
      final aim = part == ShotPart.head
          ? vm.Vector3(0, 1.68, -15)
          : part == ShotPart.mug
          ? e.mugCentre!
          : vm.Vector3(0, 1, -15);
      s.shoot(vm.Vector3(0, 1.25, -21), aim - vm.Vector3(0, 1.25, -21));
      expect(s.lastShotPart, part);
      expect(e.hp, 100 - s.bulletDamage(part));
      expect(e.alive, part != ShotPart.head);
    }
  });
  test('hard handgun damage and normal death still drops beer', () {
    final s = state(hard: true);
    final e = target(s);
    s.pistolLoaded = 10;
    for (var i = 0; i < 3; i++) {
      s.fireCooldown = 0;
      s.shoot(
        vm.Vector3(0, 1.25, -21),
        vm.Vector3(0, 1.68, -15) - vm.Vector3(0, 1.25, -21),
      );
    }
    expect(e.alive, false);
    expect(e.suppressBeer, false);
    for (var i = 0; i < 60; i++) {
      s.tick(1 / 60);
    }
    expect(s.pickups.any((p) => p.id == 'beer_${e.id}'), true);
  });
  test('highest difficulty blocks next chapter even with an open gate', () {
    final maps = {
      for (final id in ['village', 'farm', 'mountain']) id: world(id),
    };
    final c = HazardCampaign(maps, difficulty: HazardDifficulty.tense);
    final s = c.state
      ..hasKey = true
      ..gateOpen = true;
    s.exitRequested = Map<String, dynamic>.from((s.map['exits'] as List).first);
    s.phase = PlayPhase.transition;
    expect(c.traverse(), false);
    for (final e in s.enemies) {
      e.alive = false;
      e.hp = 0;
    }
    expect(c.traverse(), true);
    expect(c.state.difficulty, HazardDifficulty.tense);
  });
  test('hard ammunition exchange can replenish beyond old global stock cap and restore', () {
    final s = state(hard: true, id: 'farm')..beers = 30;
    shop(s);
    for (var i = 0; i < 5; i++) {
      s.buySupplies('ammo');
    }
    expect(s.tradePurchases['ammo'], 5);
    expect(s.beers, 20);
    s.endDialogue();
    final r = restoreHazardCheckpoint(s.checkpoint(), world('farm'), {});
    expect(r.tradePurchases['ammo'], 5);
  });
}
