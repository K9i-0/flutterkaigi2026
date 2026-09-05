import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'lab_controller.dart';
import 'simulation.dart';

/// Opt-in repeatable visible-frame benchmark. Never treats missing samples as 0.
class LabBenchmark {
  LabBenchmark(this.lab) {
    _next();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) => _poll());
  }

  final LabController lab;
  Timer? _timer;
  final _watch = Stopwatch();
  int _index = -1;
  static const _cases = [
    (name: 'one', count: 1, shadows: true, ao: false, scale: 1.0),
    (name: 'four', count: 4, shadows: true, ao: false, scale: 1.0),
    (name: 'eight', count: 8, shadows: true, ao: false, scale: 1.0),
    (name: 'twelve', count: 12, shadows: true, ao: false, scale: 1.0),
    (
      name: 'twelve-no-shadow',
      count: 12,
      shadows: false,
      ao: false,
      scale: 1.0,
    ),
    (name: 'twelve-half-res', count: 12, shadows: true, ao: false, scale: .5),
    (name: 'twelve-ao', count: 12, shadows: true, ao: true, scale: 1.0),
  ];

  void _next() {
    _index++;
    if (_index == _cases.length) {
      dispose();
      debugPrintSynchronously('HAZARD_BENCHMARK_COMPLETE');
      return;
    }
    final test = _cases[_index];
    lab.open(LabMode.crowd);
    lab.setCount(test.count);
    lab.option('motion', true);
    lab.option('shadows', test.shadows);
    lab.option('ao', test.ao);
    lab.option('scale', test.scale);
    _watch
      ..reset()
      ..start();
  }

  void _poll() {
    if (_watch.elapsedMilliseconds < 8000) return;
    final complete = lab.frames.count == 240;
    if (!complete && _watch.elapsedMilliseconds < 30000) return;
    debugPrintSynchronously(
      'HAZARD_BENCHMARK ${jsonEncode({'case': _cases[_index].name, 'valid': complete && kProfileMode, 'elapsedMs': _watch.elapsedMilliseconds, ...lab.inspect()})}',
    );
    _next();
  }

  void dispose() {
    _timer?.cancel();
    _watch.stop();
  }
}
