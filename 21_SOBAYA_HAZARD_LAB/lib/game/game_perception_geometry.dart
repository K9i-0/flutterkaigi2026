part of 'game_state.dart';

/// Breakables participate in sight and hearing without stealing the separate
/// shot hit that actually breaks them. Their cover disappears when broken.
extension HazardPerceptionGeometry on HazardGameState {
  Iterable<Obstacle> get perceptionObstacles sync* {
    yield* collisionObstacles;
    for (final c in crates.where((c) => !c.broken)) {
      yield c.sightObstacle;
    }
  }

  double sightDistance(
    vm.Vector3 origin,
    vm.Vector3 direction,
    double maxDistance,
  ) {
    var limit = maxDistance;
    for (final obstacle in perceptionObstacles) {
      if (obstacle.id == 'gate' && gateOpen) continue;
      final hit = obstacle.ray(origin, direction, limit);
      if (hit != null) limit = math.min(limit, hit);
    }
    return limit;
  }
}
