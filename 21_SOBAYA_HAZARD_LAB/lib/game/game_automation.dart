import 'game_story.dart';

import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_controller.dart';
import 'game_state.dart';
import 'game_native_audit.dart';
import 'game_debug_probe.dart';

import 'dart:io' show pid;

HazardGameController? _game;
bool _registered = false;
NativeCampaignAudit? _nativeAudit;
bool _probeRunning = false;
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
    name: 'madogiwa.debugSession',
    description: 'Read-only connection identity and readiness. Check pid/foreground before any native UI test.',
    callback: (_) async => MarionetteExtensionResult.success({
      'protocol': 1,
      'app': 'sobaya_hazard',
      'pid': pid,
      'ready': _game?.ready ?? false,
      'foreground': _game?.foreground ?? false,
      'phase': _game?.state?.phase.name,
      'ticks': _game?.renderedTicks,
      'probeRunning': _probeRunning,
      'campaignAudit': _nativeAudit?.status,
      'probes': ['conversation', 'companionYametaro', 'companionTakosan'],
    }),
  );
  registerMarionetteExtension(
    name: 'madogiwa.runGameProbe',
    description: 'name=conversation|companionYametaro|companionTakosan. Resets the test run, keeps saved collection; observes real frames/audio, pauses at the end. Foreground required, 15s deadline. Controller test, not keyboard/pointer input.',
    callback: (p) async {
      final g = _game;
      if (![
        'conversation',
        'companionYametaro',
        'companionTakosan',
      ].contains(p['name'])) {
        return MarionetteExtensionResult.invalidParams('name=conversation');
      }
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      if (_probeRunning || _nativeAudit?.status == 'running') {
        return MarionetteExtensionResult.error(
          2,
          'Another probe or campaign audit is running',
        );
      }
      _probeRunning = true;
      try {
        return MarionetteExtensionResult.success(
          p['name'] == 'conversation'
              ? await probeConversation(g)
              : await probeCompanionVoice(
                  g,
                  p['name'] == 'companionYametaro' ? 'yametaro' : 'takosan',
                ),
        );
      } finally {
        _probeRunning = false;
      }
    },
  );
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
          if (_probeRunning || _nativeAudit?.status == 'running') {
            return MarionetteExtensionResult.error(
              2,
              'Another probe or campaign audit is running',
            );
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
            'speechFaces': _game!.inspectSpeechFaces(),
            'soundscape': _game!.soundscape.inspect(),
            'event': _game!.director == null
                ? null
                : {
                    'id': _game!.director!.id,
                    'shot': _game!.director!.index,
                    'elapsed': _game!.director!.elapsed,
                    'duration': _game!.director!.duration,
                    'visual': {
                      'image': _game!.director!.cut?.image,
                      'document': _game!.director!.cut?.document,
                      'progress': _game!.director!.visualProgress,
                    },
                    'paused': _game!.director!.paused,
                  },
            'seenEvents': _game!.state!.seenEvents.toList(),
            'motion': _game!.player.current,
            'checkpoint': {
              'exists': _game!.hasCheckpoint,
              'saving': _game!.saving,
              'status': _game!.saveStatus,
            },
            'enemyMotions': _game!.enemies
                .map(
                  (a) => {
                    'motion': a.current,
                    'seconds': a.clips[a.current]!.playbackTime,
                  },
                )
                .toList(),
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
    description: 'Debug scenario name=combat|stagger|npc|merchant|pickup|collection|gate|stairs|death|companionYametaro|companionTakosan. Resets run, keeps collection.',
    callback: (p) async {
      final g = _game;
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final name = p['name'];
      if (![
        'storyMemo',
        'audioExplore',
        'audioThreat',
        'companionYametaro',
        'companionTakosan',
        'combat',
        'encounter',
        'mugTiming',
        'pickup',
        'collection',
        'gate',
        'stairs',
        'enemyStairs',
        'ladder',
        'enemyLadder',
        'window',
        'enemyWindow',
        'grapple',
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
        'merchant',
        'companionTakosan',
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
        case 'storyMemo':
          final m = villageMemos.first;
          s.x = m.x;
          s.z = m.z + 1;
          s.y = 0;
          s.yaw = 0;
        case 'audioExplore':
          s.x = 0;
          s.z = -18;
        case 'audioThreat':
          s.x = 0;
          s.z = -18;
          s.enemies.first
            ..active = true
            ..alerted = true
            ..x = 0
            ..z = -9
            ..stun = 60;
        case 'companionYametaro':
        case 'companionTakosan':
          final npc = s.npcs.firstWhere(
            (n) =>
                n['id'] ==
                (name == 'companionYametaro' ? 'yametaro' : 'takosan'),
          );
          s.x = (npc['x'] as num).toDouble() + 2.5;
          s.z = (npc['z'] as num).toDouble() - 1.8;
          s.yaw = -1;
          s.enemies.first
            ..active = true
            ..alerted = true
            ..x = (npc['x'] as num).toDouble()
            ..z = (npc['z'] as num).toDouble() + 1;
        case 'bossEvent':
          s.x = 1.5;
          s.z = 4;
          s.yaw = -1.5707963267948966;
          s.heading = 1.5707963267948966;
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
          s.z = -19.4;
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
        case 'grapple':
          s.x = 0;
          s.y = 0;
          s.z = -21;
          s.yaw = 3.141592653589793;
          s.heading = 0;
          s.invulnerable = 0;
          s.enemies.first
            ..active = true
            ..alerted = true
            ..x = 0
            ..y = 0
            ..z = -20.1
            ..heading = 3.141592653589793;
        case 'window':
          final w = s.windows.first;
          s.x = w.x;
          s.y = 0;
          s.z = w.entryZ(true);
          s.yaw = 3.141592653589793;
          s.heading = 0;
        case 'enemyWindow':
          final w = s.windows.first;
          s.x = w.x;
          s.y = 0;
          s.z = w.exitZ(true) + 2;
          s.yaw = 0;
          s.heading = 3.141592653589793;
          s.invulnerable = 100;
          for (var i = 0; i < 2; i++) {
            s.enemies[i]
              ..active = true
              ..alerted = true
              ..x = w.x
              ..y = 0
              ..z = w.entryZ(true) - i;
          }
        case 'ladder':
          s.x = -13.5;
          s.y = 0;
          s.z = -9.1;
          s.yaw = 3.141592653589793;
          s.heading = 0;
        case 'enemyLadder':
          s.x = -13.5;
          s.y = 4.22;
          s.z = -6.5;
          s.yaw = 0;
          s.invulnerable = 100;
          for (var i = 0; i < 2; i++) {
            s.enemies[i]
              ..active = true
              ..alerted = true
              ..x = -13.5 + i * .9
              ..y = 0
              ..z = -12;
          }
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
      s.phase =
          [
            'bossCombat',
            'mugTiming',
            'ladder',
            'enemyLadder',
            'window',
            'enemyWindow',
            'grapple',
          ].contains(name)
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
    description: 'Debug action=eventFrame|viewpoint|soundCue|previewState|simulate|interact|reload|fire|fireAtEnemy|step|move|aim|pause|evade|kick|pose. eventFrame shot and progress=0..1 after an event scenario: static art review. pose clip and seconds=0..3. step/simulate seconds=0..10. simulate x/y=-1..1 sprint/evade=true uses normal simulation and pauses for inspection.',
    callback: (p) async {
      final g = _game;
      if (g == null || !g.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final s = g.state!;
      switch (p['action']) {
        case 'eventFrame':
          final d = g.director;
          final shot = int.tryParse(p['shot'] ?? '');
          final progress = double.tryParse(p['progress'] ?? '.5');
          if (d == null ||
              shot == null ||
              shot < 0 ||
              shot >= d.shots.length ||
              progress == null ||
              !progress.isFinite ||
              progress < 0 ||
              progress > 1 ||
              _probeRunning ||
              _nativeAudit?.status == 'running') {
            return MarionetteExtensionResult.invalidParams(
              'Open an event scenario first; shot in range, progress=0..1; no running audit',
            );
          }
          // Static art review only. Do not pretend a background app is active,
          // advance gameplay time, or treat this as a native playback check.
          d.index = shot;
          d.elapsed = d.duration * progress;
          d.paused = true;
          g.posePreview = true;
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
          s.climb = null;
          s.vault = null;
          s.x = x;
          s.y = y;
          s.z = z;
          s.yaw = yaw!;
          s.heading = yaw + 3.141592653589793;
          s.pitch = pitch!.clamp(minCameraPitch, maxCameraPitch);
          s.aiming = false;
          s.toastTime = 0;
          for (final e in s.enemies) {
            if (p['keepEnemies'] != 'true') e.active = false;
          }
        case 'audioThreatOff':
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
          final cue = p['cue'] ?? 'enemy';
          if (![
            'enemy',
            'shot',
            'shotgun',
            'mug_ready',
            'mug_swing',
            'mug_hit',
          ].contains(cue)) {
            return MarionetteExtensionResult.invalidParams(
              'Unsupported audio cue',
            );
          }
          s.emitSound(cue, x: x, z: z);

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

        case 'windowPose':
          final seconds = double.tryParse(p['seconds'] ?? '.9');
          if (seconds == null ||
              !seconds.isFinite ||
              seconds < 0 ||
              seconds > 2.5 ||
              s.vault != null) {
            return MarionetteExtensionResult.invalidParams(
              'Window entry and seconds=0..2.5 required',
            );
          }
          s.phase = PlayPhase.playing;
          s.interact();
          if (s.vault == null) {
            return MarionetteExtensionResult.invalidParams(
              'Stand at an available window',
            );
          }
          for (var i = 0; i < (seconds * 60).round(); i++) {
            s.tick(1 / 60);
          }
          g.posePreview = true;
          s.toastTime = 0;
          s.stopInput();
          final clip = s.vault?.crossing == true ? 'Vault' : 'Walk';
          g.player.setMotion(clip);
          for (final e in g.player.clips.entries) {
            e.value.weight = e.key == clip ? 1 : 0;
          }
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
          s.struggling = p['struggling'] == 'true';
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
          g.interact();
        case 'reload':
          s.reload();
        case 'aim':
          s.aiming = true;
        case 'pause':
          if (g.director != null) {
            g.setEventPaused(true);
          } else {
            s.phase = PlayPhase.paused;
            s.stopInput();
          }
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
