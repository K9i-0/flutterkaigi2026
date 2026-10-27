/// Frame-exact perfect play (TAS), shown in the TAS mode of the balance panel
/// to prove a layout can score 100, and used by `tool/balance_report.dart`.
library;

import 'dart:isolate';
import 'dart:math' as math;

import 'balance.dart';
import 'catch_game.dart';
import 'character.dart';

/// Perfect inputs for each fixed layout with the default balance, found by
/// `tool/balance_report.dart`; test/layout_test.dart replays them to 100.
const presetTas = {
  CatchCharacter.fukuchan:
      'L205 R42 N1 R4 L7 N1 R74 N1 R6 L68 N1 R12 N1 R8 L53 R28 N1 R7 L24 R63 '
      'N1 R2 L68 R19 N1 R2 L113 R62 N1 R3 L40 R42 N1 R6 L32 R58',
  CatchCharacter.ctoOdatetsu:
      'L115 R64 N1 R7 L23 R31 N1 R6 L122 R63 N1 L22 N1 R39 L32 N1 R24 N1 R3 '
      'L49 R5 N1 R7 L27 R33 N1 R1 L28 R34 L3 R53 N1 R4 L72 R48 N1 R3 L79 N1 '
      'R29 N1 R14 L61',
  CatchCharacter.sobaya:
      'L118 R29 N1 R1 L18 R75 N1 R5 L2 R44 N1 R1 N1 L125 R24 L10 N1 R82 N1 R5 '
      'L37 N1 R57 N1 R3 L78 R8 N1 R12 L39 N1 R108 L43 R3 N1 R2 L80 R105 N1 R12',
};

/// Perfect inputs for a round: the preset for the defaults, otherwise searched
/// in the background. Null when the round cannot be made perfect.
Future<List<int>?> tasFor(
  CatchCharacter c,
  Balance balance, {
  int? seed,
}) async {
  final defaults = Balance.defaults();
  if (seed == null &&
      Balance.fields.every((f) => balance[f.key] == defaults[f.key])) {
    return decodeTas(presetTas[c]!);
  }
  final values = balance.values;
  // Pure Dart, so `dart run tool/...` can use this file without Flutter.
  return Isolate.run(() {
    final b = Balance.fromMap(values);
    // A coarse grid usually succeeds in well under a second; every result is
    // replayed by [searchTas], so coarseness never yields a wrong input.
    for (final (xq, vq) in const [(.04, .24), (.02, .12), (.01, .06)]) {
      final found = searchTas(c, seed: seed, balance: b, xq: xq, vq: vq);
      if (found != null) return found;
    }
    return null;
  });
}

CatchGame _round(CatchCharacter c, Balance? balance, int? seed) => CatchGame()
  ..balance = balance ?? Balance.defaults()
  ..selectCharacter(c)
  ..start(seed: seed);

/// Frame-exact search over full-left / none / full-right inputs, merging
/// states on a position/velocity grid. It judges good drops by the plain radius
/// at landing, stricter than the game, so a found input stays perfect there.
/// Returns per-frame screen inputs at the front view from the first playing
/// frame that make the round perfect, or null if none is found.
List<int>? searchTas(
  CatchCharacter c, {
  int? seed,
  Balance? balance,
  double xq = .01,
  double vq = .06,
}) {
  final g = _round(c, balance, seed);
  const dt = 1 / 60;
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
  return replay(c, seq, seed: seed, balance: balance).score == 100 ? seq : null;
}

/// Plays [inputs] (one per frame, from the first playing frame) then idles.
CatchGame replay(
  CatchCharacter c,
  List<int> inputs, {
  int? seed,
  Balance? balance,
}) {
  final g = _round(c, balance, seed);
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

/// Screen input for TAS frame [u] at the camera [yaw], so it walks the same
/// way as at the front view while the camera is turned.
({double x, double y}) tasInput(int u, double yaw) =>
    CatchGame.toScreen(-u.toDouble(), 0, yaw);

/// Run-length text, e.g. `R12 N3 L40`, to keep a TAS in code.
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
