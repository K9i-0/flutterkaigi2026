import {useEffect, useLayoutEffect, useMemo} from 'react';
import {AbsoluteFill, staticFile, useCurrentFrame} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader, useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import {createCameraEquipment, type Attachment} from './camera-equipment';
import manifest from './camera-manifest.json';

type View = keyof typeof manifest.views;
const FixedCamera = ({view}: {view: View}) => {
  const {camera} = useThree();
  useLayoutEffect(() => {
    const settings = manifest.views[view];
    camera.position.fromArray(settings.position);
    camera.lookAt(new THREE.Vector3().fromArray(settings.target));
    camera.zoom = manifest.composition.height / settings.verticalViewMeters;
    camera.updateProjectionMatrix();
  }, [camera, view]);
  return null;
};

const EquippedCharacter = ({clip, frame}: {clip: string; frame: number}) => {
  const character = useLoader(GLTFLoader, staticFile(manifest.character));
  const camera = useLoader(GLTFLoader, staticFile(manifest.cameraProp));
  const attachmentText = useLoader(THREE.FileLoader, staticFile(manifest.attachment));
  const equipment = useMemo(() => {
    const attachment = JSON.parse(String(attachmentText)) as Attachment;
    const result = createCameraEquipment(clone(character.scene), character.animations, clone(camera.scene), attachment);
    let boneCount = 0;
    result.group.traverse((object) => {
      if (object instanceof THREE.Bone) boneCount++;
      if (object instanceof THREE.Mesh) {
        object.castShadow = true; object.receiveShadow = true; object.frustumCulled = false;
      }
    });
    if (boneCount !== manifest.expectedBones || character.animations.length !== manifest.expectedClipCount) {
      throw new Error(`Unexpected equipped rig: ${boneCount} bones / ${character.animations.length} clips`);
    }
    return result;
  }, [character, camera, attachmentText]);
  useLayoutEffect(() => equipment.sample(clip, frame, manifest.composition.fps, true, true), [equipment, clip, frame]);
  useEffect(() => () => equipment.dispose(), [equipment]);
  return <primitive object={equipment.group}/>;
};

export const CameraEquipmentPreview = () => {
  const frame = useCurrentFrame();
  const segment = manifest.segments.find((item) => frame >= item.startFrame && frame < item.endFrameExclusive);
  if (!segment) throw new Error(`No camera preview segment at ${frame}`);
  const {width, height} = manifest.composition;
  return <AbsoluteFill style={{backgroundColor: manifest.background}}>
    <ThreeCanvas width={width} height={height} dpr={1} orthographic shadows
      camera={{position: [2.3, 1.4, 5], zoom: height / 2.65, near: .05, far: 30}}
      gl={{antialias: true, alpha: false}}
      onCreated={({gl}) => {
        gl.setClearColor(manifest.background); gl.outputColorSpace = THREE.SRGBColorSpace;
        gl.toneMapping = THREE.ACESFilmicToneMapping; gl.toneMappingExposure = 1;
      }}>
      <color attach="background" args={[manifest.background]}/>
      <FixedCamera view={segment.view as View}/>
      <ambientLight intensity={.65}/>
      <hemisphereLight args={['#ffffff', '#cccccc', .8]}/>
      <directionalLight position={[-3, 4.5, 4]} intensity={2.6} castShadow
        shadow-mapSize={[2048, 2048]} shadow-camera-left={-2} shadow-camera-right={2}
        shadow-camera-top={3} shadow-camera-bottom={-1} shadow-camera-near={.1}
        shadow-camera-far={12} shadow-bias={-.00015} shadow-normalBias={.015} shadow-radius={4}/>
      <directionalLight position={[3, 2, 1]} intensity={.8}/>
      <directionalLight position={[0, 3, -4]} intensity={1}/>
      <EquippedCharacter clip={segment.clip} frame={frame - segment.startFrame}/>
      <mesh rotation={[-Math.PI / 2, 0, 0]} position={[0, -.002, 0]} receiveShadow>
        <planeGeometry args={[200, 200]}/><meshStandardMaterial color={manifest.background} roughness={1}/>
      </mesh>
    </ThreeCanvas>
    <div style={{position: 'absolute', top: 58, width: '100%', textAlign: 'center',
      fontFamily: 'Arial, sans-serif', fontSize: 28, fontWeight: 600, color: '#333'}}>CTOおだてつ</div>
    <div style={{position: 'absolute', bottom: 64, width: '100%', textAlign: 'center',
      fontFamily: 'Arial, sans-serif', fontSize: 27, fontWeight: 600, color: '#333'}}>
      <span style={{display: 'inline-block', padding: '10px 18px', borderRadius: 8,
        backgroundColor: 'rgba(230,230,230,0.96)'}}>{segment.label}</span>
    </div>
  </AbsoluteFill>;
};
