/// Balance simulation shared by `tool/balance_report.dart` and the tests:
/// a population of human-like players and a frame-exact TAS search, both
/// driving the real [CatchGame] in the default front view.
library;

import 'dart:math' as math;

import 'package:yumemi_recruit_exam/catch_game.dart';
import 'package:yumemi_recruit_exam/character.dart';

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

/// Frame-exact search over full-left / none / full-right inputs, merging
/// states on a position/velocity grid. Returns per-frame screen inputs from the
/// first playing frame that make the round perfect, or null if none is found.
List<int>? searchTas(CatchCharacter c, {int? seed}) {
  final g = newRound(c, seed: seed);
  const dt = 1 / 60, xq = .01, vq = .06;
  final v = g.moveSpeed, r = g.catchRadius;
  final a = 1 - math.exp(-g.balance['acceleration'] * dt);
  final drops = [...g.drops]..sort((p, q) => p.landing.compareTo(q.landing));
  final parents = <List<int>>[], inputs = <List<int>>[];
  var xs = [0.0], vs = [0.0];
  var time = 0.0;
  var next = 0;
  while (next < drops.length) {
    time += dt;
    final nx = <double>[], nv = <double>[], np = <int>[], ni = <int>[];
    final seen = <int>{};
    for (var k = 0; k < xs.length; k++) {
      for (final u in const [-1, 0, 1]) {
        // Mirrors CatchGame._step at yaw 0, where world dir = -screen x.
        var vx = vs[k] + (-u * v - vs[k]) * a;
        final x = (xs[k] + vx * dt).clamp(-CatchGame.halfX, CatchGame.halfX);
        vx = (x - xs[k]) / dt;
        final key =
            ((x / xq).round() + 5000) * 100000 + (vx / vq).round() + 50000;
        if (!seen.add(key)) continue;
        nx.add(x);
        nv.add(vx);
        np.add(k);
        ni.add(u);
      }
    }
    final keep = List.filled(nx.length, true);
    while (next < drops.length && time >= drops[next].landing) {
      final d = drops[next++];
      for (var k = 0; k < nx.length; k++) {
        if (keep[k] && ((d.x - nx[k]).abs() < r) == d.kind.isBad) {
          keep[k] = false;
        }
      }
    }
    xs = [
      for (var k = 0; k < nx.length; k++)
        if (keep[k]) nx[k],
    ];
    vs = [
      for (var k = 0; k < nx.length; k++)
        if (keep[k]) nv[k],
    ];
    parents.add([
      for (var k = 0; k < nx.length; k++)
        if (keep[k]) np[k],
    ]);
    inputs.add([
      for (var k = 0; k < nx.length; k++)
        if (keep[k]) ni[k],
    ]);
    if (xs.isEmpty) return null;
  }
  final out = <int>[];
  var k = 0;
  for (var s = inputs.length - 1; s >= 0; s--) {
    out.add(inputs[s][k]);
    k = parents[s][k];
  }
  final seq = out.reversed.toList();
  return replay(c, seq, seed: seed).score == 100 ? seq : null;
}

/// Plays [inputs] (one per frame, from the first playing frame) then idles.
CatchGame replay(CatchCharacter c, List<int> inputs, {int? seed}) {
  final g = newRound(c, seed: seed);
  while (g.phase == Phase.countdown) {
    g.tick(1 / 60);
  }
  for (final u in inputs) {
    g.tick(1 / 60, inputX: u.toDouble());
  }
  while (g.phase != Phase.result) {
    g.tick(1 / 60);
  }
  return g;
}

/// Run-length text, e.g. `R12 N3 L40`, to keep a TAS in a test.
String encodeTas(List<int> inputs) {
  final parts = <String>[];
  for (var i = 0; i < inputs.length;) {
    var j = i;
    while (j < inputs.length && inputs[j] == inputs[i]) {
      j++;
    }
    parts.add('${const {-1: 'L', 0: 'N', 1: 'R'}[inputs[i]]}${j - i}');
    i = j;
  }
  return parts.join(' ');
}

List<int> decodeTas(String text) => [
  for (final part in text.split(' '))
    ...List.filled(
      int.parse(part.substring(1)),
      const {'L': -1, 'N': 0, 'R': 1}[part[0]]!,
    ),
];
