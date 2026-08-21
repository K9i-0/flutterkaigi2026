import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

import 'package:flutter/foundation.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import '../game/island_game_controller.dart';
import '../game/movement_math.dart';
import '../world/chunk_mesh_builder.dart';
import '../world/island_world.dart';

@immutable
class IslandLandmark {
  const IslandLandmark({
    required this.id,
    required this.label,
    required this.cell,
    required this.memberId,
  });

  final String id;
  final String label;
  final GridCell cell;
  final String memberId;
}

class MadogiwaIslandScene extends ChangeNotifier {
  MadogiwaIslandScene({required this.controller});

  static const _interactionReach = 7.25;
  static const _jumpDuration = 0.52;
  static const explorationRadius = 10;
  static const landmarks = <IslandLandmark>[
    IslandLandmark(
      id: 'radio_tower',
      label: '壊れた無線塔',
      cell: GridCell(-38, -30),
      memberId: 'yametaro',
    ),
    IslandLandmark(
      id: 'office_wreck',
      label: '漂着した会議室',
      cell: GridCell(42, -38),
      memberId: 'yumemin',
    ),
    IslandLandmark(
      id: 'octopus_shrine',
      label: 'タコ石の門',
      cell: GridCell(30, 53),
      memberId: 'takosan',
    ),
  ];

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
  final Map<String, Node> _landmarkNodes = {};
  final List<Node> _resourceAnimatedParts = [];
  final List<_Worker> _workers = [];
  final Uint8List _explored = Uint8List(
    IslandWorld.worldSize * IslandWorld.worldSize,
  );
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
  int _lastExploredX = 1 << 30;
  int _lastExploredZ = 1 << 30;
  int _exploredCellCount = 0;
  bool _isJumping = false;
  double _jumpElapsed = 0;
  double _jumpStartSurfaceY = 0;
  double _jumpLandingSurfaceY = 0;

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
  int get reunitedCount =>
      _workers.where((worker) => !worker.isPlayer && worker.reunited).length;
  int get exploredCellCount => _exploredCellCount;
  bool get isJumping => _isJumping;
  double get jumpOffset =>
      _isJumping ? jumpArcOffset(_jumpElapsed / _jumpDuration) : 0;
  List<String> get reunitedMemberNames => _workers
      .where((worker) => !worker.isPlayer && worker.reunited)
      .map((worker) => worker.displayName)
      .toList(growable: false);

  bool isExplored(int x, int z) {
    if (!IslandWorld.containsCell(x, z)) return false;
    return _explored[_explorationIndex(x, z)] != 0;
  }

  bool isMemberReunited(String memberId) =>
      _workers.any((worker) => worker.id == memberId && worker.reunited);

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
    _buildLandmarks();
    _revealAroundPlayer(force: true);
  }

  void _buildLandmarks() {
    for (final landmark in landmarks) {
      controller.resources.removeWhere((cell, _) {
        final dx = cell.x - landmark.cell.x;
        final dz = cell.z - landmark.cell.z;
        return dx * dx + dz * dz <= 9;
      });
      final root = switch (landmark.id) {
        'radio_tower' => _buildRadioTower(),
        'office_wreck' => _buildOfficeWreck(),
        'octopus_shrine' => _buildOctopusShrine(),
        _ => Node(name: landmark.label),
      };
      root
        ..name = landmark.label
        ..position = vm.Vector3(
          landmark.cell.x.toDouble(),
          IslandWorld.surfaceY(landmark.cell.x, landmark.cell.z),
          landmark.cell.z.toDouble(),
        )
        ..visible = false
        ..raycastable = false;
      _stage.add(root);
      _landmarkNodes[landmark.id] = root;
    }
  }

  Node _buildRadioTower() {
    final rust = _pbr(0.46, 0.16, 0.07, roughness: 0.72, metallic: 0.55);
    final signal = _unlit(2.8, 0.35, 0.08);
    final root = Node();
    for (final x in [-0.72, 0.72]) {
      root.add(
        Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.18, 5.8, 0.18)), rust))
          ..position = vm.Vector3(x, 2.9, 0),
      );
    }
    for (var level = 0; level < 5; level++) {
      root.add(
        Node(mesh: Mesh(CuboidGeometry(vm.Vector3(1.7, 0.13, 0.16)), rust))
          ..position = vm.Vector3(0, 0.7 + level * 1.1, 0)
          ..rotation = vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            level.isEven ? 0.45 : -0.45,
          ),
      );
    }
    root.addAll([
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(2.3, 0.13, 0.13)), rust))
        ..position = vm.Vector3(0, 5.5, 0),
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.32, 0.32, 0.32)), signal))
        ..position = vm.Vector3(0, 6.05, 0),
    ]);
    return root;
  }

  Node _buildOfficeWreck() {
    final wall = _pbr(0.18, 0.46, 0.55, roughness: 0.8, metallic: 0.18);
    final frame = _pbr(0.09, 0.12, 0.14, roughness: 0.55, metallic: 0.72);
    final paper = _unlit(1.3, 1.2, 0.82);
    final root = Node()
      ..rotation = vm.Quaternion.axisAngle(vm.Vector3(0, 1, 0), -0.28);
    root.addAll([
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(5.2, 0.28, 3.2)), wall))
        ..position = vm.Vector3(0, 0.14, 0),
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(5.2, 2.2, 0.2)), wall))
        ..position = vm.Vector3(0, 1.1, 1.5),
      for (final x in [-2.4, 2.4])
        Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.18, 2.6, 3.2)), frame))
          ..position = vm.Vector3(x, 1.3, 0),
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(1.9, 0.2, 0.9)), frame))
        ..position = vm.Vector3(0.3, 0.92, 0),
      for (final spec in const [(-0.4, 1.05, -0.1), (0.35, 1.06, 0.2)])
        Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.7, 0.04, 0.48)), paper))
          ..position = vm.Vector3(spec.$1, spec.$2, spec.$3),
    ]);
    return root;
  }

  Node _buildOctopusShrine() {
    final stone = _pbr(0.31, 0.24, 0.48, roughness: 0.86, metallic: 0.12);
    final glow = _unlit(1.8, 0.3, 2.4);
    final root = Node();
    root.addAll([
      for (final x in [-1.45, 1.45])
        Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.9, 4.2, 0.9)), stone))
          ..position = vm.Vector3(x, 2.1, 0),
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(3.8, 0.9, 0.9)), stone))
        ..position = vm.Vector3(0, 4.0, 0),
      Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.45, 0.45, 0.45)), glow))
        ..position = vm.Vector3(0, 4.05, -0.5),
      for (var index = 0; index < 4; index++)
        Node(mesh: Mesh(CuboidGeometry(vm.Vector3(0.35, 1.15, 0.35)), stone))
          ..position = vm.Vector3(-0.75 + index * 0.5, 0.58, -0.75)
          ..rotation = vm.Quaternion.axisAngle(
            vm.Vector3(0, 0, 1),
            (index - 1.5) * 0.18,
          ),
    ]);
    return root;
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
      _updateLandmarkVisibility();
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
      _PartySpec(
        id: 'sobaya',
        name: 'そば屋',
        cell: GridCell(0, 3),
        followOffset: (0.0, 0.0),
        isPlayer: true,
      ),
      _PartySpec(
        id: 'yametaro',
        name: 'やめ太郎',
        cell: GridCell(-38, -27),
        followOffset: (-1.35, 1.35),
      ),
      _PartySpec(
        id: 'yumemin',
        name: 'ゆめみん',
        cell: GridCell(42, -34),
        followOffset: (1.35, 1.35),
      ),
      _PartySpec(
        id: 'takosan',
        name: 'タコさん',
        cell: GridCell(30, 49),
        followOffset: (0.0, 2.35),
      ),
    ];
    final loaded = await Future.wait(
      specs.map((spec) => Node.fromGlbAsset('assets/models/${spec.id}.glb')),
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
        spec.cell.x.toDouble(),
        IslandWorld.surfaceY(spec.cell.x, spec.cell.z),
        spec.cell.z.toDouble(),
      );
      final root = Node(name: spec.name)
        ..position = vm.Vector3.copy(home)
        ..visible = spec.isPlayer
        ..add(model);
      final idle = model.findAnimationByName('Idle');
      if (idle != null) {
        model.createAnimationClip(idle)
          ..loop = true
          ..play();
      }
      totalMeshes += model.meshNodes.length;
      _partyRoot.add(root);
      _workers.add(
        _Worker(
          id: spec.id,
          displayName: spec.name,
          root: root,
          home: home,
          followOffset: spec.followOffset,
          isPlayer: spec.isPlayer,
          reunited: spec.isPlayer,
          walkRig: _VoxelWalkRig.fromModel(model),
        ),
      );
      if (spec.isPlayer) {
        _playerRoot = root;
        _playerPosition = vm.Vector3.copy(home);
      }
    }
    characterMeshCount = totalMeshes;
    characterNames = specs.map((spec) => spec.name).toList(growable: false);
  }

  void reset() {
    controller.reset();
    for (final landmark in landmarks) {
      controller.resources.removeWhere((cell, _) {
        final dx = cell.x - landmark.cell.x;
        final dz = cell.z - landmark.cell.z;
        return dx * dx + dz * dz <= 9;
      });
    }
    _structureRoot.removeAll();
    _selection.visible = false;
    _rebuildVisibleResources(_desiredChunks());
    _playerPosition = vm.Vector3(0, IslandWorld.surfaceY(0, 3), 3);
    _cancelJump();
    _playerChunk = const ChunkCoordinate(0, 0);
    _explored.fillRange(0, _explored.length, 0);
    _exploredCellCount = 0;
    _lastExploredX = 1 << 30;
    _lastExploredZ = 1 << 30;
    _revealAroundPlayer(force: true);
    for (final worker in _workers) {
      if (worker.isPlayer) {
        worker
          ..reunited = true
          ..root.visible = true;
        worker.root.position = vm.Vector3.copy(_playerPosition);
        continue;
      }
      worker.reunited = false;
      worker.root
        ..position = vm.Vector3.copy(worker.home)
        ..visible = false;
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

  /// Moves the player to a deterministic debug location for MCP scenarios.
  Future<GridCell?> automationTeleport(int requestedX, int requestedZ) async {
    if (!_loaded) return null;
    GridCell? destination;
    for (var radius = 0; radius <= 8 && destination == null; radius++) {
      for (var dz = -radius; dz <= radius && destination == null; dz++) {
        for (var dx = -radius; dx <= radius; dx++) {
          if (radius > 0 && dx.abs() != radius && dz.abs() != radius) continue;
          final x = requestedX + dx;
          final z = requestedZ + dz;
          if (IslandWorld.containsCell(x, z) && IslandWorld.isLand(x, z)) {
            destination = GridCell(x, z);
            break;
          }
        }
      }
    }
    if (destination == null) return null;

    stopMoving();
    _cancelJump();
    _playerPosition = vm.Vector3(
      destination.x.toDouble(),
      IslandWorld.surfaceY(destination.x, destination.z),
      destination.z.toDouble(),
    );
    _playerRoot?.position = vm.Vector3.copy(_playerPosition);
    _playerChunk = ChunkCoordinate(
      IslandWorld.chunkForCoordinate(_playerPosition.x),
      IslandWorld.chunkForCoordinate(_playerPosition.z),
    );
    _revealAroundPlayer(force: true);
    await _refreshVisibleChunks(force: true);
    notifyListeners();
    return destination;
  }

  void handleTap(Offset position, Size viewSize) {
    if (!_loaded || viewSize.isEmpty) return;
    final ray = _activeCamera.screenPointToRay(position, viewSize);
    GridCell? cell = controller.tool == IslandTool.gather
        ? _findResourceTarget(ray)
        : null;
    if (controller.tool == IslandTool.gather && cell == null) {
      controller.showMessage('近くの木か岩を直接タップしよう（届く範囲は7マス）');
      return;
    }
    for (var distance = 0.2; distance <= 70; distance += 0.16) {
      if (cell != null) break;
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
    if (_horizontalDistanceToPlayer(cell) > _interactionReach) {
      controller.showMessage('遠すぎて届かない。対象の近くまで移動しよう');
      return;
    }

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

  GridCell? _findResourceTarget(vm.Ray ray) {
    final direction = ray.direction.normalized();
    GridCell? target;
    var bestDistance = double.infinity;
    for (final entry in controller.resources.entries) {
      final cell = entry.key;
      if (!_resourceNodes.containsKey(cell) ||
          _horizontalDistanceToPlayer(cell) > _interactionReach) {
        continue;
      }
      final center = vm.Vector3(
        cell.x.toDouble(),
        IslandWorld.surfaceY(cell.x, cell.z) +
            (entry.value == IslandResource.tree ? 1.1 : 0.38),
        cell.z.toDouble(),
      );
      final fromOrigin = center - ray.origin;
      final depth = fromOrigin.dot(direction);
      if (depth <= 0) continue;
      final closestPoint = ray.origin + direction.scaled(depth);
      final distance = (center - closestPoint).length;
      final hitRadius = entry.value == IslandResource.tree ? 1.25 : 0.78;
      if (distance <= hitRadius && distance < bestDistance) {
        target = cell;
        bestDistance = distance;
      }
    }
    return target;
  }

  double _horizontalDistanceToPlayer(GridCell cell) {
    final dx = cell.x - _playerPosition.x;
    final dz = cell.z - _playerPosition.z;
    return math.sqrt(dx * dx + dz * dz);
  }

  int _explorationIndex(int x, int z) =>
      (z + IslandWorld.worldHalfSize) * IslandWorld.worldSize +
      x +
      IslandWorld.worldHalfSize;

  void _revealAroundPlayer({bool force = false}) {
    final centerX = _playerPosition.x.round();
    final centerZ = _playerPosition.z.round();
    if (!force && centerX == _lastExploredX && centerZ == _lastExploredZ) {
      return;
    }
    _lastExploredX = centerX;
    _lastExploredZ = centerZ;
    for (var dz = -explorationRadius; dz <= explorationRadius; dz++) {
      for (var dx = -explorationRadius; dx <= explorationRadius; dx++) {
        if (dx * dx + dz * dz > explorationRadius * explorationRadius) {
          continue;
        }
        final x = centerX + dx;
        final z = centerZ + dz;
        if (IslandWorld.containsCell(x, z)) {
          final index = _explorationIndex(x, z);
          if (_explored[index] == 0) {
            _explored[index] = 1;
            _exploredCellCount++;
          }
        }
      }
    }
  }

  void _updateLandmarkVisibility() {
    for (final landmark in landmarks) {
      final chunk = ChunkCoordinate(
        IslandWorld.chunkForCoordinate(landmark.cell.x.toDouble()),
        IslandWorld.chunkForCoordinate(landmark.cell.z.toDouble()),
      );
      _landmarkNodes[landmark.id]?.visible = _chunkNodes.containsKey(chunk);
    }
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

  void tick(double deltaSeconds) {
    if (!_loaded) return;
    final dt = deltaSeconds.clamp(0.0, 0.05);
    _elapsed += dt;
    _hudAccumulator += dt;
    _updatePlayer(dt);
    _revealAroundPlayer();
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
      final dxToPlayer = worker.root.position.x - _playerPosition.x;
      final dzToPlayer = worker.root.position.z - _playerPosition.z;
      final distanceToPlayer = math.sqrt(
        dxToPlayer * dxToPlayer + dzToPlayer * dzToPlayer,
      );
      if (!worker.reunited) {
        worker.root.visible = distanceToPlayer <= 9;
        if (distanceToPlayer <= 2.6) {
          worker
            ..reunited = true
            ..root.visible = true;
          controller.showMessage('${worker.displayName}と再会！ これから一緒に行動する');
        }
      }
      final destination = worker.reunited
          ? vm.Vector3(
              _playerPosition.x + worker.followOffset.$1,
              _playerPosition.y,
              _playerPosition.z + worker.followOffset.$2,
            )
          : worker.home;
      final position = worker.root.position;
      final previousX = position.x;
      final previousZ = position.z;
      position.x += (destination.x - position.x) * math.min(1, dt * 4.5);
      position.z += (destination.z - position.z) * math.min(1, dt * 4.5);
      final movedX = position.x - previousX;
      final movedZ = position.z - previousZ;
      final moving = movedX * movedX + movedZ * movedZ > 0.000001;
      position.y =
          IslandWorld.surfaceY(position.x.round(), position.z.round()) +
          (moving
              ? worker.walkRig.stepBob(_elapsed)
              : math.sin(_elapsed * 2.2 + index) * 0.018);
      worker.root
        ..position = position
        ..rotation = moving
            ? vm.Quaternion.axisAngle(
                vm.Vector3(0, 1, 0),
                characterFacingYaw(movedX, movedZ),
              )
            : worker.root.rotation;
      worker.walkRig.update(dt: dt, elapsed: _elapsed, moving: moving);
    }
    if (_hudAccumulator >= 0.15) {
      _hudAccumulator = 0;
      notifyListeners();
    }
  }

  void _updatePlayer(double dt) {
    final player = _playerRoot;
    if (player == null) return;
    final playerWorker = _workers.firstWhere((worker) => worker.isPlayer);
    _advanceJump(dt);
    final inputLength = math.sqrt(
      _moveRight * _moveRight + _moveForward * _moveForward,
    );
    var moving = false;
    if (inputLength > 0.01) {
      final previousX = _playerPosition.x;
      final previousZ = _playerPosition.z;
      final previousSurfaceY = _playerPosition.y;
      final rightInput = _moveRight / math.max(1, inputLength);
      final forwardInput = _moveForward / math.max(1, inputLength);
      final movement = cameraRelativeMovement(
        yaw: _yaw,
        right: rightInput,
        forward: forwardInput,
      );
      final dx = movement.$1 * dt * 4.4;
      final dz = movement.$2 * dt * 4.4;
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
      if (canTraverseHeight(
        currentHeight: currentHeight.toDouble(),
        targetHeight: xHeight.toDouble(),
      )) {
        _playerPosition.x = nextX;
      }
      final zHeight = IslandWorld.surfaceHeight(
        _playerPosition.x.round(),
        nextZ.round(),
      );
      if (canTraverseHeight(
        currentHeight: currentHeight.toDouble(),
        targetHeight: zHeight.toDouble(),
      )) {
        _playerPosition.z = nextZ;
      }
      _playerPosition.y = IslandWorld.surfaceY(
        _playerPosition.x.round(),
        _playerPosition.z.round(),
      );
      final movedX = _playerPosition.x - previousX;
      final movedZ = _playerPosition.z - previousZ;
      moving = movedX * movedX + movedZ * movedZ > 0.000001;
      if (_playerPosition.y > previousSurfaceY && !_isJumping) {
        _startJump(
          fromSurfaceY: previousSurfaceY,
          toSurfaceY: _playerPosition.y,
        );
      } else if (_isJumping) {
        _jumpLandingSurfaceY = _playerPosition.y;
      }
      if (moving) {
        player.rotation = vm.Quaternion.axisAngle(
          vm.Vector3(0, 1, 0),
          characterFacingYaw(movedX, movedZ),
        );
      }
      final nextChunk = ChunkCoordinate(
        IslandWorld.chunkForCoordinate(_playerPosition.x),
        IslandWorld.chunkForCoordinate(_playerPosition.z),
      );
      if (nextChunk != _playerChunk) {
        _playerChunk = nextChunk;
        unawaited(_refreshVisibleChunks());
      }
    }
    final jumping = _isJumping;
    final renderedSurfaceY = jumping
        ? _jumpStartSurfaceY +
              (_jumpLandingSurfaceY - _jumpStartSurfaceY) *
                  (_jumpElapsed / _jumpDuration).clamp(0.0, 1.0) +
              jumpOffset
        : _playerPosition.y;
    player.position = vm.Vector3(
      _playerPosition.x,
      renderedSurfaceY +
          (jumping
              ? 0
              : moving
              ? playerWorker.walkRig.stepBob(_elapsed)
              : math.sin(_elapsed * 2.2) * 0.018),
      _playerPosition.z,
    );
    playerWorker.walkRig.update(
      dt: dt,
      elapsed: _elapsed,
      moving: moving || jumping,
    );
  }

  void _startJump({required double fromSurfaceY, required double toSurfaceY}) {
    _isJumping = true;
    _jumpElapsed = 0;
    _jumpStartSurfaceY = fromSurfaceY;
    _jumpLandingSurfaceY = toSurfaceY;
  }

  void _advanceJump(double dt) {
    if (!_isJumping) return;
    _jumpElapsed += dt;
    if (_jumpElapsed >= _jumpDuration) _cancelJump();
  }

  void _cancelJump() {
    _isJumping = false;
    _jumpElapsed = 0;
    _jumpStartSurfaceY = _playerPosition.y;
    _jumpLandingSurfaceY = _playerPosition.y;
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
  _Worker({
    required this.id,
    required this.displayName,
    required this.root,
    required this.home,
    required this.followOffset,
    required this.isPlayer,
    required this.reunited,
    required this.walkRig,
  });

  final String id;
  final String displayName;
  final Node root;
  final vm.Vector3 home;
  final (double, double) followOffset;
  final bool isPlayer;
  final _VoxelWalkRig walkRig;
  bool reunited;
}

class _PartySpec {
  const _PartySpec({
    required this.id,
    required this.name,
    required this.cell,
    required this.followOffset,
    this.isPlayer = false,
  });

  final String id;
  final String name;
  final GridCell cell;
  final (double, double) followOffset;
  final bool isPlayer;
}

class _VoxelWalkRig {
  _VoxelWalkRig({
    required this.primaryArm,
    required this.secondaryArm,
    required this.leftLeg,
    required this.rightLeg,
    required this.locomotion,
  }) : _baseRotations = {
         for (final node in [
           primaryArm,
           secondaryArm,
           leftLeg,
           rightLeg,
           ...locomotion,
         ].whereType<Node>())
           node: node.rotation,
       };

  factory _VoxelWalkRig.fromModel(Node model) {
    final locomotion = model.meshNodes
        .map((node) => _findAncestorWithPrefix(node, 'VoxelRig_Locomotion_'))
        .whereType<Node>()
        .toSet()
        .toList(growable: false);
    return _VoxelWalkRig(
      primaryArm: model.getChildByName('VoxelRig_ArmPrimary'),
      secondaryArm: model.getChildByName('VoxelRig_ArmSecondary'),
      leftLeg: model.getChildByName('VoxelRig_LegLeft'),
      rightLeg: model.getChildByName('VoxelRig_LegRight'),
      locomotion: locomotion,
    );
  }

  final Node? primaryArm;
  final Node? secondaryArm;
  final Node? leftLeg;
  final Node? rightLeg;
  final List<Node> locomotion;
  final Map<Node, vm.Quaternion> _baseRotations;
  double _motionWeight = 0;

  static Node? _findAncestorWithPrefix(Node node, String prefix) {
    Node? current = node;
    while (current != null) {
      if (current.name.startsWith(prefix)) return current;
      current = current.parent;
    }
    return null;
  }

  double stepBob(double elapsed) =>
      math.sin(elapsed * 10.5).abs() * 0.045 * _motionWeight;

  void update({
    required double dt,
    required double elapsed,
    required bool moving,
  }) {
    final response = 1 - math.exp(-dt * 20);
    _motionWeight += ((moving ? 1.0 : 0.0) - _motionWeight) * response;
    final stride = math.sin(elapsed * 10.5) * 0.5 * _motionWeight;
    _setRotation(leftLeg, vm.Vector3(1, 0, 0), stride);
    _setRotation(rightLeg, vm.Vector3(1, 0, 0), -stride);
    _setRotation(primaryArm, vm.Vector3(1, 0, 0), stride * 0.18);
    _setRotation(secondaryArm, vm.Vector3(1, 0, 0), -stride * 0.46);
    for (var index = 0; index < locomotion.length; index++) {
      final wave = math.sin(elapsed * 9 + index * 0.9) * 0.3 * _motionWeight;
      _setRotation(locomotion[index], vm.Vector3(0, 0, 1), wave);
    }
  }

  void _setRotation(Node? node, vm.Vector3 axis, double angle) {
    if (node == null) return;
    final base = _baseRotations[node];
    if (base == null) return;
    node.rotation = base * vm.Quaternion.axisAngle(axis, angle);
  }
}
