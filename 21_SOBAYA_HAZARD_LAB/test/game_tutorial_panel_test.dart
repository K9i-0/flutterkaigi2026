import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_tutorial_panel.dart';

void main() {
  for (final size in [
    const Size(1280, 840),
    const Size(844, 390),
    const Size(390, 844),
  ]) {
    testWidgets(
      'coaching leaves the center and lower controls clear at $size',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final s = HazardGameState(
          jsonDecode(File('assets/village.json').readAsStringSync()),
        );
        for (final step in tutorialSteps) {
          s.beginTutorial(step: step);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    Positioned(
                      left: 12,
                      top: 10,
                      width: math.min(360, size.width * .42),
                      child: HazardTutorialPanel(
                        state: s,
                        mobile: size.width < 1000,
                        onRetry: () {},
                        onFinish: () {},
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          expect(tester.takeException(), isNull, reason: step);
          final rect = tester.getRect(
            find.byKey(const ValueKey('game-tutorial-panel')),
          );
          expect(rect.contains(size.center(Offset.zero)), false, reason: step);
          expect(rect.bottom, lessThan(size.height - 130), reason: step);
        }
      },
    );
  }
}
