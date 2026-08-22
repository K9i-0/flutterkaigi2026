import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_island_craft/game/island_game_controller.dart';
import 'package:madogiwa_island_craft/game/movement_math.dart';
import 'package:madogiwa_island_craft/game/visual_math.dart';
import 'package:madogiwa_island_craft/world/chunk_mesh_builder.dart';
import 'package:madogiwa_island_craft/world/island_world.dart';

void main() {
  group('day and night visuals', () {
    test('sun and phase helpers identify noon, twilight, and midnight', () {
      expect(daylightForTime(0.5), closeTo(1, 0.000001));
      expect(daylightForTime(0), closeTo(0, 0.000001));
      expect(moonlightForTime(0.5), closeTo(0, 0.000001));
      expect(moonlightForTime(0), closeTo(1, 0.000001));
      expect(twilightForTime(0.25), closeTo(1, 0.000001));
      expect(solarTimeForClock(0.5), closeTo(0.5, 0.000001));
      expect(sunElevationForTime(solarTimeForClock(0.75)), greaterThan(0.45));
      expect(
        sunElevationForTime(solarTimeForClock(0.875)),
        closeTo(0, 0.000001),
      );
      expect(phaseLabelForTime(0.5), '昼');
      expect(phaseLabelForTime(0.7), '夕方');
      expect(phaseLabelForTime(0.86), '夕方');
      expect(phaseLabelForTime(0.88), '夜');
      expect(clockLabelForTime(0.5), '12:00');
    });

    test('golden hour advances more slowly than daytime', () {
      expect(timeFlowRate(0.72), lessThan(timeFlowRate(0.5)));
      final dayAdvance = advanceTimeOfDay(0.5, 60) - 0.5;
      final eveningAdvance = advanceTimeOfDay(0.72, 60) - 0.72;
      expect(eveningAdvance, lessThan(dayAdvance));
    });
  });

  group('character movement direction', () {
    test('jump traversal allows 1.25 blocks but rejects higher cliffs', () {
      expect(canTraverseHeight(currentHeight: 0, targetHeight: 1.25), isTrue);
      expect(canTraverseHeight(currentHeight: 0, targetHeight: 1.251), isFalse);
      expect(canTraverseHeight(currentHeight: 2, targetHeight: 0.75), isTrue);
      expect(canTraverseHeight(currentHeight: 0, targetHeight: -0.01), isFalse);
    });

    test('jump arc reaches 1.25 blocks at its apex', () {
      expect(jumpArcOffset(0), 0);
      expect(jumpArcOffset(0.5), jumpArcHeight);
      expect(jumpArcOffset(1), 0);
    });

    test('canonical -Z facing follows every cardinal movement direction', () {
      expect(characterFacingYaw(0, -1), closeTo(0, 0.000001));
      expect(characterFacingYaw(-1, 0), closeTo(math.pi / 2, 0.000001));
      expect(characterFacingYaw(0, 1).abs(), closeTo(math.pi, 0.000001));
      expect(characterFacingYaw(1, 0), closeTo(-math.pi / 2, 0.000001));
    });

    test('screen arrows follow flutter_scene camera handedness', () {
      final left = cameraRelativeMovement(yaw: 0, right: -1, forward: 0);
      final right = cameraRelativeMovement(yaw: 0, right: 1, forward: 0);
      final forward = cameraRelativeMovement(yaw: 0, right: 0, forward: 1);

      expect(left, (1.0, 0.0));
      expect(right, (-1.0, 0.0));
      expect(forward, (0.0, -1.0));
    });
  });

  group('IslandGameController', () {
    test('tree and rock harvesting adds canonical build resources', () {
      final controller = IslandGameController();

      final tree = controller.actOn(const GridCell(-3, -1));
      final rock = controller.actOn(const GridCell(-2, -3));

      expect(tree.kind, IslandActionKind.treeHarvested);
      expect(rock.kind, IslandActionKind.rockHarvested);
      expect(controller.wood, 2);
      expect(controller.stone, 2);
    });

    test('build actions enforce floor and material prerequisites', () {
      final controller = IslandGameController()..selectTool(IslandTool.wall);

      final result = controller.actOn(const GridCell(-1, 0));

      expect(result.changed, isFalse);
      expect(controller.wallsBuilt, 0);
      expect(controller.message, contains('床'));
    });

    test('harvesting all resources can complete the four-block house', () {
      final controller = IslandGameController();
      const resourceCells = [
        GridCell(-3, -1),
        GridCell(3, -1),
        GridCell(-3, 2),
        GridCell(3, 2),
        GridCell(0, -3),
        GridCell(-2, -3),
        GridCell(2, -3),
      ];
      for (final cell in resourceCells) {
        controller.actOn(cell);
      }
      expect(controller.wood, 10);
      expect(controller.stone, 4);

      controller.selectTool(IslandTool.floor);
      for (final cell in IslandGameController.buildZone) {
        expect(controller.actOn(cell).kind, IslandActionKind.floorPlaced);
      }
      controller.selectTool(IslandTool.wall);
      for (final cell in IslandGameController.buildZone) {
        expect(controller.actOn(cell).kind, IslandActionKind.wallPlaced);
      }
      controller.selectTool(IslandTool.roof);
      final result = controller.actOn(IslandGameController.buildZone.first);

      expect(result.kind, IslandActionKind.roofPlaced);
      expect(controller.homeComplete, isTrue);
      expect(controller.wood, 0);
      expect(controller.stone, 0);
    });

    test('construction can start away from the recommended camp', () {
      final controller = IslandGameController()
        ..actOn(const GridCell(-3, -1))
        ..selectTool(IslandTool.floor);

      final result = controller.actOn(const GridCell(20, 20));

      expect(result.kind, IslandActionKind.floorPlaced);
      expect(controller.floorsBuilt, 1);
    });

    test('one wood places a torch while the camp torch remains free', () {
      final controller = IslandGameController()
        ..actOn(const GridCell(-3, -1))
        ..selectTool(IslandTool.torch);

      final result = controller.actOn(const GridCell(5, 5));

      expect(result.kind, IslandActionKind.torchPlaced);
      expect(controller.wood, 1);
      expect(controller.torches, contains(const GridCell(2, 2)));
      expect(controller.torches, contains(const GridCell(5, 5)));
    });

    test('coal and iron require a stone pickaxe', () {
      const coalCell = GridCell(10, 10);
      final controller = IslandGameController();
      controller.resources[coalCell] = IslandResource.coal;

      expect(controller.actOn(coalCell).changed, isFalse);
      expect(controller.resources[coalCell], IslandResource.coal);

      controller.grantDebugResources();
      controller.craftedRecipes.add(CraftRecipe.workbench);
      expect(controller.craft(CraftRecipe.stonePickaxe), isTrue);
      expect(controller.actOn(coalCell).kind, IslandActionKind.coalHarvested);
      expect(controller.coal, greaterThan(99));
    });

    test('campaign advances from beach construction to both endings', () {
      final controller = IslandGameController()..grantDebugResources();

      controller.selectTool(IslandTool.floor);
      for (final cell in IslandGameController.buildZone) {
        controller.actOn(cell);
      }
      controller.selectTool(IslandTool.wall);
      for (final cell in IslandGameController.buildZone) {
        controller.actOn(cell);
      }
      controller.selectTool(IslandTool.roof);
      controller.actOn(IslandGameController.buildZone.first);
      expect(controller.chapter, GameChapter.beach);

      expect(controller.craft(CraftRecipe.campfire), isTrue);
      expect(controller.craft(CraftRecipe.workbench), isTrue);
      expect(controller.chapter, GameChapter.forest);
      expect(controller.explorationLimit, 38);

      expect(controller.craft(CraftRecipe.stoneAxe), isTrue);
      expect(controller.craft(CraftRecipe.stonePickaxe), isTrue);
      expect(controller.craft(CraftRecipe.bridgeKit), isTrue);
      controller.reuniteMember('yametaro', 'やめ太郎');
      expect(controller.completeLandmark('radio_tower'), isTrue);
      expect(controller.chapter, GameChapter.quarry);

      controller.reuniteMember('yumemin', 'ゆめみん');
      expect(controller.craft(CraftRecipe.ironPickaxe), isTrue);
      expect(controller.craft(CraftRecipe.forge), isTrue);
      expect(controller.completeLandmark('office_wreck'), isTrue);
      expect(controller.chapter, GameChapter.marsh);

      expect(controller.craft(CraftRecipe.fogGear), isTrue);
      controller.reuniteMember('takosan', 'タコさん');
      expect(controller.completeLandmark('octopus_shrine'), isTrue);
      expect(controller.chapter, GameChapter.summit);
      expect(controller.completeLandmark('summit_relay'), isTrue);
      expect(controller.endingAvailable, isTrue);

      controller.chooseEnding(EndingChoice.rescue);
      expect(controller.endingChoice, EndingChoice.rescue);
      controller.chooseEnding(EndingChoice.stay);
      expect(controller.campaignComplete, isTrue);
      expect(controller.chapter, GameChapter.complete);
      expect(controller.chapterObjective, contains('発展'));
    });
  });

  group('256x256 chunk world', () {
    test('world is split into sixteen chunks per axis', () {
      expect(IslandWorld.worldSize, 256);
      expect(IslandWorld.chunksPerAxis, 16);
      expect(IslandWorld.minChunk, -8);
      expect(IslandWorld.maxChunk, 7);
      expect(const ChunkCoordinate(-8, -8).isInsideWorld, isTrue);
      expect(const ChunkCoordinate(8, 0).isInsideWorld, isFalse);
      expect(IslandWorld.chunkForCoordinate(-0.1), -1);
      expect(IslandWorld.chunkForCoordinate(15.9), 0);
      expect(IslandWorld.chunkForCoordinate(16), 1);
    });

    test('terrain is deterministic and surrounded by ocean', () {
      expect(IslandWorld.surfaceHeight(0, 0), 0);
      expect(IslandWorld.isLand(32, 17), isTrue);
      expect(IslandWorld.surfaceHeight(127, 127), -3);
      expect(IslandWorld.surfaceHeight(-128, -128), -3);
      expect(IslandWorld.surfaceHeight(128, 0), -3);
    });

    test('generated cliffs higher than the jump limit are impassable', () {
      (int from, int to)? cliff;
      for (
        var z = -IslandWorld.worldHalfSize;
        z < IslandWorld.worldHalfSize && cliff == null;
        z++
      ) {
        for (
          var x = -IslandWorld.worldHalfSize;
          x < IslandWorld.worldHalfSize - 1;
          x++
        ) {
          final from = IslandWorld.surfaceHeight(x, z);
          final to = IslandWorld.surfaceHeight(x + 1, z);
          if (from >= 0 && to - from > maxJumpClimb) {
            cliff = (from, to);
            break;
          }
        }
      }

      expect(cliff, isNotNull);
      expect(
        canTraverseHeight(
          currentHeight: cliff!.$1.toDouble(),
          targetHeight: cliff.$2.toDouble(),
        ),
        isFalse,
      );
    });

    test('campaign trails remain jumpable from camp to every landmark', () {
      const destinations = [(-38, -30), (64, -48), (55, 76), (-30, 107)];
      for (final destination in destinations) {
        var previousHeight = 0;
        for (var step = 1; step <= 160; step++) {
          final t = step / 160;
          final x = (destination.$1 * t).round();
          final z = (destination.$2 * t).round();
          final height = IslandWorld.surfaceHeight(x, z);
          expect(
            (height - previousHeight).abs(),
            lessThanOrEqualTo(1),
            reason: 'trail to $destination failed at $x,$z',
          );
          previousHeight = height;
        }
      }
    });

    test('one chunk is batched into an indexed vertex-colored mesh', () {
      final payload = buildChunkMesh(const ChunkCoordinate(0, 0));

      expect(payload.coordinate, const ChunkCoordinate(0, 0));
      expect(payload.quadCount, greaterThanOrEqualTo(256));
      expect(payload.positions.length, payload.quadCount * 4 * 3);
      expect(payload.normals.length, payload.quadCount * 4 * 3);
      expect(payload.colors.length, payload.quadCount * 4 * 4);
      expect(payload.indices.length, payload.quadCount * 6);
      expect(payload.indices.take(6), [0, 2, 1, 0, 3, 2]);
    });
  });
}
