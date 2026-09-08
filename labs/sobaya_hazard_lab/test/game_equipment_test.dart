import 'dart:ui' show SemanticsAction, Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_equipment.dart';

void main() {
  for (final size in [
    const Size(320, 568),
    const Size(402, 874),
    const Size(568, 320),
    const Size(874, 402),
  ]) {
    testWidgets('equipment and close fit the safe area at $size', (
      tester,
    ) async {
      final safe = size.width > size.height
          ? const EdgeInsets.fromLTRB(24, 0, 24, 21)
          : const EdgeInsets.fromLTRB(0, 44, 0, 34);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final selections = <String>[];
      var closes = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, padding: safe),
            child: Scaffold(
              body: equipment(
                onSelect: selections.add,
                onClose: () => closes++,
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final safeRect = Rect.fromLTRB(
        safe.left,
        safe.top,
        size.width - safe.right,
        size.height - safe.bottom,
      );
      final rects = <Rect>[];
      for (final id in ['handgun', 'shotgun', 'rocket', 'beer']) {
        final target = find.byKey(ValueKey('game-equip-$id'));
        final rect = tester.getRect(target);
        expect(rect.width, greaterThanOrEqualTo(48));
        expect(rect.height, greaterThanOrEqualTo(64));
        expect(safeRect.contains(rect.topLeft), isTrue);
        expect(safeRect.contains(rect.bottomRight), isTrue);
        expect(target.hitTestable(), findsOneWidget);
        expect(rects.any(rect.overlaps), isFalse);
        rects.add(rect);
        await tester.tap(target);
      }
      expect(selections, ['handgun', 'shotgun', 'rocket', 'beer']);
      expect(rects[0].top, rects[1].top);
      expect(rects[2].top, rects[3].top);
      expect(rects[0].left, rects[2].left);
      final close = find.byKey(const ValueKey('game-modal-close'));
      final closeRect = tester.getRect(close);
      expect(closeRect.width, greaterThanOrEqualTo(48));
      expect(closeRect.height, greaterThanOrEqualTo(48));
      expect(safeRect.contains(closeRect.topLeft), isTrue);
      expect(safeRect.contains(closeRect.bottomRight), isTrue);
      expect(rects.any(closeRect.overlaps), isFalse);
      await tester.tap(close);
      expect(closes, 1);
      expect(selections, hasLength(4));
    });
  }

  testWidgets('only owned guns appear and empty beer cannot be selected', (
    tester,
  ) async {
    final selected = <String>[];
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HazardQuickEquipment(
            currentWeapon: 'handgun',
            hasShotgun: false,
            hasRocket: false,
            beers: 0,
            pistolLoaded: 0,
            shotgunLoaded: 0,
            onSelect: selected.add,
            onClose: () {},
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('game-equip-shotgun')), findsNothing);
    expect(find.byKey(const ValueKey('game-equip-rocket')), findsNothing);
    expect(find.text('装填 0 / 10'), findsOneWidget);
    expect(find.text('0 杯・拾って補充'), findsOneWidget);
    final beer = find.byKey(const ValueKey('game-equip-beer'));
    expect(
      tester.getSemantics(beer).flagsCollection.isEnabled,
      Tristate.isFalse,
    );
    expect(
      tester
          .getSemantics(beer)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isFalse,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('game-equip-handgun')))
          .flagsCollection
          .isSelected,
      Tristate.isTrue,
    );
    expect(
      tester
          .getSemantics(find.byKey(const ValueKey('game-equip-handgun')))
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    await tester.tap(beer);
    expect(selected, isEmpty);
    await tester.tap(find.byKey(const ValueKey('game-equip-handgun')));
    expect(selected, ['handgun']);
    semantics.dispose();
  });

  testWidgets('large text can scroll while close remains accessible', (
    tester,
  ) async {
    const size = Size(568, 320);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var closes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            padding: EdgeInsets.fromLTRB(24, 0, 24, 21),
            textScaler: TextScaler.linear(2),
          ),
          child: Scaffold(body: equipment(onClose: () => closes++)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('game-equip-beer')),
      80,
      scrollable: find.byType(Scrollable),
    );
    expect(
      find.byKey(const ValueKey('game-equip-beer')).hitTestable(),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('game-modal-close')));
    expect(closes, 1);
    expect(tester.takeException(), isNull);
  });
}

HazardQuickEquipment equipment({
  ValueChanged<String>? onSelect,
  VoidCallback? onClose,
}) => HazardQuickEquipment(
  currentWeapon: 'shotgun',
  hasShotgun: true,
  hasRocket: true,
  beers: 3,
  pistolLoaded: 8,
  shotgunLoaded: 2,
  onSelect: onSelect ?? (_) {},
  onClose: onClose ?? () {},
);
