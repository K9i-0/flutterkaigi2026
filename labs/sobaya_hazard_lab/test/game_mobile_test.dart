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
    for (final mode in ['explore', 'interact', 'shoot', 'throw']) {
      testWidgets('$mode targets fit safe area at $size', (tester) async {
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
                      child: controls(
                        aiming: mode == 'shoot' || mode == 'throw',
                        throwingBeer: mode == 'throw',
                        canInteract: mode == 'interact',
                      ),
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
        for (final id in ['evade', 'kick', 'heal']) {
          expect(find.byKey(ValueKey('game-$id')), findsNothing);
        }
        final visibleIds = [
          'aim',
          if (mode == 'shoot' || mode == 'throw') 'fire',
          if (mode == 'shoot') 'reload',
          if (mode == 'interact') 'interact',
          'weapon',
          'sneak',
          'sprint',
        ];
        for (final id in ['fire', 'reload', 'interact']) {
          if (!visibleIds.contains(id)) {
            expect(find.byKey(ValueKey('game-$id')), findsNothing);
          }
        }
        final rects = <Rect>[];
        for (final id in visibleIds) {
          final rect = tester.getRect(find.byKey(ValueKey('game-$id')));
          final minimum = id == 'fire' || id == 'interact' ? 64 : 48;
          expect(rect.width, greaterThanOrEqualTo(minimum), reason: id);
          expect(rect.height, greaterThanOrEqualTo(minimum), reason: id);
          expect(safeRect.contains(rect.topLeft), isTrue, reason: '$id top');
          expect(
            rect.right,
            lessThanOrEqualTo(safeRect.right + .01),
            reason: id,
          );
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
  }

  testWidgets('aim and main action keep their positions across all modes', (
    tester,
  ) async {
    Future<void> show({required bool aiming, bool throwingBeer = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: controls(aiming: aiming, throwingBeer: throwingBeer),
            ),
          ),
        ),
      );
    }

    await show(aiming: false);
    final aim = tester.getRect(find.byKey(const ValueKey('game-aim')));
    final mainAction = tester.getRect(
      find.byKey(const ValueKey('game-interact')),
    );
    final equipment = tester.getRect(find.byKey(const ValueKey('game-weapon')));
    expect(find.text('構える'), findsOneWidget);
    expect(find.text('破壊'), findsOneWidget);
    await show(aiming: true);
    expect(tester.getRect(find.byKey(const ValueKey('game-aim'))), aim);
    expect(tester.getRect(find.byKey(const ValueKey('game-fire'))), mainAction);
    expect(
      tester.getRect(find.byKey(const ValueKey('game-weapon'))),
      equipment,
    );
    expect(find.text('戻す'), findsOneWidget);
    expect(find.text('撃つ'), findsOneWidget);
    expect(find.text('6 / 24  装填'), findsOneWidget);
    await show(aiming: true, throwingBeer: true);
    expect(tester.getRect(find.byKey(const ValueKey('game-aim'))), aim);
    expect(tester.getRect(find.byKey(const ValueKey('game-fire'))), mainAction);
    expect(find.text('投げる'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-reload')), findsNothing);
  });

  testWidgets('changing mode beneath a held interaction cannot shoot', (
    tester,
  ) async {
    var shots = 0, interactions = 0;
    Future<void> show(bool aiming) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: controls(
              aiming: aiming,
              onFire: () => shots++,
              onInteract: () => interactions++,
            ),
          ),
        ),
      );
    }

    await show(false);
    final press = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('game-interact'))),
    );
    await show(true);
    await press.up();
    expect(shots, 0);
    expect(interactions, 0);
    await tester.tap(find.byKey(const ValueKey('game-fire')));
    expect(shots, 1);
  });

  testWidgets('weapon swaps and lower-raise cancel an already held shot', (
    tester,
  ) async {
    var shots = 0;
    Future<void> show({
      bool aiming = true,
      bool throwingBeer = false,
      String weaponLabel = 'ハンドガン',
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: controls(
              aiming: aiming,
              throwingBeer: throwingBeer,
              weaponLabel: weaponLabel,
              onFire: () => shots++,
            ),
          ),
        ),
      );
    }

    await show();
    final swap = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('game-fire'))),
    );
    await show(weaponLabel: 'ショットガン');
    await swap.up();
    expect(shots, 0);
    final beer = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('game-fire'))),
    );
    await show(throwingBeer: true, weaponLabel: 'ビール');
    await beer.up();
    expect(shots, 0);
    final mode = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('game-fire'))),
    );
    await show(aiming: false);
    await show();
    await mode.up();
    expect(shots, 0);
    await tester.tap(find.byKey(const ValueKey('game-fire')));
    expect(shots, 1);
  });

  testWidgets('button keeps its original callback through an ordinary tick', (
    tester,
  ) async {
    var first = 0, replacement = 0;
    Future<void> show(VoidCallback onPressed, {bool enabled = true}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(
            child: HazardTouchButton(
              id: 'test',
              label: '実行',
              icon: Icons.touch_app,
              onPressed: onPressed,
              enabled: enabled,
            ),
          ),
        ),
      );
    }

    await show(() => first++);
    final press = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('game-test'))),
    );
    await show(() => replacement++);
    await press.up();
    expect(first, 1);
    expect(replacement, 0);
    final disabled = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('game-test'))),
    );
    await show(() => replacement++, enabled: false);
    await show(() => replacement++);
    await disabled.up();
    expect(replacement, 0);
  });

  testWidgets('dragging out of an action or canceling never activates it', (
    tester,
  ) async {
    var shots = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: controls(aiming: true, onFire: () => shots++)),
      ),
    );
    final center = tester.getCenter(find.byKey(const ValueKey('game-fire')));
    final drag = await tester.startGesture(center);
    await drag.moveBy(const Offset(30, 0));
    await drag.moveTo(center);
    await drag.up();
    final canceled = await tester.startGesture(center);
    await canceled.cancel();
    expect(shots, 0);
    final rightClick = await tester.startGesture(
      center,
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await rightClick.up();
    expect(shots, 0);
    await tester.tap(find.byKey(const ValueKey('game-fire')));
    expect(shots, 1);
  });

  testWidgets(
    'reload stays available manually and respects its enabled state',
    (tester) async {
      var reloads = 0;
      Future<void> show(bool canReload) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: controls(
                aiming: true,
                canReload: canReload,
                onReload: () => reloads++,
              ),
            ),
          ),
        );
      }

      await show(true);
      await tester.tap(find.byKey(const ValueKey('game-reload')));
      expect(reloads, 1);
      await show(false);
      expect(find.byKey(const ValueKey('game-reload')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('game-reload')));
      expect(reloads, 1);
    },
  );

  testWidgets('equipment keeps beer counts visible and rocket has no reload', (
    tester,
  ) async {
    for (final aiming in [false, true]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: controls(
              aiming: aiming,
              throwingBeer: true,
              weaponLabel: 'ビール',
              ammoLabel: '3',
            ),
          ),
        ),
      );
      expect(find.text('ビール\n3 ▾'), findsOneWidget);
      expect(find.byKey(const ValueKey('game-reload')), findsNothing);
    }
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: controls(
            aiming: true,
            weaponLabel: 'ロケットランチャー',
            ammoLabel: '∞',
            showReload: false,
          ),
        ),
      ),
    );
    expect(find.text('ロケットランチャー\n∞ ▾'), findsOneWidget);
    expect(find.byKey(const ValueKey('game-reload')), findsNothing);
    expect(find.byKey(const ValueKey('game-fire')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

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
                  aiming: true,
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

  testWidgets(
    'removing a held stick stops callbacks from the old pointer stream',
    (tester) async {
      final moves = <Offset>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: HazardThumbstick(onMove: moves.add)),
        ),
      );
      final hold = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('game-thumbstick'))),
      );
      await hold.moveBy(const Offset(0, -40));
      expect(moves.last, const Offset(0, 1));
      await tester.pumpWidget(const MaterialApp(home: Text('装備')));
      final beforeRemoval = List<Offset>.of(moves);
      await hold.moveBy(const Offset(30, 0));
      await hold.up();
      expect(tester.takeException(), isNull);
      expect(moves, beforeRemoval);

      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: HazardThumbstick(onMove: moves.add)),
        ),
      );
      final next = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('game-thumbstick'))),
      );
      await next.moveBy(const Offset(-40, 0));
      expect(moves.last, const Offset(-1, 0));
      await next.cancel();
      expect(moves.last, Offset.zero);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'removing the look surface ignores held touch and mouse callbacks',
    (tester) async {
      final touchLooks = <Offset>[], mouseLooks = <Offset>[];
      final aims = <bool>[];
      await tester.pumpWidget(
        MaterialApp(
          home: HazardTouchLookSurface(
            onLook: touchLooks.add,
            onMouseLook: mouseLooks.add,
            onMouseAim: aims.add,
          ),
        ),
      );
      final touch = await tester.startGesture(
        const Offset(200, 120),
        pointer: 31,
      );
      final mouse = await tester.startGesture(
        const Offset(240, 120),
        pointer: 32,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await touch.moveBy(const Offset(5, 3));
      await mouse.moveBy(const Offset(4, -2));
      expect(touchLooks, [const Offset(5, 3)]);
      expect(mouseLooks, [const Offset(4, -2)]);
      expect(aims, [true]);
      await tester.pumpWidget(const MaterialApp(home: Text('装備')));
      await touch.moveBy(const Offset(8, 2));
      await mouse.moveBy(const Offset(9, 4));
      await touch.up();
      await mouse.up();
      expect(tester.takeException(), isNull);
      expect(touchLooks, [const Offset(5, 3)]);
      expect(mouseLooks, [const Offset(4, -2)]);
      expect(aims, [true]);
    },
  );

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
  VoidCallback? onReload,
  VoidCallback? onInteract,
  bool aiming = false,
  bool throwingBeer = false,
  bool canInteract = true,
  bool canReload = true,
  bool showReload = true,
  String ammoLabel = '6 / 24',
  String weaponLabel = 'ハンドガン',
}) => HazardTouchControls(
  onMove: onMove ?? (_) {},
  sneaking: false,
  sprinting: false,
  aiming: aiming,
  weaponLabel: weaponLabel,
  ammoLabel: ammoLabel,
  throwingBeer: throwingBeer,
  canInteract: canInteract,
  canReload: canReload,
  showReload: showReload,
  stealthReady: true,
  onSneak: () {},
  onSprint: () {},
  onAim: () {},
  onFire: onFire ?? () {},
  onReload: onReload ?? () {},
  onInteract: onInteract ?? () {},
  onWeapon: () {},
);
