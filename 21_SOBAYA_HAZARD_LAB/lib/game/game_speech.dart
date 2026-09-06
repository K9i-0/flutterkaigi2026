import 'game_voice.dart';

/// Audio-energy envelopes sampled from the bundled, hash-checked speech WAVs.
/// This follows articulation timing, without claiming phoneme recognition.
class SpeechEnvelopes {
  SpeechEnvelopes(Map<String, dynamic> data)
    : hz = (data['hz'] as num).toDouble() {
    for (final row in data['clips'] as List) {
      samples[row['asset'] as String] = (row['open'] as List)
          .map((v) => (v as num).toDouble())
          .toList();
    }
  }
  final double hz;
  final samples = <String, List<double>>{};

  double sample(String asset, double seconds) {
    final values = samples[asset];
    if (values == null || !seconds.isFinite || seconds < 0) return 0;
    final at = seconds * hz, index = at.floor();
    if (index >= values.length - 1) return 0;
    return (values[index] + (values[index + 1] - values[index]) * (at - index))
        .clamp(0.0, 1.0);
  }

  double opening(VoiceSession voice, String speaker) {
    final cue = voice.activeCue, seconds = voice.playbackSeconds;
    if (!voice.speaking || cue?.speaker != speaker || seconds == null) return 0;
    return sample(cue!.asset, seconds);
  }
}
