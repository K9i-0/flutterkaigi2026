import 'package:flutter_test/flutter_test.dart';
import 'package:madogiwa_island_craft/game/island_game_controller.dart';
import 'package:madogiwa_island_craft/world/chunk_mesh_builder.dart';
import 'package:madogiwa_island_craft/world/island_world.dart';

void main() {
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
