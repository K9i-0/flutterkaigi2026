import 'package:flutter/foundation.dart';

enum HazardModelProfile { standard, mobile }

const hazardCharacterModels = {'sobaya', 'fukuchan', 'yametaro', 'takosan'};

/// Choose once at startup; do not keep both sets of GPU models resident.
HazardModelProfile selectHazardModelProfile(
  TargetPlatform platform, {
  String override = const String.fromEnvironment(
    'HAZARD_MODEL_PROFILE',
    defaultValue: 'auto',
  ),
}) {
  return switch (override) {
    'standard' => HazardModelProfile.standard,
    'mobile' => HazardModelProfile.mobile,
    'auto' =>
      platform == TargetPlatform.iOS || platform == TargetPlatform.android
          ? HazardModelProfile.mobile
          : HazardModelProfile.standard,
    _ => throw ArgumentError.value(
      override,
      'HAZARD_MODEL_PROFILE',
      'Expected auto, standard or mobile',
    ),
  };
}

String hazardModelAsset(String name, HazardModelProfile profile) {
  final folder =
      profile == HazardModelProfile.mobile &&
          hazardCharacterModels.contains(name)
      ? 'assets/models/mobile'
      : 'assets/models';
  return '$folder/$name.glb';
}
