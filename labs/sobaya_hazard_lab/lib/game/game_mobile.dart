import 'dart:math' as math;

import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kPrimaryButton, kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart' show HardwareKeyboard;

import 'game_input.dart';

const _ivory = Color(0xffe6dec6), _gold = Color(0xffc8b077);

/// A pointer belongs to the surface on which it started, so movement, looking,
/// and action presses can run together without joining a drag gesture arena.
class HazardTouchLookSurface extends StatefulWidget {
  const HazardTouchLookSurface({
    super.key,
    required this.onLook,
    this.onStart,
    this.onMouseLook,
    this.onMouseAim,
  });
  final ValueChanged<Offset> onLook;
  final VoidCallback? onStart;
  final ValueChanged<Offset>? onMouseLook;
  final ValueChanged<bool>? onMouseAim;
  @override
  State<HazardTouchLookSurface> createState() => _HazardTouchLookSurfaceState();
}

class _HazardTouchLookSurfaceState extends State<HazardTouchLookSurface> {
  int? pointer;
  int? mousePointer;
  bool mouseAiming = false;

  @override
  void dispose() {
    pointer = null;
    mousePointer = null;
    mouseAiming = false;
    super.dispose();
  }

  void releaseMouse(int id) {
    if (!mounted || mousePointer != id) return;
    mousePointer = null;
    if (mouseAiming) widget.onMouseAim?.call(false);
    mouseAiming = false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: const ValueKey('game-look-surface'),
    behavior: HitTestBehavior.opaque,
    onPointerDown: (event) {
      if (!mounted) return;
      if (event.kind == PointerDeviceKind.mouse) {
        mousePointer = event.pointer;
        widget.onStart?.call();
        if (hazardMouseAims(
          buttons: event.buttons,
          controlPressed: HardwareKeyboard.instance.isControlPressed,
          platform: defaultTargetPlatform,
        )) {
          mouseAiming = true;
          widget.onMouseAim?.call(true);
        }
        return;
      }
      if (pointer != null) return;
      pointer = event.pointer;
      widget.onStart?.call();
    },
    onPointerMove: (event) {
      if (!mounted) return;
      if (event.kind == PointerDeviceKind.mouse) {
        if (mousePointer == event.pointer) {
          (widget.onMouseLook ?? widget.onLook)(event.delta);
        }
        return;
      }
      if (pointer == event.pointer) widget.onLook(event.delta);
    },
    onPointerUp: (event) {
      if (!mounted) return;
      if (event.kind == PointerDeviceKind.mouse) {
        releaseMouse(event.pointer);
        return;
      }
      if (pointer == event.pointer) pointer = null;
    },
    onPointerCancel: (event) {
      if (!mounted) return;
      if (event.kind == PointerDeviceKind.mouse) {
        releaseMouse(event.pointer);
        return;
      }
      if (pointer == event.pointer) pointer = null;
    },
    child: const SizedBox.expand(),
  );
}

/// Fixed-origin analog thumb stick. The dead zone avoids accidental steps, and
/// normalized output caps diagonal speed without turning tiny drags into runs.
class HazardThumbstick extends StatefulWidget {
  const HazardThumbstick({super.key, required this.onMove, this.size = 112});
  final ValueChanged<Offset> onMove;
  final double size;
  @override
  State<HazardThumbstick> createState() => _HazardThumbstickState();
}

class _HazardThumbstickState extends State<HazardThumbstick> {
  int? pointer;
  Offset displacement = Offset.zero;

  @override
  void dispose() {
    pointer = null;
    displacement = Offset.zero;
    super.dispose();
  }

  void update(Offset position) {
    if (!mounted) return;
    final radius = widget.size * .33;
    final delta = position - Offset(widget.size / 2, widget.size / 2);
    final length = delta.distance;
    displacement = length > radius ? delta * (radius / length) : delta;
    final amount = ((length / radius - .14) / .86).clamp(0.0, 1.0);
    final value = length > 0 ? delta / length * amount : Offset.zero;
    widget.onMove(Offset(value.dx, -value.dy));
    if (mounted) setState(() {});
  }

  void release(int id) {
    if (!mounted || id != pointer) return;
    pointer = null;
    displacement = Offset.zero;
    widget.onMove(Offset.zero);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '移動スティック。小さく倒すとゆっくり移動',
    child: Listener(
      key: const ValueKey('game-thumbstick'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (!mounted || pointer != null) return;
        pointer = event.pointer;
        update(event.localPosition);
      },
      onPointerMove: (event) {
        if (event.pointer == pointer) update(event.localPosition);
      },
      onPointerUp: (event) => release(event.pointer),
      onPointerCancel: (event) => release(event.pointer),
      child: SizedBox.square(
        dimension: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x70171d17),
                border: Border.all(color: const Color(0x88939c86)),
              ),
              child: const Center(
                child: Icon(Icons.add, color: Color(0x668d9a7c), size: 58),
              ),
            ),
            Transform.translate(
              offset: displacement,
              child: Container(
                width: widget.size * .4,
                height: widget.size * .4,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: pointer == null ? const Color(0xaad1ceb2) : _gold,
                  border: Border.all(color: _ivory),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Keep a press attached to the action that was visible when the finger landed.
/// New closures are common during a game tick; only semantic action changes
/// cancel the press, and an unchanged action invokes its captured callback.
class HazardTouchButton extends StatefulWidget {
  const HazardTouchButton({
    super.key,
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.emphasized = false,
    this.enabled = true,
    this.actionIdentity,
    this.horizontal = false,
    this.maxLabelLines = 1,
  });
  final String id, label;
  final int maxLabelLines;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active, emphasized, enabled, horizontal;
  final Object? actionIdentity;

  @override
  State<HazardTouchButton> createState() => _HazardTouchButtonState();
}

class _HazardTouchButtonState extends State<HazardTouchButton> {
  int? pointer;
  Offset? origin;
  VoidCallback? pendingAction;

  @override
  void didUpdateWidget(covariant HazardTouchButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.actionIdentity != widget.actionIdentity ||
        oldWidget.active != widget.active ||
        !widget.enabled) {
      pendingAction = null;
    }
  }

  @override
  void dispose() {
    pointer = null;
    pendingAction = null;
    super.dispose();
  }

  void release(PointerEvent event, {bool canceled = false}) {
    if (event.pointer != pointer) return;
    final action = pendingAction;
    pointer = null;
    origin = null;
    pendingAction = null;
    final box = context.findRenderObject() as RenderBox?;
    if (!canceled &&
        widget.enabled &&
        box != null &&
        (Offset.zero & box.size).contains(event.localPosition)) {
      action?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final icon = Icon(widget.icon, color: _ivory, size: 20);
    final label = Text(
      widget.label,
      maxLines: widget.maxLabelLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: _ivory,
        fontSize: widget.maxLabelLines > 1 ? 10 : (widget.horizontal ? 11 : 10),
      ),
    );
    return Semantics(
      button: true,
      enabled: widget.enabled,
      selected: widget.active,
      label: widget.label,
      onTap: widget.enabled ? widget.onPressed : null,
      excludeSemantics: true,
      child: Listener(
        key: ValueKey('game-${widget.id}'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (event) {
          if (!widget.enabled || pointer != null) return;
          if (event.kind == PointerDeviceKind.mouse &&
              event.buttons & kPrimaryButton == 0) {
            return;
          }
          pointer = event.pointer;
          origin = event.position;
          pendingAction = widget.onPressed;
        },
        onPointerMove: (event) {
          if (event.pointer == pointer &&
              origin != null &&
              (event.position - origin!).distance > kTouchSlop) {
            pendingAction = null;
          }
        },
        onPointerUp: release,
        onPointerCancel: (event) => release(event, canceled: true),
        child: Container(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          padding: EdgeInsets.symmetric(horizontal: widget.horizontal ? 8 : 3),
          decoration: BoxDecoration(
            color: widget.active
                ? const Color(0xe3707850)
                : widget.emphasized
                ? const Color(0xdd695335)
                : const Color(0xc018211b),
            border: Border.all(
              color: widget.active || widget.emphasized
                  ? _gold
                  : const Color(0x887a836d),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Opacity(
            opacity: widget.enabled ? 1 : .4,
            child: widget.horizontal
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      icon,
                      const SizedBox(width: 6),
                      Flexible(child: label),
                    ],
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [icon, const SizedBox(height: 1), label],
                  ),
          ),
        ),
      ),
    );
  }
}

class HazardTouchControls extends StatelessWidget {
  static double heightFor({required double width, required bool landscape}) =>
      landscape && width >= 480 ? 128 : 186;

  const HazardTouchControls({
    super.key,
    required this.onMove,
    required this.sneaking,
    required this.sprinting,
    required this.aiming,
    required this.weaponLabel,
    required this.ammoLabel,
    required this.onSneak,
    required this.onSprint,
    required this.onAim,
    required this.onFire,
    required this.onReload,
    required this.onInteract,
    required this.onWeapon,
    this.canInteract = false,
    this.canReload = true,
    this.showReload = true,
    this.stealthReady = false,
    this.throwingBeer = false,
  });
  final ValueChanged<Offset> onMove;
  final bool sneaking, sprinting, aiming, canInteract, stealthReady;
  final bool throwingBeer, canReload, showReload;
  final String weaponLabel, ammoLabel;
  final VoidCallback onSneak,
      onSprint,
      onAim,
      onFire,
      onReload,
      onInteract,
      onWeapon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final height = heightFor(
        width: constraints.maxWidth,
        landscape: MediaQuery.orientationOf(context) == Orientation.landscape,
      );
      final landscape = height == 128;
      // Both slots stay fixed when the available actions change. In particular,
      // revealing fire never moves it underneath the finger pressing aim.
      final actionIdentity = (aiming, throwingBeer, weaponLabel);
      final modes = [
        HazardTouchButton(
          id: 'sneak',
          label: '忍び足',
          icon: Icons.visibility_off,
          active: sneaking,
          onPressed: onSneak,
        ),
        HazardTouchButton(
          id: 'sprint',
          label: '走る',
          icon: Icons.directions_run,
          active: sprinting,
          onPressed: onSprint,
        ),
      ];
      return SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              bottom: 0,
              child: HazardThumbstick(
                size: landscape ? 104 : 112,
                onMove: onMove,
              ),
            ),
            if (landscape)
              Positioned(
                left: 114,
                bottom: 0,
                child: SizedBox(
                  width: 50,
                  child: Column(
                    children: [modes[0], const SizedBox(height: 6), modes[1]],
                  ),
                ),
              )
            else
              Positioned(
                left: 0,
                bottom: 120,
                child: SizedBox(
                  width: 112,
                  child: Row(
                    children: [
                      Expanded(child: modes[0]),
                      const SizedBox(width: 6),
                      Expanded(child: modes[1]),
                    ],
                  ),
                ),
              ),
            Positioned(
              right: 80,
              bottom: landscape ? 0 : 58,
              width: 56,
              height: 56,
              child: HazardTouchButton(
                key: const ValueKey('mobile-aim-action'),
                id: 'aim',
                label: aiming ? '戻す' : '構える',
                icon: aiming
                    ? Icons.keyboard_arrow_down
                    : Icons.center_focus_strong,
                active: aiming,
                actionIdentity: actionIdentity,
                onPressed: onAim,
              ),
            ),
            if (aiming)
              Positioned(
                key: const ValueKey('mobile-fire-slot'),
                right: 0,
                bottom: landscape ? 0 : 58,
                width: 72,
                height: 72,
                child: HazardTouchButton(
                  id: 'fire',
                  label: throwingBeer ? '投げる' : '撃つ',
                  icon: throwingBeer ? Icons.sports_bar : Icons.flash_on,
                  emphasized: true,
                  actionIdentity: actionIdentity,
                  onPressed: onFire,
                ),
              )
            else if (canInteract)
              Positioned(
                key: const ValueKey('mobile-interact-slot'),
                right: 0,
                bottom: landscape ? 0 : 58,
                width: 72,
                height: 72,
                child: HazardTouchButton(
                  id: 'interact',
                  label: stealthReady ? '破壊' : '調べる',
                  icon: stealthReady
                      ? Icons.sports_bar
                      : Icons.touch_app_outlined,
                  emphasized: stealthReady,
                  actionIdentity: (actionIdentity, stealthReady),
                  onPressed: onInteract,
                ),
              ),
            if (aiming && !throwingBeer && showReload)
              Positioned(
                key: const ValueKey('mobile-reload-slot'),
                right: 0,
                bottom: landscape ? 80 : 138,
                width: 136,
                height: 48,
                child: HazardTouchButton(
                  id: 'reload',
                  label: '$ammoLabel  装填',
                  icon: Icons.sync,
                  horizontal: true,
                  enabled: canReload,
                  actionIdentity: actionIdentity,
                  onPressed: onReload,
                ),
              ),
            Positioned(
              right: landscape ? (constraints.maxWidth - 136) / 2 : 0,
              bottom: 0,
              width: 136,
              height: 48,
              child: HazardTouchButton(
                key: const ValueKey('mobile-weapon-action'),
                id: 'weapon',
                label: '$weaponLabel\n$ammoLabel ▾',
                maxLabelLines: 2,
                icon: throwingBeer ? Icons.sports_bar : Icons.swap_horiz,
                horizontal: true,
                actionIdentity: actionIdentity,
                onPressed: onWeapon,
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Menus remain readable at phone widths, with scrolling available on short
/// landscape screens and room reserved for display cutouts and home indicators.
class HazardAdaptivePanel extends StatelessWidget {
  const HazardAdaptivePanel({
    super.key,
    required this.heading,
    required this.body,
    required this.onClose,
    this.width = 850,
  });
  final String heading;
  final Widget body;
  final VoidCallback onClose;
  final double width;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: const Color(0xe810130f),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth < 700 || constraints.maxHeight < 500;
          return Center(
            child: Container(
              width: math.min(width, constraints.maxWidth),
              margin: EdgeInsets.all(compact ? 10 : 30),
              padding: EdgeInsets.all(compact ? 14 : 26),
              decoration: BoxDecoration(
                color: const Color(0xf0181b17),
                border: Border.all(color: const Color(0xff60654f)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          heading,
                          style: TextStyle(
                            color: _ivory,
                            fontSize: compact ? 18 : 24,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey('game-modal-close'),
                        onPressed: onClose,
                        icon: const Icon(Icons.close, color: _ivory),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xff484e3d)),
                  Flexible(child: body),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );
}
