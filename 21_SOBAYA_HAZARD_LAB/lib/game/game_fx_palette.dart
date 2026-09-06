/// Alternate timbres without consuming game RNG or overlapping whole sentences.
class HazardFxPalette {
  static const variants = {
    'shot',
    'shotgun',
    'enemy',
    'mug_ready',
    'mug_swing',
    'mug_hit',
  };
  final _indices = <String, int>{};
  double _gruntUntil = 0, _clock = 0;
  String? select(String name, double clock) {
    if (clock < _clock) _gruntUntil = 0;
    _clock = clock;
    if (name == 'enemy') {
      if (clock < _gruntUntil) return null;
      _gruntUntil = clock + 3.2;
    }
    if (!variants.contains(name)) return name;
    final i = _indices[name] ?? 0;
    _indices[name] = (i + 1) % 3;
    return '${name}_$i';
  }
}
