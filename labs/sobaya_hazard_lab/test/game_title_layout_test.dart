import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_title.dart';

void main() {
  for (final size in [
    const Size(568, 320),
    const Size(844, 390),
    const Size(320, 568),
    const Size(390, 844),
    const Size(1280, 800),
  ]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('title actions stay visible at $size and text scale $scale', (
        tester,
      ) async {
        final safe = size.width > size.height
            ? const EdgeInsets.fromLTRB(24, 0, 24, 21)
            : const EdgeInsets.fromLTRB(0, 44, 0, 34);
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final calls = <String>[];
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: safe,
                textScaler: TextScaler.linear(scale),
              ),
              child: Scaffold(body: title(calls, saveStatus: '進行を保存しました')),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(Scrollable), findsNothing);
        final safeRect = Rect.fromLTRB(
          safe.left,
          safe.top,
          size.width - safe.right,
          size.height - safe.bottom,
        );
        final rects = <Rect>[];
        for (final id in ['continue', 'start', 'title-settings']) {
          final finder = find.byKey(ValueKey('game-$id'));
          final rect = tester.getRect(finder);
          expect(rect.width, greaterThanOrEqualTo(48), reason: id);
          expect(rect.height, greaterThanOrEqualTo(48), reason: id);
          expect(safeRect.contains(rect.topLeft), isTrue, reason: id);
          expect(rect.right, lessThanOrEqualTo(safeRect.right), reason: id);
          expect(rect.bottom, lessThanOrEqualTo(safeRect.bottom), reason: id);
          expect(finder.hitTestable(), findsOneWidget);
          expect(rects.any(rect.overlaps), isFalse, reason: id);
          rects.add(rect);
          await tester.tap(finder);
        }
        expect(calls, ['continue', 'new', 'settings']);
        final logo = tester.getRect(
          find.byKey(const ValueKey('game-title-logo')),
        );
        expect(logo.width, greaterThan(90));
        expect(logo.height, greaterThan(30));
        expect(logo.overlaps(rects.first), isFalse);
        expect(
          tester
              .getRect(find.byKey(const ValueKey('game-title-collection')))
              .bottom,
          lessThanOrEqualTo(safeRect.bottom),
        );
        if (size.width > size.height && size.height < 620) {
          expect(
            find.byKey(const ValueKey('game-title-landscape')),
            findsOneWidget,
          );
          expect(logo.right, lessThan(rects.first.left));
        }
      });
    }
  }

  testWidgets('first launch exposes new game and settings directly', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: title(calls, hasCheckpoint: false))),
    );
    expect(find.byKey(const ValueKey('game-continue')), findsNothing);
    expect(find.text('新しく始める'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-start')));
    await tester.tap(find.byKey(const ValueKey('game-title-settings')));
    expect(calls, ['new', 'settings']);
    expect(find.textContaining('上書き'), findsNothing);
  });
}

Widget title(
  List<String> calls, {
  bool hasCheckpoint = true,
  String saveStatus = '',
}) => HazardTitleScreen(
  hasCheckpoint: hasCheckpoint,
  collectedCount: 3,
  galleryCount: 20,
  saveStatus: saveStatus,
  onContinue: () => calls.add('continue'),
  onNewGame: () => calls.add('new'),
  onSettings: () => calls.add('settings'),
);
