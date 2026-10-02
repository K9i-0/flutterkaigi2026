import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_scene/scene.dart';

import 'surface_fluid.dart';

/// A closed, topology-stable liquid mesh. Volume wall and top have independent
/// normals, and both share the same meniscus/wave boundary with no open seam.
class LiquidGeometry {
  static const segments = 96, rings = 20, radius = .0625;
  late final Float32List positions, normals, uv;
  late final MeshGeometry geometry;
  final _indices = <int>[];
  static const sideCount = (segments + 1) * 2;
  LiquidGeometry() {
    final count = sideCount + (rings + 1) * (segments + 1);
    positions = Float32List(count * 3);
    normals = Float32List(count * 3);
    uv = Float32List(count * 2);
    for (var j = 0; j < segments; j++) {
      final a = j * 2, b = (j + 1) * 2, c = a + 1, d = b + 1;
      _indices.addAll([a, c, b, b, c, d]);
    }
    for (var r = 0; r < rings; r++) {
      for (var j = 0; j < segments; j++) {
        final a = sideCount + r * (segments + 1) + j,
            b = a + 1,
            c = a + segments + 1,
            d = c + 1;
        _indices.addAll([a, d, c, a, b, d]);
      }
    }
    // Flutter Scene procedural meshes use clockwise front faces, matching
    // CylinderGeometry. Reverse mathematical CCW faces before uploading.
    for (var i = 0; i < _indices.length; i += 3) {
      final t = _indices[i + 1];
      _indices[i + 1] = _indices[i + 2];
      _indices[i + 2] = t;
    }
    // The bottom is deliberately omitted: always behind the thick glass base.
    update(SurfaceFluid(), bottom: .027, top: .03, foam: false, upload: false);
    geometry = MeshGeometry.fromArrays(
      positions: positions,
      normals: normals,
      texCoords: uv,
      indices: _indices,
      storage: GeometryStorage.updatable,
    );
  }
  void update(
    SurfaceFluid fluid, {
    required double bottom,
    required double top,
    required bool foam,
    bool upload = true,
  }) {
    double innerRadius(double y) =>
        .0607 +
        .003 * ((y - .027) / .013).clamp(0, 1) +
        .002 * ((y - .174) / .033).clamp(0, 1);
    final topRadius = innerRadius(top), bottomRadius = innerRadius(bottom);
    final waveScale = ((top - .027) / .01).clamp(0, 1);
    double y(double x, double z) {
      final r = math.sqrt(x * x + z * z) / topRadius;
      final meniscus = math.pow(r, 20) * (.0012);
      return top + fluid.at(x, z) * waveScale + meniscus;
    }

    for (var j = 0; j <= segments; j++) {
      final a = j * math.pi * 2 / segments, c = math.cos(a), s = math.sin(a);
      for (var k = 0; k < 2; k++) {
        final i = j * 2 + k;
        final radius = k == 0 ? bottomRadius : topRadius;
        positions[i * 3] = c * radius;
        positions[i * 3 + 1] = k == 0
            ? bottom +
                  (foam
                      ? fluid.at(c * radius, s * radius) * waveScale + .0012
                      : 0)
            : y(c * radius, s * radius);
        positions[i * 3 + 2] = s * radius;
        normals[i * 3] = c;
        normals[i * 3 + 1] = 0;
        normals[i * 3 + 2] = s;
        uv[i * 2] = a * radius;
        uv[i * 2 + 1] = positions[i * 3 + 1];
      }
    }
    for (var r = 0; r <= rings; r++) {
      for (var j = 0; j <= segments; j++) {
        final a = j * math.pi * 2 / segments,
            rad = topRadius * r / rings,
            x = math.cos(a) * rad,
            z = math.sin(a) * rad;
        final i = sideCount + r * (segments + 1) + j;
        positions[i * 3] = x;
        positions[i * 3 + 1] = y(x, z);
        positions[i * 3 + 2] = z;
        const e = .0005;
        final nx = -(y(x + e, z) - y(x - e, z)) / (2 * e),
            nz = -(y(x, z + e) - y(x, z - e)) / (2 * e),
            inv = 1 / math.sqrt(nx * nx + 1 + nz * nz);
        normals[i * 3] = nx * inv;
        normals[i * 3 + 1] = inv;
        normals[i * 3 + 2] = nz * inv;
        uv[i * 2] = x;
        uv[i * 2 + 1] = z;
      }
    }
    if (upload) {
      geometry.updatePositions(positions);
      geometry.updateNormals(normals);
      geometry.updateTexCoords(uv);
    }
  }
}

/// Merged droplets: hundreds of beads share one draw rather than one node per
/// droplet. Small, irregular, flattened droplets cling to the outer glass.
MeshGeometry condensationGeometry() {
  final rng = math.Random(2502),
      p = <double>[],
      n = <double>[],
      uv = <double>[],
      indices = <int>[];
  const rows = 6, columns = 9;
  for (var bead = 0; bead < 240; bead++) {
    final angle = rng.nextDouble() * math.pi * 2,
        y = .032 + rng.nextDouble() * .168;
    final size = .0004 + math.pow(rng.nextDouble(), 3) * .0022;
    final c = math.cos(angle),
        s = math.sin(angle),
        radius = y > .17 ? .071 : .072;
    final start = p.length ~/ 3;
    for (var r = 0; r <= rows; r++) {
      for (var j = 0; j <= columns; j++) {
        final phi = math.pi * r / rows, theta = math.pi * 2 * j / columns;
        final tx = math.sin(phi) * math.cos(theta),
            ty = math.cos(phi),
            tz = math.sin(phi) * math.sin(theta);
        p.addAll([
          c * (radius + tz * size * .45) - s * tx * size,
          y + ty * size * (bead % 7 == 0 ? 1.9 : 1.1),
          s * (radius + tz * size * .45) + c * tx * size,
        ]);
        n.addAll([c * tz - s * tx, ty, s * tz + c * tx]);
        uv.addAll([j / columns, r / rows]);
      }
    }
    for (var r = 0; r < rows; r++) {
      for (var j = 0; j < columns; j++) {
        final a = start + r * (columns + 1) + j,
            b = a + 1,
            c = a + columns + 1,
            d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
      }
    }
  }
  return MeshGeometry.fromArrays(
    positions: Float32List.fromList(p),
    normals: Float32List.fromList(n),
    texCoords: Float32List.fromList(uv),
    indices: indices,
  );
}

/// Incompressible falling jet: its section shrinks as falling speed grows.
class PourJetGeometry {
  static const rows = 28, columns = 14;
  final positions = Float32List((rows + 1) * (columns + 1) * 3);
  final normals = Float32List((rows + 1) * (columns + 1) * 3);
  late final MeshGeometry geometry;
  PourJetGeometry() {
    final indices = <int>[];
    for (var r = 0; r < rows; r++) {
      for (var j = 0; j < columns; j++) {
        final a = r * (columns + 1) + j,
            b = a + 1,
            c = a + columns + 1,
            d = c + 1;
        indices.addAll([a, c, b, b, c, d]);
      }
    }
    update(1.2, 1, 0, 0, 1, upload: false);
    geometry = MeshGeometry.fromArrays(
      positions: positions,
      normals: normals,
      indices: indices,
      storage: GeometryStorage.updatable,
    );
  }
  void update(
    double endY,
    double flow,
    double time,
    double startT,
    double endT, {
    bool upload = true,
  }) {
    for (var r = 0; r <= rows; r++) {
      final t = startT + (endT - startT) * r / rows;
      final centerX = .10 + (.007 - .10) * t,
          centerY = 1.41 + (endY - 1.41) * (.25 * t + .75 * t * t),
          centerZ = .35 + .02 * t;
      final speed = .25 + 1.5 * t;
      final radius =
          .0045 * math.sqrt(math.max(.01, flow)) / math.sqrt(1 + 3 * t);
      for (var j = 0; j <= columns; j++) {
        final a = j * math.pi * 2 / columns,
            c = math.cos(a),
            s = math.sin(a),
            i = r * (columns + 1) + j;
        final ripple = 1 + .045 * math.sin(time * 43 - t * 68 + a * 3);
        positions[i * 3] = centerX + c * radius * ripple;
        positions[i * 3 + 1] =
            centerY + c * radius * .093 / ((1.41 - endY) * speed);
        positions[i * 3 + 2] = centerZ + s * radius * ripple;
        normals[i * 3] = c;
        normals[i * 3 + 1] = 0;
        normals[i * 3 + 2] = s;
      }
    }
    if (upload) {
      geometry.updatePositions(positions);
      geometry.updateNormals(normals);
    }
  }
}
