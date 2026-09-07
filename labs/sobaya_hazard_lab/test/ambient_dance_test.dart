import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_motion_blend.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

void main() {
  test(
    '20 percent spawn choice covers all three dances and excludes bosses',
    () {
      expect(chooseAmbientDance(.1999, 0), 'DanceStep');
      expect(chooseAmbientDance(.1, 1), 'DanceDisco');
      expect(chooseAmbientDance(.1, 2), 'DanceVictory');
      expect(chooseAmbientDance(.2, 0), isNull);
      expect(chooseAmbientDance(0, 0, boss: true), isNull);
    },
  );
  test('dance stops on suspicion, detection, damage, death or inactivity', () {
    final e = Enemy(1, 0, 0)
      ..ambientDance = 'DanceDisco'
      ..active = true;
    expect(e.idleDance, 'DanceDisco');
    e.notice = .01;
    expect(e.idleDance, isNull);
    e.notice = 0;
    e.hp = 99;
    expect(e.idleDance, isNull);
    e.hp = 100;
    e.active = false;
    expect(e.idleDance, isNull);
    e.active = true;
    e.alive = false;
    expect(e.idleDance, isNull);
    e.alive = true;
    e.alerted = true;
    expect(e.idleDance, isNull);
    e.alerted = false;
    expect(e.idleDance, isNull); // Losing the player does not restart the gag.
  });
}
