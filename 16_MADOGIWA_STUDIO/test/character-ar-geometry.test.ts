import { describe, expect, it } from "vitest";
import * as THREE from "three";
import { backfaceARGeometry, freezeARGeometry } from "../src/official/character-ar-geometry";

function triangle() {
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute("position", new THREE.Float32BufferAttribute([0, 0, 0, 1, 0, 0, 0, 1, 0], 3));
  // Authored smooth normals intentionally differ from this triangle's face.
  geometry.setAttribute("normal", new THREE.Float32BufferAttribute([0, .6, .8, 0, .6, .8, 0, .6, .8], 3));
  geometry.setAttribute("uv", new THREE.Float32BufferAttribute([0, 0, 1, 0, 0, 1], 2));
  return geometry;
}
describe("AR surface fidelity", () => {
  it("preserves authored smooth normals through a posed skeleton and world transform", () => {
    const geometry = triangle();
    geometry.setAttribute("skinIndex", new THREE.Uint16BufferAttribute([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0], 4));
    geometry.setAttribute("skinWeight", new THREE.Float32BufferAttribute([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], 4));
    const mesh = new THREE.SkinnedMesh(geometry, new THREE.MeshStandardMaterial());
    const bone = new THREE.Bone();
    mesh.add(bone);
    mesh.bind(new THREE.Skeleton([bone]));
    bone.rotation.z = Math.PI / 2;
    mesh.rotation.y = Math.PI / 2;
    mesh.scale.set(2, 1, 3);
    mesh.updateMatrixWorld(true);
    mesh.skeleton.update();
    const frozen = freezeARGeometry(mesh);
    const expected = new THREE.Vector3(-.6, 0, .8).applyMatrix3(new THREE.Matrix3().getNormalMatrix(mesh.matrixWorld)).normalize();
    const actual = new THREE.Vector3().fromBufferAttribute(frozen.getAttribute("normal"), 0);
    expect(actual.distanceTo(expected)).toBeLessThan(1e-6);
    const expectedPoint = mesh.getVertexPosition(1, new THREE.Vector3()).applyMatrix4(mesh.matrixWorld);
    expect(new THREE.Vector3().fromBufferAttribute(frozen.getAttribute("position"), 1).distanceTo(expectedPoint)).toBeLessThan(1e-6);
    expect(frozen.getAttribute("skinIndex")).toBeUndefined();
    expect(geometry.getAttribute("normal").getY(0)).toBeCloseTo(.6);
  });
  it("bakes relative morph normals without recomputing faceted normals", () => {
    const geometry = triangle();
    geometry.morphTargetsRelative = true;
    geometry.morphAttributes.normal = [new THREE.Float32BufferAttribute([.2, 0, 0, .2, 0, 0, .2, 0, 0], 3)];
    const mesh = new THREE.Mesh(geometry);
    mesh.morphTargetInfluences = [.5];
    const frozen = freezeARGeometry(mesh);
    const expected = new THREE.Vector3(.1, .6, .8).normalize();
    expect(new THREE.Vector3().fromBufferAttribute(frozen.getAttribute("normal"), 0).distanceTo(expected)).toBeLessThan(1e-6);
  });
  it("provides inward-facing triangles with the same UVs without changing the outer surface", () => {
    const front = triangle();
    const back = backfaceARGeometry(front);
    expect([...back.index!.array]).toEqual([0, 2, 1]);
    expect(back.getAttribute("position").array).toEqual(front.getAttribute("position").array);
    expect(back.getAttribute("uv").array).toEqual(front.getAttribute("uv").array);
    expect(back.getAttribute("normal").getZ(0)).toBeCloseTo(-.8);
    expect(front.index).toBeNull();
    expect(front.getAttribute("normal").getZ(0)).toBeCloseTo(.8);
  });
});
