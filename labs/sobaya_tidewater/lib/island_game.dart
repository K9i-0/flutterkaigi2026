import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter_scene/scene.dart';
import 'package:vector_math/vector_math.dart' as vm;

import 'island_world.dart';

class IslandGame {
  final scene = Scene();
  final camera = PerspectiveCamera(
    position: vm.Vector3(53.6, 5, -77),
    target: vm.Vector3(53.6, 3, 40),
    fovFar: 3000,
    fovNear: .08,
  );
  late IslandWorld world;
  PreprocessedMaterial? water;
  bool ready = false, disposed = false, flying = false;
  double yaw = math.pi, pitch = 0, forward = 0, strafe = 0, vertical = 0;
  bool sprint = false;
  final feet = vm.Vector3.zero();

  Future<void> load() async {
    await Scene.initializeStaticResources();
    final metadata = jsonDecode(
      await rootBundle.loadString('assets/world.json'),
    ) as Map<String, dynamic>;
    world = IslandWorld(metadata, await rootBundle.load('assets/heights.bin'));
    final island = await Node.fromGlbAsset('assets/island.glb');
    water = await loadFmatMaterial('assets/coastal_water.fmat');
    if (disposed) return;
    // The runtime importer supplies a glTF Z-mirror at its root. This port
    // deliberately keeps Tidewater world coordinates for terrain/collisions.
    // Cancel only that boundary transform; preserve source indices/normals.
    island.localTransform = vm.Matrix4.identity();
    scene.add(island);
    scene.environmentSettings = EnvironmentSettings(
      exposure: 1,
      ambientOcclusionEnabled: false,
    );
    final sky = GradientSkySource(
      zenithColor: vm.Vector3(.08, .28, .52),
      horizonColor: vm.Vector3(.63, .75, .78),
      groundColor: vm.Vector3(.15, .21, .23),
      sunColor: vm.Vector3(4, 3.6, 2.6),
    );
    scene.skybox = Skybox(sky);
    scene.skyEnvironment = SkyEnvironment(sky);
    scene.directionalLight = DirectionalLight(
      direction: vm.Vector3(-.6, -1, -.4),
      intensity: 2.2,
      castsShadow: true,
      shadowMapResolution: 1024,
      shadowCascadeCount: 2,
      shadowMaxDistance: 80,
      cacheStaticShadows: true,
    );
    scene.renderScale = .85;
    // The fixed grid is centred on the bay. Vertex animation stays entirely on Flutter GPU.
    const n = 180, size = 3000.0;
    final positions = Float32List((n + 1) * (n + 1) * 3),
        normals = Float32List((n + 1) * (n + 1) * 3);
    final indices = <int>[];
    for (var z = 0; z <= n; z++) {
      for (var x = 0; x <= n; x++) {
        final i = (z * (n + 1) + x) * 3;
        positions[i] = (x / n - .5) * size;
        positions[i + 2] = (z / n - .5) * size;
        normals[i + 1] = 1;
      }
    }
    for (var z = 0; z < n; z++) {
      for (var x = 0; x < n; x++) {
        final i = z * (n + 1) + x, j = i + n + 1;
        indices.addAll([i, j, i + 1, i + 1, j, j + 1]);
      }
    }
    scene.add(
      Node(
        name: 'Coastal water',
        mesh: Mesh(
          MeshGeometry.fromArrays(
            positions: positions,
            normals: normals,
            indices: indices,
          ),
          water!,
        ),
      ),
    );
    ready = true;
    open('pier');
  }

  void open(String name) {
    if (!ready) return;
    clearInput();
    pitch = 0;
    flying = name == 'overview';
    switch (name) {
      case 'village':
        feet.setValues(42, world.groundAt(42, -107, 100), -107);
        yaw = 0;
        break;
      case 'overview':
        feet.setValues(220, 140, 220);
        yaw = .55;
        pitch = -.3;
        break;
      default:
        feet.setValues(53.6, world.groundAt(53.6, -77, 100), -77);
        yaw = math.pi;
    }
    syncCamera();
  }

  void clearInput() {
    forward = 0;
    strafe = 0;
    vertical = 0;
    sprint = false;
  }

  void look(double dx, double dy) {
    yaw -= dx * .003;
    pitch = (pitch - dy * .003).clamp(-1.45, 1.45);
    syncCamera();
  }

  void tick(Duration elapsed, double delta) {
    if (!ready || disposed) return;
    water?.parameters.setFloat('time', elapsed.inMicroseconds / 1e6);
    final dt = delta.clamp(0.0, .05),
        speed = flying ? (sprint ? 60.0 : 20.0) : (sprint ? 5.5 : 2.8);
    final len = math.max(1.0, math.sqrt(forward * forward + strafe * strafe));
    final dx =
        (-math.sin(yaw) * forward + math.cos(yaw) * strafe) / len * speed * dt;
    final dz =
        (-math.cos(yaw) * forward - math.sin(yaw) * strafe) / len * speed * dt;
    if (flying) {
      feet.x += dx;
      feet.z += dz;
      feet.y += vertical * speed * dt;
    } else {
      final count = math.max(1, (math.sqrt(dx * dx + dz * dz) / .08).ceil());
      for (var i = 0; i < count; i++) {
        final before = feet.clone();
        feet.x += dx / count;
        feet.z += dz / count;
        world.resolve(feet);
        final ground = world.groundAt(feet.x, feet.z, feet.y + .4);
        // First milestone is dry-land walking; keep sea entry and steep rises blocked.
        if (ground < -.2 || ground > feet.y + .45) {
          feet.setFrom(before);
        } else {
          feet.y = math.max(ground, feet.y - 9.8 * dt / count);
        }
      }
    }
    syncCamera();
  }

  void syncCamera() {
    camera.position = feet + vm.Vector3(0, 1.7, 0);
    camera.target =
        camera.position +
        vm.Vector3(
          -math.sin(yaw) * math.cos(pitch),
          math.sin(pitch),
          -math.cos(yaw) * math.cos(pitch),
        );
  }

  Map<String, Object?> inspect() => {
    'ready': ready,
    'flying': flying,
    'position': [feet.x, feet.y, feet.z],
    'yaw': yaw,
    'pitch': pitch,
    'flutterGpu': 'stock',
    'sceneFork': '93d420be938213d19744723f8f6bb56be301187d',
    'source': ready ? world.metadata['revision'] : null,
    'buildings': ready ? (world.metadata['buildings'] as List).length : 0,
  };
  void dispose() {
    disposed = true;
    clearInput();
    scene.removeAll();
  }
}
