import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'atmosphere_settings.dart';

class AtmosphereStore {
  File? _file;
  Timer? _timer;
  Future<void> _writes = Future.value();
  String? error;
  Future<AtmosphereSettings> load() async {
    try {
      final directory = await getApplicationSupportDirectory();
      await directory.create(recursive: true);
      _file = File('${directory.path}/island-atmosphere.json');
      if (await _file!.exists()) {
        return AtmosphereSettings.fromJson(
          jsonDecode(await _file!.readAsString()) as Map<String, dynamic>,
        );
      }
    } catch (e) {
      error = '$e';
    }
    return const AtmosphereSettings();
  }

  void save(AtmosphereSettings settings) {
    _timer?.cancel();
    _timer = Timer(const Duration(milliseconds: 350), () => _enqueue(settings));
  }

  void _enqueue(AtmosphereSettings settings) {
    _writes = _writes.then((_) async {
      try {
        if (_file == null) return;
        final temp = File('${_file!.path}.tmp');
        await temp.writeAsString(jsonEncode(settings.toJson()), flush: true);
        await temp.rename(_file!.path);
        error = null;
      } catch (e) {
        error = '$e';
      }
    });
  }

  void flush(AtmosphereSettings settings) {
    _timer?.cancel();
    _enqueue(settings);
  }
}
