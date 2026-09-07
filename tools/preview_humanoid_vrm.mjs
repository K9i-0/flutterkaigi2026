import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {VRMLoaderPlugin} from '@pixiv/three-vrm';
import {createVRMAnimationClip,VRMAnimationLoaderPlugin} from '@pixiv/three-vrm-animation';
import {createBoneOverlay} from './vrm_bone_overlay.mjs';
const $=id=>document.getElementById(id);
const drawBones=createBoneOverlay($('bones-overlay'));
const scene=new THREE.Scene();scene.background=new THREE.Color('#405364');
const camera=new THREE.PerspectiveCamera(35,innerWidth/innerHeight,.01,100);camera.position.set(0,1.4,5.7);
const renderer=new THREE.WebGLRenderer({antialias:true});renderer.setSize(innerWidth,innerHeight);renderer.setPixelRatio(Math.min(devicePixelRatio,2));document.body.append(renderer.domElement);
const controls=new OrbitControls(camera,renderer.domElement);controls.target.set(0,.9,0);controls.update();
scene.add(new THREE.HemisphereLight(0xffffff,0x808080,3));const sun=new THREE.DirectionalLight(0xffffff,3);sun.position.set(2,4,4);scene.add(sun);scene.add(new THREE.GridHelper(10,20));
const revision=new URLSearchParams(location.search).get('revision')==='baseline'?'baseline':'improved';
$('revision').value=revision;
const base=revision==='baseline'?'/.local/dance_deformation/baseline':'/04_GAME_ASSETS/vrm';
const actors=[];let paused=false,seconds=0,duration=1,previous=null,ready=false;
function place(){for(const [i,a] of actors.entries()){a.vrm.scene.visible=$('character').value==='both'||$('character').value===a.name;a.vrm.scene.position.x=$('character').value==='both'?(i?-.55:.95):.25;}}
function select(){for(const a of actors){a.mixer.stopAllAction();a.vrm.humanoid.resetNormalizedPose();a.action=a.mixer.clipAction(a.clips.get($('motion').value));a.action.reset().play();}duration=actors[0].action.getClip().duration;seconds=0;sample();$('status').textContent='VRMA適用済み · '+$('motion').selectedOptions[0].textContent+(revision==='baseline'?'\n修正前の公開ライブラリ移植':($('motion').value==='Candidate_Mixamo_Run'?'\n既存のMixamo収録動作（CC0ではありません）':$('motion').value==='Candidate_Chase_Run'?'\nJogを調整：前傾・腕振り・足の回転1.2倍':$('motion').value.startsWith('Dance')?'\n関節軌道を保持 / 肩・腕のねじれ補正':'\n体格別の初期姿勢補正'));}
function sample(){for(const a of actors){a.mixer.setTime(seconds);if($('rest').checked)a.vrm.humanoid.resetNormalizedPose();a.vrm.expressionManager?.setValue('aa',$('mouth').checked?(1+Math.sin(seconds*12))*.4:0);a.vrm.update(0);a.vrm.scene.updateMatrixWorld(true);} $('seek').value=seconds/duration;$('time').textContent=`${seconds.toFixed(2)} / ${duration.toFixed(2)} 秒`;}
try{
const catalog=await(await fetch(base+'/motions/catalog.json')).json();
if(revision==='improved'){const candidates=await(await fetch(base+'/motions/run_candidates.json',{cache:'no-store'})).json();for(const name of ['sobaya','fukuchan'])catalog.characters[name].push(...candidates.characters[name]);}
for(const name of ['sobaya','fukuchan']){
 const loader=new GLTFLoader();loader.register(p=>new VRMLoaderPlugin(p));const asset=await loader.loadAsync(base+'/characters/'+name+'.vrm');const vrm=asset.userData.vrm;scene.add(vrm.scene);vrm.scene.traverse(o=>o.frustumCulled=false);
 const motionLoader=new GLTFLoader();motionLoader.register(p=>new VRMAnimationLoaderPlugin(p));const clips=new Map();
 for(const entry of catalog.characters[name]){const data=await motionLoader.loadAsync(base+'/motions/'+entry.file);const clip=createVRMAnimationClip(data.userData.vrmAnimations[0],vrm);clip.userData=entry;clips.set(entry.sourceClip,clip);}
 actors.push({name,vrm,clips,mixer:new THREE.AnimationMixer(vrm.scene)});
}
for(const entry of catalog.characters.sobaya){const option=new Option(entry.sourceClip==='Sprint'?'ダッシュ：現行 Sprint':entry.label,entry.sourceClip);$('motion').append(option);}const requestedMotion=new URLSearchParams(location.search).get('motion');$('motion').value=catalog.characters.sobaya.some(e=>e.sourceClip===requestedMotion)?requestedMotion:'Walk';$('motion').disabled=false;place();select();if(new URLSearchParams(location.search).has('time')){seconds=Math.max(0,Math.min(duration,Number(new URLSearchParams(location.search).get('time'))||0));paused=true;$('play').textContent='再生';sample();}const savedCamera=new URLSearchParams(location.search).get('camera');if(savedCamera){try{const c=JSON.parse(savedCamera);if(c.position?.length===3&&c.target?.length===3&&[...c.position,...c.target,c.yaw].every(Number.isFinite)){camera.position.fromArray(c.position);controls.target.fromArray(c.target);controls.update();for(const a of actors)a.vrm.scene.rotation.y=c.yaw;}}catch{}}ready=true;
}catch(error){$('status').textContent='読み込み失敗：'+error.message;console.error(error);}
$('revision').onchange=()=>{const url=new URL(location.href);url.searchParams.set('revision',$('revision').value);url.searchParams.set('motion',$('motion').value);url.searchParams.set('time',seconds.toFixed(5));url.searchParams.set('camera',JSON.stringify({position:camera.position.toArray(),target:controls.target.toArray(),yaw:actors[0]?.vrm.scene.rotation.y||0}));location.href=url;};
$('motion').onchange=select;$('character').onchange=place;
$('play').onclick=()=>{paused=!paused;$('play').textContent=paused?'再生':'一時停止'};
$('reset').onclick=()=>{seconds=0;sample()};$('seek').oninput=()=>{paused=true;$('play').textContent='再生';seconds=Number($('seek').value)*duration;sample()};
$('front').onclick=()=>{for(const a of actors)a.vrm.scene.rotation.y=0};$('side').onclick=()=>{for(const a of actors)a.vrm.scene.rotation.y=Math.PI/2};
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
renderer.setAnimationLoop(t=>{const dt=previous===null?0:Math.min((t-previous)/1000,.1);previous=t;if(ready){if(!paused)seconds=(seconds+dt*Number($('speed').value))%duration;sample();}renderer.render(scene,camera);drawBones(actors,camera,$('bones').checked,$('axes').checked)});
