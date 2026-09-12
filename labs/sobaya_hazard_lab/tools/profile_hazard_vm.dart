// Capture an owned Flutter profile session through the public VM service.
// Usage: dart tools/profile_hazard_vm.dart <ws-uri> <output-directory> [seconds]
// Isolate samples may include native blocking stacks; they are not busy-CPU
// percentages or whole-process CPU utilization.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class VmConnection {
  VmConnection(this.socket) {
    subscription = socket.listen(
      (message) {
        final response = jsonDecode(message as String) as Map<String, dynamic>;
        final id = response['id']?.toString();
        final completer = pending.remove(id);
        if (completer == null) return;
        if (response.containsKey('error')) {
          completer.completeError(StateError(jsonEncode(response['error'])));
        } else {
          completer.complete(
            Map<String, dynamic>.from(response['result'] as Map),
          );
        }
      },
      onError: fail,
      onDone: () => fail(StateError('VM disconnected')),
    );
  }

  final WebSocket socket;
  late final StreamSubscription<dynamic> subscription;
  final pending = <String, Completer<Map<String, dynamic>>>{};
  int serial = 0;

  void fail(Object error) {
    final outstanding = pending.values.toList();
    pending.clear();
    for (final call in outstanding) {
      call.completeError(error);
    }
  }

  Future<Map<String, dynamic>> call(
    String method, [
    Map<String, dynamic> params = const {},
  ]) async {
    final id = '${++serial}';
    final completer = Completer<Map<String, dynamic>>();
    pending[id] = completer;
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': id,
        'method': method,
        'params': params,
      }),
    );
    try {
      return await completer.future.timeout(const Duration(seconds: 30));
    } finally {
      pending.remove(id);
    }
  }

  Future<void> close() async {
    await subscription.cancel();
    await socket.close();
  }
}

Future<void> main(List<String> args) async {
  if (args.length < 2 || args.length > 3) {
    stderr.writeln(
      'Usage: profile_hazard_vm.dart <ws-uri> <out-dir> [seconds]',
    );
    exitCode = 64;
    return;
  }
  final uri = Uri.parse(args[0]);
  if (uri.scheme != 'ws' ||
      !['127.0.0.1', 'localhost', '::1'].contains(uri.host)) {
    throw ArgumentError(
      'Use the loopback VM service URI of the owned profile app.',
    );
  }
  final seconds = args.length == 3 ? int.parse(args[2]) : 20;
  if (seconds < 1 || seconds > 60) throw ArgumentError('seconds must be 1..60');
  final output = Directory(args[1])..createSync(recursive: true);
  void save(String name, Object value) =>
      File('${output.path}/$name').writeAsStringSync(jsonEncode(value));
  final connection = VmConnection(await WebSocket.connect(uri.toString()));
  List<dynamic>? previousStreams;
  final previousFlags = <String, String>{};
  final metadata = <String, dynamic>{
    'requestedSeconds': seconds,
    'recordedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'measurement': 'Sampled Dart isolate stacks, including possible native waits; not busy-CPU percentages, total process CPU, GPU time, or presented FPS',
  };
  try {
    final vm = await connection.call('getVM');
    final isolates = (vm['isolates'] as List).cast<Map<String, dynamic>>();
    final isolate = isolates.firstWhere(
      (i) => i['name'] == 'main',
      orElse: () => isolates.first,
    );
    metadata['isolateName'] = isolate['name'];
    metadata['pid'] = vm['pid'];
    final flags = (await connection.call('getFlagList'))['flags'] as List;
    for (final entry in {
      'profiler': 'true',
      'profile_period': '1000',
    }.entries) {
      final flag = flags
          .cast<Map>()
          .where((f) => f['name'] == entry.key)
          .firstOrNull;
      if (flag == null) continue;
      final previous = flag['value'].toString();
      if (previous != entry.value) {
        await connection.call('setFlag', {
          'name': entry.key,
          'value': entry.value,
        });
        previousFlags[entry.key] = previous;
      }
    }
    final timelineFlags = await connection.call('getVMTimelineFlags');
    previousStreams = timelineFlags['recordedStreams'] as List;
    await connection.call('setVMTimelineFlags', {
      'recordedStreams': {
        ...previousStreams.cast<String>(),
        'Dart',
        'Embedder',
        'GC',
      }.toList(),
    });
    final start =
        (await connection.call('getVMTimelineMicros'))['timestamp'] as int;
    stdout.writeln(
      'CPU capture started for $seconds seconds (pid ${vm['pid']}).',
    );
    await Future<void>.delayed(Duration(seconds: seconds));
    final end =
        (await connection.call('getVMTimelineMicros'))['timestamp'] as int;
    final range = {'timeOriginMicros': start, 'timeExtentMicros': end - start};
    final samples = await connection.call('getCpuSamples', {
      'isolateId': isolate['id'],
      ...range,
    });
    save('cpu-samples.json', samples);
    final timeline = await connection.call('getVMTimeline', range);
    save('timeline.json', timeline);
    metadata.addAll({
      ...range,
      'sampleCount': samples['sampleCount'],
      'samplePeriodMicros': samples['samplePeriod'],
      'returnedOriginMicros': samples['timeOriginMicros'],
      'returnedExtentMicros': samples['timeExtentMicros'],
      'timelineEventCount': (timeline['traceEvents'] as List?)?.length,
    });
    stdout.writeln(jsonEncode(metadata));
  } finally {
    // Restore only the tracing configuration we changed in this owned session.
    for (final entry in previousFlags.entries) {
      try {
        await connection.call('setFlag', {
          'name': entry.key,
          'value': entry.value,
        });
      } catch (error) {
        metadata['restoreFlagError'] = error.toString();
      }
    }
    if (previousStreams != null) {
      try {
        await connection.call('setVMTimelineFlags', {
          'recordedStreams': previousStreams,
        });
      } catch (error) {
        metadata['restoreTimelineError'] = error.toString();
      }
    }
    save('capture-metadata.json', metadata);
    await connection.close();
  }
}
