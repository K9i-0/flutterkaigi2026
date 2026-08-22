enum GraphicsQuality { auto, performance, balanced, quality }

extension GraphicsQualityLabel on GraphicsQuality {
  String get label => switch (this) {
    GraphicsQuality.auto => 'Auto',
    GraphicsQuality.performance => 'Performance',
    GraphicsQuality.balanced => 'Balanced',
    GraphicsQuality.quality => 'Quality',
  };
}

class MobileQualityProfile {
  const MobileQualityProfile({
    required this.renderScale,
    required this.shadowCascades,
    required this.shadowResolution,
    required this.shadowDistance,
    required this.contactShadows,
    required this.ambientOcclusion,
    required this.ambientOcclusionSamples,
    required this.screenSpaceReflections,
    required this.ssrResolutionScale,
    required this.ssrSteps,
    required this.bloom,
    required this.godRays,
    required this.maxTorchLights,
    required this.maxTorchParticles,
    required this.terrainChunkRadius,
    required this.resourceChunkRadius,
    required this.resourceFullDetailDistance,
    required this.skyBakeInterval,
    required this.lightingUpdatesPerSecond,
    required this.effectsUpdatesPerSecond,
  });

  final double renderScale;
  final int shadowCascades;
  final int shadowResolution;
  final double shadowDistance;
  final bool contactShadows;
  final bool ambientOcclusion;
  final int ambientOcclusionSamples;
  final bool screenSpaceReflections;
  final double ssrResolutionScale;
  final int ssrSteps;
  final bool bloom;
  final bool godRays;
  final int maxTorchLights;
  final int maxTorchParticles;
  final int terrainChunkRadius;
  final int resourceChunkRadius;
  final double resourceFullDetailDistance;
  final Duration skyBakeInterval;
  final double lightingUpdatesPerSecond;
  final double effectsUpdatesPerSecond;

  bool usesFullResourceDetail(double distanceSquared) =>
      distanceSquared <=
      resourceFullDetailDistance * resourceFullDetailDistance;

  static const performance = MobileQualityProfile(
    renderScale: 0.62,
    shadowCascades: 1,
    shadowResolution: 384,
    shadowDistance: 28,
    contactShadows: false,
    ambientOcclusion: false,
    ambientOcclusionSamples: 4,
    screenSpaceReflections: false,
    ssrResolutionScale: 0.25,
    ssrSteps: 12,
    bloom: false,
    godRays: false,
    maxTorchLights: 2,
    maxTorchParticles: 0,
    terrainChunkRadius: 1,
    resourceChunkRadius: 1,
    resourceFullDetailDistance: 7,
    skyBakeInterval: Duration(seconds: 30),
    lightingUpdatesPerSecond: 1,
    effectsUpdatesPerSecond: 15,
  );

  static const balanced = MobileQualityProfile(
    renderScale: 1,
    shadowCascades: 2,
    shadowResolution: 512,
    shadowDistance: 36,
    contactShadows: true,
    ambientOcclusion: true,
    ambientOcclusionSamples: 8,
    screenSpaceReflections: false,
    ssrResolutionScale: 0.35,
    ssrSteps: 20,
    bloom: true,
    godRays: false,
    maxTorchLights: 4,
    maxTorchParticles: 4,
    terrainChunkRadius: 2,
    resourceChunkRadius: 1,
    resourceFullDetailDistance: 14,
    skyBakeInterval: Duration(seconds: 15),
    lightingUpdatesPerSecond: 0.5,
    effectsUpdatesPerSecond: 30,
  );

  static const quality = MobileQualityProfile(
    renderScale: 1,
    shadowCascades: 3,
    shadowResolution: 1024,
    shadowDistance: 56,
    contactShadows: true,
    ambientOcclusion: true,
    ambientOcclusionSamples: 16,
    screenSpaceReflections: true,
    ssrResolutionScale: 0.5,
    ssrSteps: 32,
    bloom: true,
    godRays: true,
    maxTorchLights: 8,
    maxTorchParticles: 8,
    terrainChunkRadius: 2,
    resourceChunkRadius: 2,
    resourceFullDetailDistance: 40,
    skyBakeInterval: Duration(seconds: 5),
    lightingUpdatesPerSecond: 2,
    effectsUpdatesPerSecond: 60,
  );

  /// First automatic fallback: retain native resolution and character models,
  /// then reduce distant world detail and expensive shadow work.
  static const adaptiveWorld = MobileQualityProfile(
    renderScale: 1,
    shadowCascades: 1,
    shadowResolution: 384,
    shadowDistance: 30,
    contactShadows: false,
    ambientOcclusion: true,
    ambientOcclusionSamples: 6,
    screenSpaceReflections: false,
    ssrResolutionScale: 0.3,
    ssrSteps: 16,
    bloom: true,
    godRays: false,
    maxTorchLights: 3,
    maxTorchParticles: 2,
    terrainChunkRadius: 2,
    resourceChunkRadius: 1,
    resourceFullDetailDistance: 10,
    skyBakeInterval: Duration(seconds: 20),
    lightingUpdatesPerSecond: 0.5,
    effectsUpdatesPerSecond: 20,
  );

  /// Second fallback: preserve character geometry/materials, remove
  /// fullscreen/depth effects, and apply only a modest resolution reduction.
  static const adaptiveVisual = MobileQualityProfile(
    renderScale: 0.88,
    shadowCascades: 1,
    shadowResolution: 384,
    shadowDistance: 26,
    contactShadows: false,
    ambientOcclusion: false,
    ambientOcclusionSamples: 6,
    screenSpaceReflections: false,
    ssrResolutionScale: 0.3,
    ssrSteps: 16,
    bloom: true,
    godRays: false,
    maxTorchLights: 3,
    maxTorchParticles: 0,
    terrainChunkRadius: 1,
    resourceChunkRadius: 1,
    resourceFullDetailDistance: 7,
    skyBakeInterval: Duration(seconds: 30),
    lightingUpdatesPerSecond: 0.33,
    effectsUpdatesPerSecond: 15,
  );

  /// Sustained-load fallback: keep PBR lighting, world shadows, emissive
  /// highlights and fog, but remove the depth-driven AO/contact-shadow chain
  /// and the bloom mip chain. Both are fullscreen multi-pass effects; proxy
  /// shadows and emissive materials keep the important visual cues.
  static const adaptivePerformance = MobileQualityProfile(
    renderScale: 0.72,
    shadowCascades: 1,
    shadowResolution: 384,
    shadowDistance: 28,
    contactShadows: false,
    ambientOcclusion: false,
    ambientOcclusionSamples: 6,
    screenSpaceReflections: false,
    ssrResolutionScale: 0.25,
    ssrSteps: 12,
    bloom: false,
    godRays: false,
    maxTorchLights: 3,
    maxTorchParticles: 3,
    terrainChunkRadius: 1,
    resourceChunkRadius: 1,
    resourceFullDetailDistance: 6,
    skyBakeInterval: Duration(seconds: 30),
    lightingUpdatesPerSecond: 0.25,
    effectsUpdatesPerSecond: 20,
  );

  /// Final emergency mode for devices where world/effect LOD is insufficient.
  static const adaptiveEmergency = MobileQualityProfile(
    renderScale: 0.58,
    shadowCascades: 1,
    shadowResolution: 256,
    shadowDistance: 22,
    contactShadows: false,
    ambientOcclusion: false,
    ambientOcclusionSamples: 4,
    screenSpaceReflections: false,
    ssrResolutionScale: 0.25,
    ssrSteps: 10,
    bloom: false,
    godRays: false,
    maxTorchLights: 2,
    maxTorchParticles: 0,
    terrainChunkRadius: 1,
    resourceChunkRadius: 1,
    resourceFullDetailDistance: 5,
    skyBakeInterval: Duration(seconds: 40),
    lightingUpdatesPerSecond: 0.25,
    effectsUpdatesPerSecond: 12,
  );

  static MobileQualityProfile forQuality(GraphicsQuality quality) =>
      switch (quality) {
        GraphicsQuality.performance => performance,
        GraphicsQuality.quality => MobileQualityProfile.quality,
        GraphicsQuality.auto || GraphicsQuality.balanced => balanced,
      };

  MobileQualityProfile withRenderScale(double scale) => MobileQualityProfile(
    renderScale: scale,
    shadowCascades: shadowCascades,
    shadowResolution: shadowResolution,
    shadowDistance: shadowDistance,
    contactShadows: contactShadows,
    ambientOcclusion: ambientOcclusion,
    ambientOcclusionSamples: ambientOcclusionSamples,
    screenSpaceReflections: screenSpaceReflections,
    ssrResolutionScale: ssrResolutionScale,
    ssrSteps: ssrSteps,
    bloom: bloom,
    godRays: godRays,
    maxTorchLights: maxTorchLights,
    maxTorchParticles: maxTorchParticles,
    terrainChunkRadius: terrainChunkRadius,
    resourceChunkRadius: resourceChunkRadius,
    resourceFullDetailDistance: resourceFullDetailDistance,
    skyBakeInterval: skyBakeInterval,
    lightingUpdatesPerSecond: lightingUpdatesPerSecond,
    effectsUpdatesPerSecond: effectsUpdatesPerSecond,
  );
}

/// Slow hysteresis prevents render-target reallocations from oscillating.
class AutoQualityController {
  AutoQualityController({this.evaluationIntervalSeconds = 5});

  final double evaluationIntervalSeconds;
  double _elapsed = 0;
  int _healthyWindows = 0;
  double renderScale = 1;
  int pressureLevel = 0;

  bool update({
    required double deltaSeconds,
    required double framesPerSecond,
    required double p95FrameTimeMs,
  }) {
    _elapsed += deltaSeconds;
    if (_elapsed < evaluationIntervalSeconds || framesPerSecond <= 0) {
      return false;
    }
    _elapsed = 0;

    if (framesPerSecond < 57 || p95FrameTimeMs > 18.5) {
      _healthyWindows = 0;
      // Do not leave a thermally constrained device stuck at native
      // resolution for several evaluation windows. Moderate pressure still
      // walks through every fidelity tier; severe pressure skips one tier.
      final severePressure = framesPerSecond < 35 || p95FrameTimeMs > 30;
      final nextLevel = (pressureLevel + (severePressure ? 2 : 1)).clamp(0, 4);
      final next = switch (nextLevel) {
        0 || 1 => 1.0,
        2 => 0.88,
        3 => 0.72,
        _ => 0.58,
      };
      if (next == renderScale && nextLevel == pressureLevel) return false;
      pressureLevel = nextLevel;
      renderScale = next;
      return true;
    }
    if (framesPerSecond >= 59 && p95FrameTimeMs <= 17.2) {
      _healthyWindows++;
      if (_healthyWindows < 2) return false;
      _healthyWindows = 0;
      final nextLevel = (pressureLevel - 1).clamp(0, 4);
      final next = switch (nextLevel) {
        0 || 1 => 1.0,
        2 => 0.88,
        3 => 0.72,
        _ => 0.58,
      };
      if (next == renderScale && nextLevel == pressureLevel) return false;
      pressureLevel = nextLevel;
      renderScale = next;
      return true;
    }
    _healthyWindows = 0;
    return false;
  }

  void reset() {
    _elapsed = 0;
    _healthyWindows = 0;
    pressureLevel = 0;
    renderScale = 1;
  }
}
