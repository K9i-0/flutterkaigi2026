import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_motion_blend.dart';

void main() {
  test(
    'game walk uses the measured shared clip and its exact ground speed',
    () {
      final catalog = jsonDecode(
        File('../04_GAME_ASSETS/3d/hazard_adopted/manifest.json')
            .readAsStringSync(),
      ) as Map<String, dynamic>;
      for (final name in ['sobaya', 'fukuchan']) {
        final row = catalog[name] as Map<String, dynamic>;
        final sources = name == 'sobaya'
            ? sobayaMotionSources
            : playerMotionSources;
        for (final role in ['Walk', 'Run']) {
          expect(sources[role], row['sources'][role]);
          expect(row['clips'], contains(sources[role]));
        }
      }
      expect(fukuchanWalkSpeed, catalog['fukuchan']['groundSpeedMps']['Walk']);
      expect(fukuchanRunSpeed, catalog['fukuchan']['groundSpeedMps']['Run']);
      expect(sobayaWalkSpeed, catalog['sobaya']['groundSpeedMps']['Walk']);
      expect(sobayaMugRunSpeed, catalog['sobaya']['groundSpeedMps']['Run']);
    },
  );
  test(
    'all mug variants contact exactly on the damage beat and finish recovery',
    () {
      for (final duration in [1.1333333333, 1.3333333333, 1.6]) {
        for (final recovery in [.55 * .9, 1.2 * .8, 1.8 * .8]) {
          expect(
            mugAttackTime(0, duration, recoveryClockDuration: recovery),
            0,
          );
          expect(
            mugAttackTime(.77, duration, recoveryClockDuration: recovery),
            closeTo(duration * .48, 1e-9),
          );
          expect(
            mugAttackTime(
              .77 + recovery,
              duration,
              recoveryClockDuration: recovery,
            ),
            closeTo(duration, 1e-9),
          );
          expect(
            mugAttackTime(.4, duration, recoveryClockDuration: recovery),
            lessThan(duration * .48),
          );
        }
      }
    },
  );

  test('actual motion after collision drives the animation clock', () {
    expect(locomotionPlaybackRate(0, 1 / 60, 1), 0);
    expect(locomotionPlaybackRate(.02, .02, 1), 1);
    expect(locomotionPlaybackRate(.01, .02, 1), .5);
    expect(locomotionPlaybackRate(.01, 0, 1), 0);
  });
  test('walk/run keeps foot phase while actions start at the beginning', () {
    expect(transitionMotionTime('Walk', 'Run', .9, 1.2, .8), closeTo(.6, 1e-9));
    expect(transitionMotionTime('Run', 'Walk', .6, .8, 1.2), closeTo(.9, 1e-9));
    expect(transitionMotionTime('Walk', 'ReloadHandgun', .9, 1.2, .8), 0);
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
