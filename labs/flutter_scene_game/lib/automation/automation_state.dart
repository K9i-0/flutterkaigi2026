import '../game/island_game_controller.dart';
import '../scene/madogiwa_island_scene.dart';

abstract final class IslandAutomationState {
  static IslandGameController? controller;
  static MadogiwaIslandScene? scene;
  static final Set<String> _heldDirections = {};

  static Set<String> get heldDirections => Set.unmodifiable(_heldDirections);

  static void attach({
    required IslandGameController controller,
    required MadogiwaIslandScene scene,
  }) {
    IslandAutomationState.controller = controller;
    IslandAutomationState.scene = scene;
  }

  static void detach(MadogiwaIslandScene currentScene) {
    if (!identical(scene, currentScene)) return;
    releaseAllKeys();
    controller = null;
    scene = null;
  }

  static String? normalizeDirectionKey(String key) {
    return switch (key.trim().toLowerCase()) {
      'w' || 'arrowup' || 'up' => 'forward',
      'a' || 'arrowleft' || 'left' => 'left',
      's' || 'arrowdown' || 'down' => 'backward',
      'd' || 'arrowright' || 'right' => 'right',
      _ => null,
    };
  }

  static bool setKey(String key, {required bool pressed}) {
    final direction = normalizeDirectionKey(key);
    if (direction == null || scene == null) return false;
    if (pressed) {
      _heldDirections.add(direction);
    } else {
      _heldDirections.remove(direction);
    }
    _applyMovement();
    return true;
  }

  static void releaseAllKeys() {
    _heldDirections.clear();
    scene?.stopMoving();
  }

  static void _applyMovement() {
    scene?.setMoveInput(
      right:
          (_heldDirections.contains('right') ? 1 : 0) -
          (_heldDirections.contains('left') ? 1 : 0),
      forward:
          (_heldDirections.contains('forward') ? 1 : 0) -
          (_heldDirections.contains('backward') ? 1 : 0),
    );
  }
}
