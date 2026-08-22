class FramePerformanceTracker {
  FramePerformanceTracker({
    this.sampleLimit = 120,
    this.refreshIntervalSeconds = 0.4,
  });

  final int sampleLimit;
  final double refreshIntervalSeconds;
  final List<double> _frameTimesMs = [];
  final List<double> _buildTimesMs = [];
  final List<double> _rasterTimesMs = [];

  double _windowSeconds = 0;
  int _windowFrames = 0;

  double framesPerSecond = 0;
  double averageFrameTimeMs = 0;
  double p95FrameTimeMs = 0;
  double onePercentLowFps = 0;
  double averageBuildTimeMs = 0;
  double averageRasterTimeMs = 0;
  double p95RasterTimeMs = 0;

  void recordFlutterFrame({
    required double buildTimeMs,
    required double rasterTimeMs,
  }) {
    if (buildTimeMs.isFinite && buildTimeMs >= 0) {
      _appendLimited(_buildTimesMs, buildTimeMs);
      averageBuildTimeMs = _average(_buildTimesMs);
    }
    if (rasterTimeMs.isFinite && rasterTimeMs >= 0) {
      _appendLimited(_rasterTimesMs, rasterTimeMs);
      averageRasterTimeMs = _average(_rasterTimesMs);
      p95RasterTimeMs = _percentile(_rasterTimesMs, 0.95);
    }
  }

  bool recordFrame(double deltaSeconds) {
    if (!deltaSeconds.isFinite || deltaSeconds <= 0 || deltaSeconds > 0.5) {
      return false;
    }

    _windowSeconds += deltaSeconds;
    _windowFrames++;
    _appendLimited(_frameTimesMs, deltaSeconds * 1000);
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

  void _appendLimited(List<double> samples, double value) {
    samples.add(value);
    if (samples.length > sampleLimit) samples.removeAt(0);
  }

  double _average(List<double> samples) => samples.isEmpty
      ? 0
      : samples.fold<double>(0, (sum, value) => sum + value) / samples.length;

  double _percentile(List<double> samples, double percentile) {
    if (samples.isEmpty) return 0;
    final sorted = List<double>.of(samples)..sort();
    return sorted[((sorted.length - 1) * percentile).round()];
  }
}
