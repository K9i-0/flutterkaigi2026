import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kSecondaryMouseButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_mobile.dart';
import 'package:sobaya_hazard_lab/game/game_settings.dart';

void main() {
  testWidgets('Mac control-drag looks without entering aim on the overlay', (
    tester,
  ) async {
    final aims = <bool>[], looks = <Offset>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HazardTouchLookSurface(onLook: looks.add, onMouseAim: aims.add),
        ),
      ),
    );
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    final mouse = await tester.startGesture(
      const Offset(200, 120),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await mouse.moveBy(const Offset(12, 8));
    expect(looks, [const Offset(12, 8)]);
    expect(aims, isEmpty);
    await mouse.up();
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    final right = await tester.startGesture(
      const Offset(200, 120),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    expect(aims, [true]);
    await right.up();
    expect(aims, [true, false]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets(
    'mouse secondary aim and normal look remain independent from touch look',
    (tester) async {
      final touchLooks = <Offset>[];
      final mouseLooks = <Offset>[];
      final aiming = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HazardTouchLookSurface(
              onLook: (delta) => touchLooks.add(delta * 2),
              onMouseLook: mouseLooks.add,
              onMouseAim: aiming.add,
            ),
          ),
        ),
      );
      final touch = await tester.startGesture(
        const Offset(120, 120),
        pointer: 20,
      );
      final mouse = await tester.startGesture(
        const Offset(240, 120),
        pointer: 21,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      expect(aiming, [true]);
      await mouse.moveBy(const Offset(12, -4));
      expect(mouseLooks, [const Offset(12, -4)]);
      expect(touchLooks, isEmpty);
      await touch.moveBy(const Offset(3, 5));
      expect(touchLooks, [const Offset(6, 10)]);
      await mouse.up();
      expect(aiming, [true, false]);
      await touch.moveBy(const Offset(-2, 1));
      expect(touchLooks.last, const Offset(-4, 2));
      await touch.up();

      final canceled = await tester.startGesture(
        const Offset(240, 120),
        pointer: 22,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await canceled.cancel();
      expect(aiming, [true, false, true, false]);
    },
  );

  const sizes = [
    Size(320, 568),
    Size(390, 844),
    Size(568, 320),
    Size(844, 390),
  ];
  for (final size in sizes) {
    testWidgets('touch targets fit safe area at $size', (tester) async {
      final safe = size.width > size.height
          ? const EdgeInsets.fromLTRB(24, 0, 24, 21)
          : const EdgeInsets.fromLTRB(0, 44, 0, 34);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size, padding: safe),
            child: Scaffold(
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: controls(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final safeRect = Rect.fromLTRB(
        safe.left + 12,
        safe.top + 12,
        size.width - safe.right - 12,
        size.height - safe.bottom - 12,
      );
      expect(find.byKey(const ValueKey('game-evade')), findsNothing);
      expect(find.byKey(const ValueKey('game-kick')), findsNothing);
      final rects = <Rect>[];
      for (final id in [
        'aim',
        'fire',
        'reload',
        'interact',
        'heal',
        'weapon',
        'sneak',
        'sprint',
      ]) {
        final rect = tester.getRect(find.byKey(ValueKey('game-$id')));
        expect(rect.width, greaterThanOrEqualTo(48), reason: id);
        expect(rect.height, greaterThanOrEqualTo(48), reason: id);
        expect(safeRect.contains(rect.topLeft), isTrue, reason: '$id top');
        expect(rect.right, lessThanOrEqualTo(safeRect.right + .01), reason: id);
        expect(
          rect.bottom,
          lessThanOrEqualTo(safeRect.bottom + .01),
          reason: id,
        );
        for (final previous in rects) {
          expect(
            rect.overlaps(previous),
            isFalse,
            reason: '$id overlaps a control',
          );
        }
        rects.add(rect);
      }
      final stick = tester.getRect(
        find.byKey(const ValueKey('game-thumbstick')),
      );
      expect(rects.any((rect) => rect.overlaps(stick)), isFalse);
    });
  }

  testWidgets('three fingers can move, look and shoot independently', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var movement = Offset.zero;
    final looks = <Offset>[];
    var shots = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              Positioned.fill(
                left: 170,
                child: HazardTouchLookSurface(onLook: looks.add),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: controls(
                  onMove: (value) => movement = value,
                  onFire: () => shots++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final stickCenter = tester.getCenter(
      find.byKey(const ValueKey('game-thumbstick')),
    );
    final move = await tester.startGesture(stickCenter, pointer: 1);
    await move.moveBy(const Offset(20, -30));
    expect(movement.dx, greaterThan(0));
    expect(movement.dy, greaterThan(.5));
    expect(movement.distance, lessThanOrEqualTo(1));
    expect(looks, isEmpty);
    final look = await tester.startGesture(const Offset(280, 380), pointer: 2);
    await look.moveBy(const Offset(16, -9));
    expect(looks.single, const Offset(16, -9));
    final beforeShot = movement;
    final fire = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('game-fire'))),
      pointer: 3,
    );
    await fire.up();
    await tester.pump();
    expect(shots, 1);
    expect(movement, beforeShot);
    expect(looks.length, 1);
    await move.up();
    expect(movement, Offset.zero);
    await look.moveBy(const Offset(-8, 4));
    expect(looks.last, const Offset(-8, 4));
    await look.cancel();
  });

  testWidgets('stick ignores second pointer and resets when owner cancels', (
    tester,
  ) async {
    var movement = Offset.zero;
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: HazardThumbstick(onMove: (value) => movement = value),
        ),
      ),
    );
    final center = tester.getCenter(
      find.byKey(const ValueKey('game-thumbstick')),
    );
    final first = await tester.startGesture(center, pointer: 4);
    await first.moveBy(const Offset(0, -50));
    expect(movement, const Offset(0, 1));
    final second = await tester.startGesture(center, pointer: 5);
    await second.moveBy(const Offset(-40, 0));
    await second.up();
    expect(movement, const Offset(0, 1));
    await first.cancel();
    expect(movement, Offset.zero);
  });

  testWidgets('short landscape panel keeps close and final action reachable', (
    tester,
  ) async {
    const size = Size(568, 320);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: size,
            padding: EdgeInsets.fromLTRB(24, 0, 24, 21),
          ),
          child: Scaffold(
            body: HazardAdaptivePanel(
              heading: 'SETTINGS',
              onClose: () => closed = true,
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < 20; i++) Text('設定項目 $i'),
                    TextButton(
                      key: const ValueKey('last'),
                      onPressed: () {},
                      child: const Text('戻る'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('last')),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(find.byKey(const ValueKey('last')).hitTestable(), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('game-modal-close')));
    expect(closed, isTrue);
  });

  test(
    'touch preferences round trip and damaged values keep usable bounds',
    () {
      final options = HazardSettings(
        touchControls: true,
        touchSensitivity: 1.7,
      );
      final restored = HazardSettings.decode(options.encode());
      expect(restored.touchControls, isTrue);
      expect(restored.touchSensitivity, 1.7);
      expect(
        HazardSettings.decode('{"touchSensitivity":100}').touchSensitivity,
        2,
      );
      expect(
        HazardSettings.decode('{"touchSensitivity":"broken"}').touchSensitivity,
        1,
      );
      expect(HazardSettings.decode('{}').touchControls, isFalse);
    },
  );
}

HazardTouchControls controls({
  ValueChanged<Offset>? onMove,
  VoidCallback? onFire,
}) => HazardTouchControls(
  onMove: onMove ?? (_) {},
  sneaking: false,
  sprinting: false,
  aiming: false,
  canInteract: true,
  stealthReady: true,
  onSneak: () {},
  onSprint: () {},
  onAim: () {},
  onFire: onFire ?? () {},
  onReload: () {},
  onInteract: () {},
  onHeal: () {},
  onWeapon: () {},
);
