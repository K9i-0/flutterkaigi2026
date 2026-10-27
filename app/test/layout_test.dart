import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/character.dart';

import '../tool/balance_sim.dart';

/// Sobaya's fixed layout made perfect by `tool/balance_report.dart`.
const sobayaTas =
    'L118 R29 N1 R1 L18 R75 N1 R5 L2 R44 N1 R1 N1 L125 R24 L10 N1 R82 N1 R5 '
    'L37 N1 R57 N1 R3 L78 R8 N1 R12 L39 N1 R108 L43 R3 N1 R2 L80 R105 N1 R12';

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
    expect(normal.pass, inInclusiveRange(.8, easy.pass));
    expect(hard.pass, lessThanOrEqualTo(.3));
    expect(easy.perfect, greaterThan(normal.perfect));
    expect(normal.perfect, greaterThan(hard.perfect));
    expect(hard.perfect, 0);
  });

  test('Sobaya is perfect only with a frame-exact input', () {
    final tas = replay(CatchCharacter.sobaya, decodeTas(sobayaTas));
    expect([tas.caught, tas.bad, tas.score], [tas.goodTotal, 0, 100]);
    // Even an instant, flawless greedy player misses something.
    final greedy = playHuman(CatchCharacter.sobaya, reaction: 0, aimError: 0);
    expect(greedy.score, lessThan(100));
  });

  test('TAS run-length text round trips', () {
    final inputs = [-1, -1, 0, 1, 1, 1];
    expect(encodeTas(inputs), 'L2 N1 R3');
    expect(decodeTas(encodeTas(inputs)), inputs);
    expect(CatchGame.passScore, 80);
  });
}
