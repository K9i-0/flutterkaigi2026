import 'dart:math' as math;

typedef FloorSampler = double Function(double x, double z, double previous);
typedef NavigationCollision = bool Function(double x, double z, double y);

class NavigationTransition {
  const NavigationTransition(this.from, this.to);
  final (double, double, double) from, to;
}

class NavigationPoint {
  NavigationPoint(this.id, this.x, this.y, this.z);
  final int id;
  final double x, y, z;
  final links = <int>[];
  final incoming = <int>[];
}

/// Shared flow over actual floor heights. Static geometry is sampled once;
/// doors and breakables are checked when the destination field is refreshed.
class EnemyNavigation {
  EnemyNavigation(
    this.height,
    this.staticBlocked, {
    List<NavigationTransition> transitions = const [],
  }) : points = {} {
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < columns; col++) {
        final x = minX + (col + .5) * spacing;
        final z = minZ + (row + .5) * spacing;
        final ground = height(x, z, 0), upper = height(x, z, 6);
        for (var layer = 0; layer < 2; layer++) {
          if (layer == 1 && (upper - ground).abs() < .05) continue;
          final y = layer == 0 ? ground : upper;
          if (staticBlocked(x, z, y)) continue;
          final id = _id(col, row, layer);
          points[id] = NavigationPoint(id, x, y, z);
        }
      }
    }
    for (final point in points.values) {
      final cell = point.id % cells,
          col = cell % columns,
          row = cell ~/ columns;
      for (var dz = -1; dz <= 1; dz++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dz == 0) continue;
          if (col + dx < 0 ||
              col + dx >= columns ||
              row + dz < 0 ||
              row + dz >= rows) {
            continue;
          }
          for (var layer = 0; layer < 2; layer++) {
            final other = points[_id(col + dx, row + dz, layer)];
            if (other != null && walkableEdge(point, other)) {
              point.links.add(other.id);
              other.incoming.add(point.id);
            }
          }
        }
      }
    }
    for (final t in transitions) {
      final a = nearest(t.from.$1, t.from.$2, t.from.$3);
      final b = nearest(t.to.$1, t.to.$2, t.to.$3);
      if (a == null || b == null) continue;
      a.links.add(b.id);
      b.incoming.add(a.id);
      b.links.add(a.id);
      a.incoming.add(b.id);
    }
  }

  EnemyNavigation._shared(this.height, this.staticBlocked, this.points);

  /// Geometry is immutable after construction; each run owns its flow distances.
  EnemyNavigation fork() =>
      EnemyNavigation._shared(height, staticBlocked, points);

  static const spacing = .5, minX = -23.0, minZ = -25.0;
  static const columns = 92, rows = 110, cells = columns * rows;
  final FloorSampler height;
  final NavigationCollision staticBlocked;
  final Map<int, NavigationPoint> points;
  final distances = <int, int>{};
  NavigationPoint? _target;
  int _id(int col, int row, int layer) => layer * cells + row * columns + col;

  bool walkableEdge(NavigationPoint from, NavigationPoint to) {
    var y = from.y;
    for (var i = 1; i <= 8; i++) {
      final x = from.x + (to.x - from.x) * i / 8;
      final z = from.z + (to.z - from.z) * i / 8;
      final next = height(x, z, y);
      if (next > y + .34 || next < y - .4 || staticBlocked(x, z, next)) {
        return false;
      }
      y = next;
    }
    return (y - to.y).abs() < .05;
  }

  NavigationPoint? nearest(
    double x,
    double y,
    double z, {
    NavigationCollision? blocked,
  }) {
    final col = ((x - minX) / spacing).floor();
    final row = ((z - minZ) / spacing).floor();
    NavigationPoint? best;
    var score = double.infinity;
    for (var dz = -2; dz <= 2; dz++) {
      for (var dx = -2; dx <= 2; dx++) {
        if (col + dx < 0 ||
            col + dx >= columns ||
            row + dz < 0 ||
            row + dz >= rows) {
          continue;
        }
        for (var layer = 0; layer < 2; layer++) {
          final p = points[_id(col + dx, row + dz, layer)];
          if (p == null ||
              (p.y - y).abs() > .65 ||
              (blocked?.call(p.x, p.z, p.y) ?? false)) {
            continue;
          }
          final d =
              math.pow(p.x - x, 2) +
              math.pow(p.z - z, 2) +
              4 * math.pow(p.y - y, 2);
          if (d < score) {
            score = d.toDouble();
            best = p;
          }
        }
      }
    }
    return best;
  }

  void update(double x, double y, double z, NavigationCollision blocked) {
    distances.clear();
    final start = nearest(x, y, z, blocked: blocked);
    if (start == null) {
      _target = null;
      return;
    }
    _target = NavigationPoint(-1, x, y, z);
    final queue = <int>[start.id], usable = <int, bool>{start.id: true};
    distances[start.id] = 0;
    for (var i = 0; i < queue.length; i++) {
      final p = points[queue[i]]!;
      for (final next in p.incoming) {
        if (distances.containsKey(next)) continue;
        final q = points[next]!;
        if (!(usable[next] ??= !blocked(q.x, q.z, q.y))) continue;
        distances[next] = distances[p.id]! + 1;
        queue.add(next);
      }
    }
  }

  bool transitionLeadsCloser(
    (double, double, double) from,
    (double, double, double) to,
  ) {
    final a = nearest(from.$1, from.$2, from.$3),
        b = nearest(to.$1, to.$2, to.$3);
    final da = a == null ? null : distances[a.id],
        db = b == null ? null : distances[b.id];
    return da != null && db != null && db < da;
  }

  NavigationPoint? waypoint(double x, double y, double z) {
    final here = nearest(x, y, z);
    if (here == null || !distances.containsKey(here.id)) return null;
    var depth = distances[here.id]!;
    if (depth == 0) return _target;
    var best = here;
    final actual = NavigationPoint(-1, x, y, z);
    for (final id in here.links) {
      final next = distances[id];
      if (next != null && next < depth && walkableEdge(actual, points[id]!)) {
        depth = next;
        best = points[id]!;
      }
    }
    return best;
  }
}
