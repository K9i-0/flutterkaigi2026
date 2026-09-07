import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:humanoid_motion_lab/catalog.dart';

void main() {
  test(
    'one-shot holds its final pose, replay wraps and pause freezes time',
    () {
      final clock = MotionClock()
        ..repeat = false
        ..seconds = .98;
      clock.advance(.04, 1);
      expect(clock.seconds, 1);
      expect(clock.paused, isTrue);
      clock.advance(.1, 1);
      expect(clock.seconds, 1);
      clock
        ..repeat = true
        ..paused = false
        ..speed = .5
        ..seconds = .98;
      clock.advance(.1, 1);
      expect(clock.seconds, closeTo(.03, 1e-9));
      clock.seek(.6, 1);
      clock.advance(.1, 1);
      expect(clock.seconds, .6);
      expect(() => clock.seek(double.nan, 1), throwsArgumentError);
    },
  );

  test('catalog supports four methods on both measured skeletons', () {
    final json = jsonDecode(
      File('assets/catalog.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final bodies = (json['characters'] as List)
        .map((e) => BodyProfile(e as Map<String, dynamic>))
        .toList();
    expect(bodies.length, 2);
    for (final body in bodies) {
      for (final method in MotionMethod.values) {
        expect(
          body.find(method, 'Walk'),
          isNotNull,
          reason: '${body.id}/${method.name}',
        );
        expect(
          body.find(method, 'Run'),
          isNotNull,
          reason: '${body.id}/${method.name}',
        );
      }
      for (final role in ['pelvis', 'foot_l', 'foot_r', 'hand_l', 'hand_r']) {
        expect(body.boneMap[role], isNotNull);
      }
    }
    final sobaya = bodies.firstWhere((b) => b.id == 'sobaya');
    final fuku = bodies.firstWhere((b) => b.id == 'fukuchan');
    expect(sobaya.leg, greaterThan(fuku.leg));
    expect(sobaya.shoulder, greaterThan(fuku.shoulder * 1.4));
    // Height scaling alone must not be used for limb retargeting.
    expect(
      (sobaya.leg / fuku.leg - sobaya.height / fuku.height).abs(),
      greaterThan(.02),
    );
  });
}
