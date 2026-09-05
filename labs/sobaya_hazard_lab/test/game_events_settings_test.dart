import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_events.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';

void main() {
  test(
    'event camera follows a bounded clock; pause and skip are deterministic',
    () {
      final d = HazardDirector('opening');
      for (var i = 0; i < 20; i++) {
        d.tick(.05);
      }
      expect(d.elapsed, closeTo(1, .00001));
      final camera = d.shot.camera(d.progress);
      d.paused = true;
      for (var i = 0; i < 100; i++) {
        d.tick(.05);
      }
      expect(d.shot.camera(d.progress), camera);
      d.paused = false;
      d.next();
      expect(d.index, 1);
      expect(d.elapsed, 0);
      d.skip();
      d.tick(.05);
      expect(d.done, true);
    },
  );
  test('every event finishes without indexing past its final shot', () {
    for (final id in hazardEvents.keys) {
      final d = HazardDirector(id);
      for (var i = 0; i < 2000; i++) {
        d.tick(.05);
      }
      expect(d.done, true, reason: id);
      expect(d.shot.text, isNotEmpty);
      expect(d.shot.camera(0).storage.every((v) => v.isFinite), true);
    }
  });
  test('seen events survive region return and serialized campaign restore', () {
    final maps = <String, Map<String, dynamic>>{
      for (final id in ['village', 'farm', 'mountain'])
        id: jsonDecode(File('assets/$id.json').readAsStringSync()),
    };
    final c = HazardCampaign(maps);
    c.state.seenEvents.add('opening');
    c.state.hasKey = c.state.gateOpen = true;
    c.state.exitRequested = Map<String, dynamic>.from(
      (c.state.map['exits'] as List).first,
    );
    c.state.phase = PlayPhase.transition;
    c.traverse();
    c.state.seenEvents.add('farm');
    final restored = HazardCampaign.restore(
      jsonDecode(jsonEncode(c.checkpoint())),
      maps,
      {},
    );
    expect(restored.state.seenEvents, {'opening', 'farm'});
    restored.state.exitRequested = Map<String, dynamic>.from(
      (restored.state.map['exits'] as List).first,
    );
    restored.state.phase = PlayPhase.transition;
    restored.traverse();
    expect(restored.state.seenEvents, {'opening', 'farm'});
  });
  test('preferences round trip and recover safely from invalid values', () {
    final p = HazardSettings(
      difficulty: HazardDifficulty.tense,
      volume: .3,
      sensitivity: 1.7,
      renderScale: .65,
      muted: true,
    );
    final restored = HazardSettings.decode(p.encode());
    expect(restored.encode(), p.encode());
    expect(
      HazardSettings.decode('corrupt').difficulty,
      HazardDifficulty.standard,
    );
    final bad = HazardSettings.decode(
      '{"volume":-4,"sensitivity":99,"renderScale":0,"difficulty":"unknown"}',
    );
    expect(bad.volume, 0);
    expect(bad.sensitivity, 2);
    expect(bad.renderScale, .85);
    expect(bad.difficulty, HazardDifficulty.standard);
  });
  test(
    'difficulty changes attack damage without changing enemy hit points',
    () {
      for (final d in HazardDifficulty.values) {
        final settings = HazardSettings(difficulty: d);
        final s =
            HazardGameState(
                jsonDecode(File('assets/village.json').readAsStringSync()),
              )
              ..x = 0
              ..z = -16
              ..damageScale = settings.damageScale;
        for (final e in s.enemies) {
          e.active = false;
        }
        s.enemies.first
          ..active = true
          ..alerted = true
          ..x = 0
          ..z = -15.1;
        for (var i = 0; i < 50; i++) {
          s.tick(1 / 60);
        }
        expect(s.health, closeTo(100 - 15 * settings.damageScale, .001));
        expect(s.enemies.first.hp, 100);
      }
    },
  );
  test('cinematic freezes movement, damage and game timer', () {
    final s =
        HazardGameState(
            jsonDecode(File('assets/village.json').readAsStringSync()),
          )
          ..phase = PlayPhase.cinematic
          ..inputY = 1;
    for (var i = 0; i < 500; i++) {
      s.tick(.05);
    }
    expect(s.z, -21);
    expect(s.time, 0);
    expect(s.health, 100);
    s.toggle(PlayPhase.inventory);
    expect(s.phase, PlayPhase.cinematic);
  });
}
