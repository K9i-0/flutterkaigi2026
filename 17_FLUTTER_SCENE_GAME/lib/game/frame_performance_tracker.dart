class FramePerformanceTracker {
  FramePerformanceTracker({
    this.sampleLimit = 120,
    this.refreshIntervalSeconds = 0.4,
  });

  final int sampleLimit;
  final double refreshIntervalSeconds;
  final List<double> _frameTimesMs = [];

  double _windowSeconds = 0;
  int _windowFrames = 0;

  double framesPerSecond = 0;
  double averageFrameTimeMs = 0;
  double p95FrameTimeMs = 0;
  double onePercentLowFps = 0;

  bool recordFrame(double deltaSeconds) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0 || deltaSeconds > 0.5) {
      return false;
    }

    _windowSeconds += deltaSeconds;
    _windowFrames++;
    _frameTimesMs.add(deltaSeconds * 1000);
    if (_frameTimesMs.length > sampleLimit) {
      _frameTimesMs.removeAt(0);
    }
    if (_windowSeconds < refreshIntervalSeconds) return false;

    framesPerSecond = _windowFrames / _windowSeconds;
    averageFrameTimeMs =
        _frameTimesMs.fold<double>(0, (sum, value) => sum + value) /
        _frameTimesMs.length;
    final sorted = List<double>.of(_frameTimesMs)..sort();
    final p95Index = ((sorted.length - 1) * 0.95).round();
    p95FrameTimeMs = sorted[p95Index];
    final slowFrameCount = (sorted.length * 0.01).ceil();
    final slowFrameStart = sorted.length - slowFrameCount;
    final slowFrameAverageMs =
        sorted
            .skip(slowFrameStart)
            .fold<double>(0, (sum, value) => sum + value) /
        slowFrameCount;
    onePercentLowFps = 1000 / slowFrameAverageMs;
    _windowSeconds = 0;
    _windowFrames = 0;
    return true;
  }
}
