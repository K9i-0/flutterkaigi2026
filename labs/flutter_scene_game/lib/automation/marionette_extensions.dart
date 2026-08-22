import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../game/island_game_controller.dart';
import '../game/mobile_quality.dart';
import '../scene/madogiwa_island_scene.dart';
import 'automation_state.dart';

void registerIslandMarionetteExtensions() {
  if (!kDebugMode || kIsWeb) return;

  registerMarionetteExtension(
    name: 'madogiwa.inspectIsland',
    description:
        'Inspect campaign, player, chunk, exploration, reunion, inventory, '
        'crafting, build, visual, landmark, and ending state.',
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
        'timeOfDay': scene.timeOfDay,
        'clock': scene.clockLabel,
        'phase': scene.phaseLabel,
        'visualOptions': scene.visualOptions,
        'performance': {
          'fps': scene.framesPerSecond,
          'averageFrameTimeMs': scene.averageFrameTimeMs,
          'p95FrameTimeMs': scene.p95FrameTimeMs,
          'onePercentLowFps': scene.onePercentLowFps,
          'averageBuildTimeMs': scene.averageBuildTimeMs,
          'averageRasterTimeMs': scene.averageRasterTimeMs,
          'p95RasterTimeMs': scene.p95RasterTimeMs,
          'quality': scene.graphicsQuality.name,
          'renderScale': scene.renderScale,
          'characterAtNativeResolution': scene.characterAtNativeResolution,
          'adaptiveDetail': scene.adaptiveDetailLabel,
          'resourceLod': scene.resourceLodLabel,
        },
        'torches': scene.torchCount,
        'activeTorchLights': scene.activeTorchLightCount,
        'reunitedCount': scene.reunitedCount,
        'reunitedMembers': scene.reunitedMemberNames,
        'companionModes': {
          for (final member in controller.reunitedMembers)
            member: controller.companionMode(member).name,
        },
        'heldDirections': IslandAutomationState.heldDirections.toList(),
        'tool': controller.tool.name,
        'selectedBuildCell': controller.selectedCell == null
            ? null
            : {
                'x': controller.selectedCell!.x,
                'z': controller.selectedCell!.z,
              },
        'chapter': controller.chapter.name,
        'chapterLabel': controller.chapter.label,
        'objective': controller.chapterObjective,
        'signalLevel': controller.signalLevel,
        'explorationLimit': controller.explorationLimit,
        'signalBoundaryRadius': scene.signalBoundaryRadius,
        'inventory': {
          for (final item in IslandItem.values)
            item.name: controller.itemCount(item),
        },
        'craftedRecipes': controller.craftedRecipes
            .map((recipe) => recipe.name)
            .toList(),
        'completedLandmarks': controller.completedLandmarks.toList(),
        'endingAvailable': controller.endingAvailable,
        'ending': controller.endingChoice.name,
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
              'completed': scene.isLandmarkComplete(landmark.id),
            },
        ],
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setGraphicsQuality',
    description: 'Set auto, performance, balanced, or quality rendering.',
    callback: (params) async {
      final scene = IslandAutomationState.scene;
      final qualityName = params['quality'];
      final quality = GraphicsQuality.values
          .where((value) => value.name == qualityName)
          .firstOrNull;
      if (scene == null || quality == null) {
        return MarionetteExtensionResult.invalidParams(
          'Required quality=auto/performance/balanced/quality.',
        );
      }
      scene.setGraphicsQuality(quality);
      return MarionetteExtensionResult.success({
        'quality': quality.name,
        'renderScale': scene.renderScale,
        'characterAtNativeResolution': scene.characterAtNativeResolution,
        'adaptiveDetail': scene.adaptiveDetailLabel,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setVisualOption',
    description:
        'Toggle a visual debug option. Params: option and enabled. '
        'Inspect madogiwa.inspectIsland for available option names.',
    callback: (params) async {
      final scene = IslandAutomationState.scene;
      final option = params['option'];
      final enabled = switch (params['enabled']?.toLowerCase()) {
        'true' || '1' || 'on' => true,
        'false' || '0' || 'off' => false,
        _ => null,
      };
      if (scene == null || option == null || enabled == null) {
        return MarionetteExtensionResult.invalidParams(
          'Required: option and enabled=true/false.',
        );
      }
      if (!scene.setVisualOption(option, enabled)) {
        return MarionetteExtensionResult.invalidParams(
          'Unknown visual option: $option.',
        );
      }
      return MarionetteExtensionResult.success({
        'option': option,
        'enabled': enabled,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.setTimeOfDay',
    description:
        'Set visual test time. Params: preset=morning/day/evening/night or '
        'time=0.0..1.0.',
    callback: (params) async {
      final scene = IslandAutomationState.scene;
      if (scene == null) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      final presetTime = switch (params['preset']) {
        'morning' => 0.27,
        'day' => 0.5,
        'evening' => 0.73,
        'night' => 0.88,
        _ => null,
      };
      final time = presetTime ?? double.tryParse(params['time'] ?? '');
      if (time == null) {
        return MarionetteExtensionResult.invalidParams(
          'Provide preset or numeric time.',
        );
      }
      scene.setTimeOfDay(time);
      return MarionetteExtensionResult.success({
        'timeOfDay': scene.timeOfDay,
        'clock': scene.clockLabel,
        'phase': scene.phaseLabel,
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
        'Available ids: camp, radio, office, shrine, summit.',
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
        'office' => (64, -52),
        'shrine' => (55, 80),
        'summit' => (-30, 111),
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
    description: 'Select gather/build mode or a legacy placement tool.',
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
    name: 'madogiwa.buildAt',
    description:
        'Build immediately at a cell. Params: blueprint=floor/wall/roof/'
        'torch/house, x, z.',
    callback: (params) async {
      final controller = IslandAutomationState.controller;
      final scene = IslandAutomationState.scene;
      final blueprintName = params['blueprint'];
      final x = int.tryParse(params['x'] ?? '');
      final z = int.tryParse(params['z'] ?? '');
      final blueprint = BuildBlueprint.values
          .where((item) => item.name == blueprintName)
          .firstOrNull;
      if (controller == null ||
          scene == null ||
          blueprint == null ||
          x == null ||
          z == null) {
        return MarionetteExtensionResult.invalidParams(
          'Required blueprint=floor/wall/roof/torch/house and integer x/z.',
        );
      }
      controller.selectBuildTarget(GridCell(x, z));
      final built = scene.buildAtSelected(blueprint);
      return MarionetteExtensionResult.success({
        'blueprint': blueprint.name,
        'x': x,
        'z': z,
        'built': built,
        'message': controller.message,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.grantResources',
    description: 'Grant debug campaign resources. Optional amount, default 99.',
    callback: (params) async {
      final controller = IslandAutomationState.controller;
      if (controller == null) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      final amount = int.tryParse(params['amount'] ?? '') ?? 99;
      controller.grantDebugResources(amount.clamp(1, 999));
      return MarionetteExtensionResult.success({'amount': amount});
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.craftRecipe',
    description: 'Craft a campaign recipe. Param: recipe.',
    callback: (params) async {
      final scene = IslandAutomationState.scene;
      final recipeName = params['recipe'];
      if (scene == null || recipeName == null) {
        return MarionetteExtensionResult.invalidParams('Missing recipe.');
      }
      final recipe = CraftRecipe.values
          .where((item) => item.name == recipeName)
          .firstOrNull;
      if (recipe == null) {
        return MarionetteExtensionResult.invalidParams(
          'Unknown recipe: $recipeName.',
        );
      }
      final crafted = scene.craftRecipe(recipe);
      return MarionetteExtensionResult.success({
        'recipe': recipe.name,
        'crafted': crafted,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.performObjective',
    description: 'Activate the campaign landmark near the player.',
    callback: (_) async {
      final scene = IslandAutomationState.scene;
      if (scene == null) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      final landmark = scene.nearbyLandmark;
      final completed = scene.performNearbyObjective();
      return MarionetteExtensionResult.success({
        'landmark': landmark?.id,
        'completed': completed,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.performContextAction',
    description: 'Run the same context action as the mobile action button.',
    callback: (_) async {
      final scene = IslandAutomationState.scene;
      if (scene == null) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      final changed = scene.performContextAction();
      return MarionetteExtensionResult.success({
        'changed': changed,
        'label': scene.contextActionLabel,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.chooseEnding',
    description: 'Choose rescue or stay after completing the summit relay.',
    callback: (params) async {
      final controller = IslandAutomationState.controller;
      final choice = switch (params['choice']) {
        'rescue' => EndingChoice.rescue,
        'stay' => EndingChoice.stay,
        _ => null,
      };
      if (controller == null || choice == null) {
        return MarionetteExtensionResult.invalidParams(
          'Required: choice=rescue/stay.',
        );
      }
      controller.chooseEnding(choice);
      return MarionetteExtensionResult.success({
        'ending': controller.endingChoice.name,
      });
    },
  );

  registerMarionetteExtension(
    name: 'madogiwa.advanceCampaign',
    description: 'Complete the current chapter with deterministic debug state.',
    callback: (_) async {
      final scene = IslandAutomationState.scene;
      final controller = IslandAutomationState.controller;
      if (scene == null || controller == null) {
        return MarionetteExtensionResult.error(1, 'Island is not ready.');
      }
      final from = controller.chapter.name;
      final advanced = scene.automationAdvanceChapter();
      return MarionetteExtensionResult.success({
        'from': from,
        'to': controller.chapter.name,
        'advanced': advanced,
        'endingAvailable': controller.endingAvailable,
      });
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
