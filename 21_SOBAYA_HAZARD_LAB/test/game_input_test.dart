import 'package:flutter/gestures.dart'
    show kPrimaryMouseButton, kSecondaryMouseButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_input.dart';

void main() {
  for (final modifier in [
    LogicalKeyboardKey.keyZ,
    LogicalKeyboardKey.controlLeft,
    LogicalKeyboardKey.controlRight,
  ]) {
    for (final modifierFirst in [true, false]) {
      testWidgets(
        '${modifier.keyLabel} ${modifierFirst ? 'before' : 'after'} W sneaks immediately',
        (tester) async {
          final input = HazardMovementKeys();
          final focus = FocusNode();
          addTearDown(focus.dispose);
          await tester.pumpWidget(_inputHarness(input, focus));
          final first = modifierFirst ? modifier : LogicalKeyboardKey.keyW;
          final second = modifierFirst ? LogicalKeyboardKey.keyW : modifier;
          await tester.sendKeyDownEvent(first);
          await tester.sendKeyDownEvent(second);
          expect(input.y, 1);
          expect(input.x, 0);
          expect(input.sneaking, isTrue);
          expect(input.sprinting, isFalse);

          await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyW);
          expect(input.y, 1);
          expect(input.sneaking, isTrue);
          await tester.sendKeyUpEvent(modifier);
          expect(input.y, 1, reason: 'releasing sneak must keep walking');
          expect(input.sneaking, isFalse);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
          expect(input.y, 0);
        },
      );
    }
  }

  testWidgets('Z and arrow movement reach the game through a focused button', (
    tester,
  ) async {
    final input = HazardMovementKeys();
    final focus = FocusNode();
    final buttonFocus = FocusNode();
    addTearDown(focus.dispose);
    addTearDown(buttonFocus.dispose);
    await tester.pumpWidget(
      _inputHarness(input, focus, buttonFocus: buttonFocus),
    );
    buttonFocus.requestFocus();
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    for (final (key, x, y) in [
      (LogicalKeyboardKey.arrowUp, 0.0, 1.0),
      (LogicalKeyboardKey.arrowDown, 0.0, -1.0),
      (LogicalKeyboardKey.arrowLeft, -1.0, 0.0),
      (LogicalKeyboardKey.arrowRight, 1.0, 0.0),
    ]) {
      await tester.sendKeyDownEvent(key);
      await tester.pump();
      expect(input.x, x);
      expect(input.y, y);
      expect(input.sneaking, isTrue);
      expect(buttonFocus.hasPrimaryFocus, isTrue);
      await tester.sendKeyUpEvent(key);
      expect(input.x, 0);
      expect(input.y, 0);
      expect(input.sneaking, isTrue);
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
  });

  testWidgets('sneak overrides sprint and releasing it restores held sprint', (
    tester,
  ) async {
    final input = HazardMovementKeys();
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(_inputHarness(input, focus));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    expect(input.sprinting, isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
    expect(input.sprinting, isFalse);
    expect(input.sneaking, isTrue);
    expect(input.y, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
    expect(input.sprinting, isTrue);
    expect(input.y, 1);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(input.sprinting, isFalse);
  });

  testWidgets('losing game focus clears movement, modifiers, and interaction', (
    tester,
  ) async {
    final input = HazardMovementKeys();
    final focus = FocusNode();
    final outsideFocus = FocusNode();
    addTearDown(focus.dispose);
    addTearDown(outsideFocus.dispose);
    await tester.pumpWidget(
      _inputHarness(input, focus, outsideFocus: outsideFocus),
    );
    final pressed = [
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.controlRight,
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.keyE,
    ];
    for (final key in pressed) {
      await tester.sendKeyDownEvent(key);
    }
    expect(input.x, 1);
    expect(input.y, 1);
    expect(input.sneaking, isTrue);
    expect(input.interacting, isTrue);
    outsideFocus.requestFocus();
    await tester.pump();
    expect(input.x, 0);
    expect(input.y, 0);
    expect(input.sneaking, isFalse);
    expect(input.sprinting, isFalse);
    expect(input.interacting, isFalse);
    for (final key in pressed.reversed) {
      await tester.sendKeyUpEvent(key);
    }
    focus.requestFocus();
    await tester.pump();
    expect(
      input.y,
      0,
      reason: 'returning to the game must not retain movement',
    );
  });

  test(
    'only macOS Control secondary clicks are reserved for sneak dragging',
    () {
      for (final platform in TargetPlatform.values) {
        expect(
          hazardMouseAims(
            buttons: kSecondaryMouseButton,
            controlPressed: false,
            platform: platform,
          ),
          isTrue,
          reason: '$platform right click without Control must aim',
        );
        expect(
          hazardMouseAims(
            buttons: kSecondaryMouseButton,
            controlPressed: true,
            platform: platform,
          ),
          platform != TargetPlatform.macOS,
        );
        expect(
          hazardMouseAims(
            buttons: kPrimaryMouseButton,
            controlPressed: false,
            platform: platform,
          ),
          isFalse,
        );
      }
    },
  );
}

Widget _inputHarness(
  HazardMovementKeys input,
  FocusNode focus, {
  FocusNode? buttonFocus,
  FocusNode? outsideFocus,
}) => MaterialApp(
  theme: ThemeData(platform: TargetPlatform.macOS),
  home: Scaffold(
    body: Column(
      children: [
        Focus(
          focusNode: focus,
          autofocus: true,
          onKeyEvent: (_, event) {
            input.handle(event);
            return KeyEventResult.handled;
          },
          onFocusChange: (hasFocus) {
            if (!hasFocus) input.clear();
          },
          child: Column(
            children: [
              TextButton(
                focusNode: buttonFocus,
                onPressed: () {},
                child: const Text('Game action'),
              ),
              TextButton(onPressed: () {}, child: const Text('Other action')),
            ],
          ),
        ),
        TextButton(
          focusNode: outsideFocus,
          onPressed: () {},
          child: const Text('Outside game'),
        ),
      ],
    ),
  ),
);
