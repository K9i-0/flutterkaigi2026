import 'package:flutter/foundation.dart';

import '../world/island_world.dart';

enum IslandTool { gather, floor, wall, roof }

enum IslandResource { tree, rock }

enum BuildLevel { ground, floor, wall }

enum IslandActionKind {
  none,
  treeHarvested,
  rockHarvested,
  floorPlaced,
  wallPlaced,
  roofPlaced,
}

@immutable
class GridCell {
  const GridCell(this.x, this.z);

  final int x;
  final int z;

  @override
  bool operator ==(Object other) =>
      other is GridCell && other.x == x && other.z == z;

  @override
  int get hashCode => Object.hash(x, z);
}

class IslandActionResult {
  const IslandActionResult(this.kind, this.cell);

  final IslandActionKind kind;
  final GridCell cell;

  bool get changed => kind != IslandActionKind.none;
}

class IslandGameController extends ChangeNotifier {
  static final buildZone = <GridCell>{
    const GridCell(-1, 0),
    const GridCell(0, 0),
    const GridCell(-1, 1),
    const GridCell(0, 1),
  };

  IslandGameController() {
    reset();
  }

  final Map<GridCell, IslandResource> resources = {};
  final Map<GridCell, BuildLevel> structures = {};

  IslandTool tool = IslandTool.gather;
  GridCell? selectedCell;
  int wood = 0;
  int stone = 0;
  int food = 3;
  int day = 1;
  bool roofComplete = false;
  String message = '木と岩をタップして、家の材料を集めよう';

  int get floorsBuilt =>
      structures.values.where((level) => level != BuildLevel.ground).length;

  int get wallsBuilt =>
      structures.values.where((level) => level == BuildLevel.wall).length;

  Iterable<GridCell> get wallCells => structures.entries
      .where((entry) => entry.value == BuildLevel.wall)
      .map((entry) => entry.key);

  bool get homeComplete => roofComplete;

  void reset() {
    resources.clear();
    for (
      var x = -IslandWorld.worldHalfSize;
      x < IslandWorld.worldHalfSize;
      x++
    ) {
      for (
        var z = -IslandWorld.worldHalfSize;
        z < IslandWorld.worldHalfSize;
        z++
      ) {
        switch (IslandWorld.resourceCode(x, z)) {
          case 1:
            resources[GridCell(x, z)] = IslandResource.tree;
            break;
          case 2:
            resources[GridCell(x, z)] = IslandResource.rock;
            break;
          default:
            break;
        }
      }
    }
    resources.addAll({
      const GridCell(-3, -1): IslandResource.tree,
      const GridCell(3, -1): IslandResource.tree,
      const GridCell(-3, 2): IslandResource.tree,
      const GridCell(3, 2): IslandResource.tree,
      const GridCell(0, -3): IslandResource.tree,
      const GridCell(-2, -3): IslandResource.rock,
      const GridCell(2, -3): IslandResource.rock,
    });
    structures.clear();
    tool = IslandTool.gather;
    selectedCell = null;
    wood = 0;
    stone = 0;
    food = 3;
    day = 1;
    roofComplete = false;
    message = '木と岩をタップして、家の材料を集めよう';
    notifyListeners();
  }

  void selectTool(IslandTool next) {
    tool = next;
    message = switch (next) {
      IslandTool.gather => '木と岩をタップして資源を採取',
      IslandTool.floor => '好きな地面へ床ブロックを置こう（木材1）',
      IslandTool.wall => '床の上に壁を4つ積もう（木材1・石材1）',
      IslandTool.roof => '4つの壁ができたら屋根を載せよう（木材2）',
    };
    notifyListeners();
  }

  IslandActionResult actOn(GridCell cell) {
    selectedCell = cell;
    final resource = resources[cell];
    if (resource != null) {
      if (tool != IslandTool.gather) {
        message = 'まず「採取」に切り替えよう';
        notifyListeners();
        return IslandActionResult(IslandActionKind.none, cell);
      }
      resources.remove(cell);
      if (resource == IslandResource.tree) {
        wood += 2;
        message = '木材を2個入手。そば屋が黙々と運んだ';
        notifyListeners();
        return IslandActionResult(IslandActionKind.treeHarvested, cell);
      }
      stone += 2;
      message = '石材を2個入手。タコさんの触手が便利';
      notifyListeners();
      return IslandActionResult(IslandActionKind.rockHarvested, cell);
    }

    final level = structures[cell] ?? BuildLevel.ground;
    switch (tool) {
      case IslandTool.gather:
        message = 'ここには採取できるものがない';
        break;
      case IslandTool.floor:
        if (level != BuildLevel.ground) {
          message = 'このマスには床がある';
        } else if (wood < 1) {
          message = '木材が足りない。島の木を採取しよう';
        } else {
          wood--;
          structures[cell] = BuildLevel.floor;
          message = '床を設置 $floorsBuilt/4';
          notifyListeners();
          return IslandActionResult(IslandActionKind.floorPlaced, cell);
        }
        break;
      case IslandTool.wall:
        if (level == BuildLevel.ground) {
          message = '先にこのマスへ床を置こう';
        } else if (level == BuildLevel.wall) {
          message = 'このマスの壁は完成している';
        } else if (wood < 1 || stone < 1) {
          message = '壁には木材1・石材1が必要';
        } else {
          wood--;
          stone--;
          structures[cell] = BuildLevel.wall;
          message = '壁を設置 $wallsBuilt/4';
          notifyListeners();
          return IslandActionResult(IslandActionKind.wallPlaced, cell);
        }
        break;
      case IslandTool.roof:
        if (roofComplete) {
          message = '家はもう完成している。快適です！';
        } else if (wallsBuilt < 4) {
          message = '屋根を支える壁があと${4 - wallsBuilt}つ必要';
        } else if (wood < 2) {
          message = '屋根には木材が2個必要';
        } else {
          wood -= 2;
          roofComplete = true;
          message = '生活拠点が完成！ 島流しもメリットです！';
          notifyListeners();
          return IslandActionResult(IslandActionKind.roofPlaced, cell);
        }
        break;
    }
    notifyListeners();
    return IslandActionResult(IslandActionKind.none, cell);
  }
}
