import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_controller.dart';
import 'game_state.dart';

HazardGameController? _game;
bool _registered = false;
void detachGameAutomation() {
  _game = null;
}

void attachGameAutomation(HazardGameController game) {
  if (!kDebugMode) return;
  _game = game;
  if (_registered) return;
  _registered = true;
  registerMarionetteExtension(
    name: 'madogiwa.inspectHazardGame',
    description: 'Inspect game combat, pickup, collection and chapter state.',
    callback: (_) async => _game?.state == null
        ? MarionetteExtensionResult.error(1, 'Not ready')
        : MarionetteExtensionResult.success({
            ..._game!.state!.inspect(),
            'frames': _game!.frames.toJson(),
            'motion': _game!.player.current,
            'clipWeights': _game!.player.clips.map(
              (n, c) => MapEntry(n, c.weight),
            ),
            'socket': _game!.player.node
                .getChildByName('GunSocket')
                ?.globalTransform
                .storage
                .toList(),
          }),
  );
  registerMarionetteExtension(
    name: 'madogiwa.openGameScenario',
    description: 'Debug deterministic scenario name=combat|pickup|collection|gate|stairs|death. Resets this run, keeps saved collection.',
    callback: (p) async {
      final g = _game;
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final name = p['name'];
      if (![
        'combat',
        'pickup',
        'collection',
        'gate',
        'stairs',
        'death',
      ].contains(name)) {
        return MarionetteExtensionResult.invalidParams('Invalid scenario');
      }
      g.restart();
      final s = g.state!;
      for (final e in s.enemies) {
        e.active = false;
      }
      switch (name) {
        case 'combat':
          s.x = 0;
          s.z = -16;
          s.yaw = 3.141592653589793;
          s.pitch = 0;
          s.aiming = true;
          s.enemies[0]
            ..active = true
            ..x = 0
            ..z = -11;
        case 'pickup':
          s.x = -8;
          s.z = -14.8;
        case 'collection':
          s.x = -8;
          s.z = -18.8;
        case 'gate':
          s.x = 11.5;
          s.z = 22;
          s.hasKey = true;
        case 'stairs':
          s.x = 11;
          s.z = -10;
          s.yaw = 3.141592653589793;
        case 'death':
          s.health = 10;
          s.x = 0;
          s.z = -16;
          s.enemies[0]
            ..active = true
            ..x = 0
            ..z = -15.1;
      }
      s.phase = PlayPhase.playing;
      return MarionetteExtensionResult.success(s.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.gameAction',
    description: 'Debug action=interact|reload|fireAtEnemy|step|aim|pause. step seconds=0..10 advances fixed 60 Hz game simulation.',
    callback: (p) async {
      final g = _game;
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final s = g.state!;
      switch (p['action']) {
        case 'interact':
          s.interact();
        case 'reload':
          s.reload();
        case 'aim':
          s.aiming = true;
        case 'pause':
          s.phase = PlayPhase.paused;
          s.stopInput();
        case 'fireAtEnemy':
          final e = s.enemies.where((e) => e.alive && e.active).firstOrNull;
          if (e == null) return MarionetteExtensionResult.error(2, 'No enemy');
          s.aiming = true;
          final o = vm.Vector3(s.x, s.y + 1.25, s.z);
          s.shoot(o, vm.Vector3(e.x, 1.1, e.z) - o);
        case 'fire':
          g.fire();
        case 'move':
          final dx = double.tryParse(p['x'] ?? '0') ?? 0,
              dz = double.tryParse(p['z'] ?? '1') ?? 1;
          final seconds = (double.tryParse(p['seconds'] ?? '1') ?? 1).clamp(
            0,
            10,
          );
          for (var i = 0; i < (seconds * 60).round(); i++) {
            s.move(dx, dz, 1 / 60);
          }
        case 'step':
          final seconds = double.tryParse(p['seconds'] ?? '1');
          if (seconds == null || seconds < 0 || seconds > 10) {
            return MarionetteExtensionResult.invalidParams('seconds=0..10');
          }
          for (var i = 0; i < (seconds * 60).round(); i++) {
            s.tick(1 / 60);
          }
        default:
          return MarionetteExtensionResult.invalidParams('Invalid action');
      }
      return MarionetteExtensionResult.success(s.inspect());
    },
  );
}
