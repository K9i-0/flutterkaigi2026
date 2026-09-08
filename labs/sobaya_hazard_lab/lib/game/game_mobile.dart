import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind;
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

  void releaseMouse(int id) {
    if (mousePointer != id) return;
    mousePointer = null;
    if (mouseAiming) widget.onMouseAim?.call(false);
    mouseAiming = false;
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: const ValueKey('game-look-surface'),
    behavior: HitTestBehavior.opaque,
    onPointerDown: (event) {
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
      if (event.kind == PointerDeviceKind.mouse) {
        if (mousePointer == event.pointer) {
          (widget.onMouseLook ?? widget.onLook)(event.delta);
        }
        return;
      }
      if (pointer == event.pointer) widget.onLook(event.delta);
    },
    onPointerUp: (event) {
      if (event.kind == PointerDeviceKind.mouse) {
        releaseMouse(event.pointer);
        return;
      }
      if (pointer == event.pointer) pointer = null;
    },
    onPointerCancel: (event) {
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

  void update(Offset position) {
    final radius = widget.size * .33;
    final delta = position - Offset(widget.size / 2, widget.size / 2);
    final length = delta.distance;
    displacement = length > radius ? delta * (radius / length) : delta;
    final amount = ((length / radius - .14) / .86).clamp(0.0, 1.0);
    final value = length > 0 ? delta / length * amount : Offset.zero;
    widget.onMove(Offset(value.dx, -value.dy));
    setState(() {});
  }

  void release(int id) {
    if (id != pointer) return;
    pointer = null;
    displacement = Offset.zero;
    widget.onMove(Offset.zero);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '移動スティック。小さく倒すとゆっくり移動',
    child: Listener(
      key: const ValueKey('game-thumbstick'),
      behavior: HitTestBehavior.opaque,
      onPointerDown: (event) {
        if (pointer != null) return;
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

class HazardTouchButton extends StatelessWidget {
  const HazardTouchButton({
    super.key,
    required this.id,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.active = false,
    this.emphasized = false,
    this.enabled = true,
  });
  final String id, label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool active, emphasized, enabled;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: enabled,
    selected: active,
    label: label,
    child: GestureDetector(
      key: ValueKey('game-$id'),
      behavior: HitTestBehavior.opaque,
      onTap: enabled ? onPressed : null,
      child: Container(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xe3707850)
              : emphasized
              ? const Color(0xdd695335)
              : const Color(0xc018211b),
          border: Border.all(
            color: active || emphasized ? _gold : const Color(0x887a836d),
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Opacity(
          opacity: enabled ? 1 : .4,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _ivory, size: 20),
              const SizedBox(height: 1),
              Text(
                label,
                maxLines: 1,
                style: const TextStyle(color: _ivory, fontSize: 10),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class HazardTouchControls extends StatelessWidget {
  const HazardTouchControls({
    super.key,
    required this.onMove,
    required this.sneaking,
    required this.sprinting,
    required this.aiming,
    required this.onSneak,
    required this.onSprint,
    required this.onAim,
    required this.onFire,
    required this.onReload,
    required this.onInteract,
    required this.onHeal,
    required this.onWeapon,
    this.canInteract = false,
    this.stealthReady = false,
  });
  final ValueChanged<Offset> onMove;
  final bool sneaking, sprinting, aiming, canInteract, stealthReady;
  final VoidCallback onSneak,
      onSprint,
      onAim,
      onFire,
      onReload,
      onInteract,
      onHeal,
      onWeapon;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final landscape = constraints.maxWidth > 500;
      final actions = [
        HazardTouchButton(
          id: 'aim',
          label: '構え',
          icon: Icons.center_focus_strong,
          active: aiming,
          onPressed: onAim,
        ),
        HazardTouchButton(
          id: 'fire',
          label: '射撃',
          icon: Icons.flash_on,
          emphasized: true,
          onPressed: onFire,
        ),
        HazardTouchButton(
          id: 'reload',
          label: '装填',
          icon: Icons.sync,
          onPressed: onReload,
        ),
        HazardTouchButton(
          id: 'interact',
          label: stealthReady ? '破壊' : '調べる',
          icon: stealthReady ? Icons.sports_bar : Icons.touch_app_outlined,
          emphasized: stealthReady,
          enabled: canInteract,
          onPressed: onInteract,
        ),
        HazardTouchButton(
          id: 'heal',
          label: '回復',
          icon: Icons.healing,
          onPressed: onHeal,
        ),
        HazardTouchButton(
          id: 'weapon',
          label: '武器',
          icon: Icons.swap_horiz,
          onPressed: onWeapon,
        ),
      ];
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
        height: landscape ? 112 : 168,
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
              right: 0,
              bottom: 0,
              child: SizedBox(
                width: landscape ? 190 : 160,
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final action in actions)
                      SizedBox(
                        width: landscape ? 59.3 : 49.3,
                        height: 50,
                        child: action,
                      ),
                  ],
                ),
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
