import 'dart:math' as math;

import '../world/island_world.dart';
import 'island_game_controller.dart';

/// Finds the first terrain top face intersected by a screen-space camera ray.
///
/// Sampling and rounding along a ray can select the neighbouring voxel when
/// the camera is oblique. This instead intersects the exact horizontal top
/// face of every nearby terrain cell and chooses the closest visible hit.
GridCell? pickTerrainTopCell({
  required double originX,
  required double originY,
  required double originZ,
  required double directionX,
  required double directionY,
  required double directionZ,
  required int centerX,
  required int centerZ,
  int searchRadius = 12,
  double maxRayDistance = 70,
}) {
  final directionLength = math.sqrt(
    directionX * directionX + directionY * directionY + directionZ * directionZ,
  );
  if (directionLength < 0.000001) return null;
  final rayX = directionX / directionLength;
  final rayY = directionY / directionLength;
  final rayZ = directionZ / directionLength;
  if (rayY.abs() < 0.000001 || rayY >= 0) return null;

  GridCell? closestCell;
  var closestDistance = double.infinity;
  final minX = (centerX - searchRadius).clamp(
    -IslandWorld.worldHalfSize,
    IslandWorld.worldHalfSize - 1,
  );
  final maxX = (centerX + searchRadius).clamp(
    -IslandWorld.worldHalfSize,
    IslandWorld.worldHalfSize - 1,
  );
  final minZ = (centerZ - searchRadius).clamp(
    -IslandWorld.worldHalfSize,
    IslandWorld.worldHalfSize - 1,
  );
  final maxZ = (centerZ + searchRadius).clamp(
    -IslandWorld.worldHalfSize,
    IslandWorld.worldHalfSize - 1,
  );

  for (var z = minZ; z <= maxZ; z++) {
    for (var x = minX; x <= maxX; x++) {
      if (!IslandWorld.isLand(x, z)) continue;
      final surfaceY = IslandWorld.surfaceY(x, z);
      final distance = (surfaceY - originY) / rayY;
      if (distance <= 0 ||
          distance > maxRayDistance ||
          distance >= closestDistance) {
        continue;
      }
      final hitX = originX + rayX * distance;
      final hitZ = originZ + rayZ * distance;
      const edgeTolerance = 0.0001;
      if (hitX < x - 0.5 - edgeTolerance ||
          hitX > x + 0.5 + edgeTolerance ||
          hitZ < z - 0.5 - edgeTolerance ||
          hitZ > z + 0.5 + edgeTolerance) {
        continue;
      }
      closestDistance = distance;
      closestCell = GridCell(x, z);
    }
  }
  return closestCell;
}
