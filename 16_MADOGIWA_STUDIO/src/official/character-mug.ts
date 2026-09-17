import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";

export const mugUrl = "/models/props/beer_mug.glb?v=2-20260917";

export function setMugGrip(root: THREE.Object3D, enabled: boolean) {
  root.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    const index = object.morphTargetDictionary?.MugGrip;
    if (index !== undefined && object.morphTargetInfluences) object.morphTargetInfluences[index] = enabled ? 1 : 0;
  });
}

/** Attach the authored Grip anchor to the right-hand socket in glTF coordinates. */
export function mountMug(root: THREE.Object3D, mug: THREE.Group) {
  const socket = root.getObjectByName("PropSocketR") ?? root.getObjectByName("PropSocket.R");
  const grip = mug.getObjectByName("Grip");
  if (!socket || !grip) throw new Error("ジョッキの持ち手を配置できませんでした。");
  mug.updateMatrixWorld(true);
  const attachment = grip.matrixWorld.clone().invert().multiply(mug.matrixWorld);
  socket.add(mug);
  attachment.decompose(mug.position, mug.quaternion, mug.scale);
  // Quick Look has no transmission shader. The same light glass approximation
  // keeps beer visible in the viewer and the exported photo prop.
  mug.traverse((object) => {
    if (!(object instanceof THREE.Mesh)) return;
    for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
      if (!(material instanceof THREE.MeshPhysicalMaterial)) continue;
      if (material.transmission > 0) {
        material.transmission = 0;
        if (object.name === "GlassBody" || object.name === "Handle") {
          material.transparent = true;
          material.opacity = .22;
          material.depthWrite = false;
        } else {
          material.transparent = false; material.opacity = 1;
          material.color.set(0xd99022); material.roughness = .25;
        }
      }
    }
  });
  root.updateMatrixWorld(true);
  return mug;
}

export async function loadMug(signal: AbortSignal) {
  const response = await fetch(mugUrl, { signal });
  if (!response.ok) throw new Error("ジョッキを読み込めませんでした。");
  const data = await response.arrayBuffer();
  signal.throwIfAborted();
  return (await new GLTFLoader().parseAsync(data, "")).scene;
}
