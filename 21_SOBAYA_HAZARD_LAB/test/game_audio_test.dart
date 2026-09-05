import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_audio.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

void main() {
  test('upstairs attack and drop emit from the actual enemy floor', () {
    final s =
        HazardGameState(
            jsonDecode(File('assets/village.json').readAsStringSync()),
          )
          ..x = 7
          ..y = 3.03
          ..z = -5;
    for (final e in s.enemies) {
      e.active = false;
    }
    final e = s.enemies.first
      ..x = 7
      ..y = 3.03
      ..z = -5.9
      ..active = true
      ..alerted = true;
    s.drainSounds();
    s.tick(1 / 60);
    expect(
      s.drainSounds().singleWhere((e) => e.name == 'enemy').y,
      closeTo(4.23, .001),
    );
    e.alive = false;
    for (var i = 0; i < 42; i++) {
      s.tick(1 / 60);
    }
    expect(
      s.drainSounds().singleWhere((e) => e.name == 'defeat').y,
      closeTo(3.28, .001),
    );
  });
  test(
    'world sound fades with distance and cover, player cues stay audible',
    () {
      const sound = HazardSound('enemy', x: 0, z: 0);
      expect(sound.gain(0, 0), 1);
      expect(sound.gain(0, 0, listenerY: 5.2), closeTo(.5, .0001));
      expect(sound.gain(4, 0), closeTo(.5, .0001));
      expect(sound.gain(12, 0), lessThan(sound.gain(4, 0)));
      expect(sound.gain(4, 0, occluded: true), closeTo(.175, .0001));
      expect(sound.gain(24, 0), 0);
      expect(const HazardSound('reload').gain(24, 0, occluded: true), 1);
    },
  );
  test('simultaneous player and world cues survive until drained once', () {
    final s = HazardGameState(
      jsonDecode(File('assets/village.json').readAsStringSync()),
    );
    s.drainSounds();
    s.lastSound = 'shot';
    s.emitSound('enemy', x: 3, z: 4);
    final events = s.drainSounds();
    expect(events.map((e) => e.name), ['shot', 'enemy']);
    expect(events.last.x, 3);
    expect(s.drainSounds(), isEmpty);
  });
}
