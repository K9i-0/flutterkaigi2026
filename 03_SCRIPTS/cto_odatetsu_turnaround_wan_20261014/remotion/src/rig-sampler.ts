import * as THREE from 'three';

/** Sample from the imported rest pose every time, including after a backwards seek. */
export const createRigSampler = (scene: THREE.Object3D, clips: THREE.AnimationClip[]) => {
  const mixer = new THREE.AnimationMixer(scene);
  const initial: Array<{
    node: THREE.Object3D;
    position: THREE.Vector3;
    quaternion: THREE.Quaternion;
    scale: THREE.Vector3;
    morphs?: number[];
  }> = [];
  scene.traverse((node) => {
    const mesh = node as THREE.Mesh;
    initial.push({node, position: node.position.clone(), quaternion: node.quaternion.clone(),
      scale: node.scale.clone(), morphs: mesh.morphTargetInfluences?.slice()});
  });
  const clipByName = new Map(clips.map((clip) => [clip.name, clip]));
  return {
    sample(name: string, frame: number, fps: number) {
      const clip = clipByName.get(name);
      if (!clip) throw new Error(`Missing animation clip: ${name}`);
      if (!(fps > 0) || !Number.isFinite(frame)) throw new Error('Invalid frame/fps');
      mixer.stopAllAction();
      for (const pose of initial) {
        pose.node.position.copy(pose.position);
        pose.node.quaternion.copy(pose.quaternion);
        pose.node.scale.copy(pose.scale);
        if (pose.morphs) (pose.node as THREE.Mesh).morphTargetInfluences = pose.morphs.slice();
        pose.node.updateMatrix();
      }
      const action = mixer.clipAction(clip);
      action.reset().setEffectiveTimeScale(1).setEffectiveWeight(1)
        .setLoop(THREE.LoopRepeat, Infinity).play();
      const seconds = Math.max(0, frame) / fps;
      mixer.setTime(clip.duration > 0 ? seconds % clip.duration : 0);
      scene.updateMatrixWorld(true);
      scene.traverse((node) => {
        if (node instanceof THREE.SkinnedMesh) node.skeleton.update();
      });
    },
    dispose() {
      mixer.stopAllAction();
      mixer.uncacheRoot(scene);
    },
  };
};
