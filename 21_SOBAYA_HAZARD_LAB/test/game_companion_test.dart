import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_collection.dart';

Map<String, Map<String, dynamic>> maps() => {
  for (final id in ['village', 'farm', 'mountain'])
    id: jsonDecode(File('assets/$id.json').readAsStringSync()),
};
void advance(HazardGameState s, double seconds) {
  for (var t = 0.0; t < seconds; t += .02) {
    s.tick(.02);
  }
}

HazardGameState encounter(String region) {
  final s = HazardGameState(maps()[region]!);
  final n = s.npcs.first;
  s.x = (n['x'] as num).toDouble() + 2.5;
  s.z = (n['z'] as num).toDouble() - 1.8;
  for (final e in s.enemies) {
    e.active = false;
  }
  s.enemies.first
    ..active = true
    ..alerted = true
    ..x = (n['x'] as num).toDouble()
    ..z = (n['z'] as num).toDouble() + 1;
  return s;
}

void main() {
  for (final region in ['village', 'farm']) {
    test(
      '$region pursuer attacks companion with warning then causes game over',
      () {
        final s = encounter(region), e = s.enemies.first;
        final id = s.npcs.first['id'] as String;
        advance(s, .4);
        expect(e.companionTarget, id);
        expect(e.attackPending, true);
        expect(s.companionHealth[id], 60);
        advance(s, .6);
        expect(s.companionHealth[id], 40);
        expect(s.health, 100);
        advance(s, 4.8);
        expect(s.phase, PlayPhase.companionDown);
        expect(s.fallenCompanion, id);
        expect(s.health, 100);
        s.toggle(PlayPhase.inventory);
        expect(s.phase, PlayPhase.companionDown);
        advance(s, 1.3);
        expect(s.phase, PlayPhase.dead);
      },
    );
  }
  test('a shot interrupts the mug swing and saves companion', () {
    final s = encounter('village'), e = s.enemies.first;
    advance(s, .4);
    s.aiming = true;
    final origin = vm.Vector3(s.x, 1.25, s.z);
    s.shoot(origin, (vm.Vector3(e.x, 1.1, e.z) - origin).normalized());
    expect(e.stun, greaterThan(0));
    expect(e.attackPending, false);
    advance(s, .55);
    expect(s.companionHealth['yametaro'], 60);
  });
  test('walls prevent acquisition and block an already committed impact', () {
    final s = encounter('village'), e = s.enemies.first;
    final wall = Obstacle({
      'x': e.x,
      'z': e.z - .5,
      'w': 1,
      'd': .2,
      'bottom': 0,
      'top': 2,
    });
    s.obstacles.add(wall);
    s.tick(.02);
    expect(e.companionTarget, null);
    e
      ..companionTarget = 'yametaro'
      ..attackPending = true
      ..windup = .01
      ..heading = 3.141592653589793;
    s.tick(.02);
    expect(s.companionHealth['yametaro'], 60);
  });
  test('defeating a companion attacker clears target and remains saveable', () {
    final s = encounter('village'), e = s.enemies.first;
    advance(s, .4);
    s.aiming = true;
    e.hp = 1;
    final origin = vm.Vector3(s.x, 1.25, s.z);
    s.shoot(origin, (vm.Vector3(e.x, 1.1, e.z) - origin).normalized());
    expect(e.alive, false);
    expect(e.companionTarget, null);
    expect(
      restoreHazardCheckpoint(s.checkpoint(), maps()['village']!, {}).kills,
      1,
    );
    advance(s, 2);
    expect(s.companionHealth['yametaro'], 60);
  });
  test('targeted companion cannot be protected by opening dialogue', () {
    final s = encounter('village');
    s.tick(.02);
    s.x = -2.8;
    s.z = -23;
    s.startDialogue('yametaro');
    expect(s.phase, PlayPhase.playing);
  });
  test('remote player cannot start attacks on a companion', () {
    final s = encounter('village')
      ..x = 15
      ..z = 20;
    advance(s, 1);
    expect(s.enemies.first.companionTarget, null);
    expect(s.companionHealth['yametaro'], 60);
  });
  test('a committed player attack never switches victims', () {
    final s = encounter('village');
    s.enemies.first
      ..attackPending = true
      ..windup = .7;
    advance(s, .5);
    expect(s.enemies.first.companionTarget, null);
    expect(s.companionHealth['yametaro'], 60);
  });
  test('simultaneous companion impacts count once', () {
    final s = encounter('village'), first = s.enemies.first;
    for (final e in s.enemies.take(3)) {
      e
        ..active = true
        ..alerted = true
        ..x = first.x
        ..z = first.z
        ..heading = 3.141592653589793
        ..companionTarget = 'yametaro'
        ..attackPending = true
        ..windup = .01;
    }
    s.tick(.02);
    expect(s.companionHealth['yametaro'], 40);
  });
  test(
    'checkpoint retains injuries and enemy target; legacy defaults healthy',
    () {
      final s = encounter('village');
      advance(s, 1);
      final data = s.checkpoint();
      final restored = restoreHazardCheckpoint(data, maps()['village']!, {});
      expect(restored.companionHealth['yametaro'], 40);
      expect(restored.enemies.first.companionTarget, 'yametaro');
      data.remove('companionHealth');
      expect(
        restoreHazardCheckpoint(
          data,
          maps()['village']!,
          {},
        ).companionHealth['yametaro'],
        60,
      );
      data['companionHealth'] = {'yametaro': 0, 'takosan': 60};
      expect(
        () => restoreHazardCheckpoint(data, maps()['village']!, {}),
        throwsFormatException,
      );
    },
  );
  test('travel carries injuries; reset clears every cached region and survives restore', () async {
    final c = HazardCampaign(maps(), collection: {'wanted'});
    c.state.companionHealth['yametaro'] = 40;
    c.state.exitRequested = Map<String, dynamic>.from(
      (c.state.map['exits'] as List).first,
    );
    c.state.phase = PlayPhase.transition;
    expect(c.traverse(), true);
    expect(c.state.companionHealth['yametaro'], 40);
    c.state.beers = 5;
    final store = HazardCollectionStore((ids) async => true);
    expect(await store.reset(c), true);
    expect(c.regions.values.every((s) => s.collected.isEmpty), true);
    expect(c.state.beers, 5);
    final restored = HazardCampaign.restore(c.checkpoint(), maps(), {});
    expect(restored.state.collected, isEmpty);
    expect(restored.state.companionHealth['yametaro'], 40);
  });
  test('reset queues after an in-flight pickup write', () async {
    final gate = Completer<bool>(), writes = <List<String>>[];
    final store = HazardCollectionStore((ids) {
      writes.add(ids);
      return writes.length == 1 ? gate.future : Future.value(true);
    });
    final c = HazardCampaign(maps(), collection: {'wanted'});
    final pickup = store.save(c.state.collected);
    final reset = store.reset(c);
    await Future<void>.delayed(Duration.zero);
    expect(writes, [
      ['wanted'],
    ]);
    gate.complete(true);
    await pickup;
    expect(await reset, true);
    expect(writes, [
      ['wanted'],
      <String>[],
    ]);
    expect(c.state.collected, isEmpty);
  });
  test(
    'failed reset retains collection and a later reset can succeed',
    () async {
      final c = HazardCampaign(maps(), collection: {'wanted'});
      var fail = true;
      final store = HazardCollectionStore((ids) async {
        if (fail) throw StateError('disk');
        return true;
      });
      await expectLater(store.reset(c), throwsStateError);
      expect(c.state.collected, {'wanted'});
      fail = false;
      expect(await store.reset(c), true);
      expect(c.state.collected, isEmpty);
    },
  );
}
