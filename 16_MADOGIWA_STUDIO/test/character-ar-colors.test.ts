import { afterEach, describe, expect, it, vi } from "vitest";
import * as THREE from "three";
import { bakeARColors, createARColorAtlas } from "../src/official/character-ar-colors";

function skin() {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0], 3));
  geometry.setAttribute("uv", new THREE.Float32BufferAttribute([.2, .3, .4, .5, .6, .7], 2));
  geometry.setAttribute("color", new THREE.Float32BufferAttribute([1, 0, 0, 0, 1, 0, 0, 0, 1], 3));
  geometry.setIndex([0, 1, 2]);
  return geometry;
}
afterEach(() => vi.unstubAllGlobals());
describe("AR skin color conversion", () => {
  it("keeps source roughness and metallic UVs while giving the new color map its own UV set", () => {
    vi.stubGlobal("document", { createElement: () => ({
      width: 0, height: 0,
      getContext: () => ({
        createImageData: (width: number, height: number) => ({ data: new Uint8ClampedArray(width * height * 4) }),
        putImageData: () => {},
      }),
    }) });
    const geometry = skin();
    const originalUV = [...geometry.getAttribute("uv").array];
    const packed = new THREE.Texture();
    const material = new THREE.MeshStandardMaterial({ vertexColors: true, roughnessMap: packed, metalnessMap: packed });
    const mesh = new THREE.Mesh(geometry, material);
    bakeARColors(mesh);
    expect([...mesh.geometry.getAttribute("uv").array]).toEqual(originalUV);
    expect(material.map!.channel).toBe(1);
    expect(material.roughnessMap).toBe(packed);
    expect(material.metalnessMap).toBe(packed);
    expect(packed.channel).toBe(0);
    expect(mesh.geometry.getAttribute("uv1")).toBeDefined();
    expect(material.vertexColors).toBe(false);
  });
  it("retains existing secondary UVs and samples each authored vertex color at its own atlas corner", () => {
    const geometry = skin();
    geometry.setAttribute("uv1", geometry.getAttribute("uv").clone());
    const result = createARColorAtlas(geometry, new THREE.Color(0xffffff));
    expect(result.channel).toBe(2);
    expect(result.geometry.getAttribute("uv1").array).toEqual(geometry.getAttribute("uv1").array);
    const uv = result.geometry.getAttribute("uv2");
    const colors = [[255, 0, 0, 255], [0, 255, 0, 255], [0, 0, 255, 255]];
    for (let i = 0; i < 3; i++) {
      const x = Math.floor(uv.getX(i) * result.width);
      const y = Math.floor((1 - uv.getY(i)) * result.height);
      const offset = (y * result.width + x) * 4;
      expect([...result.pixels.slice(offset, offset + 4)]).toEqual(colors[i]);
    }
  });
});
