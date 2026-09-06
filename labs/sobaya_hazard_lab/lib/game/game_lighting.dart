import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

/// A static sky bake supplies cool fill while a warm key shapes the actors.
/// Reuse the binding: changing volume must not rebake image-based lighting.
class HazardLighting {
  bool? _enabled;

  void apply(Scene scene, {required bool enabled}) {
    if (_enabled == enabled) return;
    _enabled = enabled;
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
      skybox: Skybox(sky),
      skyEnvironment: enabled
          ? SkyEnvironment(sky, faceResolution: 64, equirectWidth: 256)
          : null,
      environment: enabled ? null : EnvironmentMap.studio(),
      environmentIntensity: enabled ? 1.3 : 1,
      toneMapping: enabled ? ToneMappingMode.aces : ToneMappingMode.pbrNeutral,
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
      fogColor: enabled ? vm.Vector3(.33, .37, .40) : vm.Vector3(.38, .39, .33),
      fogDensity: enabled ? .01 : .012,
      fogStart: enabled ? 18 : 16,
      fogMaxOpacity: enabled ? .65 : .80,
      vignetteEnabled: true,
      vignetteIntensity: enabled ? .18 : .30,
    );
    scene.directionalLight = DirectionalLight(
      direction: enabled ? vm.Vector3(-.65, -1, -.45) : vm.Vector3(-.6, -1, .3),
      color: enabled ? vm.Vector3(1, .88, .74) : vm.Vector3.all(1),
      intensity: enabled ? 2.6 : 2,
      castsShadow: true,
      shadowCascadeCount: enabled ? 2 : 1,
      shadowMapResolution: 1024,
      shadowMaxDistance: 35,
      cacheStaticShadows: true,
      shadowAmbientStrength: enabled ? .12 : 0,
      shadowSoftness: .08,
      shadowDepthBias: .003,
      shadowNormalBias: .01,
    );
  }
}
