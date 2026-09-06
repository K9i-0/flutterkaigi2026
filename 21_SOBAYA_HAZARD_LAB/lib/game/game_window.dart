import 'dart:math' as math;

/// Ground-floor opening authored by the environment builder. Positive Z is
/// inside the house; a passage can be used in either direction.
class HazardWindow {
  HazardWindow(Map<String, dynamic> data)
    : id = data['id'] as String,
      x = (data['x'] as num).toDouble(),
      z = (data['z'] as num).toDouble();
  final String id;
  final double x, z;
  static const offset = .95;
  double entryZ(bool inward) => z + (inward ? -offset : offset);
  double exitZ(bool inward) => entryZ(!inward);
  bool atEntry(double px, double py, double pz, bool inward) =>
      py.abs() < .12 &&
      (px - x).abs() < .48 &&
      (pz - z) * (inward ? -1 : 1) > .45 &&
      (pz - entryZ(inward)).abs() < .55;
}

/// Feet rise while the clip folds the knees and places the hands on the sill.
/// The same normalized clock drives the root and both rigs' baked Vault clip.
class WindowTraversal {
  WindowTraversal(
    this.window,
    this.inward,
    this.startX,
    this.startZ, {
    this.enemy = false,
  });
  final HazardWindow window;
  final bool inward, enemy;
  final double startX, startZ;
  double elapsed = 0;
  double get approachSeconds => math.max(
    .3,
    math.sqrt(
          math.pow(startX - window.x, 2) +
              math.pow(startZ - window.entryZ(inward), 2),
        ) /
        1.4,
  );
  double get vaultSeconds => enemy ? 2.1 : 1.6;
  double get duration => approachSeconds + vaultSeconds;
  double get progress =>
      ((elapsed - approachSeconds) / vaultSeconds).clamp(0, 1);
  bool get crossing => elapsed >= approachSeconds;
  bool get done => elapsed >= duration;
  double get heading => inward ? 0 : math.pi;
  double get x =>
      startX + (window.x - startX) * (elapsed / approachSeconds).clamp(0, 1);
  double get y => .55 * math.pow(math.sin(math.pi * progress), 2);
  double get z {
    if (!crossing) {
      return startZ +
          (window.entryZ(inward) - startZ) * elapsed / approachSeconds;
    }
    final t = progress, eased = t * t * (3 - 2 * t);
    return window.entryZ(inward) +
        (window.exitZ(inward) - window.entryZ(inward)) * eased;
  }

  void advance(double dt) => elapsed = math.min(duration, elapsed + dt);
  Map<String, Object> toJson() => {
    'window': window.id,
    'inward': inward,
    'startX': startX,
    'startZ': startZ,
    'elapsed': elapsed,
  };
  static WindowTraversal? restore(
    dynamic data,
    List<HazardWindow> windows,
    double x,
    double y,
    double z, {
    bool enemy = false,
  }) {
    if (data == null) return null;
    if (data is! Map ||
        data['inward'] is! bool ||
        ![
          'startX',
          'startZ',
          'elapsed',
        ].every((k) => data[k] is num && (data[k] as num).isFinite)) {
      throw const FormatException('Invalid window traversal');
    }
    final matches = windows.where((w) => w.id == data['window']);
    if (matches.length != 1) throw const FormatException('Unknown window');
    final t = WindowTraversal(
      matches.single,
      data['inward'],
      (data['startX'] as num).toDouble(),
      (data['startZ'] as num).toDouble(),
      enemy: enemy,
    )..elapsed = (data['elapsed'] as num).toDouble();
    if (!t.window.atEntry(t.startX, 0, t.startZ, t.inward) ||
        t.elapsed < 0 ||
        t.elapsed >= t.duration ||
        (t.x - x).abs() > .06 ||
        (t.y - y).abs() > .06 ||
        (t.z - z).abs() > .06) {
      throw const FormatException('Inconsistent window traversal');
    }
    return t;
  }
}
