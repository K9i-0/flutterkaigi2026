import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../game/island_game_controller.dart';
import '../world/chunk_mesh_builder.dart';
import '../world/island_world.dart';

class MadogiwaIslandScene extends ChangeNotifier {
  MadogiwaIslandScene({required this.controller});

  final IslandGameController controller;
  final Scene scene = Scene();
  final Node _stage = Node(name: 'MadogiwaIsland256');
  final Node _terrainRoot = Node(name: 'TerrainChunks');
  final Node _resourceRoot = Node(name: 'VisibleResources');
  final Node _structureRoot = Node(name: 'PlayerStructures');
  final Node _partyRoot = Node(name: 'MadogiwaCrew');
  final Map<ChunkCoordinate, Node> _chunkNodes = {};
  final Map<ChunkCoordinate, int> _chunkQuadCounts = {};
  final Map<GridCell, Node> _resourceNodes = {};
  final List<Node> _resourceAnimatedParts = [];
  final List<_Worker> _workers = [];
  final PhysicallyBasedMaterial _terrainMaterial = PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(1, 1, 1, 1)
    ..vertexColorWeight = 1
    ..roughnessFactor = 0.9
    ..metallicFactor = 0.02;

  late final Node _selection;
  late PerspectiveCamera _activeCamera;
  Node? _playerRoot;
  bool _loaded = false;
  bool _chunkRefreshRunning = false;
  bool _chunkRefreshPending = false;
  double _elapsed = 0;
  double _yaw = -0.72;
  double _pitch = 0.6;
  double _distance = 14.2;
  double _moveRight = 0;
  double _moveForward = 0;
  double _hudAccumulator = 0;
  vm.Vector3 _playerPosition = vm.Vector3(0, IslandWorld.surfaceY(0, 3), 3);
  ChunkCoordinate _playerChunk = const ChunkCoordinate(0, 0);

  int characterMeshCount = 0;
  List<String> characterNames = const [];
  Duration loadDuration = Duration.zero;

  bool get isLoaded => _loaded;
  int get activeChunkCount => _chunkNodes.length;
  int get terrainQuadCount =>
      _chunkQuadCounts.values.fold(0, (sum, count) => sum + count);
  int get playerX => _playerPosition.x.round();
  int get playerZ => _playerPosition.z.round();
  int get playerChunkX => _playerChunk.x;
  int get playerChunkZ => _playerChunk.z;
  double get cameraDistance => _distance;

  Future<void> load() async {
    final stopwatch = Stopwatch()..start();
    await Scene.initializeStaticResources();
    _configureRenderer();
    _buildWorldFrame();
    await _refreshVisibleChunks(force: true);
    await _loadParty();
    stopwatch.stop();
    loadDuration = stopwatch.elapsed;
    _loaded = true;
  }

  void _configureRenderer() {
    scene.environmentSettings = EnvironmentSettings(
      toneMapping: ToneMappingMode.aces,
      exposure: 1.04,
      bloomEnabled: true,
      bloomThreshold: 0.9,
      bloomIntensity: 0.2,
      bloomScatter: 0.68,
      ambientOcclusionEnabled: true,
      ambientOcclusionMethod: AmbientOcclusionMethod.groundTruth,
      ambientOcclusionIntensity: 0.92,
      vignetteEnabled: true,
      vignetteIntensity: 0.16,
      colorGradingEnabled: true,
      saturation: 1.1,
      contrast: 1.05,
      fogEnabled: true,
      fogDensity: 0.025,
      fogColor: vm.Vector3(0.2, 0.5, 0.64),
    );
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-0.55, -1, -0.35),
      color: vm.Vector3(1, 0.91, 0.72),
      intensity: 3.6,
      castsShadow: true,
      shadowSoftness: 0.11,
      shadowMapResolution: 1024,
    );
    scene.add(_stage);
    _stage.addAll([_terrainRoot, _resourceRoot, _structureRoot, _partyRoot]);
  }

  void _buildWorldFrame() {
    final water = _pbr(0.025, 0.34, 0.58, roughness: 0.12, metallic: 0.28);
    _stage.add(
      Node(
          name: 'Ocean256',
          mesh: Mesh(
            CuboidGeometry(
              vm.Vector3(
                IslandWorld.worldSize + 18,
                0.5,
                IslandWorld.worldSize + 18,
              ),
            ),
            water,
          ),
        )
        ..position = vm.Vector3(0, 0.28, 0)
        ..raycastable = false,
    );

    final zoneMaterial = _unlit(0.18, 1.5, 1.1);
    for (final cell in IslandGameController.buildZone) {
      _stage.add(
        Node(
            name: 'StarterZone_${cell.x}_${cell.z}',
            mesh: Mesh(
              CuboidGeometry(vm.Vector3(0.78, 0.025, 0.78)),
              zoneMaterial,
            ),
          )
          ..position = vm.Vector3(
            cell.x.toDouble(),
            IslandWorld.surfaceY(cell.x, cell.z) + 0.02,
            cell.z.toDouble(),
          )
          ..raycastable = false,
      );
    }
    _selection =
        Node(
            name: 'Selection',
            mesh: Mesh(
              CuboidGeometry(vm.Vector3(0.94, 0.04, 0.94)),
              _unlit(2.4, 1.25, 0.18),
            ),
          )
          ..visible = false
          ..raycastable = false;
    _stage.add(_selection);
  }

  Set<ChunkCoordinate> _desiredChunks() {
    final desired = <ChunkCoordinate>{};
    for (
      var dx = -IslandWorld.renderRadiusChunks;
      dx <= IslandWorld.renderRadiusChunks;
      dx++
    ) {
      for (
        var dz = -IslandWorld.renderRadiusChunks;
        dz <= IslandWorld.renderRadiusChunks;
        dz++
      ) {
        final coordinate = ChunkCoordinate(
          _playerChunk.x + dx,
          _playerChunk.z + dz,
        );
        if (coordinate.isInsideWorld) desired.add(coordinate);
      }
    }
    return desired;
  }

  Future<void> _refreshVisibleChunks({bool force = false}) async {
    if (_chunkRefreshRunning) {
      _chunkRefreshPending = true;
      return;
    }
    final desired = _desiredChunks();
    final missing = desired
        .where((coordinate) => !_chunkNodes.containsKey(coordinate))
        .toList(growable: false);
    if (!force && missing.isEmpty && _chunkNodes.keys.every(desired.contains)) {
      return;
    }

    _chunkRefreshRunning = true;
    try {
      final request = missing.map((chunk) => (chunk.x, chunk.z)).toList();
      final payloads = request.isEmpty
          ? const <ChunkMeshPayload>[]
          : await compute(buildChunkMeshBatch, request);

      for (final coordinate in _chunkNodes.keys.toList()) {
        if (desired.contains(coordinate)) continue;
        final node = _chunkNodes.remove(coordinate);
        if (node != null) _terrainRoot.remove(node);
        _chunkQuadCounts.remove(coordinate);
      }
      for (final payload in payloads) {
        if (payload.positions.isEmpty ||
            !desired.contains(payload.coordinate)) {
          continue;
        }
        final geometry = MeshGeometry.fromArrays(
          positions: payload.positions,
          normals: payload.normals,
          colors: payload.colors,
          indices: payload.indices,
          retainCpuData: false,
        );
        final node =
            Node(
                name: 'Chunk_${payload.coordinate.x}_${payload.coordinate.z}',
                mesh: Mesh(geometry, _terrainMaterial),
              )
              ..position = vm.Vector3(
                payload.coordinate.x * IslandWorld.chunkSize.toDouble(),
                0,
                payload.coordinate.z * IslandWorld.chunkSize.toDouble(),
              )
              ..shadowStatic = true
              ..raycastable = false;
        _terrainRoot.add(node);
        _chunkNodes[payload.coordinate] = node;
        _chunkQuadCounts[payload.coordinate] = payload.quadCount;
      }
      _rebuildVisibleResources(desired);
      notifyListeners();
    } finally {
      _chunkRefreshRunning = false;
      if (_chunkRefreshPending) {
        _chunkRefreshPending = false;
        unawaited(_refreshVisibleChunks());
      }
    }
  }

  void _rebuildVisibleResources(Set<ChunkCoordinate> visibleChunks) {
    _resourceRoot.removeAll();
    _resourceNodes.clear();
    _resourceAnimatedParts.clear();
    for (final entry in controller.resources.entries) {
      final chunk = ChunkCoordinate(
        IslandWorld.chunkForCoordinate(entry.key.x.toDouble()),
        IslandWorld.chunkForCoordinate(entry.key.z.toDouble()),
      );
      if (!visibleChunks.contains(chunk)) continue;
      final node = switch (entry.value) {
        IslandResource.tree => _buildTree(entry.key),
        IslandResource.rock => _buildRock(entry.key),
      };
      node.position = vm.Vector3(
        entry.key.x.toDouble(),
        IslandWorld.surfaceY(entry.key.x, entry.key.z),
        entry.key.z.toDouble(),
      );
      _resourceRoot.add(node);
      _resourceNodes[entry.key] = node;
    }
  }

  Node _buildTree(GridCell cell) {
    final trunk = _pbr(0.38, 0.18, 0.06, roughness: 0.95);
    final leafA = _pbr(0.08, 0.5, 0.2, roughness: 0.9);
    final leafB = _pbr(0.16, 0.68, 0.27, roughness: 0.88);
    final root = Node(name: 'Tree_${cell.x}_${cell.z}');
    final crown = Node(name: 'TreeCrown');
    root.add(
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.34, 1.25, 0.34)), trunk))
        ..position = vm.Vector3(0, 0.62, 0),
    );
    for (final spec in const [
      (-0.28, 1.35, 0.0),
      (0.28, 1.38, 0.0),
      (0.0, 1.65, 0.0),
      (0.0, 1.38, -0.28),
      (0.0, 1.38, 0.28),
    ]) {
      crown.add(
        Node(
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(0.72, 0.72, 0.72)),
            spec.$2 > 1.5 ? leafB : leafA,
          ),
        )..position = vm.Vector3(spec.$1, spec.$2, spec.$3),
      );
    }
    root.add(crown);
    _resourceAnimatedParts.add(crown);
    return root;
  }

  Node _buildRock(GridCell cell) {
    final stone = _pbr(0.34, 0.39, 0.42, roughness: 0.82, metallic: 0.12);
    final root = Node(name: 'Rock_${cell.x}_${cell.z}');
    root.addAll([
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.75, 0.62, 0.72)), stone))
        ..position = vm.Vector3(-0.08, 0.31, 0),
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.42, 0.4, 0.48)), stone))
        ..position = vm.Vector3(0.32, 0.2, 0.18)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), 0.35),
    ]);
    return root;
  }

  Future<void> _loadParty() async {
    const specs = [
      ('sobaya', 'そば屋', 0.0, 3.0),
      ('yametaro', 'やめ太郎', 2.2, 2.5),
      ('yumemin', 'ゆめみん', -2.2, 0.8),
      ('takosan', 'タコさん', 2.25, 0.7),
    ];
    final loaded = await Future.wait(
      specs.map((spec) => Node.fromGlbAsset('assets/models/${spec.$1}.glb')),
    );
    var totalMeshes = 0;
    for (var index = 0; index < loaded.length; index++) {
      final model = loaded[index];
      final spec = specs[index];
      final bounds = model.combinedLocalBounds;
      final extent = bounds == null
          ? vm.Vector3(1, 2, 1)
          : bounds.max - bounds.min;
      final scale = 1.45 / math.max(extent.y, 0.1);
      final floorY = bounds?.min.y ?? 0;
      model
        ..scale = vm.Vector3.all(scale)
        ..position = vm.Vector3(0, -floorY * scale, 0)
        ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), math.pi);
      final home = vm.Vector3(
        spec.$3,
        IslandWorld.surfaceY(spec.$3.round(), spec.$4.round()),
        spec.$4,
      );
      final root = Node(name: spec.$2)
        ..position = vm.Vector3.copy(home)
        ..add(model);
      final idle = model.findAnimationByName('Idle');
      if (idle != null) {
        model.createAnimationClip(idle)
          ..loop = true
          ..play();
      }
      totalMeshes += model.meshNodes.length;
      _partyRoot.add(root);
      _workers.add(_Worker(root: root, home: home, isPlayer: index == 0));
      if (index == 0) {
        _playerRoot = root;
        _playerPosition = vm.Vector3.copy(home);
      }
    }
    characterMeshCount = totalMeshes;
    characterNames = specs.map((spec) => spec.$2).toList(growable: false);
  }

  void reset() {
    controller.reset();
    _structureRoot.removeAll();
    _selection.visible = false;
    _rebuildVisibleResources(_desiredChunks());
    _playerPosition = vm.Vector3(0, IslandWorld.surfaceY(0, 3), 3);
    _playerChunk = const ChunkCoordinate(0, 0);
    for (final worker in _workers) {
      if (worker.isPlayer) {
        worker.root.position = vm.Vector3.copy(_playerPosition);
        continue;
      }
      worker
        ..goal = vm.Vector3.copy(worker.home)
        ..actionTime = 0;
      worker.root.position = vm.Vector3.copy(worker.home);
    }
    unawaited(_refreshVisibleChunks(force: true));
    notifyListeners();
  }

  void selectTool(IslandTool tool) => controller.selectTool(tool);

  void setMoveInput({required double right, required double forward}) {
    _moveRight = right.clamp(-1.0, 1.0);
    _moveForward = forward.clamp(-1.0, 1.0);
  }

  void stopMoving() {
    _moveRight = 0;
    _moveForward = 0;
  }

  void orbitCamera({required double deltaYaw, required double deltaPitch}) {
    _yaw += deltaYaw;
    _pitch = (_pitch + deltaPitch).clamp(0.32, 0.92);
  }

  void setCameraDistance(double distance) {
    _distance = distance.clamp(8.5, 22.0);
  }

  void handleTap(Offset position, Size viewSize) {
    if (!_loaded || viewSize.isEmpty) return;
    final ray = _activeCamera.screenPointToRay(position, viewSize);
    GridCell? cell;
    for (var distance = 0.2; distance <= 70; distance += 0.16) {
      final x = ray.origin.x + ray.direction.x * distance;
      final y = ray.origin.y + ray.direction.y * distance;
      final z = ray.origin.z + ray.direction.z * distance;
      final candidate = GridCell(x.round(), z.round());
      if (!IslandWorld.containsCell(candidate.x, candidate.z) ||
          !IslandWorld.isLand(candidate.x, candidate.z)) {
        continue;
      }
      if (y <= IslandWorld.surfaceY(candidate.x, candidate.z) + 0.12) {
        cell = candidate;
        break;
      }
    }
    if (cell == null) return;

    _selection
      ..visible = true
      ..position = vm.Vector3(
        cell.x.toDouble(),
        IslandWorld.surfaceY(cell.x, cell.z) + 0.04,
        cell.z.toDouble(),
      );
    final result = controller.actOn(cell);
    if (result.changed) _apply(result);
  }

  void _apply(IslandActionResult result) {
    switch (result.kind) {
      case IslandActionKind.treeHarvested:
      case IslandActionKind.rockHarvested:
        final node = _resourceNodes.remove(result.cell);
        if (node != null) _resourceRoot.remove(node);
        break;
      case IslandActionKind.floorPlaced:
        _addFloor(result.cell);
        break;
      case IslandActionKind.wallPlaced:
        _addWall(result.cell);
        break;
      case IslandActionKind.roofPlaced:
        _addRoof();
        break;
      case IslandActionKind.none:
        return;
    }
    _sendWorker(result);
  }

  void _addFloor(GridCell cell) {
    final surface = IslandWorld.surfaceY(cell.x, cell.z);
    _structureRoot.add(
      Node(
          name: 'Floor_${cell.x}_${cell.z}',
          mesh: Mesh(
            CuboidGeometry(vm.Vector3(0.92, 0.28, 0.92)),
            _pbr(0.58, 0.31, 0.1, roughness: 0.78),
          ),
        )
        ..position = vm.Vector3(
          cell.x.toDouble(),
          surface + 0.14,
          cell.z.toDouble(),
        ),
    );
  }

  void _addWall(GridCell cell) {
    final surface = IslandWorld.surfaceY(cell.x, cell.z);
    final timber = _pbr(0.67, 0.39, 0.14, roughness: 0.73);
    final plaster = _pbr(0.78, 0.72, 0.52, roughness: 0.9);
    final root = Node(name: 'Wall_${cell.x}_${cell.z}')
      ..position = vm.Vector3(
        cell.x.toDouble(),
        surface + 0.82,
        cell.z.toDouble(),
      );
    root.addAll([
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.9, 1.08, 0.18)), plaster)),
      for (final x in [-0.37, 0.37])
        Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.12, 1.18, 0.23)), timber))
          ..position = vm.Vector3(x, 0, 0),
    ]);
    _structureRoot.add(root);
  }

  void _addRoof() {
    final roof = _pbr(0.16, 0.35, 0.17, roughness: 0.86);
    final roofCells = controller.wallCells.take(4).toList(growable: false);
    for (final cell in roofCells) {
      final surface = IslandWorld.surfaceY(cell.x, cell.z);
      _structureRoot.add(
        Node(
            name: 'Roof_${cell.x}_${cell.z}',
            mesh: Mesh(CuboidGeometry(vm.Vector3(1.04, 0.3, 1.04)), roof),
          )
          ..position = vm.Vector3(
            cell.x.toDouble(),
            surface + 1.51,
            cell.z.toDouble(),
          ),
      );
    }
    if (roofCells.isNotEmpty) {
      final beacon = roofCells.first;
      _structureRoot.add(
        Node(
            name: 'HomeBeacon',
            mesh: Mesh(
              CuboidGeometry(vm.Vector3(0.14, 1.15, 0.14)),
              _unlit(2.4, 1.15, 0.18),
            ),
          )
          ..position = vm.Vector3(
            beacon.x.toDouble(),
            IslandWorld.surfaceY(beacon.x, beacon.z) + 2.25,
            beacon.z.toDouble(),
          ),
      );
    }
  }

  void _sendWorker(IslandActionResult result) {
    if (_workers.length < 4) return;
    final index = switch (result.kind) {
      IslandActionKind.treeHarvested => 1,
      IslandActionKind.rockHarvested => 3,
      IslandActionKind.floorPlaced => 2,
      IslandActionKind.wallPlaced => 1,
      IslandActionKind.roofPlaced => 2,
      IslandActionKind.none => 1,
    };
    final worker = _workers[index];
    worker
      ..goal = vm.Vector3(
        result.cell.x + 0.62,
        IslandWorld.surfaceY(result.cell.x, result.cell.z),
        result.cell.z + 0.62,
      )
      ..actionTime = 2;
  }

  void tick(double deltaSeconds) {
    if (!_loaded) return;
    final dt = deltaSeconds.clamp(0.0, 0.05);
    _elapsed += dt;
    _hudAccumulator += dt;
    _updatePlayer(dt);
    _selection.scale = vm.Vector3.all(1 + math.sin(_elapsed * 4) * 0.05);
    for (var index = 0; index < _resourceAnimatedParts.length; index++) {
      _resourceAnimatedParts[index].rotation = vm.Quaternion.axisAngle(
        vm.Vector3(0, 0, 1),
        math.sin(_elapsed * 1.4 + index) * 0.025,
      );
    }
    for (var index = 0; index < _workers.length; index++) {
      final worker = _workers[index];
      if (worker.isPlayer) continue;
      var destination = worker.home;
      if (worker.actionTime > 0) {
        worker.actionTime = math.max(0, worker.actionTime - dt);
        destination = worker.actionTime > 0.75 ? worker.goal : worker.home;
      }
      final position = worker.root.position;
      position.x += (destination.x - position.x) * math.min(1, dt * 4.5);
      position.z += (destination.z - position.z) * math.min(1, dt * 4.5);
      position.y =
          IslandWorld.surfaceY(position.x.round(), position.z.round()) +
          math.sin(_elapsed * 2.2 + index) * 0.018;
      worker.root.position = position;
    }
    if (_hudAccumulator >= 0.15) {
      _hudAccumulator = 0;
      notifyListeners();
    }
  }

  void _updatePlayer(double dt) {
    final player = _playerRoot;
    if (player == null) return;
    final inputLength = math.sqrt(
      _moveRight * _moveRight + _moveForward * _moveForward,
    );
    if (inputLength > 0.01) {
      final rightInput = _moveRight / math.max(1, inputLength);
      final forwardInput = _moveForward / math.max(1, inputLength);
      final rightX = math.cos(_yaw);
      final rightZ = -math.sin(_yaw);
      final forwardX = -math.sin(_yaw);
      final forwardZ = -math.cos(_yaw);
      final dx = (rightX * rightInput + forwardX * forwardInput) * dt * 4.4;
      final dz = (rightZ * rightInput + forwardZ * forwardInput) * dt * 4.4;
      final nextX = (_playerPosition.x + dx).clamp(
        -IslandWorld.worldHalfSize + 1.0,
        IslandWorld.worldHalfSize - 2.0,
      );
      final nextZ = (_playerPosition.z + dz).clamp(
        -IslandWorld.worldHalfSize + 1.0,
        IslandWorld.worldHalfSize - 2.0,
      );
      final currentHeight = IslandWorld.surfaceHeight(
        _playerPosition.x.round(),
        _playerPosition.z.round(),
      );
      final xHeight = IslandWorld.surfaceHeight(
        nextX.round(),
        _playerPosition.z.round(),
      );
      if (xHeight >= 0 && (xHeight - currentHeight).abs() <= 1) {
        _playerPosition.x = nextX;
      }
      final zHeight = IslandWorld.surfaceHeight(
        _playerPosition.x.round(),
        nextZ.round(),
      );
      if (zHeight >= 0 && (zHeight - currentHeight).abs() <= 1) {
        _playerPosition.z = nextZ;
      }
      _playerPosition.y = IslandWorld.surfaceY(
        _playerPosition.x.round(),
        _playerPosition.z.round(),
      );
      player
        ..position = vm.Vector3.copy(_playerPosition)
        ..rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          math.atan2(dx, dz),
        );

      final nextChunk = ChunkCoordinate(
        IslandWorld.chunkForCoordinate(_playerPosition.x),
        IslandWorld.chunkForCoordinate(_playerPosition.z),
      );
      if (nextChunk != _playerChunk) {
        _playerChunk = nextChunk;
        unawaited(_refreshVisibleChunks());
      }
    } else {
      final position = player.position;
      position.y = _playerPosition.y + math.sin(_elapsed * 2.2) * 0.018;
      player.position = position;
    }
  }

  PerspectiveCamera camera(Duration elapsed) {
    final horizontal = math.cos(_pitch) * _distance;
    final target = vm.Vector3(
      _playerPosition.x,
      _playerPosition.y + 0.65,
      _playerPosition.z,
    );
    _activeCamera = PerspectiveCamera(
      fovRadiansY: 48 * math.pi / 180,
      position:
          target +
          vm.Vector3(
            math.sin(_yaw) * horizontal,
            math.sin(_pitch) * _distance,
            math.cos(_yaw) * horizontal,
          ),
      target: target,
      fovNear: 0.1,
      fovFar: 90,
    );
    return _activeCamera;
  }

  PhysicallyBasedMaterial _pbr(
    double r,
    double g,
    double b, {
    required double roughness,
    double metallic = 0,
  }) => PhysicallyBasedMaterial()
    ..baseColorFactor = vm.Vector4(r, g, b, 1)
    ..roughnessFactor = roughness
    ..metallicFactor = metallic;

  UnlitMaterial _unlit(double r, double g, double b) =>
      UnlitMaterial()..baseColorFactor = vm.Vector4(r, g, b, 1);

  @override
  void dispose() {
    scene.removeAll();
    super.dispose();
  }
}

class _Worker {
  _Worker({required this.root, required this.home, required this.isPlayer})
    : goal = vm.Vector3.copy(home);

  final Node root;
  final vm.Vector3 home;
  final bool isPlayer;
  vm.Vector3 goal;
  double actionTime = 0;
}
