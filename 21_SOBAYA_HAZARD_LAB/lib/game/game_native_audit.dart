import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:vector_math/vector_math.dart' as vm;

import 'campaign_audit.dart';
import 'game_controller.dart';
import 'game_state.dart';
import 'game_camera.dart';

/// Opt-in debug driver. Frames come from the real SceneView ticker; aiming uses
/// the same camera and fire() as mouse/keyboard. No simulation fast-forward.
class NativeCampaignAudit {
  NativeCampaignAudit(this.game, {required bool completionist}) {
    game.startRun();
    final epoch = game.runEpoch;
    driver = CampaignAudit(
      game.campaign,
      pump: () async {
        do {
          await Future<void>.delayed(const Duration(milliseconds: 16));
          if (driver.cancelled ||
              game.disposed ||
              game.runEpoch != epoch ||
              game.campaign != driver.campaign) {
            throw StateError('Audit stopped or run replaced');
          }
        } while (!game.foreground ||
            ![
              PlayPhase.playing,
              PlayPhase.dead,
              PlayPhase.clear,
              PlayPhase.transition,
            ].contains(game.state!.phase));
      },
      steer: (dx, dz) {
        final s = game.state!;
        final targetYaw = math.atan2(-dx, -dz);
        final turn = math.atan2(
          math.sin(targetYaw - s.yaw),
          math.cos(targetYaw - s.yaw),
        );
        s.yaw += turn * .15;
        s.pitch += (.12 - s.pitch) * .15;
        s.inputX = -dx * math.cos(s.yaw) + dz * math.sin(s.yaw);
        s.inputY = -dx * math.sin(s.yaw) - dz * math.cos(s.yaw);
        s.sprint = true;
        s.aiming = false;
      },
      aimAndFire: (target) {
        aimCamera(game, target);
        final s = game.state!;
        final ray = game.camera().screenPointToRay(
          ui.Offset(game.viewport.width / 2, game.viewport.height / 2),
          game.viewport,
        );
        final delta = target - ray.origin,
            direction = ray.direction.normalized();
        if (delta.cross(direction).length > .1 ||
            s.wallDistance(ray.origin, direction, delta.length) <
                delta.length - .3) {
          // The shoulder can still be behind cover when the body has sight.
          // Un-aim and step sideways, just as a player must, before firing.
          s.aiming = false;
          s.sprint = false;
          s.inputX = s.inputY = 0;
          for (final angle in [
            0.0,
            math.pi / 4,
            -math.pi / 4,
            math.pi / 2,
            -math.pi / 2,
            math.pi,
          ]) {
            final dx = math.cos(s.yaw + angle), dz = -math.sin(s.yaw + angle);
            if ([
              .2,
              .4,
              .6,
            ].any((d) => s.blocked(s.x + dx * d, s.z + dz * d, s.y))) {
              continue;
            }
            s.inputX = -dx * math.cos(s.yaw) + dz * math.sin(s.yaw);
            s.inputY = -dx * math.sin(s.yaw) - dz * math.cos(s.yaw);
            break;
          }
          return;
        }
        game.fire();
      },
    )..completionist = completionist;
    unawaited(
      driver
          .run()
          .then((_) {
            status = 'complete';
            game.state!.stopInput();
          })
          .catchError((Object e, StackTrace st) {
            error = '$e\n$st';
            status = driver.cancelled ? 'stopped' : 'failed';
            if (!game.disposed &&
                game.runEpoch == epoch &&
                game.campaign == driver.campaign) {
              game.state!.stopInput();
              if (game.state!.running) game.toggle(PlayPhase.paused);
            }
          }),
    );
  }
  final HazardGameController game;
  late final CampaignAudit driver;
  String status = 'running';
  String? error;
  void stop() {
    driver.cancelled = true;
    game.state!.stopInput();
  }

  Map<String, dynamic> inspect() => {
    'auditStatus': status,
    'error': error,
    'mode': 'real SceneView frames and center-screen fire',
    'completionist': driver.completionist,
    'frames': driver.frames,
    'weaponsUsed': driver.weaponsUsed.toList(),
    'events': driver.events,
  };
}

/// Solve the shoulder offset and camera boom, then use the normal center ray.
/// This is an exact-aim audit tool, not player aim assist.
void aimCamera(HazardGameController game, vm.Vector3 target) =>
    aimCameraState(game.state!, target);

void aimCameraState(HazardGameState s, vm.Vector3 target) {
  s.aiming = true;
  s.yaw = math.atan2(s.x - target.x, s.z - target.z);
  for (var i = 0; i < 8; i++) {
    final center = playerCamera(s).target;
    s.yaw = math.atan2(center.x - target.x, center.z - target.z);
  }
  final center = playerCamera(s).target;
  final horizontal = math.sqrt(
    math.pow(center.x - target.x, 2) + math.pow(center.z - target.z, 2),
  );
  final angle = math.atan2(center.y - target.y, horizontal);
  s.pitch = (angle - math.asin(.09 * math.cos(angle)) + s.recoil).clamp(
    minCameraPitch,
    maxCameraPitch,
  );
}
