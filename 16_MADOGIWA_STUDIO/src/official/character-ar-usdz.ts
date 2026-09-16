import { strFromU8, strToU8, unzipSync, zipSync, type Zippable } from "three/addons/libs/fflate.module.js";

// Apple's Preliminary_AnchoringAPI supports faces as well as planes. Explicitly
// apply the schema; Three's exporter options/types only cover plane placement.
export function anchorUSDZ(data: Uint8Array, face: boolean): Uint8Array<ArrayBuffer> {
  const files = unzipSync(data);
  const model = files["model.usda"];
  if (!model) throw new Error("ARデータの形式を確認できませんでした。");
  let text = strFromU8(model);
  if (!text.includes('def Xform "Scene" (')) throw new Error("ARシーンが見つかりません。");
  text = text.replace('def Xform "Scene" (', 'def Xform "Scene" (\n\t\t\tprepend apiSchemas = ["Preliminary_AnchoringAPI"]');
  if (face) {
    text = text.replace('token preliminary:anchoring:type = "plane"', 'uniform token preliminary:anchoring:type = "face"');
    text = text.replace(/\s*token preliminary:planeAnchoring:alignment = "horizontal"/, "");
  }
  files["model.usda"] = strToU8(text);
  // USDZ requires uncompressed ZIP entries whose data begins on 64-byte boundaries.
  const archive: Zippable = {};
  let offset = 0;
  for (const [name, bytes] of Object.entries(files)) {
    const base = offset + 30 + strToU8(name).length;
    const padding = (64 - (base + 4) % 64) % 64;
    archive[name] = [bytes, { extra: { 12345: new Uint8Array(padding) } }];
    offset = base + 4 + padding + bytes.length;
  }
  return zipSync(archive, { level: 0 });
}
