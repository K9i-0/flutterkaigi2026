import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../game/island_game_controller.dart';
import '../scene/madogiwa_island_scene.dart';
import 'automation_state.dart';

void registerIslandMarionetteExtensions() {
  if (!kDebugMode || kIsWeb) return;

  registerMarionetteExtension(
    name: 'madogiwa.inspectIsland',
    description:
        'Inspect player, chunk, exploration, reunion, resource, build, and '
        'landmark state in the active island game.',
    callback: (_) async {
      final controller = IslandAutomationState.controller;
      final scene = IslandAutomationState.scene;
      if (controller == null || scene == null || !scene.isLoaded) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      return MarionetteExtensionResult.success({
        'player': {'x': scene.playerX, 'z': scene.playerZ},
        'chunk': {'x': scene.playerChunkX, 'z': scene.playerChunkZ},
        'activeChunks': scene.activeChunkCount,
        'terrainQuads': scene.terrainQuadCount,
        'exploredCells': scene.exploredCellCount,
        'jumping': scene.isJumping,
        'jumpOffset': scene.jumpOffset,
        'reunitedCount': scene.reunitedCount,
        'reunitedMembers': scene.reunitedMemberNames,
        'heldDirections': IslandAutomationState.heldDirections.toList(),
        'tool': controller.tool.name,
        'wood': controller.wood,
        'stone': controller.stone,
        'remainingResources': controller.resources.length,
        'structures': controller.structures.length,
        'homeComplete': controller.homeComplete,
        'message': controller.message,
        'landmarks': [
          for (final landmark in MadogiwaIslandScene.landmarks)
            {
              'id': landmark.id,
              'label': landmark.label,
              'x': landmark.cell.x,
              'z': landmark.cell.z,
              'discovered': scene.isExplored(landmark.cell.x, landmark.cell.z),
              'memberReunited': scene.isMemberReunited(landmark.memberId),
            },
        ],
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.keyInput',
    description:
        'Send a movement key. Params: key=w/a/s/d/arrowUp/arrowLeft/'
        'arrowDown/arrowRight, action=down/up/tap, durationMs for tap.',
    callback: (params) async {
      final key = params['key'];
      final action = (params['action'] ?? 'tap').toLowerCase();
      if (key == null ||
          IslandAutomationState.normalizeDirectionKey(key) == null) {
        return MarionetteExtensionResult.invalidParams(
          'Unknown or missing key. Use W/A/S/D or an arrow key.',
        );
      }
      if (IslandAutomationState.scene?.isLoaded != true) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      switch (action) {
        case 'down':
          IslandAutomationState.setKey(key, pressed: true);
        case 'up':
          IslandAutomationState.setKey(key, pressed: false);
        case 'tap':
          final duration = int.tryParse(params['durationMs'] ?? '') ?? 260;
          IslandAutomationState.setKey(key, pressed: true);
          await Future<void>.delayed(
            Duration(milliseconds: duration.clamp(16, 3000)),
          );
          IslandAutomationState.setKey(key, pressed: false);
        default:
          return MarionetteExtensionResult.invalidParams(
            'Unknown action: $action. Use down, up, or tap.',
          );
      }
      return MarionetteExtensionResult.success({
        'key': key,
        'action': action,
        'heldDirections': IslandAutomationState.heldDirections.toList(),
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.releaseKeys',
    description: 'Release every held automation movement key.',
    callback: (_) async {
      IslandAutomationState.releaseAllKeys();
      return MarionetteExtensionResult.success({'status': 'released'});
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.openScenario',
    description:
        'Teleport to a deterministic visual test location. '
        'Available ids: camp, radio, office, shrine.',
    callback: (params) async {
      final id = params['id'];
      final scene = IslandAutomationState.scene;
      if (id == null || scene == null || !scene.isLoaded) {
        return MarionetteExtensionResult.invalidParams(
          'Missing id or island is not ready.',
        );
      }
      final target = switch (id) {
        'camp' => (0, 3),
        'radio' => (-38, -35),
        'office' => (42, -42),
        'shrine' => (30, 57),
        _ => null,
      };
      if (target == null) {
        return MarionetteExtensionResult.error(2, 'Unknown scenario: $id');
      }
      final destination = await scene.automationTeleport(target.$1, target.$2);
      if (destination == null) {
        return MarionetteExtensionResult.error(3, 'No land near scenario.');
      }
      return MarionetteExtensionResult.success({
        'id': id,
        'x': destination.x,
        'z': destination.z,
        'status': 'opened',
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.selectTool',
    description: 'Select gather, floor, wall, or roof.',
    callback: (params) async {
      final controller = IslandAutomationState.controller;
      final toolName = params['tool'];
      if (controller == null || toolName == null) {
        return MarionetteExtensionResult.invalidParams('Missing tool.');
      }
      final tool = IslandTool.values
          .where((item) => item.name == toolName)
          .firstOrNull;
      if (tool == null) {
        return MarionetteExtensionResult.invalidParams(
          'Unknown tool: $toolName.',
        );
      }
      controller.selectTool(tool);
      return MarionetteExtensionResult.success({'tool': tool.name});
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.resetIsland',
    description: 'Reset the active island game to its initial state.',
    callback: (_) async {
      final scene = IslandAutomationState.scene;
      if (scene == null || !scene.isLoaded) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      IslandAutomationState.releaseAllKeys();
      scene.reset();
      return MarionetteExtensionResult.success({'status': 'reset'});
    },
  );
}
