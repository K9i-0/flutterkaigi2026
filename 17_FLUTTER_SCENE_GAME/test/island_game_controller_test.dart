import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_island_craft/game/island_game_controller.dart';
import 'package:madogiwa_island_craft/game/movement_math.dart';
import 'package:madogiwa_island_craft/game/terrain_picker.dart';
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

    test('party jump boost doubles climb and arc height', () {
      expect(
        canTraverseHeight(
          currentHeight: 0,
          targetHeight: 2.5,
          maxClimb: maxJumpClimb * 2,
        ),
        isTrue,
      );
      expect(
        canTraverseHeight(
          currentHeight: 0,
          targetHeight: 2.501,
          maxClimb: maxJumpClimb * 2,
        ),
        isFalse,
      );
      expect(jumpArcOffset(0.5, height: jumpArcHeight * 2), jumpArcHeight * 2);
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

  group('terrain tap picking', () {
    test('selects the exact voxel top on either side of a cell boundary', () {
      GridCell? pick(double x) => pickTerrainTopCell(
        originX: x,
        originY: 10,
        originZ: 0,
        directionX: 0,
        directionY: -1,
        directionZ: 0,
        centerX: 0,
        centerZ: 0,
      );

      expect(pick(0.49), const GridCell(0, 0));
      expect(pick(0.51), const GridCell(1, 0));
    });

    test('uses the visible top face for an oblique camera ray', () {
      final picked = pickTerrainTopCell(
        originX: 0,
        originY: 10,
        originZ: 10,
        directionX: 0,
        directionY: -9,
        directionZ: -10,
        centerX: 0,
        centerZ: 3,
      );

      expect(picked, const GridCell(0, 0));
    });
  });

  group('IslandGameController', () {
    test('objective HUD progress reports construction and missing items', () {
      final controller = IslandGameController();

      expect(controller.chapterObjectiveProgress, contains('床 0/4'));
      controller
        ..grantDebugResources(11)
        ..buildAt(BuildBlueprint.house, const GridCell(-1, 0));
      expect(controller.chapterObjective, contains('焚き火'));
      expect(controller.chapterObjectiveProgress, contains('必要素材は揃って'));

      controller.wood = 0;
      expect(controller.chapterObjectiveProgress, contains('木材 あと1'));
    });

    test('reunion order unlocks the three party abilities', () {
      final controller = IslandGameController();

      expect(controller.autoGatherUnlocked, isFalse);
      expect(controller.doubleJumpUnlocked, isFalse);
      expect(controller.nightVisionUnlocked, isFalse);

      controller
        ..reuniteMember('yumemin', 'ゆめみん')
        ..reuniteMember('yametaro', 'やめ太郎')
        ..reuniteMember('takosan', 'タコさん');

      expect(controller.reunitedMembers.toList(), [
        'yumemin',
        'yametaro',
        'takosan',
      ]);
      expect(controller.autoGatherUnlocked, isTrue);
      expect(controller.doubleJumpUnlocked, isTrue);
      expect(controller.nightVisionUnlocked, isTrue);
    });

    test(
      'auto gather collects harvestable resources without changing mode',
      () {
        final controller = IslandGameController()
          ..selectTool(IslandTool.build)
          ..selectBuildTarget(const GridCell(0, 0));

        final result = controller.autoHarvestAt(const GridCell(-3, -1));

        expect(result.kind, IslandActionKind.treeHarvested);
        expect(controller.wood, 2);
        expect(controller.tool, IslandTool.build);
        expect(controller.selectedCell, const GridCell(0, 0));
      },
    );

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

    test(
      'build mode places a selected blueprint without leaving build mode',
      () {
        final controller = IslandGameController()
          ..grantDebugResources(1)
          ..selectTool(IslandTool.build);

        final result = controller.buildAt(
          BuildBlueprint.floor,
          const GridCell(0, 0),
        );

        expect(result.kind, IslandActionKind.floorPlaced);
        expect(controller.tool, IslandTool.build);
        expect(controller.selectedCell, const GridCell(0, 0));
      },
    );

    test('house blueprint completes a two by two home in one action', () {
      final controller = IslandGameController()..grantDebugResources(10);

      final result = controller.buildAt(
        BuildBlueprint.house,
        const GridCell(0, 0),
      );

      expect(result.kind, IslandActionKind.housePlaced);
      expect(controller.homeComplete, isTrue);
      expect(controller.structures.length, 4);
      expect(controller.structures.values, everyElement(BuildLevel.wall));
      expect(controller.wood, 0);
      expect(controller.stone, 6);
    });

    test(
      'one-shot house, campfire, and workbench advance the beach chapter',
      () {
        final controller = IslandGameController()..grantDebugResources(20);

        expect(
          controller
              .buildAt(BuildBlueprint.house, const GridCell(0, 0))
              .changed,
          isTrue,
        );
        expect(controller.chapterObjective, contains('焚き火'));

        expect(controller.craft(CraftRecipe.campfire), isTrue);
        expect(controller.chapter, GameChapter.beach);
        expect(controller.chapterObjective, contains('作業台'));
        expect(controller.message, contains('次:'));

        expect(controller.craft(CraftRecipe.workbench), isTrue);
        expect(controller.chapter, GameChapter.forest);
        expect(controller.chapterObjective, contains('石の斧'));
      },
    );

    test('crafting explains prerequisites and quarry starts with reunion', () {
      final controller = IslandGameController();

      expect(
        controller.craftFailureReason(CraftRecipe.workbench),
        contains('小屋'),
      );
      expect(
        controller.craftFailureReason(CraftRecipe.stonePickaxe),
        contains('作業台'),
      );

      controller
        ..grantDebugResources()
        ..chapter = GameChapter.quarry
        ..craftedRecipes.add(CraftRecipe.workbench);
      expect(controller.chapterObjective, contains('ゆめみん'));
      expect(
        controller.craftFailureReason(CraftRecipe.ironPickaxe),
        contains('ゆめみん'),
      );
      final yumeminDistance = math.sqrt(64 * 64 + 44 * 44);
      expect(
        controller.explorationLimit,
        greaterThanOrEqualTo(yumeminDistance - 2.6),
      );

      controller
        ..reuniteMember('yumemin', 'ゆめみん')
        ..craftedRecipes.add(CraftRecipe.ironPickaxe);
      expect(controller.explorationLimit, 86);
    });

    test(
      'house blueprint rejects occupied or underfunded sites atomically',
      () {
        final controller = IslandGameController();

        expect(
          controller
              .buildAt(BuildBlueprint.house, const GridCell(0, 0))
              .changed,
          isFalse,
        );
        expect(controller.structures, isEmpty);
        expect(controller.homeComplete, isFalse);

        controller
          ..grantDebugResources(10)
          ..resources[const GridCell(1, 1)] = IslandResource.rock;
        expect(
          controller
              .buildAt(BuildBlueprint.house, const GridCell(0, 0))
              .changed,
          isFalse,
        );
        expect(controller.structures, isEmpty);
      },
    );

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
      expect(controller.chapterObjective, contains('救助信号'));

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
