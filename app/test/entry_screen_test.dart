import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/entry_screen.dart';
import 'package:yumemi_recruit_exam/app_style.dart';

void main() {
  testWidgets(
    'wide phone keeps start action inside safe area and accepts taps',
    (tester) async {
      tester.view.physicalSize = const Size(960, 400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var starts = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: appTheme(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(960, 400),
              padding: EdgeInsets.fromLTRB(62, 0, 62, 21),
            ),
            child: Scaffold(body: TitleScreen(onStart: () => starts++)),
          ),
        ),
      );
      final label = tester.getRect(find.text('タップして開始'));
      expect(label.bottom, lessThan(379));
      expect(label.left, greaterThan(62));
      expect(label.right, lessThan(898));
      await tester.tap(find.text('タップして開始'));
      expect(starts, 1);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('loading uses the standard circular indicator on white', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: BrandLoading())),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(ShaderMask), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
