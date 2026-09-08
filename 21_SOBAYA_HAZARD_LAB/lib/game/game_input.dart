import 'package:flutter/gestures.dart' show kSecondaryMouseButton;
import 'package:flutter/services.dart';

/// Keyboard movement shared by the game page and its input regression tests.
///
/// Deriving the current action from every held key makes modifier-first and
/// movement-first presses equivalent, including when either key is released.
class HazardMovementKeys {
  final _held = <LogicalKeyboardKey>{};

  void handle(KeyEvent event) {
    if (event is KeyUpEvent) {
      _held.remove(event.logicalKey);
    } else {
      _held.add(event.logicalKey);
    }
  }

  void clear() => _held.clear();

  bool _has(LogicalKeyboardKey first, LogicalKeyboardKey second) =>
      _held.contains(first) || _held.contains(second);

  double get x =>
      (_has(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) ? 1.0 : 0) -
      (_has(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft) ? 1.0 : 0);

  double get y =>
      (_has(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) ? 1.0 : 0) -
      (_has(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) ? 1.0 : 0);

  bool get sneaking =>
      _held.contains(LogicalKeyboardKey.keyZ) ||
      _has(LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.controlRight);

  bool get sprinting =>
      !sneaking &&
      _has(LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight);

  bool get interacting => _held.contains(LogicalKeyboardKey.keyE);
}

/// macOS reports Control-click as a secondary click. Keep it available for
/// camera dragging while using the compatibility Control sneak binding.
bool hazardMouseAims({
  required int buttons,
  required bool controlPressed,
  required TargetPlatform platform,
}) =>
    buttons & kSecondaryMouseButton != 0 &&
    !(platform == TargetPlatform.macOS && controlPressed);
