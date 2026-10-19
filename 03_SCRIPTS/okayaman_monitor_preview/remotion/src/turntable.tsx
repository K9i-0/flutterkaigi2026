import {useLayoutEffect, useMemo} from 'react';
import {AbsoluteFill, staticFile, useCurrentFrame} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader, useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import manifest from './edit-manifest.json';

export const rotationAtFrame = (frame: number): number => {
  const rotation = manifest.rotation;
  const fraction = Math.max(0, Math.min(1,
    (frame - rotation.startFrame) / (rotation.endFrameExclusive - rotation.startFrame),
  ));
  return rotation.startYawRadians + fraction * Math.PI * 2 * rotation.turns;
};

const FixedCamera = () => {
  const {camera} = useThree();
  useLayoutEffect(() => {
    if (!(camera instanceof THREE.OrthographicCamera)) {
      throw new Error('Turntable requires the manifest orthographic camera');
    }
    camera.position.fromArray(manifest.camera.position);
    camera.lookAt(new THREE.Vector3().fromArray(manifest.camera.target));
    camera.updateProjectionMatrix();
  }, [camera]);
  return null;
};

const Model = ({yaw}: {yaw: number}) => {
  const gltf = useLoader(GLTFLoader, staticFile(manifest.model));
  const {scene, offset} = useMemo(() => {
    // Clone the scene for presentation; the GLB geometry/materials are not edited.
    const scene = gltf.scene.clone(true);
    scene.traverse((object) => {
      if (object instanceof THREE.Mesh) {
        object.castShadow = true;
        object.receiveShadow = true;
        object.frustumCulled = false;
      }
    });
    scene.updateMatrixWorld(true);
    const box = new THREE.Box3().setFromObject(scene);
    const center = box.getCenter(new THREE.Vector3());
    return {scene, offset: new THREE.Vector3(-center.x, -box.min.y, -center.z)};
  }, [gltf]);

  // No delta accumulation, animation mixer, wall clock, or unseeded randomness.
  return <group rotation={[0, yaw, 0]}><primitive object={scene} position={offset}/></group>;
};

export const Turntable = () => {
  const frame = useCurrentFrame();
  const {width, height} = manifest.composition;
  return (
    <AbsoluteFill style={{backgroundColor: manifest.background}}>
      <ThreeCanvas
        width={width}
        height={height}
        dpr={1}
        orthographic
        shadows
        camera={{
          position: manifest.camera.position as [number, number, number],
          zoom: height / manifest.camera.verticalViewMeters,
          near: manifest.camera.near,
          far: manifest.camera.far,
        }}
        gl={{antialias: true, alpha: false}}
        onCreated={({gl}) => {
          gl.setClearColor(manifest.background);
          gl.outputColorSpace = THREE.SRGBColorSpace;
          gl.toneMapping = THREE.NoToneMapping;
          gl.toneMappingExposure = 1;
        }}
      >
        <color attach="background" args={[manifest.background]}/>
        <FixedCamera/>
        <ambientLight intensity={0.65}/>
        <hemisphereLight args={['#ffffff', '#cccccc', 0.8]}/>
        <directionalLight
          position={[-3, 4.5, 4]}
          intensity={2.6}
          castShadow
          shadow-mapSize={[2048, 2048]}
          shadow-camera-left={-2}
          shadow-camera-right={2}
          shadow-camera-top={3}
          shadow-camera-bottom={-1}
          shadow-camera-near={0.1}
          shadow-camera-far={12}
          shadow-bias={-0.00015}
          shadow-normalBias={0.015}
          shadow-radius={4}
        />
        <directionalLight position={[3, 2, 1]} intensity={0.8}/>
        <directionalLight position={[0, 3, -4]} intensity={1.0}/>
        <Model yaw={rotationAtFrame(frame)}/>
        <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -0.002, 0]} receiveShadow>
          <planeGeometry args={[200, 200]}/>
          <meshStandardMaterial color={manifest.background} roughness={1} metalness={0}/>
        </mesh>
      </ThreeCanvas>
    </AbsoluteFill>
  );
};
