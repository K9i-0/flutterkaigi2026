import { describe, expect, it } from "vitest";
import * as THREE from "three";
import { mountMug, setMugGrip } from "../src/official/character-mug";
import { freezeARGeometry } from "../src/official/character-ar-geometry";

describe("Sobaya's mug in the viewer and AR", () => {
  it("keeps the Grip on a moving hand socket and bakes that world position", () => {
    const root = new THREE.Group(), socket = new THREE.Bone(), mug = new THREE.Group(), grip = new THREE.Object3D();
    socket.name = "PropSocketR"; root.add(socket);
    mug.position.set(.3, .1, -.2); grip.name = "Grip"; grip.position.set(.12, .1, 0); mug.add(grip);
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(.1,.2,.1), new THREE.MeshPhysicalMaterial({ transmission: 1 }));
    mesh.name = "GlassBody"; mug.add(mesh);
    mountMug(root, mug);
    for (const angle of [0, .4, 1.3]) {
      socket.position.set(.2, 1.3, .4); socket.rotation.set(angle, .3, -.2); root.updateMatrixWorld(true);
      expect(grip.getWorldPosition(new THREE.Vector3()).distanceTo(socket.getWorldPosition(new THREE.Vector3()))).toBeLessThan(1e-7);
      const frozen = freezeARGeometry(mesh);
      const expected = new THREE.Vector3().fromBufferAttribute(mesh.geometry.attributes.position, 0).applyMatrix4(mesh.matrixWorld);
      expect(new THREE.Vector3().fromBufferAttribute(frozen.attributes.position, 0).distanceTo(expected)).toBeLessThan(1e-6);
      frozen.dispose();
    }
    expect(mesh.material.opacity).toBe(.22);
    expect(mesh.material.transmission).toBe(0);
  });
  it("releases the grip when hidden without changing facial morphs", () => {
    const root = new THREE.Group(), mesh = new THREE.Mesh(); root.add(mesh);
    mesh.morphTargetDictionary = { mouthOpen: 0, MugGrip: 1 }; mesh.morphTargetInfluences = [.4, 0];
    setMugGrip(root, true); expect(mesh.morphTargetInfluences).toEqual([.4, 1]);
    setMugGrip(root, false); expect(mesh.morphTargetInfluences).toEqual([.4, 0]);
  });
});
