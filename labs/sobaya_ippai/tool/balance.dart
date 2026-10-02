import 'dart:io';

import 'package:sobaya_ippai/pour_game.dart';

void main() {
  for (var v = .69; v < .73; v += .002) {
    final g = PourGame()..start();
    for (var i = 0; i < 204; i++) {
      g.tick(1 / 120);
    }
    while (g.fill + g.airborne < .996 && g.phase == PourPhase.pouring) {
      g.tick(1 / 120, input: v);
    }
    g.serve();
    for (var i = 0; i < 120; i++) {
      g.tick(1 / 120);
    }
    stdout.writeln('$v ${g.inspect()}');
  }
}
