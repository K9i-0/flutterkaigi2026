import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/balance.dart';
import 'package:yumemi_recruit_exam/graphics_settings.dart';
import 'package:yumemi_recruit_exam/settings_dialog.dart';

void main() {
  test('visual presets roundtrip and recover invalid saved options', () {
    expect(
      GraphicsSettings.fromMap(GraphicsSettings.light.toMap()),
      GraphicsSettings.light,
    );
    expect(
      GraphicsSettings.fromMap({'shadows': 'invalid', 'bloom': false}).shadows,
      true,
    );
    expect(
      GraphicsSettings.standard.renderScaleFor(2622),
      closeTo(1440 / 2622, 1e-9),
    );
    expect(GraphicsSettings.standard.renderScaleFor(1280), 1);
    expect(GraphicsSettings.highQuality.renderScaleFor(2622), 1);
    expect(
      GraphicsSettings.fromMap(GraphicsSettings.highQuality.toMap()),
      GraphicsSettings.highQuality,
    );
    expect(
      GraphicsSettings.light.withOption('reflections', true).reflections,
      true,
    );
    expect(
      GraphicsSettings.light.withOption('reflections', true).shadows,
      false,
    );
  });
  testWidgets('settings apply graphics, demo and balance together', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1748, 804);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SettingsResult? result;
    Future<void> open({bool inRound = false}) async {
      await tester.tap(find.text(inRound ? 'round' : 'open'));
      await tester.pumpAndSettle();
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Column(
            children: [
              for (final inRound in [false, true])
                TextButton(
                  onPressed: () async {
                    result = await showDialog<SettingsResult>(
                      context: context,
                      builder: (_) => SettingsDialog(
                        graphics: GraphicsSettings.standard,
                        balance: Balance.defaults(),
                        inRound: inRound,
                      ),
                    );
                  },
                  child: Text(inRound ? 'round' : 'open'),
                ),
            ],
          ),
        ),
      ),
    );
    await open();
    await tester.tap(find.byKey(const ValueKey('graphics_light')));
    await tester.tap(find.byKey(const ValueKey('settings_tab_demo')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tas_toggle')));
    await tester.tap(find.byKey(const ValueKey('fps_toggle')));
    await tester.pump();
    // Outside a round nothing restarts.
    expect(find.text('適用'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings_apply')));
    await tester.pumpAndSettle();
    expect(result!.graphics, GraphicsSettings.light);
    expect([result!.tas, result!.fps], [true, false]);
    expect(result!.balance.sameAs(Balance.defaults(), null), true);

    // Cancel discards edits.
    await open();
    await tester.tap(find.byKey(const ValueKey('graphics_light')));
    await tester.tap(find.byKey(const ValueKey('settings_close')));
    await tester.pumpAndSettle();
    expect(result, isNull);

    // In a round, a balance change restarts it; an invalid seed keeps the
    // dialog open on the balance tab.
    await open(inRound: true);
    await tester.tap(find.byKey(const ValueKey('settings_tab_balance')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('balance_fixed_layout')));
    await tester.pump();
    expect(find.text('適用して最初から'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('balance_seed')), 'x');
    await tester.tap(find.byKey(const ValueKey('settings_apply')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('settings')), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('balance_seed')), '42');
    await tester.tap(find.byKey(const ValueKey('settings_apply')));
    await tester.pumpAndSettle();
    expect(result!.balance.seed, 42);
  });
}
