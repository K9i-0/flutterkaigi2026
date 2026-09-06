import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'game_state.dart';
import 'game_navigation.dart';
import 'game_camera.dart';
import 'game_contact_shadows.dart';
import 'game_campaign.dart';
import 'game_settings.dart';
import 'game_events.dart';
import 'game_voice.dart';
import 'game_voice_player.dart';
import 'game_speech.dart';
import 'game_soundscape.dart';
import '../lab/beer_mug_component.dart';
import '../lab/simulation.dart' show FrameSamples;

EnemyNavigation _buildEnemyNavigation(Map<String, dynamic> map) =>
    HazardGameState(map).prepareNavigation();

class CharacterPlayer {
  CharacterPlayer(Node template, this.names) : node = template.clone() {
    for (final name in names) {
      final animation = node.findAnimationByName(name);
      if (animation == null) throw StateError('Missing $name');
      clips[name] = node.createAnimationClip(animation)
        ..loop = ![
          'ReloadHandgun',
          'ReloadShotgun',
          'Hit',
          'Evade',
          'Kick',
          'MugAttack',
          'Vault',
          'Grab',
          'Release',
          'BreakFree',
        ].contains(name)
        ..weight = 0;
    }
    setMotion('Idle');
    clips['Idle']!.weight = 1;
  }
  final Node node;
  final List<String> names;
  final clips = <String, AnimationClip>{};
  String current = '';
  void setMotion(String name) {
    if (current == name) return;
    current = name;
    clips[name]!.seek(0);
    clips[name]!.play();
  }

  void update(double dt, bool playing, {double speed = 1}) {
    for (final e in clips.entries) {
      final target = e.key == current ? 1.0 : 0.0;
      e.value.weight += (target - e.value.weight) * (dt * 12).clamp(0, 1);
      e.value.playbackTimeScale = speed;
      if (playing && (e.key == current || e.value.weight > .005)) {
        e.value.play();
      } else {
        e.value.pause();
      }
    }
  }
}

class HeldFingerPose extends Component {
  HeldFingerPose(this.pose, {this.shouldHold});
  final vm.Quaternion pose;
  final bool Function()? shouldHold;
  @override
  void update(double deltaSeconds) {
    if (shouldHold?.call() ?? true) node.rotation = pose.clone();
  }
}

class UpperBodyAim extends Component {
  UpperBodyAim(this.state);
  final HazardGameState Function() state;
  @override
  void update(double deltaSeconds) {
    final s = state();
    if (!s.aiming || s.reloading > 0 || s.hurtTime > 0 || s.actionLocked) {
      return;
    }
    final parentRotation = node.parent?.globalTransform.getRotation();
    if (parentRotation == null) return;
    parentRotation.invert();
    final axis = parentRotation.transform(
      vm.Vector3(math.cos(s.heading), 0, -math.sin(s.heading)),
    );
    node.rotation =
        vm.Quaternion.axisAngle(axis, s.pitch - s.recoil) * node.rotation;
  }
}

class HazardGameController extends ChangeNotifier {
  final scene = Scene();
  final frames = FrameSamples();
  HazardGameState? state;
  late HazardCampaign campaign;
  final environments = <String, Node>{};
  final _navigationGeometry = <String, EnemyNavigation>{};
  bool ready = false, disposed = false;
  HazardSettings settings = HazardSettings();
  HazardDirector? director;
  bool foreground = true;
  int renderedTicks = 0;
  bool get animateScene =>
      ready &&
      !disposed &&
      foreground &&
      !posePreview &&
      (state!.running ||
          state!.phase == PlayPhase.dialogue ||
          (director != null && !director!.paused));

  /// A static SceneView still repaints on UI changes. Freeze animation clocks
  /// and audio immediately; no future frame callback is needed to pause them.
  void prepareStaticFrame() {
    if (!ready || disposed || animateScene) return;
    _syncVoice();
    soundscape.pause();
    for (final actor in [player, ...enemies, ...npcs.values]) {
      for (final clip in actor.clips.values) {
        clip.pause();
      }
    }
    scene.update(0);
  }

  void refreshView() {
    if (!ready || disposed) return;
    tick(Duration.zero, 0);
    prepareStaticFrame();
    notifyListeners();
  }

  void setForeground(bool value) {
    foreground = value;
    _syncVoice();
    // A hidden window may stop frame callbacks before the next tick arrives.
    if (!value) soundscape.pause();
    if (ready && !disposed) notifyListeners();
  }

  bool get muted => settings.muted;
  PlayPhase settingsReturn = PlayPhase.title;
  Future<void> _settingsQueue = Future.value();
  late Node village, itemsTemplate, beerTemplate, fukuTemplate, sobayaTemplate;
  late CharacterPlayer player;
  final npcs = <String, CharacterPlayer>{};
  final enemyMugs = <Node>[];
  final enemyBeer = <BeerMugComponent>[];
  final enemies = <CharacterPlayer>[],
      pickupNodes = <String, Node>{},
      crateNodes = <String, Node>{};
  late Node pistol, shotgun, impact, muzzle;
  final fxPools = <String, AudioPool>{};
  final audioPlayback = <Map<String, dynamic>>[];
  late VoiceCatalog voiceCatalog;
  late SpeechEnvelopes speechEnvelopes;
  final speechWeights = <String, double>{};
  final _speechNodes = <String, List<Node>>{};
  Map<String, Object?> inspectSpeechFaces() => {
    for (final entry in _speechNodes.entries)
      entry.key: {
        'opening': speechWeights[entry.key] ?? 0,
        'nodes': entry.value.length,
        'weights': entry.value.first.morphWeights?.toList(),
      },
  };
  final voice = VoiceSession(AssetVoicePort.new);
  final soundscape = HazardSoundscape();
  int _dialogueVisit = 0;
  bool _wasDialogue = false;
  SharedPreferences? preferences;
  String? _checkpointJson;
  String saveStatus = '';
  Future<void> _saveQueue = Future.value();
  int _pendingSaves = 0;
  bool get saving => _pendingSaves > 0;
  bool get hasCheckpoint => _checkpointJson != null;
  ui.Size viewport = const ui.Size(1280, 800);
  double devicePixelRatio = 1;
  double _notifyTime = 0, _stepDistance = 0;
  String? error;
  bool posePreview = false;
  bool benchmarkMode = false;
  int runEpoch = 0;
  ContactShadows? contactShadows;
  Future<void> load() async {
    preferences = await SharedPreferences.getInstance();
    settings = HazardSettings.decode(
      preferences!.getString('hazard.settings.v1'),
    );
    final maps = <String, Map<String, dynamic>>{};
    for (final id in ['village', 'farm', 'mountain']) {
      maps[id] = jsonDecode(
        await rootBundle.loadString('assets/$id.json'),
      ) as Map<String, dynamic>;
    }
    campaign = HazardCampaign(
      maps,
      collection: preferences!.getStringList('hazard.collection.v1')?.toSet(),
    );
    for (final entry in maps.entries) {
      _navigationGeometry[entry.key] = await compute(
        _buildEnemyNavigation,
        entry.value,
      );
    }
    state = campaign.state..phase = PlayPhase.title;
    state!.useNavigation(_navigationGeometry[state!.zoneId]!);
    final savedRun = preferences!.getString('hazard.run.v1');
    if (savedRun != null) {
      try {
        HazardCampaign.restore(jsonDecode(savedRun), maps, state!.collected);
        _checkpointJson = savedRun;
      } catch (_) {
        saveStatus = '保存データを読み込めませんでした。新しく探索を始められます。';
      }
    }
    await Scene.initializeStaticResources();
    final loaded = await Future.wait(
      [
        'village',
        'items',
        'beer_mug',
        'sobaya',
        'fukuchan',
        'yametaro',
        'takosan',
        'farm',
        'mountain',
      ].map((n) => loadScene('assets/models/$n.glb')),
    );
    if (disposed) return;
    environments.addAll({
      'village': loaded[0],
      'farm': loaded[7],
      'mountain': loaded[8],
    });
    village = loaded[0];
    itemsTemplate = loaded[1];
    beerTemplate = loaded[2];
    sobayaTemplate = loaded[3];
    fukuTemplate = loaded[4];
    for (final n in state!.npcs) {
      final actor = CharacterPlayer(loaded[n['id'] == 'yametaro' ? 5 : 6], [
        'Idle',
        'Talk',
        'Wave',
        if (n['id'] == 'yametaro') 'Walk',
      ]);
      actor.node.position = vm.Vector3(
        (n['x'] as num).toDouble(),
        0,
        (n['z'] as num).toDouble(),
      );
      npcs[n['id']] = actor;
      scene.add(actor.node);
    }
    for (final entry in environments.entries) {
      final environment = entry.value, map = maps[entry.key]!;
      _static(environment);
      for (final h in map['houses']) {
        final roof = environment.getChildByName('Roof_${h['id']}');
        if (roof != null) _static(roof, value: false);
      }
      _static(environment.getChildByName('FarmGate')!, value: false);
      for (final row in [
        ...map['collection'],
        ...(map['targets'] as List? ?? []),
      ]) {
        _static(environment.getChildByName(row['node'])!, value: false);
      }
    }
    scene.add(village);
    scene.environmentSettings = EnvironmentSettings(
      exposure: 1.05,
      ambientOcclusionEnabled: false,
      fogEnabled: true,
      fogColor: vm.Vector3(.38, .39, .33),
      fogDensity: .012,
      fogStart: 16,
      fogMaxOpacity: .80,
      vignetteEnabled: true,
      vignetteIntensity: .30,
    );
    scene.skybox = Skybox(
      GradientSkySource(
        zenithColor: vm.Vector3(.23, .26, .24),
        horizonColor: vm.Vector3(.53, .51, .42),
        groundColor: vm.Vector3(.16, .17, .12),
        sunColor: vm.Vector3(.8, .65, .4),
      ),
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.6, -1, .3),
      intensity: 2,
      castsShadow: true,
      shadowCascadeCount: 1,
      shadowMapResolution: 1024,
      shadowMaxDistance: 35,
      cacheStaticShadows: true,
      shadowDepthBias: .003,
      shadowNormalBias: .01,
    );
    _applySettings();
    player = CharacterPlayer(fukuTemplate, [
      'Idle',
      'Walk',
      'Run',
      'Aim',
      'AimShotgun',
      'ReloadHandgun',
      'ReloadShotgun',
      'Hit',
      'Evade',
      'Kick',
      'Climb',
      'Vault',
      'Struggle',
      'BreakFree',
    ]);
    player.node
        .getChildByName('Spine1')!
        .addComponent(UpperBodyAim(() => state!));
    scene.add(player.node);
    // Sample the already-reviewed gripping pose through the public animation
    // player, preserving the engine's handedness and bone-frame conversion.
    final gripRig = sobayaTemplate.clone(), sampler = AnimationPlayer();
    final gripClip = sampler.createAnimationClip(
      gripRig.findAnimationByName('MugAttack')!,
      gripRig,
    )..weight = 1;
    gripClip.seek(.3);
    sampler.update(0);
    final fingerPoses = <String, vm.Quaternion>{
      for (final digit in ['Index', 'Middle', 'Ring', 'Thumb'])
        for (final joint in [1, 2])
          '$digit$joint.R': gripRig
              .getChildByName('$digit$joint.R')!
              .rotation
              .clone(),
    };
    for (var i = 0; i < state!.enemies.length; i++) {
      final actor = CharacterPlayer(sobayaTemplate, [
        'Idle',
        'Walk',
        'Run',
        'ZombieWalk',
        'Climb',
        'Vault',
        'MugAttack',
        'Grab',
        'Hold',
        'Release',
      ]);
      for (final finger in fingerPoses.entries) {
        actor.node
            .getChildByName(finger.key)!
            .addComponent(
              HeldFingerPose(
                finger.value,
                shouldHold: () =>
                    ['Grab', 'Hold', 'Release'].every(
                      (name) =>
                          actor.current != name &&
                          actor.clips[name]!.weight < .005,
                    ) &&
                    actor.current != 'Vault' &&
                    actor.clips['Vault']!.weight < .005 &&
                    actor.current != 'Climb' &&
                    actor.clips['Climb']!.weight < .005 &&
                    actor.current != 'MugAttack' &&
                    actor.clips['MugAttack']!.weight < .005,
              ),
            );
      }
      final mug = beerTemplate.clone();
      final anchor = mug.getChildByName('Grip')!;
      final inverseGrip = vm.Matrix4.copy(anchor.globalTransform)
        ..invert()
        ..multiply(mug.globalTransform);
      mug.localTransform = vm.Matrix4.rotationX(-math.pi / 2)
        ..multiply(inverseGrip);
      actor.node.getChildByName('PropSocket.R')!.add(mug);
      final liquid = BeerMugComponent(
        isPaused: () =>
            !(state!.running ||
                (director != null && !director!.paused && foreground)),
      )..detail = false;
      mug.addComponent(liquid);
      enemyMugs.add(mug);
      enemyBeer.add(liquid);
      enemies.add(actor);
      scene.add(actor.node);
    }
    pistol = _prop('Handgun');
    shotgun = _prop('Shotgun');
    scene.add(pistol);
    scene.add(shotgun);
    final mat = UnlitMaterial()..baseColorFactor = vm.Vector4(1, .82, .4, 1);
    impact = Node(mesh: Mesh(SphereGeometry(radius: .065), mat))
      ..castsShadows = false
      ..visible = false;
    scene.add(impact);
    muzzle = Node(mesh: Mesh(SphereGeometry(radius: .045), mat))
      ..castsShadows = false
      ..visible = false;
    scene.add(muzzle);
    _resetNodes();
    for (final name in [
      'shot',
      'shotgun',
      'pickup',
      'collect',
      'heal',
      'clear',
      'enemy',
      'hurt',
      'reload',
      'equip',
      'empty',
      'gate',
      'break',
      'step',
      'defeat',
    ]) {
      fxPools[name] = await AudioPool.createFromAsset(
        path: 'audio/$name.wav',
        maxPlayers: 3,
      );
    }
    contactShadows = ContactShadows(11);
    scene.add(contactShadows!.node);
    voiceCatalog = VoiceCatalog(
      jsonDecode(
        await rootBundle.loadString('assets/audio/voice-manifest.json'),
      ),
    );
    speechEnvelopes = SpeechEnvelopes(
      jsonDecode(
        await rootBundle.loadString('assets/audio/speech-envelopes.json'),
      ),
    );
    void collect(Node node, List<Node> result) {
      if (node.morphTargetNames.contains('SpeechOpen')) result.add(node);
      for (final child in node.children) {
        collect(child, result);
      }
    }

    for (final entry in {'福ちゃん': player, 'やめ太郎': npcs['yametaro']!}.entries) {
      final nodes = <Node>[];
      collect(entry.value.node, nodes);
      if (nodes.isEmpty) {
        throw StateError('Missing speech shapes: ${entry.key}');
      }
      _speechNodes[entry.key] = nodes;
    }
    ready = true;
    tick(Duration.zero, 0);
    prepareStaticFrame();
    notifyListeners();
  }

  void startEvent(String id) {
    if (state!.seenEvents.contains(id)) return;
    director = HazardDirector(id, voiceSeconds: voiceCatalog.eventSeconds);
    state!
      ..stopInput()
      ..phase = PlayPhase.cinematic;
    notifyListeners();
  }

  void advanceEvent({bool skip = false}) {
    final d = director;
    if (d == null) return;
    if (skip) {
      d.skip();
    } else if (d.paused) {
      d.paused = false;
    } else {
      d.next();
    }
    if (d.done) _finishEvent();
    _syncVoice();
    notifyListeners();
  }

  void setEventPaused(bool paused) {
    if (director == null) return;
    director!.paused = paused;
    // Apply immediately, including when no next SceneView tick is scheduled.
    _syncVoice();
    prepareStaticFrame();
    notifyListeners();
  }

  void _finishEvent() {
    final id = director!.id;
    state!.seenEvents.add(id);
    state!
      ..stopInput()
      ..phase = id == 'ending' ? PlayPhase.clear : PlayPhase.playing;
    director = null;
    // Restore any temporary ending positions and normally absent actors.
    for (final entry in npcs.entries) {
      final rows = state!.npcs.where((n) => n['id'] == entry.key);
      entry.value.node.visible = rows.isNotEmpty;
      if (rows.isNotEmpty) {
        entry.value.node.position = vm.Vector3(
          (rows.first['x'] as num).toDouble(),
          0,
          (rows.first['z'] as num).toDouble(),
        );
      }
    }
    if (id != 'ending') {
      state!.invulnerable = 1;
      state!.say(state!.objective);
      unawaited(saveCheckpoint());
    }
  }

  void _applySettings() {
    state?.damageScale = settings.damageScale;
    state?.enemySpeedScale = settings.enemySpeedScale;
    scene.renderScale = settings.renderScale;
  }

  void changeSettings(void Function(HazardSettings) change) {
    change(settings);
    _applySettings();
    _syncVoice();
    final encoded = settings.encode();
    _settingsQueue = _settingsQueue.then((_) async {
      try {
        if (!await preferences!.setString('hazard.settings.v1', encoded)) {
          throw StateError('Preferences were not saved');
        }
      } catch (_) {
        saveStatus = '設定を保存できませんでした。';
        if (!disposed) notifyListeners();
      }
    });
    notifyListeners();
  }

  void openSettings() {
    settingsReturn = state!.phase;
    state!
      ..stopInput()
      ..phase = PlayPhase.settings;
    notifyListeners();
  }

  void closeSettings() {
    state!.phase = settingsReturn;
    notifyListeners();
  }

  void _static(Node node, {bool value = true}) {
    node.shadowStatic = value;
    for (final child in node.children) {
      _static(child, value: value);
    }
  }

  Node _prop(String name) {
    final template = itemsTemplate.getChildByName(name);
    if (template == null) throw StateError('Missing prop $name');
    return template.clone();
  }

  void _resetNodes() {
    for (final node in pickupNodes.values) {
      scene.remove(node);
    }
    pickupNodes.clear();
    for (final node in crateNodes.values) {
      scene.remove(node);
    }
    crateNodes.clear();
    for (final c in state!.crates) {
      final n = _prop(c.kind == 'crate' ? 'Crate' : 'Barrel')
        ..position = vm.Vector3(c.x, 0, c.z);
      scene.add(n);
      crateNodes[c.id] = n;
    }
  }

  void _mountRegion() {
    state!.useNavigation(_navigationGeometry[state!.zoneId]!);
    _applySettings();
    scene.remove(village);
    village = environments[state!.zoneId]!;
    scene.add(village);
    for (final entry in npcs.entries) {
      final rows = state!.npcs.where((n) => n['id'] == entry.key);
      entry.value.node.visible = rows.isNotEmpty;
      if (rows.isNotEmpty) {
        final n = rows.first;
        entry.value.node.position = vm.Vector3(
          (n['x'] as num).toDouble(),
          0,
          (n['z'] as num).toDouble(),
        );
      }
    }
    _resetNodes();
    _stepDistance = 0;
  }

  bool transitionRegion() {
    if (!campaign.traverse()) return false;
    state = campaign.state;
    _mountRegion();
    if (state!.zoneId == 'farm' && !state!.seenEvents.contains('farm')) {
      startEvent('farm');
    }
    notifyListeners();
    return true;
  }

  void restart() {
    runEpoch++;
    posePreview = false;
    director = null;
    campaign.restart();
    state = campaign.state;
    _mountRegion();
    notifyListeners();
  }

  void startRun() {
    restart();
    unawaited(saveCheckpoint());
    startEvent('opening');
  }

  Future<void> saveCheckpoint({bool announce = false}) {
    final s = state;
    if (!ready ||
        s == null ||
        posePreview ||
        benchmarkMode ||
        s.health <= 0 ||
        [
          PlayPhase.title,
          PlayPhase.dead,
          PlayPhase.clear,
          PlayPhase.dialogue,
          PlayPhase.cinematic,
          PlayPhase.settings,
        ].contains(s.phase)) {
      return Future.value();
    }
    final encoded = jsonEncode(campaign.checkpoint());
    _pendingSaves++;
    saveStatus = '記録中…';
    _saveQueue = _saveQueue.then((_) async {
      try {
        final ok = await preferences!.setString('hazard.run.v1', encoded);
        if (!ok) throw StateError('Save failed');
        _checkpointJson = encoded;
        saveStatus = 'チェックポイントを保存しました。';
        if (announce && identical(s, state)) s.say(saveStatus);
      } catch (_) {
        saveStatus = '保存に失敗しました。もう一度お試しください。';
        if (identical(s, state)) s.say(saveStatus);
      } finally {
        _pendingSaves--;
        if (!disposed) notifyListeners();
      }
    });
    return _saveQueue;
  }

  void continueRun() {
    if (_checkpointJson == null) return;
    try {
      campaign = HazardCampaign.restore(
        jsonDecode(_checkpointJson!),
        campaign.maps,
        state!.collected,
      );
      state = campaign.state;
      director = null;
      posePreview = false;
      _mountRegion();
      player.setMotion('Idle');
      saveStatus = '';
    } catch (_) {
      saveStatus = '保存データを復元できませんでした。';
    }
    notifyListeners();
  }

  void toggle(PlayPhase phase) {
    state!.toggle(phase);
    notifyListeners();
  }

  void rotate(double dx, double dy) {
    final s = state!;
    if (!s.running) return;
    s.yaw -= dx * .006 * settings.sensitivity;
    s.pitch = (s.pitch + dy * .004 * settings.sensitivity).clamp(
      minCameraPitch,
      maxCameraPitch,
    );
  }

  PerspectiveCamera camera() {
    final s = state!;
    final d = director;
    if (d != null) {
      return PerspectiveCamera(
        position: d.shot.camera(d.progress),
        target: d.shot.aim,
        fovRadiansY: .78,
        fovNear: .07,
        fovFar: 85,
      );
    }
    if (s.phase == PlayPhase.dialogue && npcs.containsKey(s.talkingTo)) {
      final n = npcs[s.talkingTo]!.node.position;
      final angle = math.atan2(s.x - n.x, s.z - n.z) + .2;
      return PerspectiveCamera(
        position:
            n +
            vm.Vector3(math.sin(angle) * 2.25, 1.25, math.cos(angle) * 2.25),
        target: n + vm.Vector3(0, .94, 0),
        fovRadiansY: .68,
        fovNear: .07,
        fovFar: 85,
      );
    }
    return playerCamera(s);
  }

  void fire() {
    if (!ready) return;
    final s = state!;
    final ray = camera().screenPointToRay(
      ui.Offset(viewport.width / 2, viewport.height / 2),
      viewport,
    );
    s.shoot(ray.origin, ray.direction);
    _sound();
    notifyListeners();
  }

  void _sound() {
    final s = state!, sounds = s.drainSounds();
    if (muted) return;
    // Coalesce identical cues to the nearest/loudest source in this frame.
    // A shot no longer erases a simultaneous enemy cue or beer drop.
    final gains = <String, double>{};
    for (final sound in sounds) {
      var occluded = false;
      if (sound.spatial) {
        final delta = vm.Vector3(
          sound.x! - s.x,
          sound.y - (s.y + 1.2),
          sound.z! - s.z,
        );
        occluded =
            delta.length > .001 &&
            s.wallDistance(
                  vm.Vector3(s.x, s.y + 1.2, s.z),
                  delta.normalized(),
                  delta.length,
                ) <
                delta.length - .1;
      }
      final gain = sound.gain(
        s.x,
        s.z,
        occluded: occluded,
        listenerY: s.y + 1.2,
      );
      gains[sound.name] = math.max(gains[sound.name] ?? 0, gain);
    }
    for (final entry in gains.entries) {
      final pool = fxPools[entry.key];
      final volume =
          (entry.key == 'shotgun' ? .75 : .55) * settings.volume * entry.value;
      if (pool != null && volume > .001) {
        final record = <String, dynamic>{
          'name': entry.key,
          'volume': volume,
          'started': false,
        };
        audioPlayback.add(record);
        if (audioPlayback.length > 12) audioPlayback.removeAt(0);
        unawaited(
          pool.start(volume: volume).then((_) {
            record['started'] = true;
          }),
        );
      }
    }
  }

  void _syncVoice() {
    if (!ready || disposed) return;
    final s = state!, d = director;
    final dialogue = s.phase == PlayPhase.dialogue;
    if (dialogue && !_wasDialogue) _dialogueVisit++;
    _wasDialogue = dialogue;
    VoiceCue? cue;
    if (d != null) {
      cue = voiceCatalog.cue(
        'event:$runEpoch:${d.id}:${d.index}',
        d.shot.speaker,
        d.shot.text,
      );
    } else if (dialogue) {
      final line = s.dialogueLine;
      cue = voiceCatalog.cue(
        'dialogue:$runEpoch:$_dialogueVisit:${s.zoneId}:${s.dialogueOwner}:${s.dialogueTopic}:${s.dialogueIndex}:${line.text}',
        line.speaker,
        line.text,
      );
    }
    voice.sync(
      cue,
      paused: !foreground || (d?.paused ?? false),
      volume: settings.muted ? 0 : settings.volume * settings.voiceVolume,
    );
    _syncSpeechFaces();
  }

  void _syncSpeechFaces() {
    for (final entry in _speechNodes.entries) {
      final opening = foreground && !posePreview
          ? speechEnvelopes.opening(voice, entry.key)
          : 0.0;
      speechWeights[entry.key] = opening;
      for (final node in entry.value) {
        node.setMorphWeight(
          node.morphTargetNames.indexOf('SpeechOpen'),
          opening,
        );
        node.setMorphWeight(
          node.morphTargetNames.indexOf('SpeechNarrow'),
          opening * .2,
        );
      }
    }
  }

  void tick(Duration elapsed, double delta) {
    if (!ready || disposed) return;
    final s = state!, dt = delta.clamp(0.0, .05);
    _syncVoice();
    final bx = s.x, bz = s.z;
    if (director != null) {
      if (foreground && !voice.loading) director!.tick(dt);
      if (director!.done) _finishEvent();
    }
    if (!posePreview) s.tick(dt);
    if (!posePreview && director == null) {
      if (s.phase == PlayPhase.clear && !s.seenEvents.contains('ending')) {
        startEvent('ending');
      }
      if (s.running &&
          s.zoneId == 'mountain' &&
          s.x > 1 &&
          s.bossAlive &&
          !s.seenEvents.contains('last_order')) {
        startEvent('last_order');
      }
    }
    if (s.phase == PlayPhase.transition && transitionRegion()) return;
    _syncVoice();
    soundscape.tick(
      dt,
      zone: s.zoneId,
      active:
          foreground &&
          (s.running ||
              s.phase == PlayPhase.dialogue ||
              (director != null && !director!.paused)),
      threat:
          s.running &&
          s.enemies.any(
            (e) =>
                e.alive &&
                e.active &&
                e.alerted &&
                (e.x - s.x) * (e.x - s.x) + (e.z - s.z) * (e.z - s.z) < 144,
          ),
      speaking: voice.speaking && settings.voiceVolume > 0,
      volume: settings.muted ? 0 : settings.volume * settings.environmentVolume,
    );
    final moved = math.sqrt(math.pow(s.x - bx, 2) + math.pow(s.z - bz, 2));
    var motion = s.grapple != null
        ? 'Struggle'
        : s.breakFreeTime > 0
        ? 'BreakFree'
        : s.vault != null
        ? (s.vault!.crossing ? 'Vault' : 'Walk')
        : s.climb != null
        ? (s.climb!.onRungs ? 'Climb' : 'Walk')
        : s.hurtTime > 0
        ? 'Hit'
        : s.evadeTime > 0
        ? 'Evade'
        : s.kickTime > 0
        ? 'Kick'
        : s.reloading > 0
        ? (s.weapon == 'shotgun' ? 'ReloadShotgun' : 'ReloadHandgun')
        : s.aiming
        ? s.weapon == 'shotgun'
              ? 'AimShotgun'
              : 'Aim'
        : moved > .0001
        ? s.sprint
              ? 'Run'
              : 'Walk'
        : 'Idle';
    if (director != null) {
      motion = 'Idle';
    } else if ((!s.running || posePreview) &&
        !s.traversing &&
        s.grapple == null &&
        s.breakFreeTime <= 0) {
      motion = player.current;
    }
    player.setMotion(motion);
    player.update(
      dt,
      (s.running || (director != null && !director!.paused && foreground)) &&
          !posePreview,
      speed: s.climb != null && motion == 'Walk'
          ? (s.climb!.up ? 1 : -1) * 1.4 / .91610738
          : motion == 'Walk'
          ? 1.25 / .91610738
          : motion == 'Run'
          ? 2.8 / 2.16571248
          : 1,
    );
    if (s.grapple != null) {
      if (posePreview) {
        for (final clip in player.clips.entries) {
          clip.value.weight = clip.key == 'Struggle' ? 1 : 0;
        }
      }
      player.clips['Struggle']!
        ..seek(s.grapple!.elapsed % 1)
        ..playbackTimeScale = 0;
    } else if (s.breakFreeTime > 0) {
      player.clips['BreakFree']!
        ..seek(.7 - s.breakFreeTime)
        ..playbackTimeScale = 0;
    }
    if (s.vault?.crossing ?? false) {
      player.clips['Vault']!
        ..seek(s.vault!.progress * 1.6)
        ..playbackTimeScale = 0;
    }
    if (s.climb?.onRungs ?? false) {
      player.clips['Climb']!
        ..seek(s.climb!.clipTime)
        ..playbackTimeScale = 0;
    }
    player.node.position = vm.Vector3(s.x, s.y, s.z);
    // Dialogue uses a close shot of the speaker, beyond the player's shoulder.
    final closeCamera =
        director == null &&
        (playerCamera(s).position - vm.Vector3(s.x, s.y + 1.25, s.z)).length <
            .8;
    player.node.visible = s.phase != PlayPhase.dialogue && !closeCamera;
    player.node.rotation = vm.Quaternion.axisAngle(
      vm.Vector3(0, 1, 0),
      s.heading + math.pi,
    );
    for (final entry in npcs.entries) {
      final actor = entry.value, n = entry.value.node.position;
      if (!actor.node.visible) {
        actor.update(dt, false);
        continue;
      }
      final near = math.pow(s.x - n.x, 2) + math.pow(s.z - n.z, 2) < 36;
      final cinematicTalk = director?.shot.actor == entry.key;
      final talking = s.phase == PlayPhase.dialogue && s.talkingTo == entry.key;
      if (near) {
        actor.node.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.atan2(s.x - n.x, s.z - n.z) + math.pi,
        );
      }
      actor.setMotion(
        cinematicTalk
            ? director!.shot.motion
            : talking &&
                  s.dialogueLine.speaker ==
                      (entry.key == 'yametaro' ? 'やめ太郎' : 'たこさん')
            ? 'Talk'
            : near && !(entry.key == 'yametaro' ? s.metYametaro : s.metTakosan)
            ? 'Wave'
            : 'Idle',
      );
      actor.update(
        dt,
        s.running ||
            talking ||
            (director != null && !director!.paused && foreground),
      );
    }
    final mugCamera =
        director?.shot.camera(director!.progress) ??
        vm.Vector3(s.x, s.y + 1, s.z);
    var detailedMug = -1, nearestMugDistance = 4.0;
    for (var i = 0; i < s.enemies.length; i++) {
      final e = s.enemies[i];
      if (!e.active || e.dropped) continue;
      final distance = (mugCamera - vm.Vector3(e.x, e.y + 1, e.z)).length;
      if (distance < nearestMugDistance) {
        nearestMugDistance = distance;
        detailedMug = i;
      }
    }
    for (var i = 0; i < enemies.length; i++) {
      final actor = enemies[i];
      if (i >= s.enemies.length) {
        enemyMugs[i].visible = false;
        actor.node.visible = false;
        actor.update(dt, false);
        continue;
      }
      final e = s.enemies[i];
      enemyBeer[i].detail = i == detailedMug;
      enemyMugs[i].visible =
          e.active &&
          !e.dropped &&
          e.climb == null &&
          e.vault == null &&
          !e.grabPending &&
          s.grapple?.enemyId != e.id &&
          e.releaseTime <= 0;
      actor.node.visible = e.active && (!e.dropped);
      actor.node.position = vm.Vector3(e.x, e.y, e.z);
      actor.node.rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 1, 0),
        e.heading + math.pi,
      );
      final scale = e.alive ? 1.0 : math.max(.001, 1 - e.vanish / .65);
      actor.node.scale = vm.Vector3.all(scale * (e.boss ? 1.2 : 1));
      final bossMelee =
          e.boss &&
          (e.bossMove == BossMove.swipeWindup ||
              e.bossMove == BossMove.slamWindup ||
              (e.bossMove == BossMove.recovery &&
                  (e.bossAttack == BossMove.swipeWindup ||
                      e.bossAttack == BossMove.slamWindup)));
      actor.setMotion(
        s.grapple?.enemyId == e.id
            ? 'Hold'
            : e.attackPending && e.grabPending
            ? 'Grab'
            : e.releaseTime > 0
            ? 'Release'
            : e.vault != null
            ? (e.vault!.crossing ? 'Vault' : 'Walk')
            : e.climb != null
            ? (e.climb!.onRungs ? 'Climb' : 'Walk')
            : e.boss && director?.shot.actor == 'sobaya'
            ? director!.shot.motion
            : e.bossMove == BossMove.charging
            ? 'Run'
            : e.bossMove == BossMove.chargeWindup
            ? 'Run'
            : e.runningApproach && e.moved > .0001
            ? 'Run'
            : bossMelee || e.attackPending || e.meleeRecovery > 0
            ? 'MugAttack'
            : e.stun > 0
            ? 'Idle'
            : e.moved > .0001
            ? 'Walk'
            : 'Idle',
      );
      actor.update(
        dt,
        (s.running || (director != null && !director!.paused && foreground)) &&
            e.alive &&
            e.active,
        speed: e.climb != null && !e.climb!.onRungs
            ? (e.climb!.up ? 1 : -1) * 1.4 / 1.007474632
            : e.attackPending
            ? (e.boss
                  ? 1.05 / (e.bossMove == BossMove.slamWindup ? 1.25 : .85)
                  : 1.5)
            : e.moved > .0001 && dt > 0
            ? (e.moved /
                      dt /
                      ((e.bossMove == BossMove.charging || e.runningApproach)
                          ? 2.381708109
                          : 1.007474632) /
                      (e.boss ? 1.2 : 1))
                  .clamp(.1, 3)
            : 1,
      );
      if (s.grapple?.enemyId == e.id) {
        if (posePreview) {
          for (final clip in actor.clips.entries) {
            clip.value.weight = clip.key == 'Hold' ? 1 : 0;
          }
        }
        actor.clips['Hold']!
          ..seek(s.grapple!.elapsed % 1)
          ..playbackTimeScale = 0;
      } else if (e.attackPending && e.grabPending) {
        actor.clips['Grab']!
          ..seek(.9 * (1 - e.windup).clamp(0.0, 1.0))
          ..playbackTimeScale = 0;
      } else if (e.releaseTime > 0) {
        actor.clips['Release']!
          ..seek(.7 - e.releaseTime)
          ..playbackTimeScale = 0;
      }
      if (e.vault?.crossing ?? false) {
        if (posePreview) {
          for (final entry in actor.clips.entries) {
            entry.value.weight = entry.key == 'Vault' ? 1 : 0;
          }
        }
        actor.clips['Vault']!
          ..seek(e.vault!.progress * 1.6)
          ..playbackTimeScale = 0;
      }
      if (e.climb?.onRungs ?? false) {
        actor.clips['Climb']!
          ..seek(e.climb!.clipTime)
          ..playbackTimeScale = 0;
      } else if (director == null && !e.boss && e.meleeClipTime != null) {
        actor.clips['MugAttack']!
          ..seek(e.meleeClipTime!)
          ..playbackTimeScale = 0;
      } else if (director == null && bossMelee) {
        final attackSeconds = e.bossAttack == BossMove.slamWindup ? 1.25 : .85;
        final time = e.bossMove == BossMove.recovery
            ? .77 + (e.bossRecoveryDuration - e.bossTimer) * .8
            : .77 * (1 - e.bossTimer / attackSeconds);
        actor.clips['MugAttack']!
          ..seek(time.clamp(0.0, 1.4))
          ..playbackTimeScale = 0;
      } else if (director == null && e.bossMove == BossMove.chargeWindup) {
        // A forward-weighted stance distinguishes the rush from a raised mug.
        actor.setMotion('Run');
        actor.clips['Run']!
          ..seek(.12)
          ..playbackTimeScale = 0;
      }
    }
    for (final h in s.map['houses']) {
      final inside =
          (s.x - h['x']).abs() < h['w'] / 2 &&
          (s.z - h['z']).abs() < h['d'] / 2;
      village.getChildByName('Roof_${h['id']}')!.visible = !inside;
    }
    village.getChildByName('FarmGate')!.visible = !s.gateOpen;
    for (final p in s.images) {
      village.getChildByName(p['node'])!.visible = !s.collected.contains(
        p['id'],
      );
    }
    for (final target in s.targets) {
      village.getChildByName(target['node'])!.visible = !s.medallions.contains(
        target['id'],
      );
    }
    for (final c in s.crates) {
      crateNodes[c.id]!.visible = !c.broken;
    }
    const models = {
      'shotgun': 'Shotgun',
      'ammo': 'AmmoBox',
      'shells': 'ShellBox',
      'green': 'GreenHerb',
      'red': 'RedHerb',
      'yellow': 'YellowHerb',
      'key': 'Key',
    };
    for (final p in s.pickups) {
      final n = pickupNodes.putIfAbsent(p.id, () {
        final node = p.kind == 'beer'
            ? beerTemplate.clone()
            : _prop(models[p.kind]!);
        if (p.kind == 'beer') {
          node.addComponent(
            BeerMugComponent(isPaused: () => !s.running)..detail = false,
          );
        }
        scene.add(node);
        return node;
      });
      n.visible = !p.taken;
      n.position = vm.Vector3(
        p.x,
        p.y + math.sin(s.time * 2 + p.x) * .035,
        p.z,
      );
      n.rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), s.time * .5);
    }
    if (director != null) {
      final d = director!, shot = d.shot;
      if (d.id == 'ending') {
        player.node.position = vm.Vector3(14, 0, 16);
        npcs['takosan']!.node
          ..visible = true
          ..position = vm.Vector3(17.7, 0, 17.5);
      }
      final speaker = shot.actor == 'fukuchan' ? player : npcs[shot.actor];
      if (speaker != null) {
        final eye = shot.camera(d.progress), p = speaker.node.position;
        speaker.node.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.atan2(eye.x - p.x, eye.z - p.z) + math.pi,
        );
      }
      if (shot.actor == 'sobaya') {
        final i = s.enemies.indexWhere((e) => e.boss);
        if (i >= 0) {
          final actor = enemies[i], eye = shot.camera(d.progress);
          actor.node.rotation = vm.Quaternion.axisAngle(
            vm.Vector3(0, 1, 0),
            math.atan2(
                  eye.x - actor.node.position.x,
                  eye.z - actor.node.position.z,
                ) +
                math.pi,
          );
        }
      }
    }
    // Authored GunSocket is baked with the two-handed aiming pose.
    final socket = player.node.getChildByName('GunSocket');
    if (socket != null) {
      pistol.localTransform = vm.Matrix4.copy(socket.globalTransform);
      shotgun.localTransform = vm.Matrix4.copy(socket.globalTransform);
    } else {
      final forward = vm.Vector3(math.sin(s.heading), 0, math.cos(s.heading));
      final right = vm.Vector3(math.cos(s.heading), 0, -math.sin(s.heading));
      final position =
          vm.Vector3(s.x, s.y + 1.22, s.z) + forward * .28 + right * .18;
      pistol.position = position;
      shotgun.position = position;
      pistol.rotation = player.node.rotation;
      shotgun.rotation = player.node.rotation;
    }
    pistol.visible = (s.aiming || s.reloading > 0) && s.weapon == 'handgun';
    shotgun.visible = (s.aiming || s.reloading > 0) && s.weapon == 'shotgun';
    muzzle.visible =
        s.fireCooldown > (s.weapon == 'handgun' ? .25 : .83) && s.aiming;
    if (muzzle.visible) {
      muzzle.position = (s.weapon == 'handgun' ? pistol : shotgun)
          .globalTransform
          .transformed3(
            vm.Vector3(0, .095, s.weapon == 'handgun' ? -.215 : -.765),
          );
    }
    impact.visible = s.hitFlash > 0 && s.shotEnd != null;
    if (impact.visible) impact.position = s.shotEnd!;
    _stepDistance += moved;
    if (_stepDistance > .9) {
      _stepDistance = 0;
      s.lastSound ??= 'step';
    }
    contactShadows?.update([
      (actor: player.node, width: .46, depth: .32),
      for (final actor in enemies) (actor: actor.node, width: .58, depth: .39),
      for (final entry in npcs.entries)
        (
          actor: entry.value.node,
          width: entry.key == 'takosan' ? .47 : .32,
          depth: entry.key == 'takosan' ? .37 : .24,
        ),
    ]);
    _sound();
    if (s.collectionDirty) {
      s.collectionDirty = false;
      unawaited(
        preferences!
            .setStringList('hazard.collection.v1', s.collected.toList())
            .then((ok) {
              if (!ok) s.say('記録の保存に失敗しました。');
            }),
      );
    }
    if (s.checkpointRequested) {
      s.checkpointRequested = false;
      unawaited(saveCheckpoint());
    }
    _notifyTime += dt;
    if (_notifyTime > .07) {
      _notifyTime = 0;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disposed = true;
    for (final a in fxPools.values) {
      unawaited(a.dispose());
    }
    unawaited(voice.dispose());
    unawaited(soundscape.dispose());
    for (final name in [
      'village',
      'items',
      'beer_mug',
      'sobaya',
      'fukuchan',
      'yametaro',
      'takosan',
      'farm',
      'mountain',
    ]) {
      unawaited(releaseScene('assets/models/$name.glb'));
    }
    super.dispose();
  }
}
