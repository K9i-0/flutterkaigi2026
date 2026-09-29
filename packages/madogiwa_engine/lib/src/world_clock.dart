/// World time driven explicitly by the host simulation, never by wall time.
/// Pausing an app or changing scenes need not advance or reset this clock.
class WorldClock {
  WorldClock({
    Duration dayLength = const Duration(minutes: 15),
    double hour = 12,
  }) : _dayLength = dayLength {
    if (dayLength.inMicroseconds <= 0) {
      throw ArgumentError.value(dayLength, 'dayLength', 'Must be positive');
    }
    setHour(hour);
  }

  final Duration _dayLength;
  int _elapsedMicros = 0;
  double _fraction = 0;
  double _speed = 1;
  bool paused = false;

  Duration get dayLength => _dayLength;
  int get day => _elapsedMicros ~/ _dayLength.inMicroseconds;
  double get hour =>
      (_elapsedMicros % _dayLength.inMicroseconds) *
      24 /
      _dayLength.inMicroseconds;
  double get speed => _speed;
  set speed(double value) {
    if (!value.isFinite || value < 0) {
      throw ArgumentError.value(
        value,
        'speed',
        'Must be finite and nonnegative',
      );
    }
    _speed = value;
  }

  /// Select a time within the current day, without changing the day counter.
  void setHour(double value) {
    if (!value.isFinite || value < 0 || value >= 24) {
      throw ArgumentError.value(value, 'hour', 'Expected 0 <= hour < 24');
    }
    final cycle = _dayLength.inMicroseconds;
    final phase = (value / 24 * cycle).floor();
    _elapsedMicros = day * cycle + phase;
    _fraction = 0;
  }

  /// Returns the exact scaled duration consumed by this clock.
  Duration advance(Duration delta) {
    if (delta.isNegative) {
      throw ArgumentError.value(delta, 'delta', 'Must be nonnegative');
    }
    if (paused || _speed == 0) return Duration.zero;
    final amount = delta.inMicroseconds * _speed + _fraction;
    if (!amount.isFinite) throw ArgumentError('Clock advance overflow');
    final whole = amount.floor();
    _fraction = amount - whole;
    _elapsedMicros += whole;
    return Duration(microseconds: whole);
  }

  Map<String, Object> snapshot() => {
    'version': 1,
    'dayLengthMicros': _dayLength.inMicroseconds,
    'elapsedMicros': _elapsedMicros,
    'fraction': _fraction,
    'speed': _speed,
    'paused': paused,
  };

  factory WorldClock.fromSnapshot(Map<String, Object?> data) {
    final period = data['dayLengthMicros'], elapsed = data['elapsedMicros'];
    final fraction = data['fraction'], speed = data['speed'];
    if (data['version'] != 1 ||
        period is! int ||
        period <= 0 ||
        elapsed is! int ||
        elapsed < 0 ||
        fraction is! num ||
        !fraction.isFinite ||
        fraction < 0 ||
        fraction >= 1 ||
        speed is! num ||
        !speed.isFinite ||
        speed < 0 ||
        data['paused'] is! bool) {
      throw const FormatException('Invalid clock snapshot');
    }
    return WorldClock(dayLength: Duration(microseconds: period), hour: 0)
      .._elapsedMicros = elapsed
      .._fraction = fraction.toDouble()
      ..speed = speed.toDouble()
      ..paused = data['paused'] as bool;
  }

  Map<String, Object> inspect() => {
    'day': day,
    'hour': hour,
    'dayLengthSeconds': _dayLength.inMicroseconds / 1000000,
    'speed': speed,
    'paused': paused,
  };
}
