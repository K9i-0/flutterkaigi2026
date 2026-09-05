import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_audio.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

void main() {
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
