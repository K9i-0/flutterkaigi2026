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
      for (final preset in HazardGraphicsPreset.values) {
        final previousScale = settings.renderScale;
        await choose('game-graphics-${preset.name}');
        expect(settings.graphicsPreset, preset);
        expect(settings.renderScale, previousScale);
        expect(
          tester
              .widget<ChoiceChip>(
                find.byKey(ValueKey('game-graphics-${preset.name}')),
              )
              .selected,
          isTrue,
        );
        for (final scale in [.65, .85, 1.0]) {
          await choose('game-resolution-${(scale * 100).round()}');
          expect(settings.renderScale, scale);
          expect(settings.graphicsPreset, preset);
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
        }
      }
      await choose('game-lighting');
      expect(settings.cinematicLighting, isFalse);
      expect(settings.graphicsPreset, HazardGraphicsPreset.showcase);
      expect(settings.renderScale, 1);
    },
  );
}
