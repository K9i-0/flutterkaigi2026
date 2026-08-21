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
    if (isCampaignTrail(x, z)) {
      return ((distance - 9) / 18).floor().clamp(0, 6);
    }

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

  /// Returns 1 tree, 2 rock, 3 berry, 4 coal, 5 iron, 6 herb.
  static int resourceCode(int x, int z) {
    if (!isLand(x, z) || x.abs() < 7 && z.abs() < 7 || isCampaignTrail(x, z)) {
      return 0;
    }
    final slope = _maxNeighborHeightDelta(x, z);
    if (slope > 1) return 0;
    final roll = _hash(x, z, 2718).abs();
    final distance = math.sqrt((x * x + z * z).toDouble());
    if (distance > 70 && roll % 173 == 0) return 6;
    if (distance > 55 && roll % 197 == 0) return 5;
    if (distance > 32 && roll % 211 == 0) return 4;
    if (roll % 181 == 0) return 3;
    if (!isSand(x, z) && roll % 97 == 0) return 1;
    if (roll % 241 == 0) return 2;
    return 0;
  }

  /// Concentric campaign biomes used by exploration and the minimap.
  static int biomeCode(int x, int z) {
    final distance = math.sqrt((x * x + z * z).toDouble());
    if (distance < 26 || isSand(x, z)) return 0;
    if (distance < 64) return 1;
    if (distance < 86) return 2;
    if (distance < 104) return 3;
    return 4;
  }

  /// Guarantees a narrow, jumpable route from camp to every campaign site.
  static bool isCampaignTrail(int x, int z) {
    const destinations = [
      (-38.0, -30.0),
      (64.0, -48.0),
      (55.0, 76.0),
      (-30.0, 107.0),
    ];
    for (final destination in destinations) {
      final lengthSquared =
          destination.$1 * destination.$1 + destination.$2 * destination.$2;
      final t = ((x * destination.$1 + z * destination.$2) / lengthSquared)
          .clamp(0.0, 1.0);
      final closestX = destination.$1 * t;
      final closestZ = destination.$2 * t;
      final dx = x - closestX;
      final dz = z - closestZ;
      if (dx * dx + dz * dz <= 2.1 * 2.1) return true;
    }
    return false;
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
