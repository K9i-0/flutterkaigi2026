import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_controller.dart';
import 'game_state.dart';
import 'game_native_audit.dart';

HazardGameController? _game;
bool _registered = false;
NativeCampaignAudit? _nativeAudit;
void detachGameAutomation() {
  _nativeAudit?.stop();
  _nativeAudit = null;
  _game = null;
}

void attachGameAutomation(HazardGameController game) {
  if (!kDebugMode) return;
  _game = game;
  if (_registered) return;
  _registered = true;
  registerMarionetteExtension(
    name: 'madogiwa.auditCampaign',
    description: 'Start/inspect/stop a native rendered campaign audit. action=start|inspect|stop, complete=true includes optional collection. Start resets the run. Exact automated aim; not a human difficulty test.',
    callback: (p) async {
      final g = _game;
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      switch (p['action']) {
        case 'start':
          if (_nativeAudit?.status == 'running') {
            return MarionetteExtensionResult.error(2, 'Already running');
          }
          _nativeAudit = NativeCampaignAudit(
            g,
            completionist: p['complete'] == 'true',
          );
        case 'stop':
          _nativeAudit?.stop();
        case 'inspect':
          break;
        default:
          return MarionetteExtensionResult.invalidParams(
            'action=start|inspect|stop',
          );
      }
      return MarionetteExtensionResult.success(
        _nativeAudit?.inspect() ?? {'status': 'not-started'},
      );
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.inspectHazardGame',
    description: 'Inspect game combat, pickup, collection and chapter state.',
    callback: (_) async => _game?.state == null
        ? MarionetteExtensionResult.error(1, 'Not ready')
        : MarionetteExtensionResult.success({
            ..._game!.state!.inspect(),
            'frames': _game!.frames.toJson(),
            'settings': _game!.settings.encode(),
            'audioPlayback': _game!.audioPlayback,
            'rendering': {
              'continuous': _game!.animateScene,
              'foreground': _game!.foreground,
              'posePreview': _game!.posePreview,
              'ticks': _game!.renderedTicks,
              'simulationSeconds': _game!.state!.time,
              'playerClipSeconds':
                  _game!.player.clips[_game!.player.current]!.playbackTime,
            },
            'voice': _game!.voice.inspect(),
            'soundscape': _game!.soundscape.inspect(),
            'event': _game!.director == null
                ? null
                : {
                    'id': _game!.director!.id,
                    'shot': _game!.director!.index,
                    'elapsed': _game!.director!.elapsed,
                    'duration': _game!.director!.duration,
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
        'encounter',
        'mugTiming',
        'pickup',
        'collection',
        'gate',
        'stairs',
        'enemyStairs',
        'farmEnemyStairs',
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
        'bossCombat',
        'endingEvent',
      ].contains(name)) {
        return MarionetteExtensionResult.invalidParams('Invalid scenario');
      }
      g.restart();
      if ([
        'farm',
        'farmEnemyStairs',
        'farmGate',
        'mountain',
        'mountainGate',
        'farmEvent',
        'bossEvent',
        'bossCombat',
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
          'bossCombat',
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
        case 'bossCombat':
          s.x = 6;
          s.z = 4;
          s.yaw = -1.5707963267948966;
          s.seenEvents.add('last_order');
          s.enemies.firstWhere((e) => e.boss)
            ..active = true
            ..alerted = true;
          s.phase = PlayPhase.paused;

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
        case 'mugTiming':
          s.x = 0;
          s.z = -16;
          s.yaw = 3.141592653589793;
          s.enemies.first
            ..active = true
            ..alerted = true
            ..x = .25
            ..z = -15.1;
        case 'encounter':
          s.x = 0;
          s.z = -14;
          s.yaw = 3.141592653589793;
          s.invulnerable = 100;
          for (final e in s.enemies.take(3)) {
            e
              ..active = true
              ..alerted = true
              ..x = (e.id - 1) * 1.2
              ..z = -6;
          }
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
        case 'enemyStairs':
        case 'farmEnemyStairs':
          final ramp = (s.map['ramps'] as List).first;
          s.x = (ramp['x'] as num).toDouble() - 2;
          s.z = (ramp['z1'] as num).toDouble() + .65;
          s.y = 3.03;
          s.yaw = 0;
          s.invulnerable = 100;
          s.enemies.first
            ..active = true
            ..alerted = true
            ..x = (ramp['x'] as num).toDouble()
            ..z = (ramp['z0'] as num).toDouble() + .35;
          s.enemies.first.y = s.floorHeight(
            s.enemies.first.x,
            s.enemies.first.z,
            0,
          );
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
      s.phase = ['bossCombat', 'mugTiming'].contains(name)
          ? PlayPhase.paused
          : PlayPhase.playing;
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
      g.refreshView();
      return MarionetteExtensionResult.success(s.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.gameAction',
    description: 'Debug action=viewpoint|soundCue|previewState|simulate|interact|reload|fire|fireAtEnemy|step|move|aim|pause|evade|kick|pose. pose clip and seconds=0..3. step/simulate seconds=0..10. simulate x/y=-1..1 sprint/evade=true uses normal simulation and pauses for inspection.',
    callback: (p) async {
      final g = _game;
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final s = g.state!;
      switch (p['action']) {
        case 'viewpoint':
          final x = double.tryParse(p['x'] ?? '');
          final y = double.tryParse(p['y'] ?? '0');
          final z = double.tryParse(p['z'] ?? '');
          final yaw = double.tryParse(p['yaw'] ?? '');
          final pitch = double.tryParse(p['pitch'] ?? '.12');
          if ([x, y, z, yaw, pitch].any((v) => v == null || !v.isFinite) ||
              x!.abs() > 30 ||
              z!.abs() > 35 ||
              y! < 0 ||
              y > 10) {
            return MarionetteExtensionResult.invalidParams(
              'Finite x/z/yaw required, y=0..10; visual inspection only',
            );
          }
          // Reproducible art review with the normal gameplay camera. Explicit
          // placement and disabled enemies make this unsuitable as route proof.
          g.posePreview = true;
          g.director = null;
          s.seenEvents.addAll(['opening', 'farm', 'last_order', 'ending']);
          s.phase = PlayPhase.playing;
          s.stopInput();
          s.x = x;
          s.y = y;
          s.z = z;
          s.yaw = yaw!;
          s.heading = yaw + 3.141592653589793;
          s.pitch = pitch!.clamp(minCameraPitch, maxCameraPitch);
          s.aiming = false;
          s.toastTime = 0;
          for (final e in s.enemies) {
            e.active = false;
          }
        case 'soundCue':
          final x = double.tryParse(p['x'] ?? '');
          final z = double.tryParse(p['z'] ?? '');
          if (x == null ||
              z == null ||
              !x.isFinite ||
              !z.isFinite ||
              x.abs() > 30 ||
              z.abs() > 35) {
            return MarionetteExtensionResult.invalidParams(
              'Finite world x/z required',
            );
          }
          s.emitSound('enemy', x: x, z: z);

        case 'previewState':
          if (s.phase != PlayPhase.paused) {
            return MarionetteExtensionResult.invalidParams(
              'Pause the run first',
            );
          }
          // Render a deterministic combat pose without a pause-menu overlay.
          // posePreview also prevents debug snapshots overwriting checkpoints.
          g.posePreview = true;
          s.stopInput();
          s.phase = PlayPhase.playing;

        case 'simulate':
          final seconds = double.tryParse(p['seconds'] ?? '1');
          final inputX = double.tryParse(p['x'] ?? '0');
          final inputY = double.tryParse(p['y'] ?? '0');
          if (seconds == null ||
              !seconds.isFinite ||
              seconds < 0 ||
              seconds > 10 ||
              inputX == null ||
              !inputX.isFinite ||
              inputX.abs() > 1 ||
              inputY == null ||
              !inputY.isFinite ||
              inputY.abs() > 1 ||
              ![PlayPhase.playing, PlayPhase.paused].contains(s.phase)) {
            return MarionetteExtensionResult.invalidParams(
              'seconds=0..10, x/y=-1..1, active run required',
            );
          }
          // Use the regular simulation clock and input path, including enemy
          // movement, damage, collision and cooldowns. Freeze only for inspection.
          s.phase = PlayPhase.playing;
          s.inputX = inputX;
          s.inputY = inputY;
          s.sprint = p['sprint'] == 'true';
          if (p['evade'] == 'true') s.evade();
          for (var i = 0; i < (seconds * 60).round(); i++) {
            s.tick(1 / 60);
          }
          s.stopInput();
          if (s.running) s.phase = PlayPhase.paused;

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
          s.shoot(o, vm.Vector3(e.x, e.y + 1.1, e.z) - o);
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
      g.refreshView();
      return MarionetteExtensionResult.success(s.inspect());
    },
  );
}
