import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_motion_blend.dart';

void main() {
  test('actual motion after collision drives the animation clock', () {
    expect(locomotionPlaybackRate(0, 1 / 60, 1), 0);
    expect(locomotionPlaybackRate(.02, .02, 1), 1);
    expect(locomotionPlaybackRate(.01, .02, 1), .5);
    expect(locomotionPlaybackRate(.01, 0, 1), 0);
  });
  test('walk/run keeps foot phase while actions start at the beginning', () {
    expect(transitionMotionTime('Walk', 'Run', .9, 1.2, .8), closeTo(.6, 1e-9));
    expect(transitionMotionTime('Run', 'Walk', .6, .8, 1.2), closeTo(.9, 1e-9));
    expect(transitionMotionTime('Walk', 'Kick', .9, 1.2, .8), 0);
    expect(transitionMotionTime('Idle', 'Walk', .9, 2, 1.2), 0);
  });
  test(
    'blend duration is frame-rate independent and old clips become zero',
    () {
      double simulate(int hz, double seconds) {
        var weight = 1.0;
        for (var i = 0; i < (hz * seconds).round(); i++) {
          weight = advanceMotionWeight(weight, false, 1 / hz);
        }
        return weight;
      }

      expect(simulate(30, .2), closeTo(simulate(120, .2), 1e-9));
      expect(simulate(60, 1), 0);
      expect(advanceMotionWeight(.5, false, 0), .5);
    },
  );
}
