import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:marionette_flutter/marionette_flutter.dart';

import '../lab/lab_controller.dart';
import '../lab/simulation.dart';
import '../lab/motion_catalog.dart';

LabController? _lab;
bool _registered = false;
void detachLabAutomation(LabController lab) {
  if (identical(_lab, lab)) _lab = null;
}

void attachLabAutomation(LabController lab) {
  _lab = lab;
  if (!kDebugMode || kIsWeb || _registered) return;
  _registered = true;
  registerMarionetteExtension(
    name: 'madogiwa.playMotion',
    description: 'Play named skeletal clip. name=Idle|Walk|Run|ZombieWalk|DanceStep|DanceDisco|DanceVictory|Toast|MugAttack. Optional seek seconds pauses at a deterministic pose; speed=.25..2.',
    callback: (p) async {
      final l = _lab;
      final name = '${p['name']}';
      final seek = p['seek'] == null ? null : double.tryParse('${p['seek']}');
      final speed = p['speed'] == null ? 1.0 : double.tryParse('${p['speed']}');
      if (l == null || !l.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      if (!motions.any((m) => m.name == name) ||
          speed == null ||
          !speed.isFinite ||
          speed < .25 ||
          speed > 2 ||
          (p['seek'] != null && (seek == null || !seek.isFinite || seek < 0))) {
        return MarionetteExtensionResult.invalidParams(
          'Invalid clip, speed or seek',
        );
      }
      l.selectMotion(name);
      l.setAnimationSpeed(speed);
      if (seek != null) l.seekAnimation(seek);
      await SchedulerBinding.instance.endOfFrame;
      SchedulerBinding.instance.scheduleFrame();
      await SchedulerBinding.instance.endOfFrame;
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.inspectHazard',
    description: 'Inspect Sobaya model, scenario, collision, camera, render options and measured Flutter frame timings.',
    callback: (_) async => _lab == null
        ? MarionetteExtensionResult.error(1, 'No lab attached')
        : MarionetteExtensionResult.success(_lab!.inspect()),
  );
  registerMarionetteExtension(
    name: 'madogiwa.openScenario',
    description: 'Open deterministic scenario. name=model|movement|crowd.',
    callback: (p) async {
      final l = _lab;
      if (l == null || !l.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final name = p['name'];
      if (!LabMode.values.any((m) => m.name == name)) {
        return MarionetteExtensionResult.invalidParams(
          'name=model|movement|crowd',
        );
      }
      l.open(LabMode.values.firstWhere((m) => m.name == name));
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.setLabOption',
    description: 'Set key=shadows|ao|collision|motion|paused|turntable with value=true|false; or key=scale, value=0.5..1.',
    callback: (p) async {
      final l = _lab;
      if (l == null || !l.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      final key = p['key'], value = p['value'];
      if (key == 'scale') {
        final v = double.tryParse('$value');
        if (v == null || !v.isFinite || v < .5 || v > 1) {
          return MarionetteExtensionResult.invalidParams('scale=0.5..1');
        }
        l.option('scale', v);
      } else {
        if (![
              'shadows',
              'ao',
              'collision',
              'motion',
              'paused',
              'turntable',
            ].contains(key) ||
            !['true', 'false'].contains('$value')) {
          return MarionetteExtensionResult.invalidParams(
            'Invalid option or boolean',
          );
        }
        l.option('$key', '$value' == 'true');
      }
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.setCrowdCount',
    description: 'Set count=1|4|8|12. Resets measurement window.',
    callback: (p) async {
      final l = _lab, n = int.tryParse('${p['count']}');
      if (l == null || !l.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      if (![1, 4, 8, 12].contains(n)) {
        return MarionetteExtensionResult.invalidParams('count=1|4|8|12');
      }
      l.setCount(n!);
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.stepMovement',
    description: 'Advance the same collision simulation deterministically. dx,dz=-1..1; frames=1..600; sprint=true|false. Movement scenario required.',
    callback: (p) async {
      final l = _lab,
          dx = double.tryParse('${p['dx'] ?? 0}'),
          dz = double.tryParse('${p['dz'] ?? 0}'),
          n = int.tryParse('${p['frames'] ?? 60}');
      if (l == null || !l.ready || l.mode != LabMode.movement) {
        return MarionetteExtensionResult.error(
          1,
          'Open movement scenario first',
        );
      }
      if (dx == null ||
          dz == null ||
          !dx.isFinite ||
          !dz.isFinite ||
          dx.abs() > 1 ||
          dz.abs() > 1 ||
          n == null ||
          n < 1 ||
          n > 600) {
        return MarionetteExtensionResult.invalidParams('Invalid movement');
      }
      for (var i = 0; i < n; i++) {
        l.simulation.move(dx, dz, 1 / 60, sprint: '${p['sprint']}' == 'true');
      }
      l.placeActors();
      l.camera();
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.setBeerFill',
    description: 'Set fill=0..1 for the reusable beer prop.',
    callback: (p) async {
      final l = _lab, fill = double.tryParse(p['fill'] ?? '');
      if (l == null || !l.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      if (fill == null || !fill.isFinite || fill < 0 || fill > 1) {
        return MarionetteExtensionResult.invalidParams('fill must be 0..1');
      }
      l.setBeerFill(fill);
      final background = p['background'];
      if (background != null &&
          ['studio', 'dark', 'light', 'pattern'].contains(background)) {
        l.setBackdrop(background);
      }
      await SchedulerBinding.instance.endOfFrame;
      await SchedulerBinding.instance.endOfFrame;
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
  registerMarionetteExtension(
    name: 'madogiwa.setLabView',
    description: 'Set view=front|side|back|face|grip.',
    callback: (p) async {
      final l = _lab, v = p['view'];
      if (l == null || !l.ready) {
        return MarionetteExtensionResult.error(1, 'Not ready');
      }
      if (!['front', 'side', 'back', 'face', 'grip'].contains(v)) {
        return MarionetteExtensionResult.invalidParams('Invalid view');
      }
      l.setView('$v');
      return MarionetteExtensionResult.success(l.inspect());
    },
  );
}
