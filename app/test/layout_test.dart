import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/balance.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/character.dart';

import '../tool/balance_sim.dart';

void main() {
  test('every round without a seed plays the character layout', () {
    for (final c in CatchCharacter.values) {
      final g = newRound(c);
      expect(g.seed, c.layoutSeed);
      final again = newRound(c);
      expect(
        again.drops.map((d) => (d.x, d.spawn, d.kind, d.facing)),
        g.drops.map((d) => (d.x, d.spawn, d.kind, d.facing)),
      );
    }
  });

  test('booth bots keep the three layouts in difficulty order', () {
    // The bots see every drop, so they are an upper bound for real players.
    final easy = population(CatchCharacter.fukuchan);
    final normal = population(CatchCharacter.ctoOdatetsu);
    final hard = population(CatchCharacter.sobaya);
    expect(easy.pass, greaterThanOrEqualTo(.95));
    expect(normal.pass, inInclusiveRange(.7, .9));
    expect(hard.pass, lessThanOrEqualTo(.3));
    expect(easy.perfect, greaterThan(normal.perfect));
    expect(normal.perfect, greaterThan(hard.perfect));
    expect(hard.perfect, 0);
  });

  test('every preset TAS is perfect; Sobaya needs one', () {
    for (final c in CatchCharacter.values) {
      final tas = replay(c, decodeTas(presetTas[c]!));
      expect([tas.caught, tas.bad, tas.score], [tas.goodTotal, 0, 100]);
    }
    // Even an instant, flawless greedy player misses something.
    final greedy = playHuman(CatchCharacter.sobaya, reaction: 0, aimError: 0);
    expect(greedy.score, lessThan(100));
  });

  test('TAS mode uses the presets and searches for other settings', () async {
    final balance = Balance.defaults();
    expect(
      await tasFor(CatchCharacter.ctoOdatetsu, balance),
      decodeTas(presetTas[CatchCharacter.ctoOdatetsu]!),
    );
    final slow = Balance.fromMap({'fallSeconds': 4});
    final found = await tasFor(CatchCharacter.fukuchan, slow, seed: 3);
    expect(found, isNotNull);
    expect(
      replay(CatchCharacter.fukuchan, found!, seed: 3, balance: slow).score,
      100,
    );
    // A camera turned to any angle walks the same way as the front view.
    final g = CatchGame()..start();
    g.phase = Phase.playing;
    for (final yaw in [0.0, .5, math.pi / 2, 2.6, -1.2]) {
      g
        ..yaw = yaw
        ..targetYaw = yaw
        ..vx = 0;
      final x = g.x, s = tasInput(1, yaw);
      g.tick(1 / 60, inputX: s.x, inputY: s.y);
      expect(g.x, lessThan(x));
    }
  });

  test('TAS replays to 100 while the camera turns, as in the app', () {
    for (final c in CatchCharacter.values) {
      final inputs = decodeTas(presetTas[c]!);
      final g = CatchGame()
        ..selectCharacter(c)
        ..start();
      var frame = 0, step = 0;
      while (g.phase != Phase.result) {
        if (++step % 50 == 0) g.rotate(step % 300 < 150 ? 1 : -1);
        var u = 0;
        if (g.phase == Phase.playing && frame < inputs.length) {
          u = inputs[frame++];
        }
        final s = tasInput(u, g.yawAfter(1 / 60));
        g.tick(1 / 60, inputX: s.x, inputY: s.y);
      }
      expect(g.score, 100, reason: c.id);
    }
  });

  test('TAS run-length text round trips', () {
    final inputs = [-1, -1, 0, 1, 1, 1];
    expect(encodeTas(inputs), 'L2 N1 R3');
    expect(decodeTas(encodeTas(inputs)), inputs);
    expect(CatchGame.passScore, 80);
  });
}
