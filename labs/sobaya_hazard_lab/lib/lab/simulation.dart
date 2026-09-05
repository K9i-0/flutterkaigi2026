import 'dart:math' as math;

enum LabMode { model, movement, crowd }

class Block {
  const Block(this.x, this.z, this.width, this.depth, this.height);
  final double x, z, width, depth, height;
  double get left => x - width / 2;
  double get right => x + width / 2;
  double get near => z - depth / 2;
  double get far => z + depth / 2;
}

const arenaBlocks = <Block>[
  Block(0, -1, 3.2, 0.6, 2.1),
  Block(-3.4, 2.2, 1.4, 1.4, 1.2),
  Block(3.4, 2, 1.6, 2.4, 1.4),
  Block(-8, 0, .3, 16, 2.4),
  Block(8, 0, .3, 16, 2.4),
  Block(0, -8, 16, .3, 2.4),
  Block(0, 8, 16, .3, 2.4),
];

/// Deliberately small horizontal capsule-footprint test, not a physics engine.
/// Substeps bound travel to 5 cm so sprinting cannot tunnel through a wall.
class LabSimulation {
  static const radius = .34;
  LabMode mode = LabMode.model;
  double x = 0, z = 0, heading = 0;
  double distanceTravelled = 0;
  bool collided = false;
  int collisionFrames = 0;

  void reset(LabMode next) {
    mode = next;
    x = 0;
    z = next == LabMode.movement ? -5 : 0;
    heading = 0;
    distanceTravelled = 0;
    collided = false;
    collisionFrames = 0;
  }

  bool overlaps(double px, double pz, Block box, {double r = radius}) {
    final dx = px - px.clamp(box.left, box.right);
    final dz = pz - pz.clamp(box.near, box.far);
    return dx * dx + dz * dz < r * r - 1e-9;
  }

  void move(double dx, double dz, double seconds, {bool sprint = false}) {
    collided = false;
    if (mode != LabMode.movement || seconds <= 0 || !seconds.isFinite) return;
    final magnitude = math.sqrt(dx * dx + dz * dz);
    if (magnitude < 1e-6 || !magnitude.isFinite) return;
    dx /= math.max(1, magnitude);
    dz /= math.max(1, magnitude);
    final speed = sprint ? 4.8 : 2.6;
    final travel = speed * seconds.clamp(0, .1);
    final steps = math.max(1, (travel / .05).ceil());
    final sx = dx * travel / steps, sz = dz * travel / steps;
    for (var i = 0; i < steps; i++) {
      final beforeX = x, beforeZ = z;
      if (!arenaBlocks.any((b) => overlaps(x + sx, z, b))) {
        x += sx;
      } else {
        collided = true;
      }
      if (!arenaBlocks.any((b) => overlaps(x, z + sz, b))) {
        z += sz;
      } else {
        collided = true;
      }
      distanceTravelled += math.sqrt(
        math.pow(x - beforeX, 2) + math.pow(z - beforeZ, 2),
      );
    }
    heading = math.atan2(dx, dz);
    if (collided) collisionFrames++;
  }

  /// Shortens a camera boom before a blocking wall, using its actual height.
  double cameraFraction(
    double tx,
    double ty,
    double tz,
    double ex,
    double ey,
    double ez,
  ) {
    if (mode != LabMode.movement) return 1;
    final length = math.sqrt(
      math.pow(ex - tx, 2) + math.pow(ey - ty, 2) + math.pow(ez - tz, 2),
    );
    final steps = math.max(1, (length / .06).ceil());
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final px = tx + (ex - tx) * t,
          py = ty + (ey - ty) * t,
          pz = tz + (ez - tz) * t;
      if (arenaBlocks.any(
        (b) => py < b.height + .15 && py > -.15 && overlaps(px, pz, b, r: .15),
      )) {
        return math.max(.02, (i - 1) / steps);
      }
    }
    return 1;
  }
}

class FrameSamples {
  final List<double> _ui = [], _raster = [];
  int revision = 0;
  void reset() {
    _ui.clear();
    _raster.clear();
    revision++;
  }

  void add(double ui, double raster) {
    if (!ui.isFinite || !raster.isFinite || ui < 0 || raster < 0) return;
    _ui.add(ui);
    _raster.add(raster);
    if (_ui.length > 240) {
      _ui.removeAt(0);
      _raster.removeAt(0);
    }
  }

  int get count => _ui.length;
  double? percentile(List<double> data) {
    if (data.isEmpty) return null;
    final sorted = [...data]..sort();
    return sorted[(sorted.length * .95).ceil() - 1];
  }

  double? get uiP95 => percentile(_ui);
  double? get rasterP95 => percentile(_raster);
  Map<String, Object?> toJson() => {
    'samples': count,
    'window': 'last 240 Flutter frames',
    'uiP95Ms': uiP95,
    'rasterP95Ms': rasterP95,
  };
}
