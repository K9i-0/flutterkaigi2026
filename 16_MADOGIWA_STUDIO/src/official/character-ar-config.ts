export const arCharacters = {
  sobaya: { name: "そば屋", greeting: "Greeting", height: 1.8 },
  fukuchan: { name: "福ちゃん", greeting: "Greeting", height: 1.7 },
  takosan: { name: "たこさん", greeting: "Wave", height: 1.433 },
  yametaro: { name: "やめ太郎", greeting: "Wave", height: 1.3 },
} as const;
export type ARCharacter = keyof typeof arCharacters;
export type ARPlacement = "life" | "plush" | "selfie";
export function arHeight(character: ARCharacter, placement: ARPlacement) {
  return placement === "life" ? arCharacters[character].height : placement === "plush" ? 0.2 : 0.12;
}
export function modelUrl(character: string) {
  const version = character === "fukuchan" ? "rig-v3-gyun-twist-20260917" : character === "sobaya" ? "mug-motion-greeting-20260917" : character === "takosan" ? "tentacle-clean-20260917" : "20260916-2";
  return `/models/characters/${character}.glb?v=${version}`;
}

export function isARCharacter(value: string): value is ARCharacter {
  return Object.hasOwn(arCharacters, value);
}
export function cameraUrl(character: string) {
  return `/camera/${isARCharacter(character) ? character : "sobaya"}`;
}
