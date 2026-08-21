enum IslandItem { wood, stone, food, coal, iron, herb }

enum GameChapter { beach, forest, quarry, marsh, summit, complete }

enum EndingChoice { none, rescue, stay }

enum CompanionMode { follow, camp }

enum CraftRecipe {
  campfire,
  workbench,
  stoneAxe,
  stonePickaxe,
  bridgeKit,
  ironPickaxe,
  forge,
  fogGear,
}

extension IslandItemInfo on IslandItem {
  String get label => switch (this) {
    IslandItem.wood => '木材',
    IslandItem.stone => '石材',
    IslandItem.food => '食料',
    IslandItem.coal => '石炭',
    IslandItem.iron => '鉄',
    IslandItem.herb => '薬草',
  };
}

extension GameChapterInfo on GameChapter {
  String get label => switch (this) {
    GameChapter.beach => '漂着海岸',
    GameChapter.forest => '密林地帯',
    GameChapter.quarry => '岩山・採掘場',
    GameChapter.marsh => '圏外の湿地',
    GameChapter.summit => '山頂の社内遺跡',
    GameChapter.complete => '窓際族自治区',
  };

  int get signalLevel => switch (this) {
    GameChapter.beach => 0,
    GameChapter.forest => 1,
    GameChapter.quarry => 2,
    GameChapter.marsh => 3,
    GameChapter.summit || GameChapter.complete => 4,
  };
}

extension CraftRecipeInfo on CraftRecipe {
  String get label => switch (this) {
    CraftRecipe.campfire => '焚き火',
    CraftRecipe.workbench => '作業台',
    CraftRecipe.stoneAxe => '石の斧',
    CraftRecipe.stonePickaxe => '石のツルハシ',
    CraftRecipe.bridgeKit => '橋梁キット',
    CraftRecipe.ironPickaxe => '鉄のツルハシ',
    CraftRecipe.forge => '簡易炉',
    CraftRecipe.fogGear => '圏外霧防護具',
  };

  String get description => switch (this) {
    CraftRecipe.campfire => '夜の拠点を照らし、生活基盤を整える',
    CraftRecipe.workbench => '道具と探索設備のレシピを解放',
    CraftRecipe.stoneAxe => '木の採取量が2から4へ増加',
    CraftRecipe.stonePickaxe => '石炭と鉄鉱石を採掘可能',
    CraftRecipe.bridgeKit => '密林を横切る谷を越えられる',
    CraftRecipe.ironPickaxe => '岩山の硬い岩盤を突破',
    CraftRecipe.forge => 'ゆめみんが上位設備を製作',
    CraftRecipe.fogGear => '湿地の濃い圏外霧へ進入可能',
  };

  Map<IslandItem, int> get cost => switch (this) {
    CraftRecipe.campfire => {IslandItem.wood: 1, IslandItem.stone: 2},
    CraftRecipe.workbench => {IslandItem.wood: 4},
    CraftRecipe.stoneAxe => {IslandItem.wood: 2, IslandItem.stone: 2},
    CraftRecipe.stonePickaxe => {IslandItem.wood: 2, IslandItem.stone: 3},
    CraftRecipe.bridgeKit => {IslandItem.wood: 8},
    CraftRecipe.ironPickaxe => {IslandItem.wood: 2, IslandItem.iron: 4},
    CraftRecipe.forge => {IslandItem.stone: 8, IslandItem.coal: 4},
    CraftRecipe.fogGear => {IslandItem.herb: 6, IslandItem.coal: 2},
  };
}
