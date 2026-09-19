import { describe, expect, it } from "vitest";
import { strFromU8, strToU8, unzipSync, zipSync } from "three/addons/libs/fflate.module.js";
import { anchorUSDZ } from "../src/official/character-ar-usdz";
import { arCharacters, arHeight, cameraUrl, isARCharacter, modelUrl } from "../src/official/character-ar-config";

const source = `#usda 1.0\ndef Xform "Scene" (\n string sceneName = "Scene"\n) {\n token preliminary:anchoring:type = "plane"\n token preliminary:planeAnchoring:alignment = "horizontal"\n}`;
describe("AR handoff", () => {
  it("keeps a 20 cm plush independent of the character's life-size height", () => {
    expect(Object.keys(arCharacters).map((id) => arHeight(id as keyof typeof arCharacters, "plush"))).toEqual([.2, .2, .2, .2, .2]);
    expect(arHeight("sobaya", "life")).toBe(1.8);
    expect(arHeight("yametaro", "life")).toBe(1.3);
    expect(arHeight("takosan", "selfie")).toBe(.12);
  });
  it("supports the adopted static Yumemin in the viewer and all AR sizes", () => {
    expect(isARCharacter("yumemin")).toBe(true);
    expect(arCharacters.yumemin.greeting).toBeNull();
    expect(cameraUrl("yumemin")).toBe("/camera/yumemin");
    expect(modelUrl("yumemin")).toContain("yumemin.glb?v=clean-eyes-20260919");
    expect(arHeight("yumemin", "life")).toBe(.6);
    expect(arHeight("yumemin", "selfie")).toBe(.12);
  });
  for (const face of [false, true]) it(`writes ${face ? "face" : "plane"} anchoring and a valid aligned USDZ archive`, () => {
    const texture = new Uint8Array(137).map((_, i) => i);
    const output = anchorUSDZ(zipSync({ "model.usda": strToU8(source), "textures/skin.png": texture }, { level: 0 }), face);
    const files = unzipSync(output);
    const text = strFromU8(files["model.usda"]);
    expect(text).toContain('prepend apiSchemas = ["Preliminary_AnchoringAPI"]');
    expect(text).toContain(`anchoring:type = "${face ? "face" : "plane"}"`);
    expect(text.includes("planeAnchoring:alignment")).toBe(!face);
    expect(files["textures/skin.png"]).toEqual(texture);
    // Independently inspect ZIP local headers, as required by Apple's USDZ format.
    const view = new DataView(output.buffer, output.byteOffset, output.byteLength);
    let offset = 0, entries = 0;
    while (view.getUint32(offset, true) === 0x04034b50) {
      expect(view.getUint16(offset + 8, true)).toBe(0); // Stored, not compressed.
      const start = offset + 30 + view.getUint16(offset + 26, true) + view.getUint16(offset + 28, true);
      expect(start % 64).toBe(0);
      offset = start + view.getUint32(offset + 18, true);
      entries++;
    }
    expect(entries).toBe(2);
  });
  it("rejects an unknown exporter structure instead of silently emitting an unanchored selfie", () => {
    expect(() => anchorUSDZ(zipSync({ "model.usda": strToU8("unexpected") }), true)).toThrow();
  });
});
