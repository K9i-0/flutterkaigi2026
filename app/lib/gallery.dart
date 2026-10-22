import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'character.dart';
import 'drop_kind.dart';

enum GalleryTab {
  models,
  billboards;

  String get id => name;
}

enum SubjectGroup { character, drop, stage }

/// One viewable game asset. Framing is hand-set: skinned models report no
/// bounds, and a fixed table keeps the opening view identical on every device.
class GallerySubject {
  const GallerySubject._(
    this.id,
    this.group, {
    this.character,
    this.drop,
    required this.target,
    required this.distance,
    required this.minDistance,
    required this.maxDistance,
    this.pitch = .12,
  });
  final String id;
  final SubjectGroup group;
  final CatchCharacter? character;
  final CanKind? drop;

  /// Orbit center and its distance range, in world units.
  final vm.Vector3 target;
  final double distance, minDistance, maxDistance, pitch;

  bool get isStage => group == SubjectGroup.stage;

  static final all = [
    for (final c in pickerOrder)
      GallerySubject._(
        c.id,
        SubjectGroup.character,
        character: c,
        // Clear of the name above and the toolbar below.
        target: vm.Vector3(0, .85, 0),
        distance: 4.8,
        minDistance: .45,
        maxDistance: 8,
      ),
    for (final k in CanKind.values)
      GallerySubject._(
        k.name,
        SubjectGroup.drop,
        drop: k,
        target: vm.Vector3.zero(),
        distance: k.isChikuwa ? 3.4 : 2.9,
        minDistance: .35,
        maxDistance: 7,
        pitch: .18,
      ),
    GallerySubject._(
      'akasaka',
      SubjectGroup.stage,
      target: vm.Vector3(0, -1, 0),
      distance: 24,
      minDistance: 3,
      // Beyond this the city fog flattens everything.
      maxDistance: 80,
      pitch: .32,
    ),
  ];
  static GallerySubject? byId(String? id) =>
      all.where((s) => s.id == id).firstOrNull;
}

/// Viewer state outside the widgets, so Marionette drives exactly what a
/// finger would.
class GalleryController extends ChangeNotifier {
  GalleryController([GallerySubject? subject])
    : subject = subject ?? GallerySubject.all.first {
    reset(notify: false);
  }
  static const fovY = .6, minPitch = -.25, maxPitch = 1.4;
  GalleryTab tab = GalleryTab.models;
  GallerySubject subject;
  double yaw = 0, pitch = 0, distance = 1;
  vm.Vector3 pan = vm.Vector3.zero();

  /// Requested clip; null plays the model's first one (Idle when present).
  String? clip;
  List<String> clips = const [];
  bool playing = true, autoRotate = true, dark = false;

  /// Billboard shown full screen, by its gallery index.
  int? openBillboard;

  /// Seconds since the last touch; auto-rotation waits for the hands to leave.
  double idle = 0;

  void setTab(GalleryTab value) {
    tab = value;
    openBillboard = null;
    notifyListeners();
  }

  void showBillboard(int? index) {
    openBillboard = index;
    notifyListeners();
  }

  void select(GallerySubject value) {
    subject = value;
    clip = null;
    clips = const [];
    reset();
  }

  void reset({bool notify = true}) {
    yaw = 0;
    pitch = subject.pitch;
    distance = subject.distance;
    pan = vm.Vector3.zero();
    idle = 0;
    if (notify) notifyListeners();
  }

  void touch() => idle = 0;

  void orbit(double dYaw, double dPitch) {
    yaw = _wrap(yaw + dYaw);
    pitch = (pitch + dPitch).clamp(minPitch, maxPitch);
    idle = 0;
  }

  /// [factor] above 1 moves closer.
  void zoom(double factor) {
    if (!factor.isFinite || factor <= 0) return;
    distance = (distance / factor).clamp(
      subject.minDistance,
      subject.maxDistance,
    );
    idle = 0;
  }

  /// Screen-space pan in fractions of the view height.
  void panBy(double dx, double dy) {
    final eye = _offset().normalized(),
        right = vm.Vector3(0, 1, 0).cross(eye).normalized(),
        up = eye.cross(right).normalized();
    final scale = distance * math.tan(fovY / 2) * 2;
    pan += (right * -dx + up * dy) * scale;
    // Keep the subject on screen; panning is for detail, not wandering off.
    final limit = subject.isStage ? 60.0 : 1.2;
    if (pan.length > limit) pan = pan.normalized() * limit;
    idle = 0;
  }

  void tick(double dt) {
    idle += dt;
    if (autoRotate && idle > 2.5) yaw = _wrap(yaw + dt * .3);
  }

  void setClips(List<String> names) {
    clips = names;
    if (clip != null && !names.contains(clip)) clip = null;
  }

  vm.Vector3 _offset() => vm.Vector3(
    math.sin(yaw) * math.cos(pitch),
    math.sin(pitch),
    math.cos(yaw) * math.cos(pitch),
  );

  static double _wrap(double a) => math.atan2(math.sin(a), math.cos(a));

  PerspectiveCamera camera() {
    final target = subject.target + pan;
    return PerspectiveCamera(
      position: target + _offset() * distance,
      target: target,
      fovRadiansY: fovY,
      fovNear: subject.isStage ? .1 : .02,
      fovFar: subject.isStage ? 600 : 60,
    );
  }

  Map<String, Object?> inspect() => {
    'tab': tab.id,
    'subject': subject.id,
    'subjects': [for (final s in GallerySubject.all) s.id],
    'yaw': yaw,
    'pitch': pitch,
    'distance': distance,
    'distanceRange': [subject.minDistance, subject.maxDistance],
    'pan': [pan.x, pan.y, pan.z],
    'clip': clip ?? clips.firstOrNull,
    'clips': clips,
    'playing': playing,
    'autoRotate': autoRotate,
    'dark': dark,
    'openBillboard': openBillboard,
  };
}
