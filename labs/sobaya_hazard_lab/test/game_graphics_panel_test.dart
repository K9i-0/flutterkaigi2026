import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_graphics_panel.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';

void main() {
  testWidgets(
    'graphics controls fit 320px at 1.3 text scale and preserve independent choices',
    (tester) async {
      tester.view
        ..physicalSize = const Size(320, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final settings = HazardSettings(
        graphicsPreset: HazardGraphicsPreset.balanced,
        renderScale: .65,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 900),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) => HazardGraphicsPanel(
                    settings: settings,
                    onChanged: (change) => setState(() => change(settings)),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      void expectFits() {
        expect(tester.takeException(), isNull);
        for (final chip in tester.widgetList<ChoiceChip>(
          find.byType(ChoiceChip),
        )) {
          final rect = tester.getRect(find.byKey(chip.key!));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(320));
        }
      }

      Future<void> choose(String key) async {
        final target = find.byKey(ValueKey(key));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        expectFits();
      }

      expectFits();
      expect(settings.frameRateLimit, 60);
      for (final fps in [30, 60]) {
        expect(find.byKey(ValueKey('game-frame-rate-$fps')), findsOneWidget);
        expect(find.text('$fps fps'), findsOneWidget);
      }
      for (final preset in HazardGraphicsPreset.values) {
        final previousScale = settings.renderScale;
        final previousFrameRate = settings.frameRateLimit;
        await choose('game-graphics-${preset.name}');
        expect(settings.graphicsPreset, preset);
        expect(settings.renderScale, previousScale);
        expect(settings.frameRateLimit, previousFrameRate);
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey('game-graphics-${preset.name}')),
              )
              .selected,
          isTrue,
        );
        for (final scale in [.65, .85, 1.0]) {
          final previousFrameRate = settings.frameRateLimit;
          await choose('game-resolution-${(scale * 100).round()}');
          expect(settings.renderScale, scale);
          expect(settings.graphicsPreset, preset);
          expect(settings.frameRateLimit, previousFrameRate);
          expect(
            tester
                .widget<ChoiceChip>(
                  find.byKey(
                    ValueKey('game-resolution-${(scale * 100).round()}'),
                  ),
                )
                .selected,
            isTrue,
          );
          for (final fps in [30, 60]) {
            await choose('game-frame-rate-$fps');
            expect(settings.frameRateLimit, fps);
            expect(settings.graphicsPreset, preset);
            expect(settings.renderScale, scale);
            expect(settings.cinematicLighting, isTrue);
            for (final option in [30, 60]) {
              expect(
                tester
                    .widget<ChoiceChip>(
                      find.byKey(ValueKey('game-frame-rate-$option')),
                    )
                    .selected,
                option == fps,
              );
            }
            final restored = HazardSettings.decode(settings.encode());
            expect(restored.frameRateLimit, fps);
            expect(restored.graphicsPreset, preset);
            expect(restored.renderScale, scale);
          }
        }
      }
      await choose('game-frame-rate-30');
      await choose('game-frame-rate-30');
      expect(
        settings.frameRateLimit,
        30,
        reason: 'reselecting cannot remove the frame limit',
      );
      await choose('game-lighting');
      expect(settings.cinematicLighting, isFalse);
      expect(settings.graphicsPreset, HazardGraphicsPreset.showcase);
      expect(settings.renderScale, 1);
      expect(settings.frameRateLimit, 30);
    },
  );
}
