import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_tidewater/atmosphere_settings.dart';

void main() {
  test(
    'Settings survive serialization, including independent quality/audio',
    () {
      const s = AtmosphereSettings(
        hour: 22.5,
        weather: IslandWeather.storm,
        autoTime: true,
        dayMinutes: 60,
        quality: WeatherQuality.balanced,
        volume: .3,
      );
      expect(AtmosphereSettings.fromJson(s.toJson()).toJson(), s.toJson());
    },
  );
  test('Corrupt and future settings recover to bounded usable values', () {
    final s = AtmosphereSettings.fromJson({
      'hour': double.nan,
      'weather': 'snow',
      'strength': 12,
      'wind': -1,
      'volume': 'loud',
      'quality': 'ultra',
      'dayMinutes': 0,
    });
    expect(s.hour, 13);
    expect(s.weather, IslandWeather.clear);
    expect(s.strength, 1);
    expect(s.wind, 0);
    expect(s.volume, .8);
    expect(s.dayMinutes, 5);
  });
  test('Clock transition crosses midnight by the short path', () {
    expect(approachHour(23, 1, .5), 0);
    expect(approachHour(1, 23, .5), 0);
    expect(AtmosphereSettings.clock(24.5), '00:30');
  });
  test('Daylight has a continuous dawn and night envelope', () {
    expect(daylightAt(13), 1);
    expect(daylightAt(0), 0);
    expect(daylightAt(5.8), lessThan(daylightAt(6)));
    expect(daylightAt(6), lessThan(daylightAt(6.2)));
  });
}
