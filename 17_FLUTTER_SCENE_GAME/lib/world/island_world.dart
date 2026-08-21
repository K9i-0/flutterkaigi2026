import 'dart:math' as math;

class IslandWorld {
  const IslandWorld._();

  static const worldSize = 256;
  static const worldHalfSize = worldSize ~/ 2;
  static const chunkSize = 16;
  static const chunksPerAxis = worldSize ~/ chunkSize;
  static const minChunk = -worldHalfSize ~/ chunkSize;
  static const maxChunk = minChunk + chunksPerAxis - 1;
  static const islandRadius = 118.0;
  static const renderRadiusChunks = 2;
  static const simulationRadiusChunks = 1;
  static const minTerrainY = -8;
  static const maxBuildY = 23;

  static bool containsCell(int x, int z) =>
      x >= -worldHalfSize &&
      x < worldHalfSize &&
      z >= -worldHalfSize &&
      z < worldHalfSize;

  static int chunkForCoordinate(double value) => (value / chunkSize).floor();

  static int surfaceHeight(int x, int z) {
    if (!containsCell(x, z)) return -3;
    final distance = math.sqrt((x * x + z * z).toDouble());
    if (distance > islandRadius) return -3;
    if (distance < 9) return 0;

    final broad =
        math.sin(x * 0.061) * 1.45 +
        math.cos(z * 0.054) * 1.25 +
        math.sin((x + z) * 0.029) * 1.15 +
        math.cos((x - z) * 0.037) * 0.85;
    final detail = (_hash01(x, z, 941) - 0.5) * 1.2;
    final coastRise = ((islandRadius - distance) / 20).clamp(0.0, 1.0);
    final height = (-1 + coastRise * 2.2 + broad + detail).floor();
    final maxHeightFromCamp = ((distance - 7) / 4).floor().clamp(0, 7);
    return height.clamp(0, maxHeightFromCamp);
  }

  static double surfaceY(int x, int z) => surfaceHeight(x, z) + 1.0;

  static bool isLand(int x, int z) => surfaceHeight(x, z) >= 0;

  static bool isSand(int x, int z) {
    final distance = math.sqrt((x * x + z * z).toDouble());
    return surfaceHeight(x, z) <= 1 || distance > islandRadius - 13;
  }

  /// Returns 1 for tree, 2 for rock, and 0 for no procedural resource.
  static int resourceCode(int x, int z) {
    if (!isLand(x, z) || x.abs() < 7 && z.abs() < 7) return 0;
    final slope = _maxNeighborHeightDelta(x, z);
    if (slope > 1) return 0;
    final roll = _hash(x, z, 2718).abs();
    if (!isSand(x, z) && roll % 97 == 0) return 1;
    if (roll % 241 == 0) return 2;
    return 0;
  }

  static int _maxNeighborHeightDelta(int x, int z) {
    final center = surfaceHeight(x, z);
    var maximum = 0;
    for (final offset in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      maximum = math.max(
        maximum,
        (surfaceHeight(x + offset.$1, z + offset.$2) - center).abs(),
      );
    }
    return maximum;
  }

  static double _hash01(int x, int z, int seed) =>
      (_hash(x, z, seed) & 0x7fffffff) / 0x7fffffff;

  static int _hash(int x, int z, int seed) {
    var value = x * 0x1f1f1f1f ^ z * 0x5f356495 ^ seed;
    value = (value ^ (value >> 15)) * 0x2c1b3c6d;
    value = (value ^ (value >> 12)) * 0x297a2d39;
    return value ^ (value >> 15);
  }
}

class ChunkCoordinate {
  const ChunkCoordinate(this.x, this.z);

  final int x;
  final int z;

  bool get isInsideWorld =>
      x >= IslandWorld.minChunk &&
      x <= IslandWorld.maxChunk &&
      z >= IslandWorld.minChunk &&
      z <= IslandWorld.maxChunk;

  @override
  bool operator ==(Object other) =>
      other is ChunkCoordinate && other.x == x && other.z == z;

  @override
  int get hashCode => Object.hash(x, z);
}
