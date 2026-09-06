import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_dialogue.dart';

Map<String, dynamic> farm() =>
    jsonDecode(File('assets/farm.json').readAsStringSync());
Map<String, dynamic> map() =>
    jsonDecode(File('assets/village.json').readAsStringSync());
void advance(HazardGameState s, double seconds) {
  for (var i = 0; i < (seconds * 60).ceil(); i++) {
    s.tick(1 / 60);
  }
}

void main() {
  test('enemy floor height survives save and old saves default to ground', () {
    final world = map();
    final s = HazardGameState(world);
    s.enemies.first
      ..x = 7
      ..y = 3.03
      ..z = -5;
    final data = jsonDecode(jsonEncode(s.checkpoint())) as Map<String, dynamic>;
    expect(restoreHazardCheckpoint(data, world, {}).enemies.first.y, 3.03);
    for (final e in data['enemies']) {
      e.remove('y');
    }
    expect(restoreHazardCheckpoint(data, world, {}).enemies.first.y, 0);
  });
  test('old saves adopt authored supply heights and preserve dynamic loot', () {
    final world = map();
    final s = HazardGameState(world);
    s.pickups.first.taken = true;
    s.pickups.add(Pickup('beer_0', 'beer', -2, .25, -6)..taken = true);
    final data = jsonDecode(jsonEncode(s.checkpoint())) as Map<String, dynamic>;
    (data['pickups'] as List).first['y'] = .9;
    (world['items'] as List).first['y'] = .28;
    final restored = restoreHazardCheckpoint(data, world, {});
    expect(restored.pickups.first.y, .28);
    expect(restored.pickups.first.taken, true);
    final beer = restored.pickups.firstWhere((p) => p.id == 'beer_0');
    expect([beer.x, beer.y, beer.z], [-2, .25, -6]);
    expect(beer.taken, true);
  });
  test('beer purchases consume currency and persistent stock exactly once', () {
    final s = HazardGameState(farm())
      ..x = -13
      ..z = -19.4
      ..beers = 8;
    s.interact();
    expect(s.talkingTo, 'takosan');
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    for (var i = 0; i < 3; i++) {
      s.chooseDialogue('trade:ammo');
    }
    expect(s.beers, 2);
    expect(s.reserve, 38);
    s.chooseDialogue('trade:ammo');
    expect(s.beers, 2);
    expect(s.reserve, 38);
    expect(s.tradeMessage, contains('売り切れ'));
    s.endDialogue();
    final restored = restoreHazardCheckpoint(s.checkpoint(), farm(), {});
    restored.interact();
    expect(restored.dialogueTopic, 'greeting');
    expect(restored.stockRemaining(tradeOffers.first), 0);
    restored.chooseDialogue('trade:ammo');
    expect(restored.beers, 2);
    expect(restored.reserve, 38);
  });
  test(
    'insufficient beer or full case never consumes merchant stock or money',
    () {
      final s = HazardGameState(farm())
        ..x = -13
        ..z = -19.4;
      s.interact();
      while (!s.dialogueChoices) {
        s.advanceDialogue();
      }
      s.chooseDialogue('trade:herb');
      expect(s.beers, 0);
      expect(s.tradePurchases, isEmpty);
      while (s.addItem('green', 1)) {}
      s.beers = 3;
      s.chooseDialogue('trade:herb');
      expect(s.beers, 3);
      expect(s.tradePurchases, isEmpty);
      expect(s.tradeMessage, contains('ケースに入りません'));
    },
  );
  test('checkpoint restores resources, layout and one-time NPC reward across JSON round trip', () {
    final s = HazardGameState(map())
      ..x = -2.8
      ..z = -23;
    s.interact();
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    s.chooseDialogue('supplies');
    s.endDialogue();
    s.health = 65;
    s.beers = 3;
    s.pistolLoaded = 6;
    s.bag.first.col = 7;
    final data = jsonDecode(jsonEncode(s.checkpoint())) as Map<String, dynamic>;
    final restored = restoreHazardCheckpoint(data, map(), {'wanted', 'shark'});
    expect(restored.phase, PlayPhase.playing);
    expect(restored.health, 65);
    expect(restored.beers, 3);
    expect(restored.pistolLoaded, 6);
    expect(restored.reserve, 18);
    expect(restored.bag.first.col, 7);
    expect(restored.collected, {'wanted', 'shark'});
    restored.interact();
    expect(restored.dialogueTopic, 'greeting');
    restored.chooseDialogue('supplies');
    expect(restored.reserve, 18);
  });
  test(
    'saving during enemy disappearance neither loses nor duplicates the beer',
    () {
      final s = HazardGameState(map());
      for (final e in s.enemies) {
        e.active = false;
      }
      s.enemies.first
        ..active = true
        ..alive = false
        ..hp = 0
        ..vanish = .3;
      s.kills = 1;
      final a = restoreHazardCheckpoint(s.checkpoint(), map(), {});
      advance(a, 1);
      expect(a.pickups.where((p) => p.id == 'beer_0').length, 1);
      final beer = a.pickups.firstWhere((p) => p.id == 'beer_0');
      beer.taken = true;
      a.beers = 1;
      final b = restoreHazardCheckpoint(a.checkpoint(), map(), {});
      advance(b, 1);
      expect(b.pickups.where((p) => p.id == 'beer_0').length, 1);
      expect(b.pickups.firstWhere((p) => p.id == 'beer_0').taken, true);
      expect(b.beers, 1);
    },
  );
  test('completed enemy attack and upper floor progress can be resumed', () {
    final s = HazardGameState(map())
      ..x = 6
      ..y = 3.03
      ..z = -3;
    s.enemies.first.windup = -.016;
    s.addItem('shotgun', 1);
    s.weapon = 'shotgun';
    final restored = restoreHazardCheckpoint(s.checkpoint(), map(), {});
    expect(restored.y, 3.03);
    expect(restored.hasShotgun, true);
    expect(restored.weapon, 'shotgun');
  });
  test('invalid version, nonfinite position and overlapping inventory are rejected', () {
    final s = HazardGameState(map());
    final invalidVersion = s.checkpoint()..['version'] = 99;
    expect(
      () => restoreHazardCheckpoint(invalidVersion, map(), {}),
      throwsFormatException,
    );
    final badPosition = s.checkpoint();
    badPosition['player']['x'] = double.nan;
    expect(
      () => restoreHazardCheckpoint(badPosition, map(), {}),
      throwsFormatException,
    );
    final overlap = s.checkpoint();
    overlap['bag'][1]['col'] = 0;
    expect(
      () => restoreHazardCheckpoint(overlap, map(), {}),
      throwsFormatException,
    );
  });
}
