import type { LayerId } from "./types";

export const layerAssetUrls: Record<LayerId, string> = {
  body: new URL(
    "../../04_GAME_ASSETS/live2d/sobaya/source/sobaya_body_plate.png",
    import.meta.url,
  ).href,
  head: new URL(
    "../../04_GAME_ASSETS/live2d/sobaya/parts/sobaya_head_unit.png",
    import.meta.url,
  ).href,
  eyeLidL: new URL(
    "../../04_GAME_ASSETS/live2d/sobaya/parts/sobaya_eye_lid_l.png",
    import.meta.url,
  ).href,
  eyeLidR: new URL(
    "../../04_GAME_ASSETS/live2d/sobaya/parts/sobaya_eye_lid_r.png",
    import.meta.url,
  ).href,
  mouth: new URL(
    "../../04_GAME_ASSETS/live2d/sobaya/parts/sobaya_mouth_slot.png",
    import.meta.url,
  ).href,
  mug: new URL(
    "../../04_GAME_ASSETS/live2d/sobaya/parts/sobaya_mug_hand.png",
    import.meta.url,
  ).href,
};
