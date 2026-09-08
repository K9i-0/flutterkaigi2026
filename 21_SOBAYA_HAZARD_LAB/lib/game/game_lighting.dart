import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A static sky bake supplies cool fill while a warm key shapes the actors.
/// Reuse the binding: changing volume must not rebake image-based lighting.
class HazardLighting {
  static const advanced = bool.fromEnvironment(
    'HAZARD_ADVANCED_LIGHTING',
    defaultValue: true,
  );
  Map<String, Object> inspect(Scene scene) => {
    'advanced': advanced && _enabled == true,
    'antiAliasing': scene.antiAliasingMode.name,
    'globalIllumination': scene.globalIllumination.enabled,
    'shadowFilter': scene.directionalLight?.shadowFilter.name ?? 'none',
    'depthOfField': scene.depthOfField.enabled,
    'focusDistance': scene.depthOfField.focusDistance,
    'zone': _zone ?? 'village',
  };

  bool? _enabled;
  Object? _shot;

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
    if (advanced && _enabled == true) {
      scene.directionalLight?.shadowFilter = conversation
          ? DirectionalShadowFilter.pcss
          : DirectionalShadowFilter.bilinearPcf;
    }
    scene.depthOfField
      ..enabled = advanced && _enabled == true && conversation
      ..focusDistance = (camera.target - camera.position).length.clamp(.5, 80.0)
      ..fStop = 2.8
      ..blurScale = 1.5
      ..maxForegroundBlur = 2
      ..maxBackgroundBlur = 8
      ..quality = DepthOfFieldQuality.low;
  }

  String? _zone;

  void apply(Scene scene, {required bool enabled, String zone = 'village'}) {
    if (_enabled == enabled && _zone == zone) return;
    final rebuildSky = _enabled != enabled;
    _enabled = enabled;
    _zone = zone;
    if (rebuildSky) {
      scene.antiAliasingMode = enabled && advanced
          ? AntiAliasingMode.taa
          : AntiAliasingMode.auto;
      scene.temporalAntiAliasing
        ..objectMotion = true
        ..skinnedMotion = true
        ..minimumCurrentWeight = .2
        ..varianceGamma = 1.0
        ..sharpness = .18;
      if (!enabled) scene.depthOfField.enabled = false;
      final sky = GradientSkySource(
        zenithColor: enabled
            ? vm.Vector3(.20, .28, .38)
            : vm.Vector3(.23, .26, .24),
        horizonColor: enabled
            ? vm.Vector3(.57, .55, .47)
            : vm.Vector3(.53, .51, .42),
        groundColor: vm.Vector3(.16, .17, .12),
        sunColor: vm.Vector3(.95, .78, .55),
      );
      scene.environmentSettings = EnvironmentSettings(
        globalIlluminationEnabled: enabled && advanced,
        globalIlluminationResolution: vm.Vector3(8, 4, 8),
        globalIlluminationExtents: vm.Vector3(24, 12, 24),
        globalIlluminationIntensity: .3,
        globalIlluminationVisibility: .9,
        globalIlluminationEmissiveBoost: 1.2,
        globalIlluminationInjectionResolution:
            IrradianceInjectionResolution.sixteenth,
        skybox: Skybox(sky),
        skyEnvironment: enabled
            ? SkyEnvironment(sky, faceResolution: 64, equirectWidth: 256)
            : null,
        environment: enabled ? null : EnvironmentMap.studio(),
        environmentIntensity: enabled ? 1.3 : 1,
        toneMapping: enabled
            ? ToneMappingMode.aces
            : ToneMappingMode.pbrNeutral,
        exposure: enabled ? 1.12 : 1.05,
        colorGradingEnabled: enabled,
        contrast: 1.06,
        saturation: .92,
        bloomEnabled: enabled,
        bloomThreshold: 1.15,
        bloomIntensity: .12,
        bloomScatter: .65,
        ambientOcclusionEnabled: enabled,
        ambientOcclusionHalfResolution: true,
        ambientOcclusionSampleCount: 8,
        ambientOcclusionIntensity: .75,
        ambientOcclusionRadius: .4,
        ambientOcclusionMultiBounce: .15,
        fogEnabled: true,
        fogColor: enabled
            ? vm.Vector3(.33, .37, .40)
            : vm.Vector3(.38, .39, .33),
        fogDensity: enabled ? .01 : .012,
        fogStart: enabled ? 18 : 16,
        fogMaxOpacity: enabled ? .65 : .80,
        vignetteEnabled: true,
        vignetteIntensity: enabled ? .18 : .30,
      );
      scene.directionalLight = DirectionalLight(
        direction: enabled
            ? vm.Vector3(-.65, -1, -.45)
            : vm.Vector3(-.6, -1, .3),
        color: enabled ? vm.Vector3(1, .88, .74) : vm.Vector3.all(1),
        intensity: enabled ? 2.6 : 2,
        castsShadow: true,
        shadowCascadeCount: enabled ? 2 : 1,
        shadowMapResolution: 1024,
        shadowMaxDistance: 35,
        cacheStaticShadows: true,
        shadowAmbientStrength: enabled ? .12 : 0,
        shadowFilter: enabled && advanced
            ? DirectionalShadowFilter.bilinearPcf
            : DirectionalShadowFilter.rotatedPoisson,
        angularRadius: .008,
        shadowSoftness: .08,
        shadowDepthBias: .003,
        shadowNormalBias: .01,
      );
    }
    // Region changes reuse the baked sky. Fog stays beyond the close stealth
    // space; warm facade lamps remain recognizable against the cold mountain.
    final look = scene.environmentSettings;
    if (enabled) {
      look
        ..fogColor = switch (zone) {
          'farm' => vm.Vector3(.40, .39, .32),
          'mountain' => vm.Vector3(.29, .35, .41),
          _ => vm.Vector3(.33, .37, .40),
        }
        ..fogDensity = zone == 'mountain' ? .013 : .009
        ..fogStart = zone == 'mountain' ? 20 : 18
        ..fogMaxOpacity = zone == 'mountain' ? .62 : .55
        ..exposure = zone == 'mountain' ? 1.10 : 1.12
        ..temperature = advanced ? (zone == 'mountain' ? -.06 : .035) : 0
        ..tint = advanced && zone == 'farm' ? .015 : 0
        ..saturation = advanced ? (zone == 'mountain' ? .86 : .94) : .92
        ..contrast = advanced ? (zone == 'mountain' ? 1.08 : 1.04) : 1.06;
      scene.environmentSettings = look;
    }
  }
}
