// ignore_for_file: avoid_print

// Prints how each character's fixed layout plays for the booth population.
//   mise exec -- dart run tool/balance_report.dart [seedFrom seedTo]
// With a seed range it lists every seed for the characters, to pick layouts.
import 'package:yumemi_recruit_exam/character.dart';

import 'balance_sim.dart';

void main(List<String> args) {
  final seeds = args.length == 2
      ? [for (var s = int.parse(args[0]); s <= int.parse(args[1]); s++) s]
      : <int?>[null];
  for (final c in pickerOrder) {
    for (final seed in seeds) {
      final g = newRound(c, seed: seed);
      final p = population(c, seed: seed);
      final tas = searchTas(c, seed: seed);
      print(
        '${c.id} seed ${g.seed}: good ${g.goodTotal} / bad '
        '${g.drops.length - g.goodTotal}, pass ${(p.pass * 100).round()}%, '
        'perfect ${(p.perfect * 100).round()}%, mean ${p.mean.round()}, '
        'TAS perfect ${tas != null}',
      );
      if (tas != null && seeds.length == 1) print('  TAS ${encodeTas(tas)}');
    }
  }
}
