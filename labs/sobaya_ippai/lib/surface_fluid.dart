import 'dart:math' as math;
import 'dart:typed_data';

/// Damped height-field solver on a circular domain. The Laplacian transfers
/// momentum between neighbours; the wall reflects waves (zero normal flux).
/// It models surface waves/jet impact, not a full 3D Navier–Stokes volume.
class SurfaceFluid {
  static const n = 41, radius = .0625, dx = radius * 2 / (n - 1);
  final height = Float64List(n * n), velocity = Float64List(n * n);
  final _next = Float64List(n * n), _mask = List<bool>.filled(n * n, false);
  double clock = 0;
  SurfaceFluid() {
    for (var z = 0; z < n; z++) {
      for (var x = 0; x < n; x++) {
        _mask[z * n + x] =
            math.pow(x * dx - radius, 2) + math.pow(z * dx - radius, 2) <=
            radius * radius;
      }
    }
  }
  void reset() {
    height.fillRange(0, height.length, 0);
    velocity.fillRange(0, velocity.length, 0);
    clock = 0;
  }

  void step(
    double dt, {
    required double flow,
    required double agitation,
    required double depth,
  }) {
    var remaining = dt;
    while (remaining > 1e-9) {
      final h = math.min(remaining, 1 / 240);
      remaining -= h;
      clock += h;
      final c2 = math.min(.022, math.max(.003, depth * 1.2));
      for (var z = 1; z < n - 1; z++) {
        for (var x = 1; x < n - 1; x++) {
          final i = z * n + x;
          if (!_mask[i]) continue;
          final center = height[i];
          double neighbor(int j) => _mask[j] ? height[j] : center;
          final lap =
              (neighbor(i - 1) +
                  neighbor(i + 1) +
                  neighbor(i - n) +
                  neighbor(i + n) -
                  4 * center) /
              (dx * dx);
          final px = x * dx - radius, pz = z * dx - radius;
          final dist2 = math.pow(px - .007, 2) + pz * pz;
          final jet =
              -math.exp(-dist2 / .000045) *
              flow *
              .14 *
              (1 + .18 * math.sin(clock * 71));
          final agitationForce =
              agitation * .10 * px / radius * math.sin(clock * 12);
          _next[i] =
              (velocity[i] +
                      (c2 * lap - velocity[i] * 4.2 + jet + agitationForce) * h)
                  .clamp(-.08, .08);
        }
      }
      var sum = 0.0, count = 0;
      for (var i = 0; i < height.length; i++) {
        if (_mask[i]) {
          velocity[i] = _next[i];
          height[i] = (height[i] + velocity[i] * h).clamp(-.006, .006);
          sum += height[i];
          count++;
        }
      }
      // Remove mean displacement: waves cannot create beer volume.
      final mean = sum / count;
      for (var i = 0; i < height.length; i++) {
        if (_mask[i]) height[i] -= mean;
      }
    }
  }

  double at(double x, double z) {
    final gx = ((x + radius) / dx).clamp(1.0, n - 2.001),
        gz = ((z + radius) / dx).clamp(1.0, n - 2.001);
    final ix = gx.floor(), iz = gz.floor(), fx = gx - ix, fz = gz - iz;
    final a = height[iz * n + ix] * (1 - fx) + height[iz * n + ix + 1] * fx;
    final b =
        height[(iz + 1) * n + ix] * (1 - fx) +
        height[(iz + 1) * n + ix + 1] * fx;
    return a * (1 - fz) + b * fz;
  }

  double get peak => height.fold(0.0, (a, b) => math.max(a, b));
  double get energy => velocity.fold(0.0, (a, b) => a + b * b);
}
