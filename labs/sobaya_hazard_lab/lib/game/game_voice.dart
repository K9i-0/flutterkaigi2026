import 'dart:async';

class VoiceCue {
  const VoiceCue(this.identity, this.asset, {this.gain = 1, this.speaker = ''});
  final String identity, asset;
  final String speaker;
  final double gain;
}

class VoiceCatalog {
  VoiceCatalog(Map<String, dynamic> json) {
    for (final row in json['clips'] as List) {
      final clip = Map<String, dynamic>.from(row);
      clips['${clip['speaker']}\n${clip['text']}'] = clip;
      if (clip['kind'] == 'speech') {
        for (final use in clip['uses'] as List) {
          if ((use as String).startsWith('event:')) {
            eventSeconds[use] = (clip['seconds'] as num).toDouble();
          }
        }
      }
    }
  }
  final clips = <String, Map<String, dynamic>>{};
  final eventSeconds = <String, double>{};
  VoiceCue? cue(String identity, String speaker, String text) {
    final clip = clips['$speaker\n$text'];
    if (clip != null) {
      return VoiceCue(
        identity,
        clip['asset'] as String,
        speaker: speaker,
        gain: clip['kind'] == 'nonverbal' ? .5 : 1,
      );
    }
    if (speaker == 'たこさん') {
      return VoiceCue(identity, 'audio/voice/takosan_response.wav', gain: .5);
    }
    return null;
  }
}

abstract interface class VoicePort {
  Future<void> load(String asset);
  Future<void> volume(double gain);
  Future<void> resume();
  Future<void> pause();
  Future<void> dispose();
}

abstract interface class VoiceTelemetry {
  Map<String, dynamic> get playback;
}

/// A position anchored to backend observations, interpolated between updates.
abstract interface class VoicePositionClock {
  double? get playbackSeconds;
}

/// Each line owns its player, so late completion from a skipped line cannot
/// complete its replacement. Changes are serialized, including slow loads.
class VoiceSession {
  VoiceSession(this.create, {this.loadTimeout = const Duration(seconds: 8)});
  final VoicePort Function(void Function() complete) create;
  final Duration loadTimeout;
  VoiceCue? _wanted, _active;
  VoicePort? _port;
  bool _paused = true, _finished = false, _loading = false, _disposed = false;
  double _volume = 0;
  int _revision = 0, _applied = 0, _serial = 0;
  Future<void>? _work;
  final errors = <String>[];
  bool get loading =>
      _wanted != null && (_loading || _active?.identity != _wanted!.identity);
  bool get speaking => _active != null && !_loading && !_paused && !_finished;
  String? get activeIdentity => _active?.identity;
  VoiceCue? get activeCue => _active;
  double? get playbackSeconds => _port is VoicePositionClock
      ? (_port as VoicePositionClock).playbackSeconds
      : null;
  Future<void> get idle async {
    while (_work != null) {
      await _work;
    }
  }

  void sync(VoiceCue? cue, {required bool paused, required double volume}) {
    if (_disposed) return;
    final gain = (volume * (cue?.gain ?? 1)).clamp(0.0, 1.0);
    if (_wanted?.identity == cue?.identity &&
        _wanted?.asset == cue?.asset &&
        _paused == paused &&
        _volume == gain) {
      return;
    }
    _wanted = cue;
    _paused = paused;
    _volume = gain;
    _revision++;
    _schedule();
  }

  void _schedule() {
    if (_work != null) return;
    _work = _drain().whenComplete(() {
      _work = null;
      if (_applied != _revision) _schedule();
    });
  }

  Future<void> _drain() async {
    while (_applied != _revision) {
      final revision = _revision, cue = _wanted;
      try {
        if (_active?.identity != cue?.identity ||
            _active?.asset != cue?.asset) {
          _serial++;
          final previous = _port;
          _port = null;
          _active = null;
          if (previous != null) await previous.dispose();
          if (revision != _revision) continue;
          _finished = false;
          if (cue != null) {
            final serial = _serial;
            _active = cue;
            _loading = true;
            final port = create(() {
              if (serial == _serial) _finished = true;
            });
            _port = port;
            await port.load(cue.asset).timeout(loadTimeout);
            _loading = false;
          }
        }
        if (revision != _revision) continue;
        final port = _port;
        if (port != null) {
          await port.volume(_volume);
          if (revision != _revision) continue;
          if (_paused || _finished) {
            await port.pause();
          } else {
            await port.resume();
          }
        }
      } catch (error) {
        errors.add('$error');
        if (errors.length > 8) errors.removeAt(0);
        _loading = false;
        _finished = true; // Subtitles and cutscene timing remain available.
        _active = cue;
      }
      _applied = revision;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    sync(null, paused: true, volume: 0);
    _disposed = true;
    await idle;
  }

  Map<String, dynamic> inspect() => {
    'requested': _wanted?.identity,
    'active': activeIdentity,
    'playbackSeconds': playbackSeconds,
    'loading': loading,
    'speaking': speaking,
    'finished': _finished,
    'paused': _paused,
    'volume': _volume,
    'errors': errors,
    if (_port is VoiceTelemetry) 'backend': (_port as VoiceTelemetry).playback,
  };
}
