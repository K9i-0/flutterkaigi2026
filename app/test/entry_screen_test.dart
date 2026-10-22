import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yumemi_recruit_exam/entry_screen.dart';
import 'package:yumemi_recruit_exam/app_style.dart';
import 'package:yumemi_recruit_exam/about_dialog.dart';
import 'package:yumemi_recruit_exam/l10n.dart';

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
            child: Scaffold(
              body: TitleScreen(
                onStart: () => starts++,
                lang: AppLang.ja,
                onLang: (_) {},
              ),
            ),
          ),
        ),
      );
      final label = tester.getRect(find.text('タップして開始'));
      expect(label.bottom, lessThan(379));
      expect(label.left, greaterThan(62));
      expect(label.right, lessThan(898));
      final english = tester.getRect(find.text('Tap to start'));
      expect(english.bottom, lessThan(379));
      expect(english.right, lessThan(898));
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
  testWidgets('title switches the language without starting', (tester) async {
    tester.view.physicalSize = const Size(960, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var starts = 0;
    final langs = <AppLang>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        home: Scaffold(
          body: TitleScreen(
            onStart: () => starts++,
            lang: AppLang.ja,
            onLang: langs.add,
          ),
        ),
      ),
    );
    final about = tester.getRect(find.byKey(const ValueKey('about')));
    final toggle = tester.getRect(find.byKey(const ValueKey('lang_en')));
    expect(about.left, lessThan(480));
    expect(toggle.top, lessThan(220));
    await tester.tap(find.byKey(const ValueKey('lang_en')));
    expect(langs, [AppLang.en]);
    expect(starts, 0);
  });
  testWidgets('about opens credits and licenses without starting', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(960, 440);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var starts = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: appTheme(),
        // The start pulse never settles; reduced motion holds it still.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: Scaffold(
          body: TitleScreen(
            onStart: () => starts++,
            lang: AppLang.ja,
            onLang: (_) {},
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('about')));
    await tester.pumpAndSettle();
    expect(starts, 0);
    expect(find.byType(AboutAppDialog), findsOneWidget);
    expect(find.text('github.com/K9i-0/flutterkaigi2026'), findsOneWidget);
    expect(find.byKey(const ValueKey('about_repository_qr')), findsOneWidget);
    expect(find.text('@K9i-0'), findsOneWidget);
    expect(find.text('@karas1910'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('about_licenses')));
    await tester.pumpAndSettle();
    // Licenses slide in inside the dialog rather than pushing a page.
    expect(find.byType(LicensePage), findsNothing);
    expect(find.byKey(const ValueKey('about_license_list')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('about_tab_about')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('about_repository_qr')), findsOneWidget);
  });
}
