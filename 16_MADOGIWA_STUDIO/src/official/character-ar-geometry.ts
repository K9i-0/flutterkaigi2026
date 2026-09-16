import * as THREE from "three";

// Match Three's morphnormal/skinnormal shaders rather than rebuilding normals
// from triangles: UV seams may duplicate vertices that share smooth normals.
export function freezeARGeometry(object: THREE.Mesh): THREE.BufferGeometry {
  const geometry = object.geometry.clone();
  const position = geometry.getAttribute("position");
  const sourceNormal = object.geometry.getAttribute("normal");
  const normals = new Float32Array(position.count * 3);
  const point = new THREE.Vector3();
  const normal = new THREE.Vector3();
  const morph = new THREE.Vector3();
  const worldNormal = new THREE.Matrix3().getNormalMatrix(object.matrixWorld);
  const bone = new THREE.Matrix4();
  const skin = new THREE.Matrix4();
  const skinNormal = new THREE.Matrix3();
  const morphNormals = object.geometry.morphAttributes.normal ?? [];
  const influences = object.morphTargetInfluences ?? [];
  const baseInfluence = object.geometry.morphTargetsRelative ? 1 : 1 - influences.reduce((sum, value) => sum + value, 0);
  for (let i = 0; i < position.count; i++) {
    object.getVertexPosition(i, point).applyMatrix4(object.matrixWorld);
    position.setXYZ(i, point.x, point.y, point.z);
    if (!sourceNormal) continue;
    normal.fromBufferAttribute(sourceNormal, i);
    if (morphNormals.length) {
      normal.multiplyScalar(baseInfluence);
      morphNormals.forEach((attribute, index) => {
        normal.addScaledVector(morph.fromBufferAttribute(attribute, i), influences[index] ?? 0);
      });
    }
    if (object instanceof THREE.SkinnedMesh) {
      const boneMatrices = object.skeleton.boneMatrices;
      if (!boneMatrices) throw new Error("モデルの骨格を取得できませんでした。");
      const indices = object.geometry.getAttribute("skinIndex");
      const weights = object.geometry.getAttribute("skinWeight");
      skin.elements.fill(0);
      for (let component = 0; component < 4; component++) {
        const weight = weights.getComponent(i, component);
        if (weight === 0) continue;
        bone.fromArray(boneMatrices, indices.getComponent(i, component) * 16);
        for (let entry = 0; entry < 16; entry++) skin.elements[entry] += weight * bone.elements[entry];
      }
      skin.premultiply(object.bindMatrixInverse).multiply(object.bindMatrix);
      normal.applyMatrix3(skinNormal.setFromMatrix4(skin));
    }
    normal.applyMatrix3(worldNormal).normalize().toArray(normals, i * 3);
  }
  geometry.deleteAttribute("skinIndex");
  geometry.deleteAttribute("skinWeight");
  // Tangents no longer describe the posed/world-space geometry; USDZ derives
  // its tangent frame from the preserved normals and UV coordinates.
  geometry.deleteAttribute("tangent");
  geometry.morphAttributes = {};
  if (sourceNormal) geometry.setAttribute("normal", new THREE.BufferAttribute(normals, 3));
  else geometry.computeVertexNormals();
  if (object.matrixWorld.determinant() < 0) reverseWinding(geometry);
  geometry.computeBoundingBox();
  geometry.computeBoundingSphere();
  return geometry;
}

function reverseWinding(geometry: THREE.BufferGeometry) {
  if (!geometry.index) geometry.setIndex(Array.from({ length: geometry.getAttribute("position").count }, (_, i) => i));
  const index = geometry.index!;
  for (let i = 0; i < index.count; i += 3) {
    const second = index.getX(i + 1);
    index.setX(i + 1, index.getX(i + 2));
    index.setX(i + 2, second);
  }
}

// Quick Look does not consistently honor double-sided materials. Explicit
// inward-facing triangles preserve thin cloth such as the hood's interior.
export function backfaceARGeometry(front: THREE.BufferGeometry): THREE.BufferGeometry {
  const back = front.clone();
  reverseWinding(back);
  const normal = back.getAttribute("normal");
  for (let i = 0; i < normal.count; i++) normal.setXYZ(i, -normal.getX(i), -normal.getY(i), -normal.getZ(i));
  return back;
}
