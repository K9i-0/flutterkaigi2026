import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_mobile.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';
import 'package:sobaya_hazard_lab/game/game_threat_hud.dart';

Widget status(StealthFeedback feedback, {required bool compact}) => MaterialApp(
  home: Scaffold(
    body: Center(
      child: SizedBox(
        width: compact ? 164 : 280,
        child: HazardThreatStatus(feedback: feedback, compact: compact),
      ),
    ),
  ),
);

void main() {
  for (final compact in [false, true]) {
    testWidgets(
      '${compact ? 'compact' : 'desktop'} search countdown uses actual remaining time and shows the extension reason',
      (tester) async {
        await tester.pumpWidget(
          status(
            const StealthFeedback(
              phase: 'searching',
              remaining: 6.2,
              duration: 15.8,
              reason: '足音を聞かれた',
            ),
            compact: compact,
          ),
        );
        expect(find.text('追跡解除まで 7秒'), findsOneWidget);
        expect(find.text('足音を聞かれた'), findsOneWidget);
        final first = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('game-search-progress')),
        );
        expect(first.value, closeTo(6.2 / 15.8, .000001));
        await tester.pumpWidget(
          status(
            const StealthFeedback(
              phase: 'searching',
              remaining: 2.1,
              duration: 15.8,
            ),
            compact: compact,
          ),
        );
        expect(find.text('追跡解除まで 3秒'), findsOneWidget);
        expect(find.text('足音を聞かれた'), findsNothing);
        final next = tester.widget<LinearProgressIndicator>(
          find.byKey(const ValueKey('game-search-progress')),
        );
        expect(next.value, lessThan(first.value!));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '${compact ? 'compact' : 'desktop'} separates suspicion, discovery, return and calm without a stale countdown',
      (tester) async {
        await tester.pumpWidget(
          status(
            const StealthFeedback(phase: 'suspicious', suspicion: .45),
            compact: compact,
          ),
        );
        expect(find.text('疑われている'), findsOneWidget);
        expect(
          tester
              .widget<LinearProgressIndicator>(
                find.byKey(const ValueKey('game-search-progress')),
              )
              .value,
          .45,
        );
        await tester.pumpWidget(
          status(const StealthFeedback(phase: 'chasing'), compact: compact),
        );
        expect(find.text('発見中 — 視界を切れ'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('game-search-progress')),
          findsNothing,
        );
        await tester.pumpWidget(
          status(
            const StealthFeedback(
              phase: 'returning',
              remaining: 6,
              duration: 8,
            ),
            compact: compact,
          ),
        );
        expect(find.text('追跡解除 — 持ち場へ戻っている'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('game-search-progress')),
          findsNothing,
        );
        await tester.pumpWidget(
          status(const StealthFeedback(phase: 'calm'), compact: compact),
        );
        expect(find.byKey(const ValueKey('game-threat-status')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final strength in [0.0, .7]) {
    testWidgets(
      'threat effect strength $strength never intercepts look or action input',
      (tester) async {
        var taps = 0;
        final drags = <Offset>[];
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => taps++,
                      onPanUpdate: (event) => drags.add(event.delta),
                    ),
                  ),
                  Positioned.fill(
                    child: HazardThreatOverlay(
                      feedback: const StealthFeedback(
                        phase: 'chasing',
                        bearing: math.pi / 2,
                      ),
                      time: 1,
                      yaw: 0,
                      strength: strength,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.tapAt(const Offset(120, 120));
        expect(taps, 1);
        await tester.dragFrom(const Offset(220, 220), const Offset(70, 20));
        expect(drags, isNotEmpty);
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(HazardThreatOverlay),
            matching: find.byType(CustomPaint),
          ),
        );
        void draw(Canvas canvas) =>
            paint.painter!.paint(canvas, const Size(400, 300));
        expect(
          draw,
          strength == 0 ? paintsNothing : paintsExactlyCountTimes(#drawRect, 1),
        );
        if (strength > 0) {
          expect(draw, paintsExactlyCountTimes(#drawArc, 1));
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final direction in <String, (double, double)>{
    'right': (math.pi / 2, 0),
    'left': (-math.pi / 2, math.pi),
    'ahead': (math.pi, -math.pi / 2),
  }.entries) {
    testWidgets(
      'known ${direction.key} cue is drawn on the same side of the camera',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: HazardThreatOverlay(
              feedback: StealthFeedback(
                phase: 'chasing',
                bearing: direction.value.$1,
              ),
              time: 1,
              yaw: 0,
              strength: .7,
            ),
          ),
        );
        final paint = tester.widget<CustomPaint>(
          find.descendant(
            of: find.byType(HazardThreatOverlay),
            matching: find.byType(CustomPaint),
          ),
        );
        expect(
          (Canvas canvas) => paint.painter!.paint(canvas, const Size(400, 300)),
          paints..arc(startAngle: direction.value.$2 - .12, sweepAngle: .24),
        );
      },
    );
  }

  testWidgets('unknown enemy has no directional arc', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: HazardThreatOverlay(
          feedback: StealthFeedback(
            phase: 'searching',
            remaining: 5,
            duration: 15,
          ),
          time: 1,
          yaw: 0,
          strength: .7,
        ),
      ),
    );
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(HazardThreatOverlay),
        matching: find.byType(CustomPaint),
      ),
    );
    expect(
      (Canvas canvas) => paint.painter!.paint(canvas, const Size(400, 300)),
      paintsExactlyCountTimes(#drawArc, 0),
    );
  });

  testWidgets(
    'beer uses the existing six action buttons, disables reload and restores it on weapon change',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var throwingBeer = true, aiming = false, fires = 0, reloads = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => Padding(
                padding: const EdgeInsets.all(12),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: HazardTouchControls(
                    onMove: (_) {},
                    sneaking: false,
                    sprinting: false,
                    aiming: aiming,
                    throwingBeer: throwingBeer,
                    onSneak: () {},
                    onSprint: () {},
                    onAim: () => setState(() => aiming = !aiming),
                    onFire: () => fires++,
                    onReload: () => reloads++,
                    onInteract: () {},
                    onHeal: () {},
                    onWeapon: () =>
                        setState(() => throwingBeer = !throwingBeer),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final before = tester
          .widgetList<HazardTouchButton>(find.byType(HazardTouchButton))
          .map((button) => button.id)
          .toSet();
      expect(before, {
        'aim',
        'fire',
        'reload',
        'interact',
        'heal',
        'weapon',
        'sneak',
        'sprint',
      });
      expect(find.text('投げる'), findsOneWidget);
      expect(find.text('射撃'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('game-aim')));
      await tester.pump();
      expect(aiming, true);
      await tester.tap(find.byKey(const ValueKey('game-fire')));
      expect(fires, 1);
      final reload = tester
          .widgetList<HazardTouchButton>(find.byType(HazardTouchButton))
          .singleWhere((button) => button.id == 'reload');
      expect(reload.enabled, false);
      await tester.tap(find.byKey(const ValueKey('game-reload')));
      expect(reloads, 0);
      await tester.tap(find.byKey(const ValueKey('game-weapon')));
      await tester.pump();
      expect(find.text('射撃'), findsOneWidget);
      expect(find.text('投げる'), findsNothing);
      expect(
        tester
            .widgetList<HazardTouchButton>(find.byType(HazardTouchButton))
            .map((button) => button.id)
            .toSet(),
        before,
      );
      await tester.tap(find.byKey(const ValueKey('game-reload')));
      expect(reloads, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
