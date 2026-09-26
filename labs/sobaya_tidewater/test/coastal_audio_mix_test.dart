import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_tidewater/coastal_audio_mix.dart';
import 'package:sobaya_tidewater/island_world.dart';

void main() {
  final world = IslandWorld(
    jsonDecode(File('assets/world.json').readAsStringSync())
        as Map<String, dynamic>,
    ByteData.sublistView(File('assets/heights.bin').readAsBytesSync()),
  );
  final mix = CoastalAudioMix(world);
  test('coast proximity and elevation attenuate the recorded surf', () {
    final shore = mix.at(5, 2, -45, math.pi);
    final village = mix.at(42, 4, -107, 0);
    final flight = mix.at(220, 142, 220, .55);
    expect(shore.distance, lessThan(15));
    expect(village.distance, greaterThan(shore.distance));
    expect(CoastalAudioMix.surfWeight(flight.distance), lessThan(.1));
    expect(CoastalAudioMix.surfWeight(shore.distance), greaterThan(.5));
    expect(mix.at(55, 4, 35, 0).pier, greaterThan(village.pier));
  });
  test('turning around reverses surf direction; levels stay bounded', () {
    final a = mix.at(5, 2, -45, 0), b = mix.at(5, 2, -45, math.pi);
    expect(a.pan, closeTo(-b.pan, 1e-10));
    expect(CoastalAudioMix.gain(-20, -13), inExclusiveRange(0.0, 1.0));
    expect(CoastalAudioMix.gain(0, -30), 1);
    expect(
      CoastalAudioMix.waveCycle(10 + 2 * math.pi / 1.05),
      CoastalAudioMix.waveCycle(10) + 1,
    );
  });
  test('adopted audio slices exist and are nonempty PCM WAVs', () {
    final manifest = jsonDecode(
      File('assets/audio/bank.json').readAsStringSync(),
    );
    for (final bank in (manifest['bank'] as Map).values) {
      for (final clip in bank['clips']) {
        final bytes = File('assets/audio/${clip['file']}').readAsBytesSync();
        expect(ascii.decode(bytes.sublist(0, 4)), 'RIFF');
        expect(bytes.length, greaterThan(1000));
      }
    }
  });
}
