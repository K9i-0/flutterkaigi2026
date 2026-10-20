import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/graphics_settings.dart';

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
    expect(GraphicsSettings.standard.renderScale, 1);
    expect(GraphicsSettings.light.renderScale, .8);
    expect(
      GraphicsSettings.light.withOption('reflections', true).reflections,
      true,
    );
    expect(
      GraphicsSettings.light.withOption('reflections', true).shadows,
      false,
    );
  });
  testWidgets('light preset applies and cancel leaves caller settings intact', (
    tester,
  ) async {
    GraphicsSettings? result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await showDialog<GraphicsSettings>(
                context: context,
                builder: (_) =>
                    const GraphicsDialog(initial: GraphicsSettings.standard),
              );
            },
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('graphics_light')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('graphics_apply')));
    await tester.pumpAndSettle();
    expect(result, GraphicsSettings.light);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('キャンセル'));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
