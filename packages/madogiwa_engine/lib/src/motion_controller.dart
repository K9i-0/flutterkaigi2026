import 'dart:math' as math;

/// Model-specific clip metadata. No skeleton names or renderer dependency.
class MotionSpec {
  const MotionSpec({
    required this.duration,
    this.loop = true,
    this.syncGroup,
    this.groundSpeed,
  });
  final double duration;
  final bool loop;
  final String? syncGroup;

  /// Authored/metred speed at playback rate 1; null means a timed action.
  final double? groundSpeed;
}

/// A simulation-owned animation clock: rendering must sample, never advance it.
class MotionController {
  MotionController(
    Map<String, MotionSpec> motions, {
    required String initial,
    this.transitionSeconds,
  }) : motions = Map.unmodifiable(motions),
       current = initial {
    if (transitionSeconds != null &&
        (!transitionSeconds!.isFinite || transitionSeconds! <= 0)) {
      throw ArgumentError('transitionSeconds must be finite and positive');
    }
    if (!motions.containsKey(initial)) {
      throw ArgumentError('Unknown initial motion');
    }
    for (final entry in motions.entries) {
      final spec = entry.value;
      if (!spec.duration.isFinite ||
          spec.duration <= 0 ||
          (spec.groundSpeed != null &&
              (!spec.groundSpeed!.isFinite || spec.groundSpeed! <= 0))) {
        throw ArgumentError('Invalid motion metadata: ${entry.key}');
      }
      _seconds[entry.key] = 0;
      _weights[entry.key] = entry.key == initial ? 1 : 0;
    }
  }

  /// Optional fixed-duration quintic weight blend. Default retains exponential
  /// response. Interruptions preserve pose weights, but restart easing velocity.
  final double? transitionSeconds;
  Map<String, double>? _transitionFrom;
  double _transitionElapsed = 0;
  final Map<String, MotionSpec> motions;
  String current;
  bool paused = false;
  final _seconds = <String, double>{};
  final _weights = <String, double>{};
  Map<String, double> get seconds => Map.unmodifiable(_seconds);
  Map<String, double> get weights => Map.unmodifiable(_weights);
  double get phase => _seconds[current]! / motions[current]!.duration;
  bool get finished => !motions[current]!.loop && phase >= 1;

  /// [immediate] isolates a pose for deterministic inspection. Gameplay normally
  /// leaves it false so interruptions preserve the outgoing blend.
  /// [entryPhase] proposes a loop entry pose when no visible related gait can
  /// supply continuity. Explicit restarts/pose isolation ignore this proposal.
  /// Callers decide which transitions warrant this authored entry policy.
  void select(
    String name, {
    bool restart = false,
    bool immediate = false,
    double entryPhase = 0,
  }) {
    if (!entryPhase.isFinite || entryPhase < 0 || entryPhase >= 1) {
      throw ArgumentError.value(entryPhase, 'entryPhase');
    }
    final next = motions[name];
    if (next == null) throw ArgumentError.value(name, 'motion');
    if (immediate) {
      _transitionFrom = null;
      for (final key in _weights.keys) {
        _weights[key] = key == name ? 1 : 0;
      }
    }
    if (name == current && !restart) return;
    if (!immediate && transitionSeconds != null) {
      _transitionFrom = Map.of(_weights);
      _transitionElapsed = 0;
    }
    final old = motions[current]!;
    final sync =
        !restart && old.syncGroup != null && old.syncGroup == next.syncGroup;
    // A brief stop can leave the incoming loop visibly weighted. Rewinding it
    // changes the rendered pose even before blend weights advance. Preserve
    // that clock; explicit restarts and one-shots still start a new action.
    final resume =
        !restart && !immediate && next.loop && _weights[name]! > .0001;
    // A looping idle may sit between two related gaits.
    // If the incoming gait is not already visible, inherit the strongest
    // still-visible sibling instead of mixing its stance with phase zero.
    // Do not rewind a visible incoming loop or resurrect a fully faded gait.
    String? donor;
    if (!restart &&
        !immediate &&
        !sync &&
        !resume &&
        old.loop &&
        next.loop &&
        next.syncGroup != null) {
      var strongest = .0001;
      for (final entry in motions.entries) {
        if (entry.value.loop &&
            entry.value.syncGroup == next.syncGroup &&
            _weights[entry.key]! > strongest) {
          strongest = _weights[entry.key]!;
          donor = entry.key;
        }
      }
    }
    _seconds[name] = sync
        ? (phase % 1) * next.duration
        : resume
        ? _seconds[name]!
        : donor != null
        ? (_seconds[donor]! / motions[donor]!.duration % 1) * next.duration
        : !restart && !immediate && next.loop
        ? entryPhase * next.duration
        : 0;
    current = name;
  }

  /// Explicit action progress (gather/landing/etc.) is owned by gameplay.
  void seekPhase(double phase) {
    if (!phase.isFinite || phase < 0 || phase > 1) {
      throw ArgumentError.value(phase, 'phase');
    }
    _seconds[current] = phase * motions[current]!.duration;
  }

  void advance(double dt, {double? groundSpeed, bool sampleOnly = false}) {
    if (!dt.isFinite ||
        dt < 0 ||
        (groundSpeed != null && (!groundSpeed.isFinite || groundSpeed < 0))) {
      throw ArgumentError('Expected finite non-negative time and speed');
    }
    if (paused || dt == 0) return;
    final blend = 1 - math.exp(-16 * dt);
    final active = motions[current]!;
    double? eased;
    if (_transitionFrom != null) {
      _transitionElapsed += dt;
      final t = (_transitionElapsed / transitionSeconds!).clamp(0.0, 1.0);
      eased = t * t * t * (10 + t * (-15 + 6 * t));
    }
    for (final entry in motions.entries) {
      final name = entry.key, spec = entry.value;
      final target = name == current ? 1.0 : 0.0;
      _weights[name] = eased == null
          ? _weights[name]! + (target - _weights[name]!) * blend
          : _transitionFrom![name]! +
                (target - _transitionFrom![name]!) * eased;
      if (_weights[name]! == 0) continue;
      if (sampleOnly && name == current) continue;
      // Both sides of a gait crossfade share normalized cycle frequency.
      final sync =
          active.syncGroup != null && active.syncGroup == spec.syncGroup;
      final basis = sync ? active : spec;
      final rate = groundSpeed != null && basis.groundSpeed != null
          ? (groundSpeed / basis.groundSpeed!).clamp(0.0, 3.0)
          : 1.0;
      final elapsed =
          _seconds[name]! +
          dt * rate * (sync ? spec.duration / active.duration : 1);
      _seconds[name] = spec.loop
          ? elapsed % spec.duration
          : elapsed.clamp(0, spec.duration);
    }
    if (eased == 1) _transitionFrom = null;
  }

  Map<String, Object?> inspect() => {
    'transitionSeconds': transitionSeconds,
    'motion': current,
    'phase': phase,
    'finished': finished,
    'paused': paused,
    'seconds': seconds,
    'weights': weights,
  };
}
