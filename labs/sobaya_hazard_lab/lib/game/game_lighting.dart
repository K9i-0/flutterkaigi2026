import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_graphics.dart';

/// A static sky bake supplies cool fill while a warm key shapes the actors.
/// Reuse the binding: changing volume must not rebake image-based lighting.
class HazardLighting {
  static const advanced = bool.fromEnvironment(
    'HAZARD_ADVANCED_LIGHTING',
    defaultValue: true,
  );
  Map<String, Object> inspect(Scene scene) {
    final look = scene.environmentSettings;
    final light = scene.directionalLight;
    return {
      'advanced': advanced && _enabled == true,
      'graphicsPreset': _preset?.name ?? HazardGraphicsPreset.quality.name,
      'antiAliasing': scene.antiAliasingMode.name,
      'globalIllumination': scene.globalIllumination.enabled,
      'globalIlluminationProbeUpdateBudget':
          look.globalIlluminationProbeUpdateBudget,
      'shadowFilter': light?.shadowFilter.name ?? 'none',
      'shadowMapResolution': light?.shadowMapResolution ?? 0,
      'shadowCascadeCount': light?.shadowCascadeCount ?? 0,
      'shadowMaxDistance': light?.shadowMaxDistance ?? 0,
      'cacheStaticShadows': light?.cacheStaticShadows ?? false,
      'ambientOcclusion': look.ambientOcclusionEnabled,
      'ambientOcclusionSamples': look.ambientOcclusionSampleCount,
      'ambientOcclusionHalfResolution': look.ambientOcclusionHalfResolution,
      'bloom': look.bloomEnabled,
      'depthOfField': scene.depthOfField.enabled,
      'focusDistance': scene.depthOfField.focusDistance,
      'zone': _zone ?? 'village',
    };
  }

  bool? _enabled;
  HazardGraphicsPreset? _preset;
  Object? _shot;

  // Keep these bindings across zone, sound and graphics changes. A settings
  // toggle should not allocate another cubemap or rebake an unchanged sky.
  final _cinematicSky = GradientSkySource(
    zenithColor: vm.Vector3(.12, .19, .28),
    horizonColor: vm.Vector3(.32, .39, .46),
    groundColor: vm.Vector3(.20, .24, .27),
    sunColor: vm.Vector3(.95, .78, .55),
  );
  final _simpleSky = GradientSkySource(
    zenithColor: vm.Vector3(.23, .26, .24),
    horizonColor: vm.Vector3(.53, .51, .42),
    groundColor: vm.Vector3(.16, .17, .12),
    sunColor: vm.Vector3(.95, .78, .55),
  );
  late final _skyEnvironment = SkyEnvironment(
    _cinematicSky,
    faceResolution: 64,
    equirectWidth: 256,
  );

  /// Called once for the render camera, not gameplay picking/culling cameras.
  void prepareCamera(
    Scene scene,
    PerspectiveCamera camera, {
    required bool conversation,
    required Object shot,
  }) {
    if (_shot != shot) {
      if (scene.globalIllumination.enabled) {
        scene.invalidateGlobalIllumination();
      }
      _shot = shot;
    }
    final cinematicFocus =
        advanced && _enabled == true && (_preset?.cinematicFocus ?? false);
    if (advanced && _enabled == true) {
      scene.directionalLight?.shadowFilter = conversation && cinematicFocus
          ? DirectionalShadowFilter.pcss
          : DirectionalShadowFilter.bilinearPcf;
    }
    scene.depthOfField
      ..enabled = cinematicFocus && conversation
      ..focusDistance = (camera.target - camera.position).length.clamp(.5, 80.0)
      ..fStop = 2.8
      ..blurScale = 1.5
      ..maxForegroundBlur = 2
      ..maxBackgroundBlur = 8
      ..quality = DepthOfFieldQuality.low;
  }

  String? _zone;

  void apply(
    Scene scene, {
    required bool enabled,
    String zone = 'village',
    HazardGraphicsPreset preset = HazardGraphicsPreset.quality,
  }) {
    if (_enabled == enabled && _zone == zone && _preset == preset) return;
    final rebuildSettings = _enabled != enabled || _preset != preset;
    final changedRegion = _zone != zone;
    _enabled = enabled;
    _preset = preset;
    _zone = zone;
    if (rebuildSettings) {
      scene.antiAliasingMode = enabled && advanced
          ? (preset.temporalAntiAliasing
                ? AntiAliasingMode.taa
                : AntiAliasingMode.smaa)
          : AntiAliasingMode.auto;
      scene.temporalAntiAliasing
        ..objectMotion = true
        ..skinnedMotion = true
        ..minimumCurrentWeight = .2
        ..varianceGamma = 1.0
        ..sharpness = .22;
      scene.depthOfField.enabled = false;
      final sky = enabled ? _cinematicSky : _simpleSky;
      scene.environmentSettings = EnvironmentSettings(
        globalIlluminationEnabled:
            enabled && advanced && preset.dynamicGlobalIllumination,
        globalIlluminationResolution: vm.Vector3(8, 4, 8),
        globalIlluminationExtents: vm.Vector3(24, 12, 24),
        globalIlluminationIntensity: .3,
        globalIlluminationVisibility: .9,
        globalIlluminationEmissiveBoost: 1.2,
        // At most one quarter of the 256 probes per frame. Geometry and sky
        // already establish the broad lighting; this is a subtle extra bounce.
        globalIlluminationProbeUpdateBudget: 64,
        globalIlluminationInjectionResolution:
            IrradianceInjectionResolution.sixteenth,
        skybox: Skybox(sky),
        skyEnvironment: enabled ? _skyEnvironment : null,
        environment: enabled ? null : EnvironmentMap.studio(),
        environmentIntensity: enabled ? 1.65 : 1,
        toneMapping: enabled
            ? ToneMappingMode.aces
            : ToneMappingMode.pbrNeutral,
        exposure: enabled ? 1.12 : 1.05,
        colorGradingEnabled: enabled,
        contrast: 1.06,
        saturation: .92,
        bloomEnabled: enabled,
        bloomThreshold: 1.25,
        bloomIntensity: .10,
        bloomScatter: .65,
        ambientOcclusionEnabled: enabled,
        ambientOcclusionHalfResolution: true,
        ambientOcclusionSampleCount: preset.ambientOcclusionSamples,
        ambientOcclusionIntensity: .82,
        ambientOcclusionRadius: .45,
        ambientOcclusionMultiBounce: .15,
        fogEnabled: true,
        fogColor: enabled
            ? vm.Vector3(.33, .37, .40)
            : vm.Vector3(.38, .39, .33),
        fogDensity: enabled ? .01 : .012,
        fogStart: enabled ? 18 : 16,
        fogMaxOpacity: enabled ? .65 : .80,
        vignetteEnabled: true,
        vignetteIntensity: enabled ? .14 : .30,
      );
      scene.directionalLight = DirectionalLight(
        direction: enabled
            ? vm.Vector3(-.65, -1, -.45)
            : vm.Vector3(-.6, -1, .3),
        color: enabled ? vm.Vector3(1, .88, .74) : vm.Vector3.all(1),
        intensity: enabled ? 2.35 : 2,
        castsShadow: true,
        shadowCascadeCount: enabled ? 2 : 1,
        shadowMapResolution: enabled ? preset.shadowMapResolution : 1024,
        shadowMaxDistance: enabled ? preset.shadowMaxDistance : 35,
        cacheStaticShadows: true,
        shadowAmbientStrength: enabled ? .22 : 0,
        shadowFilter: enabled && advanced
            ? DirectionalShadowFilter.bilinearPcf
            : DirectionalShadowFilter.rotatedPoisson,
        angularRadius: .008,
        shadowSoftness: .08,
        shadowDepthBias: .002,
        shadowNormalBias: .01,
      );
    }
    if (changedRegion && scene.globalIllumination.enabled) {
      scene.invalidateGlobalIllumination();
    }
    // Region changes reuse the baked sky. Fog stays beyond the close stealth
    // space; warm facade lamps remain recognizable against the cold mountain.
    final look = scene.environmentSettings;
    if (enabled) {
      look
        ..fogColor = switch (zone) {
          'farm' => vm.Vector3(.24, .27, .25),
          'mountain' => vm.Vector3(.15, .21, .28),
          _ => vm.Vector3(.19, .25, .30),
        }
        ..fogDensity = zone == 'mountain' ? .010 : .006
        ..fogStart = zone == 'mountain' ? 20 : 18
        ..fogMaxOpacity = zone == 'mountain' ? .55 : .46
        ..exposure = zone == 'mountain' ? 1.10 : 1.12
        ..temperature = advanced ? (zone == 'mountain' ? -.06 : .035) : 0
        ..tint = advanced && zone == 'farm' ? .015 : 0
        ..saturation = advanced ? (zone == 'mountain' ? .86 : .94) : .92
        ..contrast = advanced ? (zone == 'mountain' ? 1.08 : 1.04) : 1.06;
      scene.environmentSettings = look;
    }
  }
}
