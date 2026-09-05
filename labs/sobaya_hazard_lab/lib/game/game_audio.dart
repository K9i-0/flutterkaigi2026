import 'dart:math' as math;

/// A world sound has a position; UI and player sounds stay at listener level.
class HazardSound {
  const HazardSound(this.name, {this.x, this.z, this.y = 1.2});
  final String name;
  final double? x, z;
  final double y;
  bool get spatial => x != null && z != null;
  double gain(
    double listenerX,
    double listenerZ, {
    bool occluded = false,
    double listenerY = 1.2,
  }) {
    if (!spatial) return 1;
    final distance = math.sqrt(
      math.pow(x! - listenerX, 2) +
          math.pow(z! - listenerZ, 2) +
          math.pow(y - listenerY, 2),
    );
    if (distance >= 24) return 0;
    final rolloff = 1 / (1 + math.pow(distance / 4, 2));
    final edge = ((24 - distance) / 4).clamp(0.0, 1.0);
    return rolloff * edge * (occluded ? .35 : 1);
  }
}
