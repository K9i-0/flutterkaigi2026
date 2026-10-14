import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {clone} from 'three/addons/utils/SkeletonUtils.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {createRigSampler} from './riglib/rig-sampler.js';

const fps = 30;
const canvas = document.querySelector('#scene');
const select = document.querySelector('#clip');
const seek = document.querySelector('#seek');
const play = document.querySelector('#play');
const status = document.querySelector('#status');
const time = document.querySelector('#time');
const validate = document.querySelector('#validate');
const renderer = new THREE.WebGLRenderer({canvas, antialias: true});
renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
renderer.setClearColor('#e6e6e6');
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.shadowMap.enabled = true;
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(33, innerWidth / innerHeight, 0.05, 40);
const controls = new OrbitControls(camera, canvas);
const resetView = () => {camera.position.set(2.4, 1.6, 4.2); controls.target.set(0, 0.9, 0); controls.update();};
resetView();
document.querySelector('#reset').onclick = resetView;
scene.add(new THREE.AmbientLight(0xffffff, .65), new THREE.HemisphereLight(0xffffff, 0xcccccc, .8));
const key = new THREE.DirectionalLight(0xffffff, 2.6);
key.position.set(-3, 4.5, 4); key.castShadow = true;
Object.assign(key.shadow.camera, {left:-2,right:2,top:3,bottom:-1,near:.1,far:12});
key.shadow.mapSize.set(2048,2048); key.shadow.bias=-.00015; key.shadow.normalBias=.015;
scene.add(key);
for (const [position, intensity] of [[[3,2,1],.8], [[0,3,-4],1]]) {
  const light = new THREE.DirectionalLight(0xffffff, intensity); light.position.fromArray(position); scene.add(light);
}
const floor = new THREE.Mesh(new THREE.PlaneGeometry(200,200), new THREE.MeshStandardMaterial({color:'#e6e6e6',roughness:1}));
floor.rotation.x=-Math.PI/2; floor.position.y=-.002; floor.receiveShadow=true; scene.add(floor);
let sampler, skeleton, clips = [], model, frame = 0, playing = false, startFrame = 0, startTime = 0;
const setPlaying = (value) => {playing=value;startFrame=frame;startTime=performance.now();play.textContent=value?'停止':'再生';};
const applyFrame = (value) => {
  frame=value;
  sampler.sample(select.value,frame,fps);
  seek.value=String(frame);
  const duration=clips.find((clip)=>clip.name===select.value).duration;
  time.textContent=`${(frame/fps).toFixed(2)} s / ${duration.toFixed(2)} s`;
};
select.onchange = () => {
  const clip=clips.find((item)=>item.name===select.value);
  seek.max=String(Math.max(0,Math.round(clip.duration*fps)-1));
  applyFrame(0);setPlaying(false);
};
play.onclick=()=>setPlaying(!playing);
seek.oninput=()=>{setPlaying(false);applyFrame(Number(seek.value));};
document.querySelector('#bones').onchange=(event)=>{if(skeleton)skeleton.visible=event.target.checked;};
const resize=()=>{renderer.setSize(innerWidth,innerHeight,false);camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();};
addEventListener('resize',resize);resize();

// A read-only validation surface for deterministic samples, shared with video rendering.
window.rigPreview = {
  ready: false,
  sample(clip, targetFrame) {
    if(!sampler)throw new Error('Model not ready');
    if(!clips.some((item)=>item.name===clip))throw new Error(`Unknown clip ${clip}`);
    select.value=clip; select.onchange(); applyFrame(targetFrame);
    return this.snapshot();
  },
  snapshot() {
    const bones=[];
    model.traverse((node)=>{if(node.isBone)bones.push({name:node.name,matrix:node.matrixWorld.toArray()});});
    return {clip:select.value,frame,bones};
  },
};

validate.onclick=()=>{
  setPlaying(false);
  const current=select.value, savedFrame=frame, checks=[];
  for(const clip of clips){
    const target=Math.floor(clip.duration*fps*.37);
    sampler.sample(clip.name,target,fps);
    const expected=JSON.stringify(window.rigPreview.snapshot().bones);
    for(const other of clips){sampler.sample(other.name,Math.floor(other.duration*fps*.79),fps);}
    sampler.sample(clip.name,Math.floor(clip.duration*fps*.91),fps);
    sampler.sample(clip.name,0,fps);
    sampler.sample(clip.name,target,fps);
    const actual=window.rigPreview.snapshot().bones;
    checks.push({clip:clip.name,durationSeconds:clip.duration,frameCount:Math.round(clip.duration*fps),frame:target,
      repeatable:JSON.stringify(actual)===expected,
      finite:actual.every((bone)=>bone.matrix.every(Number.isFinite))});
  }
  select.value=current;select.onchange();applyFrame(savedFrame);
  const result={passed:checks.every((check)=>check.repeatable&&check.finite),fps,checks};
  window.rigPreview.validation=result;
  document.querySelector('#validation').hidden=false;
  document.querySelector('#validation').open=true;
  document.querySelector('#validation-result').textContent=JSON.stringify(result,null,2);
  status.textContent=`seek検証: ${result.passed?'PASS':'FAIL'} · ${checks.length} clips · 全54骨の姿勢を比較`;
};

try {
  const gltf=await new GLTFLoader().loadAsync('./models/cto_odatetsu_rig.glb');
  model=clone(gltf.scene);clips=gltf.animations;
  let bones=0;
  model.traverse((object)=>{
    if(object.isBone)bones++;
    if(object.isMesh){object.castShadow=true;object.receiveShadow=true;object.frustumCulled=false;}
  });
  scene.add(model);sampler=createRigSampler(model,clips);
  skeleton=new THREE.SkeletonHelper(model);skeleton.visible=false;
  skeleton.material.depthTest=false;skeleton.material.transparent=true;skeleton.material.opacity=.85;
  scene.add(skeleton);
  for(const clip of clips)select.add(new Option(clip.name,clip.name));
  select.value=clips.some((clip)=>clip.name==='Idle')?'Idle':clips[0].name;
  select.disabled=seek.disabled=play.disabled=validate.disabled=false;select.onchange();
  status.textContent=`${bones} bones · ${clips.length} clips · ドラッグで視点回転、ホイールで拡大`;
  window.rigPreview.ready=true;
  window.rigPreview.clipNames=clips.map((clip)=>clip.name);
} catch(error) {status.textContent=`読み込みエラー: ${error.message}`;console.error(error);}

renderer.setAnimationLoop((now)=>{
  if(playing&&sampler){
    const range=Number(seek.max)+1;
    applyFrame((startFrame+Math.floor((now-startTime)*fps/1000))%range);
  }
  controls.update();renderer.render(scene,camera);
});
