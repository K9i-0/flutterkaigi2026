import 'dart:math' as math;

import 'coastal_grid.dart';
import 'island_world.dart';

class Plant {
  const Plant(this.x, this.y, this.z, this.size, this.seed, this.kind);
  final double x, y, z, size;
  final int seed;
  final String kind;
}

/// Seeded ecological patches; placement does not depend on frame rate/camera.
class NatureLayout {
  NatureLayout(this.world, {double extent = 600}) {
    final random = math.Random(271828);
    for (double z = -extent; z < extent; z += 7) {
      for (double x = -extent; x < extent; x += 7) {
        final wx = x + random.nextDouble() * 7,
            wz = z + random.nextDouble() * 7;
        final y = CoastalGrid.renderedTerrainHeight(world, wx, wz);
        if (y < 1.1 || y > 85) continue;
        final slope =
            math.max(
              (world.heightAt(wx + 2, wz) - world.heightAt(wx - 2, wz)).abs(),
              (world.heightAt(wx, wz + 2) - world.heightAt(wx, wz - 2)).abs(),
            ) /
            4;
        if (slope > .7) continue;
        final patch =
            .5 +
            .23 * math.sin(wx * .039 + math.sin(wz * .021) * 2) +
            .23 * math.sin(wz * .061 - wx * .027);
        if (random.nextDouble() > patch * .63) continue;
        if (!clear(wx, wz, .7)) continue;
        final seed = random.nextInt(1 << 30);
        grass.add(
          Plant(
            wx,
            y,
            wz,
            .6 + random.nextDouble() * .65,
            seed,
            y < 3 ? 'dune' : 'grass',
          ),
        );
        if (y > 2.8 &&
            trees.length < 520 &&
            random.nextDouble() < .26 &&
            clear(wx, wz, 4)) {
          if (trees.any(
            (t) => math.pow(t.x - wx, 2) + math.pow(t.z - wz, 2) < 70,
          )) {
            continue;
          }
          trees.add(
            Plant(wx, y, wz, 5 + random.nextDouble() * 5, seed, 'tree'),
          );
        } else if (y > 2 && random.nextDouble() < .18 && clear(wx, wz, 1.8)) {
          shrubs.add(
            Plant(wx, y, wz, .7 + random.nextDouble() * .8, seed, 'shrub'),
          );
        }
      }
    }
  }
  final IslandWorld world;
  final grass = <Plant>[], trees = <Plant>[], shrubs = <Plant>[];
  bool clear(double x, double z, double radius) {
    for (final b in world.metadata['buildings'] as List? ?? []) {
      final f = b['footprint'], r = (f['r'] as num) + radius;
      if (math.pow(x - (f['x'] as num), 2) + math.pow(z - (f['z'] as num), 2) <
          r * r) {
        return false;
      }
    }
    for (final b in world.boxes) {
      if (world.overlapsBox(b, x, z, radius)) return false;
    }
    return true;
  }

  void addColliders() {
    for (final t in trees) {
      world.cylinders.add({
        'x': t.x,
        'z': t.z,
        'radius': t.size * .04,
        'yMin': t.y,
        'yMax': t.y + t.size * .78,
        'tag': 'treeTrunk',
      });
    }
  }
}
