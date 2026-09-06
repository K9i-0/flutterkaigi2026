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
    final blast = name == 'rocket_blast';
    final range = blast ? 45.0 : 24.0;
    if (distance >= range) return 0;
    final rolloff = 1 / (1 + math.pow(distance / (blast ? 10 : 4), 2));
    final edge = ((range - distance) / 4).clamp(0.0, 1.0);
    return rolloff * edge * (occluded ? (blast ? .55 : .35) : 1);
  }
}
