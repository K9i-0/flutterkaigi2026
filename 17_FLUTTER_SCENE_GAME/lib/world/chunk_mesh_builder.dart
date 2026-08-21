import 'dart:typed_data';

import 'island_world.dart';

class ChunkMeshPayload {
  const ChunkMeshPayload({
    required this.coordinate,
    required this.positions,
    required this.normals,
    required this.colors,
    required this.indices,
    required this.quadCount,
  });

  final ChunkCoordinate coordinate;
  final Float32List positions;
  final Float32List normals;
  final Float32List colors;
  final List<int> indices;
  final int quadCount;
}

List<ChunkMeshPayload> buildChunkMeshBatch(List<(int, int)> coordinates) =>
    coordinates
        .map(
          (coordinate) =>
              buildChunkMesh(ChunkCoordinate(coordinate.$1, coordinate.$2)),
        )
        .toList(growable: false);

ChunkMeshPayload buildChunkMesh(ChunkCoordinate coordinate) {
  final positions = <double>[];
  final normals = <double>[];
  final colors = <double>[];
  final indices = <int>[];
  var quadCount = 0;
  final originX = coordinate.x * IslandWorld.chunkSize;
  final originZ = coordinate.z * IslandWorld.chunkSize;

  for (var localX = 0; localX < IslandWorld.chunkSize; localX++) {
    for (var localZ = 0; localZ < IslandWorld.chunkSize; localZ++) {
      final worldX = originX + localX;
      final worldZ = originZ + localZ;
      final height = IslandWorld.surfaceHeight(worldX, worldZ);
      if (height < 0) continue;
      final topY = height + 1.0;
      final topColor = IslandWorld.isSand(worldX, worldZ)
          ? const (0.88, 0.68, 0.35, 1.0)
          : const (0.18, 0.58, 0.25, 1.0);

      _addQuad(
        positions,
        normals,
        colors,
        indices,
        vertices: [
          (localX - 0.5, topY, localZ - 0.5),
          (localX - 0.5, topY, localZ + 0.5),
          (localX + 0.5, topY, localZ + 0.5),
          (localX + 0.5, topY, localZ - 0.5),
        ],
        normal: const (0.0, 1.0, 0.0),
        color: topColor,
      );
      quadCount++;

      for (final side in const [(1, 0, 0), (-1, 0, 1), (0, 1, 2), (0, -1, 3)]) {
        final neighborHeight = IslandWorld.surfaceHeight(
          worldX + side.$1,
          worldZ + side.$2,
        );
        if (neighborHeight >= height) continue;
        for (var blockY = neighborHeight + 1; blockY <= height; blockY++) {
          final color = blockY < height - 2
              ? const (0.3, 0.32, 0.34, 1.0)
              : const (0.34, 0.2, 0.09, 1.0);
          _addSideQuad(
            positions,
            normals,
            colors,
            indices,
            localX: localX,
            localZ: localZ,
            bottomY: blockY.toDouble(),
            side: side.$3,
            color: color,
          );
          quadCount++;
        }
      }
    }
  }

  return ChunkMeshPayload(
    coordinate: coordinate,
    positions: Float32List.fromList(positions),
    normals: Float32List.fromList(normals),
    colors: Float32List.fromList(colors),
    indices: indices,
    quadCount: quadCount,
  );
}

void _addSideQuad(
  List<double> positions,
  List<double> normals,
  List<double> colors,
  List<int> indices, {
  required int localX,
  required int localZ,
  required double bottomY,
  required int side,
  required (double, double, double, double) color,
}) {
  final x0 = localX - 0.5;
  final x1 = localX + 0.5;
  final z0 = localZ - 0.5;
  final z1 = localZ + 0.5;
  final y0 = bottomY;
  final y1 = bottomY + 1;
  switch (side) {
    case 0:
      _addQuad(
        positions,
        normals,
        colors,
        indices,
        vertices: [(x1, y0, z0), (x1, y1, z0), (x1, y1, z1), (x1, y0, z1)],
        normal: const (1.0, 0.0, 0.0),
        color: color,
      );
      break;
    case 1:
      _addQuad(
        positions,
        normals,
        colors,
        indices,
        vertices: [(x0, y0, z1), (x0, y1, z1), (x0, y1, z0), (x0, y0, z0)],
        normal: const (-1.0, 0.0, 0.0),
        color: color,
      );
      break;
    case 2:
      _addQuad(
        positions,
        normals,
        colors,
        indices,
        vertices: [(x1, y0, z1), (x1, y1, z1), (x0, y1, z1), (x0, y0, z1)],
        normal: const (0.0, 0.0, 1.0),
        color: color,
      );
      break;
    case 3:
      _addQuad(
        positions,
        normals,
        colors,
        indices,
        vertices: [(x0, y0, z0), (x0, y1, z0), (x1, y1, z0), (x1, y0, z0)],
        normal: const (0.0, 0.0, -1.0),
        color: color,
      );
      break;
  }
}

void _addQuad(
  List<double> positions,
  List<double> normals,
  List<double> colors,
  List<int> indices, {
  required List<(double, double, double)> vertices,
  required (double, double, double) normal,
  required (double, double, double, double) color,
}) {
  final base = positions.length ~/ 3;
  for (final vertex in vertices) {
    positions.addAll([vertex.$1, vertex.$2, vertex.$3]);
    normals.addAll([normal.$1, normal.$2, normal.$3]);
    colors.addAll([color.$1, color.$2, color.$3, color.$4]);
  }
  // flutter_scene treats clockwise triangles as front-facing in model space.
  indices.addAll([base, base + 2, base + 1, base, base + 3, base + 2]);
}
