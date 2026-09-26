import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'atmosphere_settings.dart';
import 'atmosphere_store.dart';
import 'island_rain.dart';
import 'island_world.dart';
import 'island_soundscape.dart';

class IslandAtmosphere extends ChangeNotifier {
  IslandAtmosphere(
    this.scene,
    this.world,
    this.sound,
    this.water,
    this.reflector,
  );
  final Scene scene;
  final IslandWorld world;
  final IslandSoundscape sound;
  final PreprocessedMaterial? water;
  final PlanarReflectorComponent? reflector;
  final store = AtmosphereStore();
  AtmosphereSettings settings = const AtmosphereSettings();
  late PreprocessedSky sky;
  late IslandRain rainfall;
  double hour = 13,
      clouds = .22,
      rain = 0,
      storm = 0,
      mist = 0,
      day = 1,
      wind = .4;
  double _time = 0, _notify = 0, _wet = 0, _nextLightning = 24, flash = 0;
  double? _thunderAt;
  double _lastWet = -1;
  bool loaded = false;
  final _wetMaterials = <PhysicallyBasedMaterial, (vm.Vector4, double)>{};
  final _lamps = <PointLight>[];
  final _bulb = PhysicallyBasedMaterial();
  Future<void> load(Node island, {bool persist = true}) async {
    if (persist) {
      settings = await store.load();
    } else {
      settings = AtmosphereSettings.fromJson({
        'weather': const String.fromEnvironment(
          'WEATHER_SCENARIO',
          defaultValue: 'clear',
        ),
        'hour':
            double.tryParse(
              const String.fromEnvironment('WEATHER_HOUR', defaultValue: '13'),
            ) ??
            13,
      });
    }
    hour = settings.hour;
    wind = settings.wind;
    sky = await loadFmatSky('assets/island_sky.fmat');
    rainfall = IslandRain(
      scene,
      world,
      await loadFmatMaterial('assets/rain.fmat'),
    );
    scene.skybox = Skybox(sky);
    scene.skyEnvironment = SkyEnvironment(
      sky,
      refresh: SkyEnvironmentRefresh.interval,
      interval: const Duration(seconds: 3),
      faceResolution: 64,
      equirectWidth: 256,
    );
    void collect(Node n) {
      for (final primitive in n.mesh?.primitives ?? <MeshPrimitive>[]) {
        final m = primitive.material;
        if (m is PhysicallyBasedMaterial && m.roughnessFactor > .4) {
          _wetMaterials.putIfAbsent(
            m,
            () => (m.baseColorFactor.clone(), m.roughnessFactor),
          );
        }
      }
      for (final child in n.children) {
        collect(child);
      }
    }

    collect(island);
    final bulbGeometry = SphereGeometry(radius: .11);
    for (final c in world.cylinders) {
      if (!['lampPost', 'pathLight'].contains(c['tag'])) continue;
      final light = PointLight(
        color: vm.Vector3(1, .58, .24),
        intensity: 0,
        range: 13,
      );
      _lamps.add(light);
      final n = Node(name: 'Warm island lamp', mesh: Mesh(bulbGeometry, _bulb))
        ..position = vm.Vector3(
          (c['x'] as num).toDouble(),
          (c['yMax'] as num).toDouble() - .08,
          (c['z'] as num).toDouble(),
        )
        ..castsShadows = false;
      n.addComponent(PointLightComponent(light));
      scene.add(n);
    }
    loaded = true;
    _quality();
  }

  void set(AtmosphereSettings value) {
    settings = value;
    _quality();
    store.save(value);
    notifyListeners();
  }

  void _quality() {
    final high = settings.quality == WeatherQuality.high;
    scene.renderScale = high ? 1 : .75;
    reflector?.resolutionScale = high ? .45 : .25;
    scene.directionalLight?.shadowMapResolution = high ? 2048 : 1024;
  }

  void save() => store.flush(settings);
  void update(double dt, vm.Vector3 eye, double yaw) {
    if (!loaded) return;
    _time += dt;
    if (settings.autoTime) {
      settings = settings.copyWith(
        hour: (settings.hour + dt * 24 / (settings.dayMinutes * 60)) % 24,
      );
    }
    final blend = 1 - math.exp(-dt * 2);
    hour = approachHour(hour, settings.hour, blend);
    day = daylightAt(hour);
    final w = settings.weather, s = settings.strength;
    final targetCloud = switch (w) {
      IslandWeather.clear => .20,
      IslandWeather.cloudy => .6 + s * .35,
      IslandWeather.mist => .55,
      IslandWeather.rain => .8 + s * .2,
      IslandWeather.storm => 1.0,
    };
    clouds += (targetCloud - clouds) * blend;
    rain +=
        (((w == IslandWeather.rain || w == IslandWeather.storm) ? s : 0) -
            rain) *
        blend;
    storm += ((w == IslandWeather.storm ? s : 0) - storm) * blend;
    mist += ((w == IslandWeather.mist ? s : 0) - mist) * blend;
    wind += ((settings.wind + storm * .35).clamp(0.0, 1.0) - wind) * blend;
    _wet += (rain - _wet) * (1 - math.exp(-dt * (rain > _wet ? .2 : .035)));
    flash *= math.exp(-dt * 8);
    if (storm > .3 && _time > _nextLightning) {
      flash = storm * .65;
      _thunderAt = _time + 2.2;
      _nextLightning = _time + 23 + math.sin(_time) * 7;
    }
    if (_thunderAt != null && _time >= _thunderAt!) {
      _thunderAt = null;
      sound.thunder(storm);
    }
    final a = (hour - 6) * math.pi / 12;
    final sun = vm.Vector3(math.cos(a) * .85, math.sin(a), .38)..normalize();
    final twilight = math.exp(-sun.y.abs() * 7) * day;
    vm.Vector3 mix(vm.Vector3 a, vm.Vector3 b, double t) => a * (1 - t) + b * t;
    var zenith = mix(
      vm.Vector3(.003, .007, .023),
      vm.Vector3(.045, .19, .46),
      day,
    );
    var horizon = mix(
      vm.Vector3(.012, .024, .05),
      vm.Vector3(.55, .71, .82),
      day,
    );
    horizon = mix(horizon, vm.Vector3(.85, .27, .09), twilight * .75);
    zenith = mix(
      zenith,
      vm.Vector3(.16, .20, .25) * (.06 + day * .94),
      clouds * .7,
    );
    horizon = mix(
      horizon,
      vm.Vector3(.31, .36, .4) * (.07 + day * .93),
      clouds * .65 + mist * .2,
    );
    final sunColor = mix(
      vm.Vector3(1, .93, .78),
      vm.Vector3(1, .36, .10),
      twilight,
    );
    final p = sky.parameters;
    p.setFloat('time', _time);
    p.setFloat('daylight', day);
    p.setFloat('clouds', clouds);
    p.setFloat('storm', storm);
    p.setFloat('wind', wind);
    p.setFloat('flash', flash);
    p.setVec3('sun_direction', sun);
    p.setVec3('zenith', zenith);
    p.setVec3('horizon', horizon);
    p.setVec3('sun_color', sunColor);
    final light = scene.directionalLight!;
    final direction = day > .1 ? sun : -sun;
    light.direction = -direction;
    light.color = day > .1 ? sunColor : vm.Vector3(.42, .57, 1);
    light.intensity = (.13 + day * 2.15) * (1 - clouds * .77) + flash * 4;
    final fog = scene.fog;
    fog.enabled = true;
    fog.mode = FogMode.exponential;
    fog.color = horizon;
    fog.density = .0008 + mist * .019 + rain * .002 + storm * .003;
    fog.height = 1.5;
    fog.heightFalloff = .035;
    fog.maxOpacity = .98;
    fog.skyColorInfluence = .65;
    fog.sunInScatter = .12 * (1 - clouds);
    final glow = 1 - day;
    for (final lamp in _lamps) {
      lamp.intensity = glow * 24;
    }
    _bulb.baseColorFactor = vm.Vector4(.8, .48, .2, 1);
    _bulb.emissiveFactor = vm.Vector4(glow * 5, glow * 2.3, glow * .7, 1);
    if ((_wet - _lastWet).abs() > .002) {
      _lastWet = _wet;
      for (final entry in _wetMaterials.entries) {
        final base = entry.value.$1;
        entry.key.baseColorFactor = vm.Vector4(
          base.x * (1 - _wet * .3),
          base.y * (1 - _wet * .3),
          base.z * (1 - _wet * .3),
          base.w,
        );
        entry.key.roughnessFactor = entry.value.$2 * (1 - _wet * .6);
      }
    }
    if (water != null) {
      water!.parameters.setVec3('sun_direction', direction);
      water!.parameters.setVec3('sun_color', light.color);
      water!.parameters.setFloat('daylight', .035 + day * (1 - clouds * .45));
      water!.parameters.setFloat('sun_strength', light.intensity / 2.2);
      water!.parameters.setFloat('wind', wind);
      water!.parameters.setFloat('rain', rain);
    }
    rainfall.update(
      eye,
      yaw,
      _time,
      rain,
      wind,
      day,
      settings.quality == WeatherQuality.high,
    );
    sound.daylight = day;
    sound.rain = rain;
    sound.wind = wind;
    sound.volume = settings.volume;
    if (_time > _notify) {
      _notify = _time + .5;
      notifyListeners();
    }
  }

  Map<String, Object?> inspect() => {
    'settings': settings.toJson(),
    'hour': hour,
    'daylight': day,
    'clouds': clouds,
    'rain': rain,
    'wetness': _wet,
    'lamps': _lamps.length,
    'rainQuads': rainfall.count,
    'saveError': store.error,
  };
}
