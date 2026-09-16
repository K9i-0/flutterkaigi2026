import * as THREE from "three";

// Quick Look does not reliably display vertex-color materials. Bake the skin's
// vertex colors to a small padded triangle atlas, retaining their actual hues.
export function bakeARColors(mesh: THREE.Mesh<THREE.BufferGeometry, THREE.MeshStandardMaterial>) {
  const material = mesh.material;
  if (!material.vertexColors) return;
  if (!mesh.geometry.getAttribute("color")) return;
  // Mapped primitives in these assets carry white colors; the color-only skin
  // primitives require a texture for Quick Look's UsdPreviewSurface.
  if (material.map) {
    const colors = mesh.geometry.getAttribute("color");
    for (let i = 0; i < colors.count; i++) {
      if (Math.min(colors.getX(i), colors.getY(i), colors.getZ(i)) < 0.999) {
        throw new Error("このモデルの色はまだAR変換に対応していません。");
      }
    }
    material.vertexColors = false;
    return;
  }
  const atlas = createARColorAtlas(mesh.geometry, material.color);
  mesh.geometry.dispose();
  mesh.geometry = atlas.geometry;
  const canvas = document.createElement("canvas");
  canvas.width = atlas.width;
  canvas.height = atlas.height;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("画像を作成できませんでした。");
  const pixels = context.createImageData(atlas.width, atlas.height);
  pixels.data.set(atlas.pixels);
  context.putImageData(pixels, 0, 0);
  material.map = new THREE.CanvasTexture(canvas);
  material.map.channel = atlas.channel;
  material.map.colorSpace = THREE.SRGBColorSpace;
  material.color.set(0xffffff);
  material.vertexColors = false;
}

// Reserve a separate UV set for the color atlas. Existing UVs still drive the
// source normal/roughness/metalness maps; overwriting them causes patchy facets.
export function createARColorAtlas(old: THREE.BufferGeometry, tint: THREE.Color) {
  const channel = [1, 2, 3].find((id) => !old.getAttribute(`uv${id}`));
  if (channel === undefined) throw new Error("肌色用のUV座標を追加できませんでした。");
  const geometry = old.index ? old.toNonIndexed() : old.clone();
  const colors = geometry.getAttribute("color");
  const triangles = colors.count / 3;
  const tile = 8;
  const columns = Math.ceil(Math.sqrt(triangles));
  const width = columns * tile;
  const height = Math.ceil(triangles / columns) * tile;
  const pixels = new Uint8ClampedArray(width * height * 4);
  const uv = new Float32Array(colors.count * 2);
  const color = new THREE.Color();
  for (let t = 0; t < triangles; t++) {
    const x = (t % columns) * tile;
    const y = Math.floor(t / columns) * tile;
    for (let py = 0; py < tile; py++) for (let px = 0; px < tile; px++) {
      let b = Math.max(0, (px - 1) / 5);
      let c = Math.max(0, (py - 1) / 5);
      if (b + c > 1) { const sum = b + c; b /= sum; c /= sum; }
      const a = 1 - b - c;
      color.setRGB(
        a * colors.getX(t * 3) + b * colors.getX(t * 3 + 1) + c * colors.getX(t * 3 + 2),
        a * colors.getY(t * 3) + b * colors.getY(t * 3 + 1) + c * colors.getY(t * 3 + 2),
        a * colors.getZ(t * 3) + b * colors.getZ(t * 3 + 1) + c * colors.getZ(t * 3 + 2),
      ).multiply(tint).convertLinearToSRGB();
      const offset = ((y + py) * width + x + px) * 4;
      pixels.set([Math.round(color.r * 255), Math.round(color.g * 255), Math.round(color.b * 255), 255], offset);
    }
    [[1.5, 1.5], [6.5, 1.5], [1.5, 6.5]].forEach(([u, v], corner) => {
      uv[(t * 3 + corner) * 2] = (x + u) / width;
      uv[(t * 3 + corner) * 2 + 1] = 1 - (y + v) / height;
    });
  }
  geometry.setAttribute(`uv${channel}`, new THREE.BufferAttribute(uv, 2));
  return { geometry, channel, pixels, width, height };
}
