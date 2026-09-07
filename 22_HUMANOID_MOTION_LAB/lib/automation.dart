import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import 'catalog.dart';
import 'motion_controller.dart';

MotionController? _lab;
bool _registered = false;
void detachMotionAutomation(MotionController lab) {
  if (identical(_lab, lab)) _lab = null;
}

void attachMotionAutomation(MotionController lab) {
  _lab = lab;
  if (!kDebugMode || kIsWeb || _registered) return;
  _registered = true;
  registerMarionetteExtension(
    name: 'madogiwa.inspectMotionLab',
    description: 'Inspect loaded clips, anatomical proportions and synchronized playback.',
    callback: (_) async => _lab?.ready == true
        ? MarionetteExtensionResult.success(_lab!.inspect())
        : MarionetteExtensionResult.error(1, 'Not ready'),
  );
  registerMarionetteExtension(
    name: 'madogiwa.setMotionLab',
    description: 'method=captured|library|procedural|hybrid, action=Walk etc, optional character=sobaya|fukuchan, compare=true|false, seek=seconds, speed=.25..2, view=front|side|back, skeleton=true|false.',
    callback: (p) async {
      final l = _lab;
      if (l == null || !l.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final methodName = p['method'] ?? l.method.name;
      final character = p['character'] ?? l.character;
      final seek = p['seek'] == null ? null : double.tryParse('${p['seek']}');
      final speed = p['speed'] == null
          ? l.clock.speed
          : double.tryParse('${p['speed']}');
      if (!MotionMethod.values.any((m) => m.name == methodName) ||
          !l.profiles.any((b) => b.id == character) ||
          speed == null ||
          !speed.isFinite ||
          speed < .25 ||
          speed > 2 ||
          (p['seek'] != null && (seek == null || !seek.isFinite || seek < 0)) ||
          (p['view'] != null &&
              !['front', 'side', 'back'].contains('${p['view']}')) ||
          ['compare', 'skeleton'].any(
            (k) => p[k] != null && !['true', 'false'].contains('${p[k]}'),
          )) {
        return MarionetteExtensionResult.invalidParams('Invalid option');
      }
      final method = MotionMethod.values.byName(methodName);
      final body = l.profiles.firstWhere((b) => b.id == character);
      if (p['action'] != null && body.find(method, '${p['action']}') == null) {
        return MarionetteExtensionResult.invalidParams(
          'Action unavailable for this method',
        );
      }
      l.setCharacter(character);
      l.chooseMethod(method);
      if (p['action'] != null) l.choose('${p['action']}');
      if (p['compare'] != null) l.layout('${p['compare']}' == 'true');
      if (p['view'] != null) l.setView('${p['view']}');
      if (p['skeleton'] != null) l.setSkeleton('${p['skeleton']}' == 'true');
      l.clock.speed = speed;
      if (seek != null) l.seek(seek);
      await SchedulerBinding.instance.endOfFrame;
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
}
