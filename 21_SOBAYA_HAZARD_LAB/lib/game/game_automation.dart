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
            'settings': _game!.settings.encode(),
            'event': _game!.director == null
                ? null
                : {
                    'id': _game!.director!.id,
                    'shot': _game!.director!.index,
                    'elapsed': _game!.director!.elapsed,
                    'paused': _game!.director!.paused,
                  },
            'seenEvents': _game!.state!.seenEvents.toList(),
            'motion': _game!.player.current,
            'checkpoint': {
              'exists': _game!.hasCheckpoint,
              'saving': _game!.saving,
              'status': _game!.saveStatus,
            },
            'enemyMugGripErrors': [
              for (var i = 0; i < _game!.enemyMugs.length; i++)
                (_game!.enemyMugs[i]
                            .getChildByName('Grip')!
                            .globalTransform
                            .getTranslation() -
                        _game!.enemies[i].node
                            .getChildByName('PropSocket.R')!
                            .globalTransform
                            .getTranslation())
                    .length,
            ],
            'npcMotions': _game!.npcs.map(
              (id, actor) => MapEntry(id, actor.current),
            ),
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
    description: 'Debug scenario name=combat|stagger|npc|merchant|pickup|collection|gate|stairs|death. Resets run, keeps collection.',
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
        'npc',
        'stagger',
        'merchant',
        'farm',
        'mountain',
        'farmGate',
        'mountainGate',
        'introEvent',
        'farmEvent',
        'bossEvent',
        'endingEvent',
      ].contains(name)) {
        return MarionetteExtensionResult.invalidParams('Invalid scenario');
      }
      g.restart();
      if ([
        'farm',
        'farmGate',
        'mountain',
        'mountainGate',
        'farmEvent',
        'bossEvent',
        'endingEvent',
      ].contains(name)) {
        final first = g.state!;
        first.hasKey = first.gateOpen = true;
        first.exitRequested = Map<String, dynamic>.from(
          (first.map['exits'] as List).first,
        );
        first.phase = PlayPhase.transition;
        g.transitionRegion();
        if ([
          'mountain',
          'mountainGate',
          'bossEvent',
          'endingEvent',
        ].contains(name)) {
          final farm = g.state!..gateOpen = true;
          farm.exitRequested = Map<String, dynamic>.from(
            (farm.map['exits'] as List).last,
          );
          farm.phase = PlayPhase.transition;
          g.transitionRegion();
        }
      }
      g.director = null;
      final s = g.state!;
      s.checkpointRequested = false;
      for (final e in s.enemies) {
        e.active = false;
      }
      switch (name) {
        case 'farm':
          s.x = -19;
          s.z = -21;
        case 'mountain':
          s.x = 0;
          s.z = 4;
          s.yaw = -1.5707963267948966;
        case 'farmGate':
          s.x = 18.5;
          s.z = -10;
          s.yaw = -1.5707963267948966;
        case 'mountainGate':
          s.x = 19.5;
          s.z = 15;
          s.yaw = -1.5707963267948966;
          final boss = s.enemies.firstWhere((e) => e.boss);
          boss.hp = 0;
          boss.alive = false;
          s.kills = 1;
        case 'merchant':
          s.x = -13;
          s.z = -19.8;
          s.beers = 8;
          s.pitch = .12;
        case 'npc':
          s.x = -2.8;
          s.z = -23;
          s.pitch = .12;
        case 'stagger':
          s.x = 0;
          s.z = -16;
          s.heading = 0;
          s.enemies[0]
            ..active = true
            ..alerted = true
            ..x = 0
            ..z = -14.6
            ..hp = 35
            ..stun = 30;
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
      final event = {
        'introEvent': 'opening',
        'farmEvent': 'farm',
        'bossEvent': 'last_order',
        'endingEvent': 'ending',
      }[name];
      if (event != null) {
        if (event == 'last_order') {
          s.enemies.firstWhere((e) => e.boss).active = true;
        }
        g.startEvent(event);
      }
      return MarionetteExtensionResult.success(s.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.gameAction',
    description: 'Debug action=interact|reload|fire|fireAtEnemy|step|move|aim|pause|evade|kick|pose. pose clip and seconds=0..3. step seconds=0..10.',
    callback: (p) async {
      final g = _game;
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final s = g.state!;
      switch (p['action']) {
        case 'pose':
          final name = p['clip'];
          if (!g.player.clips.containsKey(name)) {
            return MarionetteExtensionResult.invalidParams('Unknown clip');
          }
          final seconds = double.tryParse(p['seconds'] ?? '0');
          if (seconds == null ||
              !seconds.isFinite ||
              seconds < 0 ||
              seconds > 3) {
            return MarionetteExtensionResult.invalidParams('seconds=0..3');
          }
          g.posePreview = true;
          s.phase = PlayPhase.playing;
          s.x = 0;
          s.z = -18;
          s.y = 0;
          s.yaw = 0;
          s.heading = 0;
          for (final e in s.enemies) {
            e.active = false;
          }
          s.toastTime = 0;
          s.interaction = null;
          s.reloading = name!.startsWith('Reload') ? .5 : 0;
          s.weapon = name.contains('Shotgun') ? 'shotgun' : 'handgun';
          s.aiming = name.startsWith('Aim');
          g.player.setMotion(name);
          for (final e in g.player.clips.entries) {
            e.value.weight = e.key == name ? 1 : 0;
            e.value.pause();
          }
          g.player.clips[name]!.seek(seconds);
        case 'evade':
          s.evade();
        case 'kick':
          s.kick();
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
