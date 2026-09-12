import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math.dart' as vm;
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_checkpoint.dart';

HazardGameState world([String id = 'village']) =>
    HazardGameState(jsonDecode(File('assets/$id.json').readAsStringSync()));
void tick(HazardGameState s, double seconds) {
  for (var i = 0; i < seconds * 60; i++) {
    s.tick(1 / 60);
  }
}

void main() {
  test('training uses movement, aimed target hit and completed reload', () {
    final s = world()..beginTutorial();
    tick(s, 1);
    expect(s.tutorialStep, 'move');
    s.inputY = 1;
    for (var i = 0; i < 180 && s.tutorialStep == 'move'; i++) {
      s.tick(1 / 60);
    }
    expect(s.tutorialStep, 'aim');
    s.aiming = true;
    tick(s, .7);
    expect(s.tutorialStep, 'shoot');
    s.aiming = true;
    s.shoot(vm.Vector3(s.x, 1.5, s.z), vm.Vector3(1, 0, 0));
    expect(s.tutorialStep, 'shoot');
    tick(s, .5);
    s.shoot(vm.Vector3(s.x, 1.5, s.z), vm.Vector3(0, 0, 1));
    expect(s.tutorialStep, 'reload');
    expect(s.medallions, isEmpty);
    s.reload();
    tick(s, .5);
    expect(s.tutorialStep, 'reload');
    tick(s, 1);
    expect(s.tutorialStep, 'sneak');
    expect(s.kills, 0);
  });
  test('stealth lesson requires silent movement and actual sight loss', () {
    final s = world()..beginTutorial(step: 'sneak');
    s.yaw = math.pi;
    s.z = -15;
    s.inputX = -1;
    s.sneaking = true;
    for (var i = 0; i < 600 && s.tutorialStep == 'sneak'; i++) {
      s.tick(1 / 60);
    }
    expect(s.tutorialStep, 'escape');
    s.x = 0;
    s.z = -15;
    tick(s, .2);
    expect(s.tutorialWasSeen, true);
    s.x = -8;
    s.z = -20;
    tick(s, 35);
    expect(s.tutorialStep, 'complete');
  });
  test('paused training cannot advance and restores lesson boundary', () {
    final s = world()..beginTutorial(step: 'aim');
    s.phase = PlayPhase.paused;
    s.aiming = true;
    tick(s, 2);
    expect(s.tutorialStep, 'aim');
    final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
    expect(restored.tutorialStep, 'aim');
    final old = world();
    expect(
      restoreHazardCheckpoint(old.checkpoint(), old.map, {}).tutorialActive,
      false,
    );
  });
  test('farm collection is physical, independent of inventory, and delivered at final line', () {
    final s = world('farm');
    for (final e in s.enemies) {
      e.active = false;
    }
    expect(s.canOpenGate, false);
    for (final entry in HazardGameState.farmMissionItems.entries) {
      s.x = entry.value.x;
      s.z = entry.value.z;
      s.y = entry.value.y;
      expect(s.blocked(s.x, s.z, s.y), false, reason: entry.key);
      s.interact();
      expect(s.missionFlags, contains(entry.key));
    }
    s.x = -14.2;
    s.z = -17.8;
    s.y = 0;
    s.interact();
    expect(s.dialogueTopic, 'mission_ready');
    s.endDialogue();
    expect(s.canOpenGate, false);
    s.interact();
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    s.endDialogue();
    expect(s.canOpenGate, true);
    final ammo = s.reserve;
    s.interact();
    while (!s.dialogueChoices) {
      s.advanceDialogue();
    }
    s.endDialogue();
    expect(s.reserve, ammo, reason: 'Rescue supplies are awarded only once');
    expect(
      restoreHazardCheckpoint(s.checkpoint(), s.map, {}).missionFlags,
      contains('radio_ready'),
    );
  });
  test(
    'every lesson saves at its safe entry and malformed progress is rejected',
    () {
      for (final step in tutorialSteps) {
        final s = world()..beginTutorial(step: step);
        final restored = restoreHazardCheckpoint(s.checkpoint(), s.map, {});
        expect(restored.tutorialStep, step);
        expect(restored.blocked(restored.x, restored.z, restored.y), false);
      }
      final s = world();
      final bad = s.checkpoint()..['missionFlags'] = ['radio_ready'];
      expect(
        () => restoreHazardCheckpoint(bad, s.map, {}),
        throwsFormatException,
      );
    },
  );
}
