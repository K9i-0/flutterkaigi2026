import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { USDZExporter } from "three/addons/exporters/USDZExporter.js";
import { bakeARColors } from "./character-ar-colors";
import { backfaceARGeometry, freezeARGeometry } from "./character-ar-geometry";
import { anchorUSDZ } from "./character-ar-usdz";
import { arCharacters, arHeight, modelUrl, type ARCharacter, type ARPlacement } from "./character-ar-config";


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
    gltf.scene.traverse((object) => {
      if (!(object instanceof THREE.Mesh) || !object.visible) return;
      if (Array.isArray(object.material)) throw new Error("複数マテリアルの変換には未対応です。");
      const geometry = freezeARGeometry(object);
      const material = object.material.clone() as THREE.MeshStandardMaterial;
      material.side = THREE.FrontSide;
      const mesh = new THREE.Mesh(geometry, material);
      mesh.name = object.name;
      snapshot.add(mesh);
      bakeARColors(mesh);
      if (object.material.side === THREE.DoubleSide) {
        const back = new THREE.Mesh(backfaceARGeometry(mesh.geometry), material);
        back.name = `${object.name}_interior`;
        snapshot.add(back);
      }
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
      maxTextureSize: 4096,
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
