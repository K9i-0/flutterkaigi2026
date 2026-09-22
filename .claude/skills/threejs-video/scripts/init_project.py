"""Create a non-overwriting, local 8-second stage/motion study."""
import argparse, json, os, shutil
from pathlib import Path
from prepare_assets import prepare
ROOT=Path(__file__).resolve().parents[4]
p=argparse.ArgumentParser();p.add_argument('project',type=Path);args=p.parse_args()
target=args.project.resolve()
if target.exists():raise SystemExit('Refusing to overwrite existing project: '+str(target))
if not target.is_relative_to(ROOT):raise SystemExit('Create the project inside this repository')
source=ROOT/'03_SCRIPTS/74_yhk_jungle_available/remotion'
package=json.loads((source/'package.json').read_text())
package['name']='threejs-stage-video'
package['scripts']={'typecheck':'tsc --noEmit','studio':'remotion studio src/index.tsx','render':'remotion render src/index.tsx StageStudy out/stage-study.mp4 --gl=angle --concurrency=2 --codec=h264'}
lock=json.loads((source/'package-lock.json').read_text());lock['name']=package['name'];lock['packages']['']['name']=package['name']
(target/'src').mkdir(parents=True)
def write(name,data): (target/name).write_text(data)
write('package.json',json.dumps(package,indent=2)+'\n');write('package-lock.json',json.dumps(lock,indent=2)+'\n')
write('.gitignore','node_modules/\nout/\npublic/models/\npublic/backgrounds/\npublic/audio/\n')
write('tsconfig.json',json.dumps({'compilerOptions':{'target':'ES2020','module':'ESNext','moduleResolution':'Bundler','jsx':'react-jsx','strict':True,'esModuleInterop':True,'resolveJsonModule':True,'skipLibCheck':True,'lib':['ES2020','DOM'],'baseUrl':'.','paths':{'three':['node_modules/@types/three']}},'include':['src']},indent=2)+'\n')
shutil.copy2(ROOT/'03_SCRIPTS/73_beer_materialization_3d/remotion/remotion.config.ts',target/'remotion.config.ts')
provenance=json.loads((source.parent/'asset-provenance-3d.json').read_text())
assets=[{'source':provenance['models']['sobaya'],'target':'models/sobaya.glb'}]+[{'source':'03_SCRIPTS/74_yhk_jungle_available/backgrounds/'+f,'target':'backgrounds/'+f} for f in ['jungle_wall_day_v1.png','jungle_floor_v1.png']]
write('assets.json',json.dumps(assets,indent=2)+'\n')
shared=os.path.relpath(ROOT/'04_GAME_ASSETS/3d/stage_video/motion-player',target/'src').replace(os.sep,'/')
write('src/index.tsx',r'''import {useLayoutEffect,useMemo} from 'react';
import {registerRoot,Composition,AbsoluteFill,useCurrentFrame,staticFile} from 'remotion';
import {ThreeCanvas} from '@remotion/three';
import {useLoader,useThree} from '@react-three/fiber';
import * as THREE from 'three';
import {GLTFLoader} from 'three/examples/jsm/loaders/GLTFLoader.js';
import {clone} from 'three/examples/jsm/utils/SkeletonUtils.js';
import {createMotionPlayer,motionPlacement,MotionName} from 'SHARED';

export function Background({wall='backgrounds/jungle_wall_day_v1.png',floor='backgrounds/jungle_floor_v1.png',wallPosition=[0,5.1,-8],wallSize=[120,22.5],floorSize=30,floorRepeat=12}:{wall?:string;floor?:string;wallPosition?:[number,number,number];wallSize?:[number,number];floorSize?:number;floorRepeat?:number}){
 const w=useLoader(THREE.TextureLoader,staticFile(wall)),g=useLoader(THREE.TextureLoader,staticFile(floor));
 const [wt,gt]=useMemo(()=>{const a=w.clone(),b=g.clone();a.colorSpace=b.colorSpace=THREE.SRGBColorSpace;a.wrapS=THREE.MirroredRepeatWrapping;a.repeat.set(3,1);b.wrapS=b.wrapT=THREE.RepeatWrapping;b.repeat.set(floorRepeat,floorRepeat);a.needsUpdate=b.needsUpdate=true;return [a,b];},[w,g,floorRepeat]);
 return <><mesh position={wallPosition}><planeGeometry args={wallSize}/><meshBasicMaterial map={wt}/></mesh><mesh rotation={[-Math.PI/2,0,0]} position={[0,-.035,0]} receiveShadow><planeGeometry args={[floorSize,floorSize]}/><meshStandardMaterial map={gt} roughness={1}/></mesh></>;
}
export function Actor({motion='DogSniff',seconds}:{motion?:MotionName;seconds:number}){
 const gltf=useLoader(GLTFLoader,staticFile('models/sobaya.glb'));
 const {scene,player}=useMemo(()=>{const scene=clone(gltf.scene);scene.traverse(o=>{if(o instanceof THREE.Mesh){o.castShadow=true;o.frustumCulled=false;}});return {scene,player:createMotionPlayer(scene,gltf.animations,'sobaya')};},[gltf]);
 const offset=motionPlacement(motion,seconds);
 useLayoutEffect(()=>{scene.updateWorldMatrix(true,true);player.sample(motion,seconds);},[scene,player,motion,seconds]);
 return <group position={[offset.x,0,offset.z]} rotation={[0,offset.yaw,0]}><primitive object={scene}/></group>;
}
function Camera(){const {camera}=useThree();useLayoutEffect(()=>{camera.position.set(2.4,2,3.6);camera.lookAt(0,.5,-.3);camera.updateProjectionMatrix();},[camera]);return null;}
function Film(){const frame=useCurrentFrame();return <AbsoluteFill style={{background:'#25372b'}}><ThreeCanvas width={854} height={480} shadows camera={{fov:38}}><Camera/><ambientLight intensity={1.2}/><directionalLight position={[3,6,4]} intensity={2} castShadow/><Background/><Actor seconds={frame/24}/><mesh position={[.035,.035,.17]}><cylinderGeometry args={[.11,.11,.07,24]}/><meshStandardMaterial color='#947149'/></mesh></ThreeCanvas><div style={{position:'absolute',left:32,bottom:24,color:'white',fontSize:20}}>セット・犬モーション確認／無音</div></AbsoluteFill>;}
registerRoot(()=> <Composition id='StageStudy' component={Film} width={854} height={480} fps={24} durationInFrames={192}/>);
'''.replace('SHARED',shared))
prepare(target,ROOT)
print('Created',target,'\nRun npm ci, npm run typecheck, npm run render. This is a silent study, not a finished film.')
