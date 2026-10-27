/// Balance simulation shared by `tool/balance_report.dart` and the tests:
/// a population of human-like players and the frame-exact TAS search from
/// `lib/tas.dart`, all driving the real [CatchGame] in the default front view.
library;

import 'dart:math' as math;

import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/character.dart';

export 'package:yumemi_recruit_exam/tas.dart';

CatchGame newRound(CatchCharacter c, {int? seed}) => CatchGame()
  ..selectCharacter(c)
  ..start(seed: seed);

/// Greedy player that sees every drop's kind and landing spot (an upper bound:
/// real players must also turn the camera to read labels). It heads for the
/// next good drop a reaction time after the previous drop lands, misses its
/// aim by up to [aimError], and sidesteps a bad drop landing first.
CatchGame playHuman(
  CatchCharacter c, {
  int? seed,
  double reaction = .3,
  double aimError = .3,
  int botSeed = 0,
}) {
  final g = newRound(c, seed: seed);
  final rnd = math.Random(botSeed * 7919 + g.seed);
  final aim = <int, double>{}, delay = <int, double>{};
  var lastResolve = -10.0, resolved = 0;
  var target = 0.0;
  int? targetId;
  while (g.phase != Phase.result) {
    var input = 0.0;
    if (g.phase == Phase.playing) {
      final count = g.drops.where((d) => d.resolved).length;
      if (count != resolved) {
        resolved = count;
        lastResolve = g.time;
      }
      final pending =
          g.drops
              .where((d) => !d.resolved && d.spawn + reaction <= g.time)
              .toList()
            ..sort((a, b) => a.landing.compareTo(b.landing));
      final good = pending.where((d) => !d.kind.isBad).firstOrNull;
      final chasing = g.drops.any((d) => d.id == targetId && !d.resolved);
      if (!chasing && good != null) {
        final wait = delay.putIfAbsent(
          good.id,
          () => reaction * (.5 + rnd.nextDouble()),
        );
        if (g.time >= lastResolve + wait) {
          targetId = good.id;
          target =
              good.x +
              aim.putIfAbsent(
                good.id,
                () => (rnd.nextDouble() * 2 - 1) * aimError,
              );
        }
      }
      final chased = g.drops.where((d) => d.id == targetId).firstOrNull;
      var goal = target;
      final margin = g.catchRadius + .1;
      for (final b in pending.where((d) => d.kind.isBad)) {
        if (chased != null && b.landing > chased.landing + .05) continue;
        if (b.landing - g.time > .7) continue;
        if ((goal - b.x).abs() < margin || (g.x - b.x).abs() < margin) {
          final side = g.x >= b.x ? 1 : -1;
          goal = b.x + side * (g.catchRadius + .2);
          if (goal.abs() > CatchGame.halfX) {
            goal = b.x - side * (g.catchRadius + .2);
          }
        }
      }
      // Front view: tilting right walks toward world -x.
      input = -((goal - g.x) * 4).clamp(-1.0, 1.0);
    }
    g.tick(1 / 60, inputX: input);
  }
  return g;
}

/// Booth visitors: reaction .2-.5 s and aim error .1-.5 per player.
({double pass, double perfect, double mean}) population(
  CatchCharacter c, {
  int? seed,
  int players = 200,
}) {
  final rnd = math.Random(c.index * 31 + 7);
  var pass = 0, perfect = 0, sum = 0;
  for (var b = 0; b < players; b++) {
    final g = playHuman(
      c,
      seed: seed,
      reaction: .2 + rnd.nextDouble() * .3,
      aimError: .1 + rnd.nextDouble() * .4,
      botSeed: b,
    );
    if (g.passed) pass++;
    if (g.score == 100) perfect++;
    sum += g.score;
  }
  return (
    pass: pass / players,
    perfect: perfect / players,
    mean: sum / players,
  );
}
