import 'dart:math' as math;

class Point2 {
  const Point2(this.x, this.z);
  final double x, z;
  Point2 operator +(Point2 p) => Point2(x + p.x, z + p.z);
  Point2 operator -(Point2 p) => Point2(x - p.x, z - p.z);
  Point2 operator *(double n) => Point2(x * n, z * n);
  double get length => math.sqrt(x * x + z * z);
  Point2 get normalized =>
      length < 1e-9 ? const Point2(0, 0) : this * (1 / length);
  double dot(Point2 p) => x * p.x + z * p.z;
  List<double> toJson() => [x, z];
}

class SolidBox {
  const SolidBox(this.x, this.z, this.width, this.depth);
  final double x, z, width, depth;
  bool contains(Point2 p, [double padding = 0]) =>
      (p.x - x).abs() < width / 2 + padding &&
      (p.z - z).abs() < depth / 2 + padding;

  /// Segment hit distance from origin, including a hit when starting inside.
  double? ray(Point2 origin, Point2 direction, double range) {
    var near = 0.0, far = range;
    for (final (p, d, low, high) in [
      (origin.x, direction.x, x - width / 2, x + width / 2),
      (origin.z, direction.z, z - depth / 2, z + depth / 2),
    ]) {
      if (d.abs() < 1e-9) {
        if (p < low || p > high) return null;
        continue;
      }
      final a = (low - p) / d, b = (high - p) / d;
      near = math.max(near, math.min(a, b));
      far = math.min(far, math.max(a, b));
      if (near > far) return null;
    }
    return near;
  }
}

class CollisionWorld {
  CollisionWorld(Iterable<SolidBox> boxes) : boxes = List.unmodifiable(boxes);
  final List<SolidBox> boxes;
  Point2 move(Point2 origin, Point2 delta, {double radius = .3}) {
    if (!delta.x.isFinite ||
        !delta.z.isFinite ||
        !radius.isFinite ||
        radius <= 0) {
      throw ArgumentError('Invalid movement');
    }
    final count = math.max(1, (delta.length / (radius * .5)).ceil());
    if (count > 10000) throw ArgumentError('Movement must be stepped');
    final step = delta * (1 / count);
    var p = origin;
    for (var i = 0; i < count; i++) {
      final a = Point2(p.x + step.x, p.z);
      if (!boxes.any((b) => b.contains(a, radius))) p = a;
      final b = Point2(p.x, p.z + step.z);
      if (!boxes.any((s) => s.contains(b, radius))) p = b;
    }
    return p;
  }

  double? ray(Point2 from, Point2 direction, double range) {
    if (range < 0 ||
        !range.isFinite ||
        !direction.x.isFinite ||
        !direction.z.isFinite) {
      throw ArgumentError('Invalid ray');
    }
    double? nearest;
    final unit = direction.normalized;
    if (unit.length == 0) return null;
    for (final b in boxes) {
      final hit = b.ray(from, unit, range);
      if (hit != null && (nearest == null || hit < nearest)) nearest = hit;
    }
    return nearest;
  }

  bool visible(Point2 a, Point2 b) => ray(a, b - a, (b - a).length) == null;
}
