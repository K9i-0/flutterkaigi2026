import * as THREE from 'three';
import {createRigSampler} from './rig-sampler';

export type Attachment = {
  socket: string;
  threeSocketName: string;
  cameraGripNode: string;
  socketToGrip: number[];
  rightGripPose: Array<{node: string; quaternion: number[]}>;
  strapAnchors?: [string, string];
};

const findNode = (root: THREE.Object3D, name: string) => {
  const sanitized = THREE.PropertyBinding.sanitizeNodeName(name);
  let result: THREE.Object3D | undefined;
  root.traverse((node) => {
    if (node.name === name || node.name === sanitized || node.userData.name === name) result = node;
  });
  if (!result) throw new Error(`Equipment node missing: ${name}`);
  return result;
};

const strapTexture = () => {
  if (typeof document === 'undefined') return undefined;
  const canvas = document.createElement('canvas');
  canvas.width = 2048; canvas.height = 128;
  const context = canvas.getContext('2d')!;
  context.fillStyle = '#161616'; context.fillRect(0, 0, canvas.width, canvas.height);
  context.fillStyle = '#eeeeec'; context.font = 'bold 78px Arial';
  context.textAlign = 'center'; context.textBaseline = 'middle';
  context.fillText('ODATETSU', 610, 64);
  context.fillText('ODATETSU', 1460, 64);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace; texture.anisotropy = 8;
  return texture;
};

/** Stateless hanging ribbon. Gravity is evaluated in world space after hand attachment. */
const createStrap = (root: THREE.Group, camera: THREE.Object3D, names: [string, string]) => {
  const anchors = names.map((name) => findNode(camera, name));
  const segments = 64;
  const positions = new Float32Array((segments + 1) * 6);
  const uvs = new Float32Array((segments + 1) * 4);
  const indices: number[] = [];
  for (let i = 0; i <= segments; i++) {
    uvs.set([i / segments, 0, i / segments, 1], i * 4);
    if (i < segments) indices.push(i*2, i*2+1, i*2+2, i*2+1, i*2+3, i*2+2);
  }
  const geometry = new THREE.BufferGeometry();
  geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
  geometry.setAttribute('uv', new THREE.BufferAttribute(uvs, 2));
  geometry.setIndex(indices);
  const texture = strapTexture();
  const material = new THREE.MeshStandardMaterial({color: texture ? '#ffffff' : '#161616',
    ...(texture ? {map: texture} : {}), roughness: .95, metalness: 0, side: THREE.DoubleSide});
  const mesh = new THREE.Mesh(geometry, material);
  mesh.name = 'OdatetsuHangingStrap'; mesh.frustumCulled = false;
  mesh.castShadow = true; mesh.receiveShadow = true; root.add(mesh);
  const down = new THREE.Vector3(0, -1, 0);
  return {
    mesh,
    update() {
      const [a, b] = anchors.map((node) => node.getWorldPosition(new THREE.Vector3()));
      const middle = a.clone().add(b).multiplyScalar(.5);
      // Hang on the outer side of the hand. No velocity/history or cloth simulation.
      const outward = new THREE.Vector3(middle.x >= 0 ? 1 : -1, 0, .15).normalize();
      const drop = Math.max(.10, Math.min(.49, middle.y - .04));
      const curve = new THREE.CatmullRomCurve3([
        a, a.clone().addScaledVector(down, drop * .38).addScaledVector(outward, .055),
        middle.clone().addScaledVector(down, drop).addScaledVector(outward, .11),
        b.clone().addScaledVector(down, drop * .38).addScaledVector(outward, .055), b,
      ], false, 'centripetal');
      const planeNormal = new THREE.Vector3(0, 0, 1);
      const inverse = root.matrixWorld.clone().invert();
      for (let i = 0; i <= segments; i++) {
        const t = i / segments;
        const center = curve.getPoint(t);
        const across = curve.getTangent(t).cross(planeNormal).normalize().multiplyScalar(.011);
        center.clone().sub(across).applyMatrix4(inverse).toArray(positions, i * 6);
        center.clone().add(across).applyMatrix4(inverse).toArray(positions, i * 6 + 3);
      }
      geometry.attributes.position.needsUpdate = true;
      geometry.computeVertexNormals(); geometry.computeBoundingSphere();
    },
    dispose() {geometry.dispose(); material.dispose(); texture?.dispose();},
  };
};

/** Shared by the browser and Remotion: sample -> optional grip -> socket -> strap. */
export const createCameraEquipment = (
  character: THREE.Object3D, clips: THREE.AnimationClip[], camera: THREE.Object3D,
  attachment: Attachment,
) => {
  const group = new THREE.Group(); group.name = 'OdatetsuCameraEquipment';
  group.add(character, camera);
  group.updateMatrixWorld(true);
  const sampler = createRigSampler(character, clips);
  const socket = findNode(character, attachment.socket || attachment.threeSocketName);
  const grip = findNode(camera, attachment.cameraGripNode);
  const inverseGrip = camera.matrixWorld.clone().invert().multiply(grip.matrixWorld).invert();
  const socketToGrip = new THREE.Matrix4().fromArray(attachment.socketToGrip);
  const fingers = attachment.rightGripPose.map((pose) => ({
    node: findNode(character, pose.node), quaternion: new THREE.Quaternion().fromArray(pose.quaternion),
  }));
  const strap = createStrap(group, camera, attachment.strapAnchors ?? ['StrapAnchorLeft', 'StrapAnchorRight']);
  camera.matrixAutoUpdate = false;
  return {
    group, character, camera, socket, grip, strap: strap.mesh,
    sample(clip: string, frame: number, fps: number, equipped = true, showStrap = true) {
      // Sampling always restores original clip fingers, so ON -> OFF has no residue.
      sampler.sample(clip, frame, fps);
      if (equipped) for (const pose of fingers) pose.node.quaternion.copy(pose.quaternion);
      group.updateMatrixWorld(true);
      character.traverse((node) => {if (node instanceof THREE.SkinnedMesh) node.skeleton.update();});
      camera.visible = equipped; strap.mesh.visible = equipped && showStrap;
      camera.matrix.copy(group.matrixWorld.clone().invert().multiply(socket.matrixWorld)
        .multiply(socketToGrip).multiply(inverseGrip));
      camera.updateMatrixWorld(true);
      if (equipped && showStrap) strap.update();
      group.updateMatrixWorld(true);
    },
    snapshot() {
      const bones: Array<{name: string; matrix: number[]}> = [];
      character.traverse((node) => {if (node instanceof THREE.Bone) bones.push({name: node.name, matrix: node.matrixWorld.toArray()});});
      const desired = socket.matrixWorld.clone().multiply(socketToGrip);
      const actual = grip.matrixWorld;
      return {bones, cameraMatrix: camera.matrixWorld.toArray(),
        gripError: Math.max(...actual.elements.map((value, i) => Math.abs(value - desired.elements[i]))),
        equipped: camera.visible, strap: strap.mesh.visible};
    },
    dispose() {sampler.dispose(); strap.dispose();},
  };
};
