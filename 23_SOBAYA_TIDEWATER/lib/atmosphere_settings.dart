import 'dart:math' as math;

enum IslandWeather { clear, cloudy, mist, rain, storm }

enum WeatherQuality { balanced, high }

extension WeatherLabel on IslandWeather {
  String get label => ['晴れ', '曇り', '霧', '雨', '嵐'][index];
  String get description => [
    '澄んだ空と、穏やかな海。',
    '流れる雲と、柔らかな光。',
    '海岸を包む霧と、静かな遠景。',
    '雨に濡れる桟橋と、波紋。',
    '低い雲、強い風、遠くの雷。',
  ][index];
}

class AtmosphereSettings {
  const AtmosphereSettings({
    this.hour = 13,
    this.weather = IslandWeather.clear,
    this.strength = .75,
    this.wind = .4,
    this.autoTime = false,
    this.dayMinutes = 20,
    this.quality = WeatherQuality.high,
    this.volume = .8,
  });
  final double hour, strength, wind, dayMinutes, volume;
  final IslandWeather weather;
  final WeatherQuality quality;
  final bool autoTime;
  AtmosphereSettings copyWith({
    double? hour,
    IslandWeather? weather,
    double? strength,
    double? wind,
    bool? autoTime,
    double? dayMinutes,
    WeatherQuality? quality,
    double? volume,
  }) => AtmosphereSettings(
    hour: hour ?? this.hour,
    weather: weather ?? this.weather,
    strength: strength ?? this.strength,
    wind: wind ?? this.wind,
    autoTime: autoTime ?? this.autoTime,
    dayMinutes: dayMinutes ?? this.dayMinutes,
    quality: quality ?? this.quality,
    volume: volume ?? this.volume,
  );
  Map<String, Object> toJson() => {
    'version': 1,
    'hour': hour,
    'weather': weather.name,
    'strength': strength,
    'wind': wind,
    'autoTime': autoTime,
    'dayMinutes': dayMinutes,
    'quality': quality.name,
    'volume': volume,
  };
  factory AtmosphereSettings.fromJson(Map<String, dynamic> json) {
    double number(String key, double fallback, double min, double max) {
      final v = json[key];
      return v is num && v.isFinite ? v.toDouble().clamp(min, max) : fallback;
    }

    return AtmosphereSettings(
      hour: number('hour', 13, 0, 23.99),
      weather:
          IslandWeather.values
              .where((e) => e.name == json['weather'])
              .firstOrNull ??
          IslandWeather.clear,
      strength: number('strength', .75, 0, 1),
      wind: number('wind', .4, 0, 1),
      autoTime: json['autoTime'] == true,
      dayMinutes: number('dayMinutes', 20, 5, 120),
      quality:
          WeatherQuality.values
              .where((e) => e.name == json['quality'])
              .firstOrNull ??
          WeatherQuality.high,
      volume: number('volume', .8, 0, 1),
    );
  }
  static String clock(double hour) {
    final minutes = (hour * 60).round() % (24 * 60);
    return '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
  }
}

/// Smooth cyclic interpolation must take the short path across midnight.
double approachHour(double current, double target, double blend) {
  final delta = (target - current + 12) % 24 - 12;
  return (current + delta * blend) % 24;
}

double daylightAt(double hour) {
  final altitude = math.sin((hour - 6) * math.pi / 12);
  final t = ((altitude + .12) / .35).clamp(0.0, 1.0);
  return t * t * (3 - 2 * t);
}
