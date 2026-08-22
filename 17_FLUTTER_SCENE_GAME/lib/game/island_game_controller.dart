import 'package:flutter/foundation.dart';

import '../world/island_world.dart';
import 'island_progression.dart';

export 'island_progression.dart';

enum IslandTool { gather, build, floor, wall, roof, torch }

enum BuildBlueprint { floor, wall, roof, torch, house }

extension BuildBlueprintDetails on BuildBlueprint {
  String get label => switch (this) {
    BuildBlueprint.floor => '床',
    BuildBlueprint.wall => '壁',
    BuildBlueprint.roof => '屋根',
    BuildBlueprint.torch => '松明',
    BuildBlueprint.house => '小屋を一括建築',
  };

  String get description => switch (this) {
    BuildBlueprint.floor => '地面に足場を置く',
    BuildBlueprint.wall => '選んだ床へ壁を立てる',
    BuildBlueprint.roof => '壁4枚の上へ屋根を載せる',
    BuildBlueprint.torch => '周囲を照らす',
    BuildBlueprint.house => '2×2の床・壁・屋根を一度に完成',
  };

  Map<IslandItem, int> get cost => switch (this) {
    BuildBlueprint.floor => const {IslandItem.wood: 1},
    BuildBlueprint.wall => const {IslandItem.wood: 1, IslandItem.stone: 1},
    BuildBlueprint.roof => const {IslandItem.wood: 2},
    BuildBlueprint.torch => const {IslandItem.wood: 1},
    BuildBlueprint.house => const {IslandItem.wood: 10, IslandItem.stone: 4},
  };

  IslandTool? get placementTool => switch (this) {
    BuildBlueprint.floor => IslandTool.floor,
    BuildBlueprint.wall => IslandTool.wall,
    BuildBlueprint.roof => IslandTool.roof,
    BuildBlueprint.torch => IslandTool.torch,
    BuildBlueprint.house => null,
  };
}

enum IslandResource { tree, rock, berry, coal, iron, herb }

enum BuildLevel { ground, floor, wall }

enum IslandActionKind {
  none,
  treeHarvested,
  rockHarvested,
  floorPlaced,
  wallPlaced,
  roofPlaced,
  torchPlaced,
  housePlaced,
  berryHarvested,
  coalHarvested,
  ironHarvested,
  herbHarvested,
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
  final Set<GridCell> torches = {};
  final Set<CraftRecipe> craftedRecipes = {};
  final Set<String> reunitedMembers = {};
  final Map<String, CompanionMode> companionModes = {};
  final Set<String> completedLandmarks = {};

  IslandTool tool = IslandTool.gather;
  GridCell? selectedCell;
  int wood = 0;
  int stone = 0;
  int food = 3;
  int coal = 0;
  int iron = 0;
  int herb = 0;
  int day = 1;
  bool roofComplete = false;
  GameChapter chapter = GameChapter.beach;
  EndingChoice endingChoice = EndingChoice.none;
  String message = '周囲を探索し、木と岩を集めながら3人を捜そう';

  int get floorsBuilt =>
      structures.values.where((level) => level != BuildLevel.ground).length;

  int get wallsBuilt =>
      structures.values.where((level) => level == BuildLevel.wall).length;

  Iterable<GridCell> get wallCells => structures.entries
      .where((entry) => entry.value == BuildLevel.wall)
      .map((entry) => entry.key);

  bool get homeComplete => roofComplete;

  int get signalLevel => chapter.signalLevel;

  bool get campaignComplete => endingChoice != EndingChoice.none;

  bool get endingAvailable => completedLandmarks.contains('summit_relay');

  double get explorationLimit => switch (chapter) {
    GameChapter.beach => 24,
    GameChapter.forest => hasRecipe(CraftRecipe.bridgeKit) ? 64 : 38,
    GameChapter.quarry => hasRecipe(CraftRecipe.ironPickaxe) ? 86 : 80,
    GameChapter.marsh => hasRecipe(CraftRecipe.fogGear) ? 104 : 90,
    GameChapter.summit || GameChapter.complete => 120,
  };

  int itemCount(IslandItem item) => switch (item) {
    IslandItem.wood => wood,
    IslandItem.stone => stone,
    IslandItem.food => food,
    IslandItem.coal => coal,
    IslandItem.iron => iron,
    IslandItem.herb => herb,
  };

  bool hasRecipe(CraftRecipe recipe) => craftedRecipes.contains(recipe);

  String get chapterObjective {
    switch (chapter) {
      case GameChapter.beach:
        if (!homeComplete) return '床4・壁4・屋根を建てて小屋を完成させる';
        if (!hasRecipe(CraftRecipe.campfire)) return '焚き火をクラフトする';
        if (!hasRecipe(CraftRecipe.workbench)) return '作業台をクラフトする';
        return '密林へ向かう';
      case GameChapter.forest:
        if (!hasRecipe(CraftRecipe.stoneAxe)) return '作業台で石の斧を作る';
        if (!hasRecipe(CraftRecipe.stonePickaxe)) return '石のツルハシを作る';
        if (!hasRecipe(CraftRecipe.bridgeKit)) return '木材8で橋梁キットを作る';
        if (!reunitedMembers.contains('yametaro')) return '壊れた無線塔でやめ太郎を捜す';
        return '無線塔を調べて修復する（石材4・石炭2）';
      case GameChapter.quarry:
        if (!reunitedMembers.contains('yumemin')) return '漂着した会議室でゆめみんを捜す';
        if (!hasRecipe(CraftRecipe.ironPickaxe)) {
          return 'ゆめみんと鉄のツルハシを作る（木材2・鉄4）';
        }
        if (!hasRecipe(CraftRecipe.forge)) return 'ゆめみんと簡易炉を作る';
        return '漂着した会議室の中継器を起動する';
      case GameChapter.marsh:
        if (!hasRecipe(CraftRecipe.fogGear)) return '薬草6・石炭2で霧防護具を作る';
        if (!reunitedMembers.contains('takosan')) return 'タコ石の門でタコさんを捜す';
        return 'タコ石の門を修復する（鉄6・石炭4）';
      case GameChapter.summit:
        if (endingAvailable) return '救助信号を送るか、島に残るか選ぶ';
        return '山頂で最終通信機を完成（鉄8・石炭6・石材10）';
      case GameChapter.complete:
        return endingChoice == EndingChoice.stay
            ? '島を新しい窓際族エリアとして発展させる'
            : '救助船の到着を待つ';
    }
  }

  String get progressLabel =>
      '通信 Lv.$signalLevel/4 · 再会 ${reunitedMembers.length}/3';

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
          case 3:
            resources[GridCell(x, z)] = IslandResource.berry;
            break;
          case 4:
            resources[GridCell(x, z)] = IslandResource.coal;
            break;
          case 5:
            resources[GridCell(x, z)] = IslandResource.iron;
            break;
          case 6:
            resources[GridCell(x, z)] = IslandResource.herb;
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
      const GridCell(-4, 4): IslandResource.tree,
      const GridCell(4, 4): IslandResource.tree,
      const GridCell(0, 5): IslandResource.tree,
      const GridCell(-2, -3): IslandResource.rock,
      const GridCell(2, -3): IslandResource.rock,
      const GridCell(5, 0): IslandResource.rock,
      const GridCell(-5, 0): IslandResource.berry,
    });
    structures.clear();
    torches
      ..clear()
      ..add(const GridCell(2, 2));
    craftedRecipes.clear();
    reunitedMembers.clear();
    companionModes.clear();
    completedLandmarks.clear();
    tool = IslandTool.gather;
    selectedCell = null;
    wood = 0;
    stone = 0;
    food = 3;
    coal = 0;
    iron = 0;
    herb = 0;
    day = 1;
    roofComplete = false;
    chapter = GameChapter.beach;
    endingChoice = EndingChoice.none;
    message = '周囲を探索し、木と岩を集めながら3人を捜そう';
    notifyListeners();
  }

  void selectTool(IslandTool next) {
    tool = next;
    message = switch (next) {
      IslandTool.gather => '木と岩をタップして資源を採取',
      IslandTool.build => '建設したい地面をタップして位置を指定',
      IslandTool.floor => '好きな地面へ床ブロックを置こう（木材1）',
      IslandTool.wall => '床の上に壁を4つ積もう（木材1・石材1）',
      IslandTool.roof => '4つの壁ができたら屋根を載せよう（木材2）',
      IslandTool.torch => '地面をタップして松明を置こう（木材1）',
    };
    notifyListeners();
  }

  void selectBuildTarget(GridCell cell) {
    selectedCell = cell;
    message = '建設位置 ${cell.x}, ${cell.z} を選択';
    notifyListeners();
  }

  void showMessage(String next) {
    message = next;
    notifyListeners();
  }

  IslandActionResult actOn(GridCell cell) => _actOn(cell, tool);

  IslandActionResult buildAt(BuildBlueprint blueprint, GridCell cell) {
    selectedCell = cell;
    final failure = buildFailureReason(blueprint, cell);
    if (failure != null) {
      message = failure;
      notifyListeners();
      return IslandActionResult(IslandActionKind.none, cell);
    }
    if (blueprint != BuildBlueprint.house) {
      return _actOn(cell, blueprint.placementTool!);
    }

    for (final entry in blueprint.cost.entries) {
      _changeItem(entry.key, -entry.value);
    }
    for (final footprintCell in houseFootprint(cell)) {
      structures[footprintCell] = BuildLevel.wall;
    }
    roofComplete = true;
    message = '小屋を一括建築！';
    final previousChapter = chapter;
    _updateChapter();
    if (chapter == previousChapter) message = '小屋が完成。次: $chapterObjective';
    notifyListeners();
    return IslandActionResult(IslandActionKind.housePlaced, cell);
  }

  String? buildFailureReason(BuildBlueprint blueprint, GridCell cell) {
    if (!IslandWorld.containsCell(cell.x, cell.z) ||
        !IslandWorld.isLand(cell.x, cell.z)) {
      return 'ここには設置できない';
    }
    if (blueprint == BuildBlueprint.house) {
      if (roofComplete) return '生活用の小屋は完成済み';
      final footprint = houseFootprint(cell);
      if (footprint.any(
        (target) =>
            !IslandWorld.containsCell(target.x, target.z) ||
            !IslandWorld.isLand(target.x, target.z),
      )) {
        return '小屋には2×2マスの陸地が必要';
      }
      final heights = footprint
          .map((target) => IslandWorld.surfaceHeight(target.x, target.z))
          .toList(growable: false);
      final minHeight = heights.reduce((a, b) => a < b ? a : b);
      final maxHeight = heights.reduce((a, b) => a > b ? a : b);
      if (maxHeight - minHeight > 1) return '小屋には平らな2×2マスが必要';
      if (footprint.any(resources.containsKey)) return '建設予定地の資源を先に採取しよう';
      if (footprint.any(structures.containsKey)) return '建設予定地に別の建物がある';
    } else if (resources.containsKey(cell)) {
      return 'このマスの資源を先に採取しよう';
    }

    final level = structures[cell] ?? BuildLevel.ground;
    switch (blueprint) {
      case BuildBlueprint.floor:
        if (level != BuildLevel.ground) return 'このマスには床がある';
        break;
      case BuildBlueprint.wall:
        if (level == BuildLevel.ground) return '先にこのマスへ床を置こう';
        if (level == BuildLevel.wall) return 'このマスの壁は完成している';
        break;
      case BuildBlueprint.roof:
        if (roofComplete) return '家の屋根は完成済み';
        if (!wallCells.contains(cell)) return '建てた壁のマスを選択しよう';
        if (wallsBuilt < 4) return '屋根を支える壁があと${4 - wallsBuilt}つ必要';
        break;
      case BuildBlueprint.torch:
        if (torches.contains(cell)) return 'このマスには松明がある';
        break;
      case BuildBlueprint.house:
        break;
    }

    final missing = blueprint.cost.entries
        .where((entry) => itemCount(entry.key) < entry.value)
        .map((entry) => '${entry.key.label}${entry.value}')
        .join('・');
    return missing.isEmpty ? null : '$missingが必要';
  }

  bool canBuildAt(BuildBlueprint blueprint, GridCell cell) =>
      buildFailureReason(blueprint, cell) == null;

  List<GridCell> houseFootprint(GridCell anchor) => [
    anchor,
    GridCell(anchor.x + 1, anchor.z),
    GridCell(anchor.x, anchor.z + 1),
    GridCell(anchor.x + 1, anchor.z + 1),
  ];

  IslandActionResult _actOn(GridCell cell, IslandTool activeTool) {
    selectedCell = cell;
    final resource = resources[cell];
    if (resource != null) {
      if (activeTool != IslandTool.gather) {
        message = 'まず「採取」に切り替えよう';
        notifyListeners();
        return IslandActionResult(IslandActionKind.none, cell);
      }
      resources.remove(cell);
      if (resource == IslandResource.tree) {
        final amount = hasRecipe(CraftRecipe.stoneAxe) ? 4 : 2;
        wood += amount;
        message = '木材を$amount個入手';
        notifyListeners();
        return IslandActionResult(IslandActionKind.treeHarvested, cell);
      }
      if (resource == IslandResource.rock) {
        final amount = hasRecipe(CraftRecipe.stonePickaxe) ? 3 : 2;
        stone += amount;
        message = '石材を$amount個入手';
        notifyListeners();
        return IslandActionResult(IslandActionKind.rockHarvested, cell);
      }
      if (resource == IslandResource.berry) {
        food += 2;
        message = '食料を2個入手';
        notifyListeners();
        return IslandActionResult(IslandActionKind.berryHarvested, cell);
      }
      if (resource == IslandResource.coal) {
        if (!hasRecipe(CraftRecipe.stonePickaxe)) {
          resources[cell] = resource;
          message = '石炭には石のツルハシが必要';
          notifyListeners();
          return IslandActionResult(IslandActionKind.none, cell);
        }
        final amount = hasRecipe(CraftRecipe.ironPickaxe) ? 3 : 2;
        coal += amount;
        message = '石炭を$amount個入手';
        notifyListeners();
        return IslandActionResult(IslandActionKind.coalHarvested, cell);
      }
      if (resource == IslandResource.iron) {
        if (!hasRecipe(CraftRecipe.stonePickaxe)) {
          resources[cell] = resource;
          message = '鉄鉱石には石のツルハシが必要';
          notifyListeners();
          return IslandActionResult(IslandActionKind.none, cell);
        }
        final amount = hasRecipe(CraftRecipe.ironPickaxe) ? 3 : 1;
        iron += amount;
        message = '鉄を$amount個入手';
        notifyListeners();
        return IslandActionResult(IslandActionKind.ironHarvested, cell);
      }
      herb += 2;
      message = '薬草を2個入手';
      notifyListeners();
      return IslandActionResult(IslandActionKind.herbHarvested, cell);
    }

    final level = structures[cell] ?? BuildLevel.ground;
    switch (activeTool) {
      case IslandTool.gather:
        message = 'ここには採取できるものがない';
        break;
      case IslandTool.build:
        message = '建設メニューから作りたいものを選ぼう';
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
          message = '小屋が完成！';
          final previousChapter = chapter;
          _updateChapter();
          if (chapter == previousChapter) {
            message = '小屋が完成。次: $chapterObjective';
          }
          notifyListeners();
          return IslandActionResult(IslandActionKind.roofPlaced, cell);
        }
        break;
      case IslandTool.torch:
        if (torches.contains(cell)) {
          message = 'このマスには松明がある';
        } else if (wood < 1) {
          message = '松明には木材1が必要';
        } else {
          wood--;
          torches.add(cell);
          message = '松明を設置。夜の探索範囲が広がった';
          notifyListeners();
          return IslandActionResult(IslandActionKind.torchPlaced, cell);
        }
        break;
    }
    notifyListeners();
    return IslandActionResult(IslandActionKind.none, cell);
  }

  bool canCraft(CraftRecipe recipe) => craftFailureReason(recipe) == null;

  String? craftFailureReason(CraftRecipe recipe) {
    if (hasRecipe(recipe)) return '作成済み';
    if (recipe == CraftRecipe.workbench && !homeComplete) {
      return '先に小屋を完成させよう';
    }
    if (recipe != CraftRecipe.campfire &&
        recipe != CraftRecipe.workbench &&
        !hasRecipe(CraftRecipe.workbench)) {
      return '先に作業台を作ろう';
    }
    if ((recipe == CraftRecipe.ironPickaxe ||
            recipe == CraftRecipe.forge ||
            recipe == CraftRecipe.fogGear) &&
        !reunitedMembers.contains('yumemin')) {
      return '先に漂着した会議室でゆめみんと再会しよう';
    }
    if (recipe == CraftRecipe.fogGear && !hasRecipe(CraftRecipe.forge)) {
      return '先に簡易炉を作ろう';
    }
    final missing = recipe.cost.entries
        .where((entry) => itemCount(entry.key) < entry.value)
        .map(
          (entry) =>
              '${entry.key.label}あと${entry.value - itemCount(entry.key)}',
        )
        .join('・');
    return missing.isEmpty ? null : missing;
  }

  bool craft(CraftRecipe recipe) {
    if (hasRecipe(recipe)) {
      message = '${recipe.label}は作成済み';
      notifyListeners();
      return false;
    }
    if (!canCraft(recipe)) {
      message = craftFailureReason(recipe) ?? '${recipe.label}はまだ作れない';
      notifyListeners();
      return false;
    }
    for (final entry in recipe.cost.entries) {
      _changeItem(entry.key, -entry.value);
    }
    craftedRecipes.add(recipe);
    final previousChapter = chapter;
    _updateChapter();
    if (chapter == previousChapter) {
      message = '${recipe.label}をクラフト。次: $chapterObjective';
    }
    notifyListeners();
    return true;
  }

  bool reuniteMember(String memberId, String displayName) {
    if (!reunitedMembers.add(memberId)) return false;
    companionModes[memberId] = CompanionMode.follow;
    message = '$displayNameと再会！ 固有能力と新レシピが使えるようになった';
    notifyListeners();
    return true;
  }

  CompanionMode companionMode(String memberId) =>
      companionModes[memberId] ?? CompanionMode.camp;

  void toggleCompanionMode(String memberId) {
    if (!reunitedMembers.contains(memberId)) return;
    final next = companionMode(memberId) == CompanionMode.follow
        ? CompanionMode.camp
        : CompanionMode.follow;
    companionModes[memberId] = next;
    message = next == CompanionMode.follow ? '仲間が探索へ同行する' : '仲間を拠点の設備担当に配置した';
    notifyListeners();
  }

  bool completeLandmark(String id) {
    if (completedLandmarks.contains(id)) {
      message = 'この設備は起動済み';
      notifyListeners();
      return false;
    }
    switch (id) {
      case 'radio_tower':
        if (chapter != GameChapter.forest ||
            !reunitedMembers.contains('yametaro') ||
            !hasRecipe(CraftRecipe.bridgeKit) ||
            !_spend({IslandItem.stone: 4, IslandItem.coal: 2})) {
          message = 'やめ太郎・橋梁キット・石材4・石炭2が必要';
          notifyListeners();
          return false;
        }
        chapter = GameChapter.quarry;
        break;
      case 'office_wreck':
        if (chapter != GameChapter.quarry ||
            !reunitedMembers.contains('yumemin') ||
            !hasRecipe(CraftRecipe.ironPickaxe) ||
            !hasRecipe(CraftRecipe.forge)) {
          message = 'ゆめみん・鉄のツルハシ・簡易炉が必要';
          notifyListeners();
          return false;
        }
        chapter = GameChapter.marsh;
        break;
      case 'octopus_shrine':
        if (chapter != GameChapter.marsh ||
            !reunitedMembers.contains('takosan') ||
            !hasRecipe(CraftRecipe.fogGear) ||
            !_spend({IslandItem.iron: 6, IslandItem.coal: 4})) {
          message = 'タコさん・霧防護具・鉄6・石炭4が必要';
          notifyListeners();
          return false;
        }
        chapter = GameChapter.summit;
        break;
      case 'summit_relay':
        if (chapter != GameChapter.summit ||
            reunitedMembers.length < 3 ||
            !_spend({
              IslandItem.iron: 8,
              IslandItem.coal: 6,
              IslandItem.stone: 10,
            })) {
          message = '全員の力と鉄8・石炭6・石材10が必要';
          notifyListeners();
          return false;
        }
        break;
      default:
        message = 'ここには修復できる設備がない';
        notifyListeners();
        return false;
    }
    completedLandmarks.add(id);
    message = id == 'summit_relay'
        ? '最終通信機が完成。会社へ救助信号を送るか決めよう'
        : '中継設備を起動！ 次: $chapterObjective';
    notifyListeners();
    return true;
  }

  void chooseEnding(EndingChoice choice) {
    if (!endingAvailable || choice == EndingChoice.none) return;
    endingChoice = choice;
    chapter = GameChapter.complete;
    message = choice == EndingChoice.stay
        ? '救助を断り、島を新しい窓際族エリアにした'
        : '救助信号を送信。全員で会社へ帰還する';
    notifyListeners();
  }

  void grantDebugResources([int amount = 99]) {
    wood += amount;
    stone += amount;
    food += amount;
    coal += amount;
    iron += amount;
    herb += amount;
    message = 'デバッグ資源を追加';
    notifyListeners();
  }

  void _updateChapter() {
    if (chapter == GameChapter.beach &&
        homeComplete &&
        hasRecipe(CraftRecipe.campfire) &&
        hasRecipe(CraftRecipe.workbench)) {
      chapter = GameChapter.forest;
      message = '生活基盤完成。通信Lv.1、密林の圏外霧が後退した';
    }
  }

  bool _spend(Map<IslandItem, int> cost) {
    if (!cost.entries.every((entry) => itemCount(entry.key) >= entry.value)) {
      return false;
    }
    for (final entry in cost.entries) {
      _changeItem(entry.key, -entry.value);
    }
    return true;
  }

  void _changeItem(IslandItem item, int delta) {
    switch (item) {
      case IslandItem.wood:
        wood += delta;
        break;
      case IslandItem.stone:
        stone += delta;
        break;
      case IslandItem.food:
        food += delta;
        break;
      case IslandItem.coal:
        coal += delta;
        break;
      case IslandItem.iron:
        iron += delta;
        break;
      case IslandItem.herb:
        herb += delta;
        break;
    }
  }
}
