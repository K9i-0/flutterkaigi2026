import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_campaign.dart';
import 'package:sobaya_hazard_lab/game/game_region_loader.dart';
import 'package:sobaya_hazard_lab/game/game_state.dart';

class _Resource {
  _Resource(this.id, this.serial);
  final String id;
  final int serial;
}

class _Harness {
  final events = <String>[];
  final claims = <String, int>{};
  final mounted = <_Resource>{};
  int serial = 0, commits = 0;
  String? failAcquire, failPrepare, failAttach;
  bool failWarmUp = false;
  Completer<void>? acquisitionGate, warmUpGate;

  late final loader = HazardRegionLoader<_Resource>(
    acquire: (id) async {
      events.add('acquire:$id');
      await acquisitionGate?.future;
      if (id == failAcquire) throw StateError('load failed');
      claims.update(id, (count) => count + 1, ifAbsent: () => 1);
      return _Resource(id, ++serial);
    },
    release: (id) async {
      events.add('release:$id');
      expect(mounted.any((node) => node.id == id), isFalse);
      expect(claims[id], 1);
      claims.remove(id);
    },
    prepare: (id, node) {
      events.add('prepare:$id');
      if (id == failPrepare) throw StateError('preparation failed');
    },
    attach: (id, node) {
      events.add('attach:$id');
      mounted.add(node);
      if (id == failAttach) throw StateError('mount failed');
    },
    detach: (id, node) {
      events.add('detach:$id');
      mounted.remove(node);
    },
    warmUp: () async {
      events.add('warm');
      await warmUpGate?.future;
      if (failWarmUp) throw StateError('warm-up failed');
    },
  );

  Future<bool> go(String id) => loader.activate(
    id,
    commit: () {
      events.add('commit:$id');
      commits++;
    },
  );
}

void main() {
  test('initial load owns only the requested region', () async {
    final h = _Harness();
    expect(await h.go('village'), isTrue);
    expect(h.claims, {'village': 1});
    expect(h.mounted.single, same(h.loader.current));
    expect(h.events, [
      'acquire:village',
      'prepare:village',
      'attach:village',
      'warm',
      'commit:village',
    ]);
    await h.loader.dispose();
    expect(h.claims, isEmpty);
    expect(h.mounted, isEmpty);
  });

  test(
    'retains previous claim until mounted target finishes warming',
    () async {
      final h = _Harness();
      await h.go('village');
      final previous = h.loader.current;
      h.warmUpGate = Completer<void>();
      final transition = h.go('farm');
      await Future<void>.delayed(Duration.zero);
      expect(h.loader.loading, isTrue);
      expect(h.loader.targetId, 'farm');
      expect(h.loader.current, same(previous));
      expect(h.claims, {'village': 1, 'farm': 1});
      expect(h.mounted.single.id, 'farm');
      expect(h.commits, 1);
      expect(await h.go('mountain'), isFalse);
      expect(h.events, isNot(contains('acquire:mountain')));
      h.warmUpGate!.complete();
      expect(await transition, isTrue);
      expect(h.claims, {'farm': 1});
      expect(
        h.events.indexOf('commit:farm'),
        lessThan(h.events.indexOf('release:village')),
      );
      expect(h.loader.loading, isFalse);
      expect(h.loader.targetId, isNull);
      await h.loader.dispose();
    },
  );

  test('same-region action keeps the existing claim and geometry', () async {
    final h = _Harness();
    await h.go('village');
    final original = h.loader.current;
    h.events.clear();
    expect(await h.go('village'), isTrue);
    expect(h.loader.current, same(original));
    expect(h.events, ['commit:village']);
    await h.loader.dispose();
  });

  for (final stage in ['acquire', 'prepare', 'attach', 'warm']) {
    test(
      '$stage failure restores previous region and retries cleanly',
      () async {
        final h = _Harness();
        await h.go('village');
        final original = h.loader.current;
        switch (stage) {
          case 'acquire':
            h.failAcquire = 'farm';
          case 'prepare':
            h.failPrepare = 'farm';
          case 'attach':
            h.failAttach = 'farm';
          case 'warm':
            h.failWarmUp = true;
        }
        expect(await h.go('farm'), isFalse);
        expect(h.loader.error, isA<StateError>());
        expect(h.loader.current, same(original));
        expect(h.loader.targetId, 'farm');
        expect(h.mounted.single, same(original));
        expect(h.claims, {'village': 1});
        expect(h.commits, 1);
        expect(
          h.events.where((e) => e == 'release:farm').length,
          stage == 'acquire' ? 0 : 1,
        );
        h.failAcquire = h.failPrepare = h.failAttach = null;
        h.failWarmUp = false;
        expect(await h.go('farm'), isTrue);
        expect(h.loader.error, isNull);
        expect(h.claims, {'farm': 1});
        await h.loader.dispose();
      },
    );
  }

  for (final stage in ['acquire', 'warm']) {
    test(
      'dispose during $stage releases late success without committing',
      () async {
        final h = _Harness();
        await h.go('village');
        final gate = Completer<void>();
        if (stage == 'acquire') h.acquisitionGate = gate;
        if (stage == 'warm') h.warmUpGate = gate;
        final transition = h.go('farm');
        await Future<void>.delayed(Duration.zero);
        final disposal = h.loader.dispose();
        gate.complete();
        expect(await transition, isFalse);
        await disposal;
        expect(h.commits, 1);
        expect(h.claims, isEmpty);
        expect(h.mounted, isEmpty);
        expect(h.loader.current, isNull);
        expect(await h.go('mountain'), isFalse);
        await h.loader.dispose();
      },
    );
  }

  test(
    'backtracking reloads nodes while campaign retains regional state',
    () async {
      final maps = <String, Map<String, dynamic>>{
        for (final id in ['village', 'farm', 'mountain'])
          id: jsonDecode(
            File('assets/$id.json').readAsStringSync(),
          ) as Map<String, dynamic>,
      };
      final campaign = HazardCampaign(maps);
      final h = _Harness();
      await h.go('village');
      final originalNode = h.loader.current;
      final originalState = campaign.state;
    originalState.crates.first.broken = true;
      originalState.hasKey = originalState.gateOpen = true;
      originalState.exitRequested = Map<String, dynamic>.from(
        (originalState.map['exits'] as List).first,
      );
      originalState.phase = PlayPhase.transition;
      expect(
        await h.loader.activate(
          'farm',
          commit: () => expect(campaign.traverse(), isTrue),
        ),
        isTrue,
      );
      final farm = campaign.state;
      farm.exitRequested = Map<String, dynamic>.from(
        (farm.map['exits'] as List).firstWhere(
          (exit) => exit['target'] == 'village',
        ),
      );
      farm.phase = PlayPhase.transition;
      expect(
        await h.loader.activate(
          'village',
          commit: () => expect(campaign.traverse(), isTrue),
        ),
        isTrue,
      );
      expect(campaign.state, same(originalState));
    expect(campaign.state.crates.first.broken, isTrue);
      expect(h.loader.current, isNot(same(originalNode)));
      expect(h.claims, {'village': 1});
      expect(campaign.regions.keys, containsAll(['village', 'farm']));
      await h.loader.dispose();
    },
  );
}
