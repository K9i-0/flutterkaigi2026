import 'dart:math' as math;
import 'dart:typed_data';

import 'package:vector_math/vector_math.dart';

/// Tidewater's metre-based, Y-up heightfield and village collision data.
class IslandWorld {
  IslandWorld(this.metadata, this.heights) {
    final h = metadata['heightfield'] as Map<String, dynamic>;
    resolution = h['resolution'] as int;
    origin = (h['origin'] as num).toDouble();
    texel = (h['texel'] as num).toDouble();
    if (heights.lengthInBytes != resolution * resolution * 4) {
      throw const FormatException('Heightfield size does not match metadata');
    }
  }
  final Map<String, dynamic> metadata;
  final ByteData heights;
  late final int resolution;
  late final double origin, texel;
  List<dynamic> get boxes => metadata['boxes'] as List;
  List<dynamic> get cylinders => metadata['cylinders'] as List;

  double heightAt(double x, double z) {
    final fx = (x - origin) / texel - .5;
    final fz = (z - origin) / texel - .5;
    if (fx < 0 || fz < 0 || fx >= resolution - 1 || fz >= resolution - 1) {
      return -90;
    }
    final i = fx.floor(), j = fz.floor();
    final tx = fx - i, tz = fz - j, k = j * resolution + i;
    double h(int index) => heights.getFloat32(index * 4, Endian.little);
    return (h(k) * (1 - tx) + h(k + 1) * tx) * (1 - tz) +
        (h(k + resolution) * (1 - tx) + h(k + resolution + 1) * tx) * tz;
  }

  double groundAt(double x, double z, double maxY) {
    var best = heightAt(x, z);
    for (final b in boxes) {
      if (b['walkable'] != true || (b['top'] as num) > maxY) continue;
      final dx = x - (b['center']['x'] as num),
          dz = z - (b['center']['z'] as num);
      final co = b['cos'] as num, si = b['sin'] as num;
      if ((dx * co - dz * si).abs() <= (b['half']['x'] as num) &&
          (dx * si + dz * co).abs() <= (b['half']['z'] as num)) {
        best = math.max(best, (b['top'] as num).toDouble());
      }
    }
    return best;
  }

  bool overlapsBox(Map<dynamic, dynamic> b, double x, double z, double radius) {
    final dx = x - (b['center']['x'] as num),
        dz = z - (b['center']['z'] as num);
    final co = b['cos'] as num, si = b['sin'] as num;
    final lx = dx * co - dz * si, lz = dx * si + dz * co;
    final hx = (b['half']['x'] as num).toDouble(),
        hz = (b['half']['z'] as num).toDouble();
    final ex = lx - lx.clamp(-hx, hx), ez = lz - lz.clamp(-hz, hz);
    return ex * ex + ez * ez <= radius * radius;
  }

  /// A solid object's top is a landing surface even if it is not a stair.
  double supportAt(double x, double z, double maxY) {
    var floor = heightAt(x, z);
    for (final b in boxes) {
      final top = (b['top'] as num).toDouble();
      if ((b['solid'] == true || b['walkable'] == true) &&
          top <= maxY + .001 &&
          overlapsBox(b, x, z, 0)) {
        floor = math.max(floor, top);
      }
    }
    for (final c in cylinders) {
      final top = (c['yMax'] as num).toDouble();
      if (top <= maxY + .001 &&
          math.pow(x - (c['x'] as num), 2) + math.pow(z - (c['z'] as num), 2) <=
              math.pow(c['radius'] as num, 2)) {
        floor = math.max(floor, top);
      }
    }
    return floor;
  }

  double ceilingAt(double x, double z, double head) {
    var ceiling = double.infinity;
    for (final b in boxes) {
      final bottom = (b['bottom'] as num).toDouble();
      if (b['solid'] == true &&
          bottom >= head - .002 &&
          overlapsBox(b, x, z, .28)) {
        ceiling = math.min(ceiling, bottom);
      }
    }
    for (final c in cylinders) {
      final bottom = (c['yMin'] as num).toDouble();
      if (bottom >= head - .002 &&
          math.pow(x - (c['x'] as num), 2) + math.pow(z - (c['z'] as num), 2) <=
              math.pow((c['radius'] as num) + .28, 2)) {
        ceiling = math.min(ceiling, bottom);
      }
    }
    return ceiling;
  }

  String surfaceAt(double x, double z, double feetY) {
    for (final b in boxes) {
      if ((feetY - (b['top'] as num)).abs() < .06 && overlapsBox(b, x, z, 0)) {
        return 'wood';
      }
    }
    for (final c in cylinders) {
      if ((feetY - (c['yMax'] as num)).abs() < .06 &&
          math.pow(x - (c['x'] as num), 2) + math.pow(z - (c['z'] as num), 2) <=
              math.pow(c['radius'] as num, 2)) {
        return 'wood';
      }
    }
    final h = heightAt(x, z);
    final slope =
        (heightAt(x + .5, z) - heightAt(x - .5, z)).abs() +
        (heightAt(x, z + .5) - heightAt(x, z - .5)).abs();
    if (slope > 1.1) return 'rock';
    if (h < .5) return 'wetsand';
    if (h < 2.5) return 'sand';
    return 'grass';
  }

  /// Sliding capsule, with substeps handled by the caller.
  void resolve(
    Vector3 p, {
    double radius = .28,
    double height = 1.7,
    double step = .4,
  }) {
    for (final b in boxes) {
      if (b['solid'] != true ||
          p.y + height <= (b['bottom'] as num) + .001 ||
          p.y + step >= (b['top'] as num) - .001) {
        continue;
      }
      final dx = p.x - (b['center']['x'] as num),
          dz = p.z - (b['center']['z'] as num);
      final co = b['cos'] as num, si = b['sin'] as num;
      final lx = dx * co - dz * si, lz = dx * si + dz * co;
      final hx = (b['half']['x'] as num).toDouble(),
          hz = (b['half']['z'] as num).toDouble();
      var nx = lx - lx.clamp(-hx, hx), nz = lz - lz.clamp(-hz, hz);
      final d2 = nx * nx + nz * nz;
      if (d2 >= radius * radius) continue;
      double pen;
      if (d2 > 1e-8) {
        final d = math.sqrt(d2);
        nx /= d;
        nz /= d;
        pen = radius - d;
      } else if (hx - lx.abs() < hz - lz.abs()) {
        nx = lx < 0 ? -1 : 1;
        nz = 0;
        pen = hx - lx.abs() + radius;
      } else {
        nx = 0;
        nz = lz < 0 ? -1 : 1;
        pen = hz - lz.abs() + radius;
      }
      p.x += (nx * co + nz * si) * pen;
      p.z += (-nx * si + nz * co) * pen;
    }
    for (final c in cylinders) {
      if (p.y + height <= (c['yMin'] as num) + .001 ||
          p.y + step >= (c['yMax'] as num) - .001) {
        continue;
      }
      final dx = p.x - (c['x'] as num),
          dz = p.z - (c['z'] as num),
          r = (c['radius'] as num) + radius;
      final d = math.sqrt(dx * dx + dz * dz);
      if (d >= r) continue;
      p.x = (c['x'] as num).toDouble() + (d < 1e-5 ? r : dx / d * r);
      p.z = (c['z'] as num).toDouble() + (d < 1e-5 ? 0 : dz / d * r);
    }
  }
}
