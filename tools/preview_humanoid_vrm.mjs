import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {VRMLoaderPlugin} from '@pixiv/three-vrm';
import {createVRMAnimationClip,VRMAnimationLoaderPlugin} from '@pixiv/three-vrm-animation';
const $=id=>document.getElementById(id);
const scene=new THREE.Scene();scene.background=new THREE.Color('#405364');
const camera=new THREE.PerspectiveCamera(35,innerWidth/innerHeight,.01,100);camera.position.set(0,1.4,5.7);
const renderer=new THREE.WebGLRenderer({antialias:true});renderer.setSize(innerWidth,innerHeight);renderer.setPixelRatio(Math.min(devicePixelRatio,2));document.body.append(renderer.domElement);
const controls=new OrbitControls(camera,renderer.domElement);controls.target.set(0,.9,0);controls.update();
scene.add(new THREE.HemisphereLight(0xffffff,0x808080,3));const sun=new THREE.DirectionalLight(0xffffff,3);sun.position.set(2,4,4);scene.add(sun);scene.add(new THREE.GridHelper(10,20));
const actors=[];let paused=false,seconds=0,duration=1,previous=null,ready=false;
function place(){for(const [i,a] of actors.entries()){a.vrm.scene.visible=$('character').value==='both'||$('character').value===a.name;a.vrm.scene.position.x=$('character').value==='both'?(i?-.55:.95):.25;}}
function select(){for(const a of actors){a.mixer.stopAllAction();a.vrm.humanoid.resetNormalizedPose();a.action=a.mixer.clipAction(a.clips.get($('motion').value));a.action.reset().play();}duration=actors[0].action.getClip().duration;seconds=0;sample();$('status').textContent='VRMA適用済み · '+$('motion').selectedOptions[0].textContent+'\n体格別の初期姿勢補正 / 元の演技を保持';}
function sample(){for(const a of actors){a.mixer.setTime(seconds);a.vrm.expressionManager?.setValue('aa',$('mouth').checked?(1+Math.sin(seconds*12))*.4:0);a.vrm.update(0);a.vrm.scene.updateMatrixWorld(true);} $('seek').value=seconds/duration;$('time').textContent=`${seconds.toFixed(2)} / ${duration.toFixed(2)} 秒`;}
try{
const catalog=await(await fetch('/04_GAME_ASSETS/vrm/motions/catalog.json')).json();
for(const name of ['sobaya','fukuchan']){
 const loader=new GLTFLoader();loader.register(p=>new VRMLoaderPlugin(p));const asset=await loader.loadAsync('/04_GAME_ASSETS/vrm/characters/'+name+'.vrm');const vrm=asset.userData.vrm;scene.add(vrm.scene);vrm.scene.traverse(o=>o.frustumCulled=false);
 const motionLoader=new GLTFLoader();motionLoader.register(p=>new VRMAnimationLoaderPlugin(p));const clips=new Map();
 for(const entry of catalog.characters[name]){const data=await motionLoader.loadAsync('/04_GAME_ASSETS/vrm/motions/'+entry.file);const clip=createVRMAnimationClip(data.userData.vrmAnimations[0],vrm);clips.set(entry.sourceClip,clip);}
 actors.push({name,vrm,clips,mixer:new THREE.AnimationMixer(vrm.scene)});
}
for(const entry of catalog.characters.sobaya){const option=new Option(entry.label,entry.sourceClip);$('motion').append(option);}$('motion').value='Walk';$('motion').disabled=false;place();select();ready=true;
}catch(error){$('status').textContent='読み込み失敗：'+error.message;console.error(error);}
$('motion').onchange=select;$('character').onchange=place;
$('play').onclick=()=>{paused=!paused;$('play').textContent=paused?'再生':'一時停止'};
$('reset').onclick=()=>{seconds=0;sample()};$('seek').oninput=()=>{paused=true;$('play').textContent='再生';seconds=Number($('seek').value)*duration;sample()};
$('front').onclick=()=>{for(const a of actors)a.vrm.scene.rotation.y=0};$('side').onclick=()=>{for(const a of actors)a.vrm.scene.rotation.y=Math.PI/2};
window.addEventListener('resize',()=>{camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();renderer.setSize(innerWidth,innerHeight)});
renderer.setAnimationLoop(t=>{const dt=previous===null?0:Math.min((t-previous)/1000,.1);previous=t;if(ready){if(!paused)seconds=(seconds+dt*Number($('speed').value))%duration;sample();}renderer.render(scene,camera)});
