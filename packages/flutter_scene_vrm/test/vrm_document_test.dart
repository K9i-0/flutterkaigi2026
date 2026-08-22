import 'dart:io';

import 'package:flutter_scene_vrm/flutter_scene_vrm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reads official VRM 1.0 avatar metadata and expression binds', () {
    final bytes = File(
      '../../04_GAME_ASSETS/vrm/models/'
      'VRM1_Constraint_Twist_Sample.vrm',
    ).readAsBytesSync();
    final document = VrmDocument.fromGlbBytes(bytes);

    expect(document.meta.name, isNotEmpty);
    expect(document.meta.authors.single, contains('pixiv'));
    expect(document.humanoidBones.length, greaterThan(40));
    expect(document.expressions.length, greaterThanOrEqualTo(17));
    expect(document.expressions['happy']!.morphTargetBinds.single.node, 1);
    expect(document.expressions['happy']!.morphTargetBinds.single.index, 3);
    expect(document.expressions['blink']!.morphTargetBinds.single.index, 12);
    expect(document.hasMToon, isTrue);
    expect(document.hasSpringBone, isTrue);
    expect(document.hasNodeConstraint, isTrue);
  });
}
