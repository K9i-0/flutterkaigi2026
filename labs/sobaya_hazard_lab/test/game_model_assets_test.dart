import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sobaya_hazard_lab/game/game_model_assets.dart';

void main() {
  test('mobile platforms select the light set, desktop retains standard', () {
    for (final platform in TargetPlatform.values) {
      expect(
        selectHazardModelProfile(platform, override: 'auto'),
        [TargetPlatform.iOS, TargetPlatform.android].contains(platform)
            ? HazardModelProfile.mobile
            : HazardModelProfile.standard,
      );
      expect(
        selectHazardModelProfile(platform, override: 'standard'),
        HazardModelProfile.standard,
      );
      expect(
        selectHazardModelProfile(platform, override: 'mobile'),
        HazardModelProfile.mobile,
      );
    }
    expect(
      () => selectHazardModelProfile(TargetPlatform.iOS, override: 'typo'),
      throwsArgumentError,
    );
  });

  test('all four variants exist as separate canonical symlinks', () async {
    for (final name in hazardCharacterModels) {
      final standard = hazardModelAsset(name, HazardModelProfile.standard);
      final mobile = hazardModelAsset(name, HazardModelProfile.mobile);
      expect(await FileSystemEntity.isLink(standard), isTrue);
      expect(await FileSystemEntity.isLink(mobile), isTrue);
      expect(await File(standard).exists(), isTrue);
      expect(await File(mobile).exists(), isTrue);
      expect(
        await File(mobile).resolveSymbolicLinks(),
        isNot(await File(standard).resolveSymbolicLinks()),
      );
    }
    for (final prop in ['beer_mug', 'items', 'village', 'farm', 'mountain']) {
      expect(
        hazardModelAsset(prop, HazardModelProfile.mobile),
        hazardModelAsset(prop, HazardModelProfile.standard),
      );
    }
  });
}
