export type MapId = "castle" | "town" | "field" | "cave" | "throne";
export type Direction = "up" | "down" | "left" | "right";
export type Phase = "title" | "map" | "dialog" | "shop" | "battle" | "boss" | "ending";

export interface Position {
  x: number;
  y: number;
}

export interface MapDefinition {
  id: MapId;
  name: string;
  tiles: string[];
  start: Position;
  hint: string;
}

export type ItemId =
  | "happoshu"
  | "third"
  | "nonAlcohol"
  | "superDry"
  | "yebisu"
  | "premiumMalts";

export interface Item {
  id: ItemId;
  name: string;
  price: number;
  note: string;
}

export type EndingKind = "good" | "close" | "gameover";
