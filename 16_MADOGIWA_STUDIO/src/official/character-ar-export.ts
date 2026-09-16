import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { USDZExporter } from "three/addons/exporters/USDZExporter.js";
import { anchorUSDZ } from "./character-ar-usdz";
import { arCharacters, arHeight, modelUrl, type ARCharacter, type ARPlacement } from "./character-ar-config";

// Quick Look does not reliably display vertex-color materials. Bake the skin's
// vertex colors to a small padded triangle atlas, retaining their actual hues.
function bakeColors(mesh: THREE.Mesh<THREE.BufferGeometry, THREE.MeshStandardMaterial>) {
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
  const old = mesh.geometry;
  const geometry = old.index ? old.toNonIndexed() : old.clone();
  old.dispose();
  mesh.geometry = geometry;
  const colors = geometry.getAttribute("color");
  const triangles = colors.count / 3;
  const tile = 8;
  const columns = Math.ceil(Math.sqrt(triangles));
  const canvas = document.createElement("canvas");
  canvas.width = columns * tile;
  canvas.height = Math.ceil(triangles / columns) * tile;
  const context = canvas.getContext("2d");
  if (!context) throw new Error("画像を作成できませんでした。");
  const pixels = context.createImageData(canvas.width, canvas.height);
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
      ).multiply(material.color).convertLinearToSRGB();
      const offset = ((y + py) * canvas.width + x + px) * 4;
      pixels.data.set([Math.round(color.r * 255), Math.round(color.g * 255), Math.round(color.b * 255), 255], offset);
    }
    [[1.5, 1.5], [6.5, 1.5], [1.5, 6.5]].forEach(([u, v], corner) => {
      uv[(t * 3 + corner) * 2] = (x + u) / canvas.width;
      uv[(t * 3 + corner) * 2 + 1] = 1 - (y + v) / canvas.height;
    });
  }
  context.putImageData(pixels, 0, 0);
  geometry.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  material.map = new THREE.CanvasTexture(canvas);
  material.map.colorSpace = THREE.SRGBColorSpace;
  material.color.set(0xffffff);
  material.vertexColors = false;
}

function dispose(root: THREE.Object3D) {
  const textures = new Set<THREE.Texture>();
  const geometries = new Set<THREE.BufferGeometry>();
  const materials = new Set<THREE.Material>();
  root.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    geometries.add(object.geometry);
    for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
      materials.add(material);
      for (const value of Object.values(material)) if (value instanceof THREE.Texture) textures.add(value);
    }
    if (object instanceof THREE.SkinnedMesh) object.skeleton.dispose();
  });
  geometries.forEach((geometry) => geometry.dispose());
  materials.forEach((material) => material.dispose());
  textures.forEach((texture) => {
    if (typeof ImageBitmap !== "undefined" && texture.source.data instanceof ImageBitmap) texture.source.data.close();
    texture.dispose();
  });
}

export async function createARAsset(character: ARCharacter, placement: ARPlacement, pose: "Idle" | "Wave", signal: AbortSignal): Promise<Blob> {
  const response = await fetch(modelUrl(character), { signal });
  if (!response.ok) throw new Error("モデルを読み込めませんでした。");
  const data = await response.arrayBuffer();
  signal.throwIfAborted();
  const gltf = await new GLTFLoader().parseAsync(data, "");
  const snapshot = new THREE.Scene();
  let mixer: THREE.AnimationMixer | undefined;
  try {
    signal.throwIfAborted();
    gltf.scene.updateMatrixWorld(true);
    const restBox = new THREE.Box3().setFromObject(gltf.scene);
    const restHeight = restBox.max.y - restBox.min.y;
    const clipName = pose === "Wave" ? arCharacters[character].greeting : "Idle";
    const clip = gltf.animations.find((clip) => clip.name === clipName);
    if (!clip) throw new Error("このポーズはまだ利用できません。");
    mixer = new THREE.AnimationMixer(gltf.scene);
    mixer.clipAction(clip).play();
    mixer.setTime(pose === "Wave" ? 0.8 : 0);
    gltf.scene.updateMatrixWorld(true);
    gltf.scene.traverse((object) => { if (object instanceof THREE.SkinnedMesh) object.skeleton.update(); });
    // USDZExporter doesn't bake skinning. Freeze evaluated vertices into static
    // meshes so arms, morphs and the character's pose survive the conversion.
    const point = new THREE.Vector3();
    gltf.scene.traverse((object) => {
      if (!(object instanceof THREE.Mesh) || !object.visible) return;
      if (Array.isArray(object.material)) throw new Error("複数マテリアルの変換には未対応です。");
      const geometry = object.geometry.clone();
      const position = geometry.getAttribute("position");
      for (let i = 0; i < position.count; i++) {
        object.getVertexPosition(i, point).applyMatrix4(object.matrixWorld);
        position.setXYZ(i, point.x, point.y, point.z);
      }
      geometry.deleteAttribute("skinIndex");
      geometry.deleteAttribute("skinWeight");
      geometry.morphAttributes = {};
      geometry.computeVertexNormals();
      geometry.computeBoundingBox();
      geometry.computeBoundingSphere();
      const material = object.material.clone() as THREE.MeshStandardMaterial;
      material.side = THREE.FrontSide;
      const mesh = new THREE.Mesh(geometry, material);
      mesh.name = object.name;
      snapshot.add(mesh);
      bakeColors(mesh);
    });
    const box = new THREE.Box3().setFromObject(snapshot);
    const height = restHeight;
    if (!Number.isFinite(height) || height <= 0) throw new Error("モデルの寸法を取得できませんでした。");
    const scale = arHeight(character, placement) / height;
    const center = box.getCenter(new THREE.Vector3());
    snapshot.traverse((object) => {
      if (!(object instanceof THREE.Mesh)) return;
      object.geometry.translate(-center.x, -box.min.y, -center.z);
      object.geometry.scale(scale, scale, scale);
      // Face-local position: a 12 cm friend beside the cheek, not a tracked shoulder.
      if (placement === "selfie") object.geometry.translate(0.19, -0.08, 0.025);
    });
    signal.throwIfAborted();
    const output = await new USDZExporter().parseAsync(snapshot, {
      quickLookCompatible: true,
      maxTextureSize: 2048,
      ar: { anchoring: { type: "plane" }, planeAnchoring: { alignment: "horizontal" } },
    });
    signal.throwIfAborted();
    return new Blob([anchorUSDZ(output, placement === "selfie")], { type: "model/vnd.usdz+zip" });
  } finally {
    mixer?.stopAllAction();
    mixer?.uncacheRoot(gltf.scene);
    dispose(snapshot);
    dispose(gltf.scene);
  }
}
