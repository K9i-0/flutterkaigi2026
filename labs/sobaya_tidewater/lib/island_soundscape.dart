import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'coastal_audio_mix.dart';
import 'island_world.dart';

/// Recorded surf, wind, dock water and intermittent birds. Assets are local;
/// at most 3 beds + 3 surf stages + 1 bird + 1 footstep, with bounded async mixer updates.
class IslandSoundscape {
  final _beds = <String, AudioPlayer>{};
  final _voices = <String, AudioPlayer>{};
  final _levels = <String, double>{};
  final _random = math.Random(7);
  Map<String, dynamic> _bank = {};
  CoastalAudioMix? _mix;
  bool ready = false, muted = false, _active = true, _disposed = false;
  bool _busy = false;
  String? error;
  double distance = 0, _nextUpdate = 0, _nextBird = 4;
  double? _washAt, _backAt;
  int? _lastCycle;
  int surfEvents = 0, birdEvents = 0, footstepEvents = 0;
  bool _stepBusy = false;
  String lastSurface = "";

  Iterable<AudioPlayer> get _players => [..._beds.values, ..._voices.values];
  bool get _audible => _active && !muted && !_disposed;

  Future<void> load(IslandWorld world) async {
    try {
      _mix = CoastalAudioMix(world);
      _bank =
          (jsonDecode(await rootBundle.loadString('assets/audio/bank.json'))
                  as Map<String, dynamic>)['bank']
              as Map<String, dynamic>;
      for (final name in ['surf_far', 'wind', 'pier_lap']) {
        if (_disposed) return;
        final p = AudioPlayer();
        _beds[name] = p;
        await p.setReleaseMode(ReleaseMode.loop);
        await p.setVolume(0);
        await p.setSourceAsset('audio/${_bank[name]['clips'][0]['file']}');
        if (_audible) await p.resume();
      }
      for (final name in ['crash', 'wash', 'back', 'bird', 'step']) {
        if (_disposed) return;
        _voices[name] = AudioPlayer();
      }
      ready = !_disposed;
    } catch (e) {
      _failed(e);
    }
  }

  void _failed(Object e) {
    error = e.toString();
    debugPrint('Island soundscape: $e');
  }

  void setActive(bool active) {
    _active = active;
    _lastCycle = null;
    _washAt = null;
    _backAt = null;
    unawaited(_applyActivity());
  }

  Future<void> toggleMute() async {
    muted = !muted;
    await _applyActivity();
  }

  Future<void> _applyActivity() async {
    try {
      for (final p in _players) {
        if (!_audible) {
          await p.pause();
        } else if (_beds.containsValue(p)) {
          await p.resume();
        }
      }
    } catch (e) {
      if (!_disposed) _failed(e);
    }
  }

  void update(
    double time,
    double x,
    double y,
    double z,
    double yaw, {
    bool frozen = false,
  }) {
    if (!ready || !_audible || _busy || time < _nextUpdate) return;
    _nextUpdate = time + .1;
    _busy = true;
    unawaited(
      _update(time, x, y, z, yaw, frozen)
          .catchError((Object e) {
            if (!_disposed) _failed(e);
          })
          .whenComplete(() => _busy = false),
    );
  }

  Future<void> _update(
    double time,
    double x,
    double y,
    double z,
    double yaw,
    bool frozen,
  ) async {
    final mix = _mix!.at(x, y, z, yaw);
    distance = mix.distance;
    final near = CoastalAudioMix.surfWeight(distance);
    final gust = .55 + .25 * math.sin(time * .13) + .2 * math.sin(time * .37);
    await _bed('surf_far', -31, .25 + .75 / (1 + distance / 120));
    await _bed('wind', -36, gust.clamp(.1, 1.0));
    await _bed('pier_lap', -32, mix.pier);
    if (!_audible) return;
    final cycle = CoastalAudioMix.waveCycle(time);
    if (!frozen && _lastCycle != null && cycle > _lastCycle! && near > .02) {
      await _shot('crash', 'surf_crash', -20, near, mix.pan);
      surfEvents++;
      _washAt = time + 1.15;
      _backAt = time + 3.05;
    }
    _lastCycle = cycle;
    if (!frozen && _washAt != null && time >= _washAt!) {
      _washAt = null;
      await _shot('wash', 'surf_wash', -24, near, mix.pan);
    }
    if (!frozen && _backAt != null && time >= _backAt!) {
      _backAt = null;
      await _shot('back', 'surf_backwash', -27, near, mix.pan);
    }
    if (time >= _nextBird) {
      _nextBird = time + 9 + _random.nextDouble() * 12;
      final forest = mix.inland > .5;
      await _shot(
        'bird',
        forest ? 'bird_forest' : 'gull',
        forest ? -34 : -30,
        (1 - y.abs() / 150).clamp(0.0, 1.0),
        _random.nextDouble() * 1.4 - .7,
      );
      birdEvents++;
    }
  }

  void footstep(String surface, {bool landing = false, bool left = false}) {
    if (!ready || !_audible || _stepBusy) return;
    _stepBusy = true;
    lastSurface = surface;
    unawaited(
      _shot('step', 'step_$surface', landing ? -29 : -34, 1, left ? -.12 : .12)
          .then((_) {
            footstepEvents++;
          })
          .catchError((Object e) {
            if (!_disposed) _failed(e);
          })
          .whenComplete(() => _stepBusy = false),
    );
  }

  Future<void> _bed(String name, double target, double weight) async {
    final gain =
        CoastalAudioMix.gain(
          target,
          (_bank[name]['clips'][0]['lufs'] as num).toDouble(),
        ) *
        weight;
    final old = _levels[name] ?? 0;
    final next = old + (gain - old) * .25;
    if ((next - old).abs() > .0005) {
      _levels[name] = next;
      await _beds[name]!.setVolume(_audible ? next : 0);
    }
  }

  Future<void> _shot(
    String voice,
    String name,
    double target,
    double weight,
    double pan,
  ) async {
    if (!_audible || weight < .01) return;
    final clips = _bank[name]['clips'] as List;
    final clip = clips[_random.nextInt(clips.length)];
    final player = _voices[voice]!;
    await player.stop();
    await player.setBalance(pan);
    await player.setVolume(
      CoastalAudioMix.gain(target, (clip['lufs'] as num).toDouble()) * weight,
    );
    await player.setSourceAsset('audio/${clip['file']}');
    if (_audible) await player.resume();
  }

  Future<Map<String, Object?>> inspect() async => {
    'ready': ready,
    'muted': muted,
    'active': _active,
    'error': error,
    'coastDistance': distance,
    'surfEvents': surfEvents,
    'footstepEvents': footstepEvents,
    'lastSurface': lastSurface,
    'birdEvents': birdEvents,
    'levels': Map<String, double>.from(_levels),
    'players': {
      for (final e in _beds.entries)
        e.key: {
          'state': e.value.state.name,
          'positionMs': (await e.value.getCurrentPosition())?.inMilliseconds,
        },
    },
  };

  Future<void> dispose() async {
    _disposed = true;
    for (final p in _players) {
      await p.dispose();
    }
  }
}
