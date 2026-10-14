import {useEffect, useLayoutEffect, useMemo} from 'react';
import {AbsoluteFill, staticFile, useCurrentFrame} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader, useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import {createRigSampler} from './rig-sampler';
import manifest from './rig-manifest.json';

const FixedCamera = () => {
  const {camera} = useThree();
  useLayoutEffect(() => {
    camera.position.fromArray(manifest.camera.position);
    camera.lookAt(new THREE.Vector3().fromArray(manifest.camera.target));
    camera.updateProjectionMatrix();
  }, [camera]);
  return null;
};

const RigModel = ({clip, frame}: {clip: string; frame: number}) => {
  const gltf = useLoader(GLTFLoader, staticFile(manifest.model));
  const {scene, sampler} = useMemo(() => {
    const scene = clone(gltf.scene);
    let boneCount = 0;
    scene.traverse((object) => {
      if (object instanceof THREE.Bone) boneCount++;
      if (object instanceof THREE.Mesh) {
        object.castShadow = true;
        object.receiveShadow = true;
        object.frustumCulled = false;
      }
    });
    if (boneCount !== manifest.expectedBones || gltf.animations.length !== manifest.expectedClipCount) {
      throw new Error(`Unexpected rig: ${boneCount} bones / ${gltf.animations.length} clips`);
    }
    for (const segment of manifest.segments) {
      if (!gltf.animations.some((animation) => animation.name === segment.clip)) {
        throw new Error(`Required animation not embedded: ${segment.clip}`);
      }
    }
    return {scene, sampler: createRigSampler(scene, gltf.animations)};
  }, [gltf]);
  useLayoutEffect(() => {
    sampler.sample(clip, frame, manifest.composition.fps);
  }, [sampler, clip, frame]);
  useEffect(() => () => sampler.dispose(), [sampler]);
  return <primitive object={scene}/>;
};

export const RigMotionPreview = () => {
  const frame = useCurrentFrame();
  const segment = manifest.segments.find((item) => frame >= item.startFrame && frame < item.endFrameExclusive);
  if (!segment) throw new Error(`No rig preview segment at frame ${frame}`);
  const {width, height} = manifest.composition;
  return (
    <AbsoluteFill style={{backgroundColor: manifest.background}}>
      <ThreeCanvas
        width={width} height={height} dpr={1} orthographic shadows
        camera={{position: manifest.camera.position as [number, number, number],
          zoom: height / manifest.camera.verticalViewMeters,
          near: manifest.camera.near, far: manifest.camera.far}}
        gl={{antialias: true, alpha: false}}
        onCreated={({gl}) => {
          gl.setClearColor(manifest.background);
          gl.outputColorSpace = THREE.SRGBColorSpace;
          gl.toneMapping = THREE.ACESFilmicToneMapping;
          gl.toneMappingExposure = 1;
        }}>
        <color attach="background" args={[manifest.background]}/>
        <FixedCamera/>
        <ambientLight intensity={0.65}/>
        <hemisphereLight args={['#ffffff', '#cccccc', 0.8]}/>
        <directionalLight position={[-3, 4.5, 4]} intensity={2.6} castShadow
          shadow-mapSize={[2048, 2048]} shadow-camera-left={-2} shadow-camera-right={2}
          shadow-camera-top={3} shadow-camera-bottom={-1} shadow-camera-near={0.1}
          shadow-camera-far={12} shadow-bias={-0.00015} shadow-normalBias={0.015} shadow-radius={4}/>
        <directionalLight position={[3, 2, 1]} intensity={0.8}/>
        <directionalLight position={[0, 3, -4]} intensity={1}/>
        <RigModel clip={segment.clip} frame={frame - segment.startFrame}/>
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.002, 0]} receiveShadow>
          <planeGeometry args={[200, 200]}/>
          <meshStandardMaterial color={manifest.background} roughness={1} metalness={0}/>
        </mesh>
      </ThreeCanvas>
      <div style={{position: 'absolute', bottom: 64, width: '100%', textAlign: 'center',
        fontFamily: 'Arial, sans-serif', fontSize: 32, fontWeight: 600, color: '#333',
        letterSpacing: 0.5}}>{segment.clip}</div>
    </AbsoluteFill>
  );
};
