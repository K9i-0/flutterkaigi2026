import * as THREE from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {clone} from 'three/addons/utils/SkeletonUtils.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {createCameraEquipment} from './riglib/camera-equipment.js';

const fps=30, canvas=document.querySelector('#scene'), select=document.querySelector('#clip');
const seek=document.querySelector('#seek'), play=document.querySelector('#play'), status=document.querySelector('#status');
const equipped=document.querySelector('#equipped'), strap=document.querySelector('#strap'), validate=document.querySelector('#validate');
const renderer=new THREE.WebGLRenderer({canvas,antialias:true});
renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.setClearColor('#e6e6e6');
renderer.outputColorSpace=THREE.SRGBColorSpace;renderer.toneMapping=THREE.ACESFilmicToneMapping;renderer.shadowMap.enabled=true;
const scene=new THREE.Scene(), camera=new THREE.PerspectiveCamera(33,innerWidth/innerHeight,.05,40);
const controls=new OrbitControls(camera,canvas);
let needsRender=true;
controls.addEventListener('change',()=>{needsRender=true;});
const reset=()=>{camera.position.set(2.3,1.6,4.4);controls.target.set(0,.95,0);controls.update();};
const detail=()=>{camera.position.set(.95,1.55,2.4);controls.target.set(-.05,1.33,0);controls.update();};
reset();document.querySelector('#reset').onclick=reset;document.querySelector('#detail').onclick=detail;
scene.add(new THREE.AmbientLight(0xffffff,.65),new THREE.HemisphereLight(0xffffff,0xcccccc,.8));
const key=new THREE.DirectionalLight(0xffffff,2.6);key.position.set(-3,4.5,4);key.castShadow=true;
Object.assign(key.shadow.camera,{left:-2,right:2,top:3,bottom:-1,near:.1,far:12});key.shadow.mapSize.set(2048,2048);
key.shadow.bias=-.00015;key.shadow.normalBias=.015;scene.add(key);
for(const [position,intensity]of[[[3,2,1],.8],[[0,3,-4],1]]){const light=new THREE.DirectionalLight(0xffffff,intensity);light.position.fromArray(position);scene.add(light);}
const floor=new THREE.Mesh(new THREE.PlaneGeometry(200,200),new THREE.MeshStandardMaterial({color:'#e6e6e6',roughness:1}));
floor.rotation.x=-Math.PI/2;floor.position.y=-.002;floor.receiveShadow=true;scene.add(floor);
let equipment,skeleton,clips=[],frame=0,playing=false,startFrame=0,startTime=0;
const setPlaying=(value)=>{playing=value;startFrame=frame;startTime=performance.now();play.textContent=value?'停止':'再生';};
const applyFrame=(value)=>{frame=value;equipment.sample(select.value,frame,fps,equipped.checked,strap.checked);seek.value=String(frame);needsRender=true;
  const duration=clips.find((clip)=>clip.name===select.value).duration;
  document.querySelector('#time').textContent=`${(frame/fps).toFixed(2)} s / ${duration.toFixed(2)} s`;};
select.onchange=()=>{const clip=clips.find((item)=>item.name===select.value);seek.max=String(Math.max(0,Math.round(clip.duration*fps)-1));applyFrame(0);setPlaying(false);};
play.onclick=()=>setPlaying(!playing);seek.oninput=()=>{setPlaying(false);applyFrame(Number(seek.value));};
equipped.onchange=strap.onchange=()=>{if(equipment)applyFrame(frame);};
document.querySelector('#bones').onchange=(event)=>{if(skeleton)skeleton.visible=event.target.checked;needsRender=true;};
const resize=()=>{renderer.setSize(innerWidth,innerHeight,false);camera.aspect=innerWidth/innerHeight;camera.updateProjectionMatrix();needsRender=true;};addEventListener('resize',resize);resize();

window.cameraPreview={ready:false,sample(clip,targetFrame,on=true){if(!equipment)throw new Error('Model not ready');
  if(!clips.some((item)=>item.name===clip))throw new Error(`Unknown clip ${clip}`);
  equipped.checked=on;select.value=clip;select.onchange();applyFrame(targetFrame);return this.snapshot();},
  snapshot(){return{clip:select.value,frame,...equipment.snapshot()};},
  view(name){name==='detail'?detail():reset();},
};
validate.onclick=()=>{
  setPlaying(false);const current=select.value,savedFrame=frame,savedEquipped=equipped.checked,checks=[];
  for(const clip of clips){
    const target=Math.floor(clip.duration*fps*.37);
    equipment.sample(clip.name,target,fps,false,true);const off=JSON.stringify(equipment.snapshot().bones);
    equipment.sample(clip.name,target,fps,true,true);const on=JSON.stringify(equipment.snapshot());
    for(const other of clips)equipment.sample(other.name,Math.floor(other.duration*fps*.79),fps,true,true);
    equipment.sample(clip.name,Math.floor(clip.duration*fps*.91),fps,false,false);
    equipment.sample(clip.name,0,fps,true,false);equipment.sample(clip.name,target,fps,true,true);
    const actual=equipment.snapshot();
    const repeatable=on===JSON.stringify(actual);
    equipment.sample(clip.name,target,fps,false,true);
    checks.push({clip:clip.name,durationSeconds:clip.duration,repeatable,
      offRestoresOriginalFingers:off===JSON.stringify(equipment.snapshot().bones),gripError:actual.gripError,
      finite:actual.bones.every((bone)=>bone.matrix.every(Number.isFinite))&&actual.cameraMatrix.every(Number.isFinite)});
  }
  equipped.checked=savedEquipped;select.value=current;select.onchange();applyFrame(savedFrame);
  const result={passed:checks.every((check)=>check.repeatable&&check.offRestoresOriginalFingers&&check.finite&&check.gripError<1e-6),fps,checks};
  window.cameraPreview.validation=result;document.querySelector('#validation').hidden=false;document.querySelector('#validation').open=true;
  document.querySelector('#validation-result').textContent=JSON.stringify(result,null,2);
  status.textContent=`装備/seek検証: ${result.passed?'PASS':'FAIL'} · ${checks.length} clips`;
};
try{
  const loader=new GLTFLoader();
  const [actor,prop,attachment]=await Promise.all([loader.loadAsync('./models/cto_odatetsu_camera.glb'),
    loader.loadAsync('./models/odatetsu_camera.glb'),fetch('./camera/attachment.json').then((response)=>{if(!response.ok)throw new Error('Attachment config unavailable');return response.json();})]);
  clips=actor.animations;equipment=createCameraEquipment(clone(actor.scene),clips,clone(prop.scene),attachment);
  let bones=0;equipment.group.traverse((object)=>{if(object.isBone)bones++;if(object.isMesh){object.castShadow=true;object.receiveShadow=true;object.frustumCulled=false;}});
  scene.add(equipment.group);skeleton=new THREE.SkeletonHelper(equipment.character);skeleton.visible=false;
  skeleton.material.depthTest=false;skeleton.material.transparent=true;skeleton.material.opacity=.85;scene.add(skeleton);
  for(const clip of clips)select.add(new Option(clip.name,clip.name));select.value='CameraCarry';
  select.disabled=seek.disabled=play.disabled=validate.disabled=false;select.onchange();
  status.textContent=`${bones} bones · ${clips.length} clips · ドラッグで視点回転、ホイールで拡大`;
  window.cameraPreview.ready=true;window.cameraPreview.clipNames=clips.map((clip)=>clip.name);
}catch(error){status.textContent=`読み込みエラー: ${error.message}`;console.error(error);}
renderer.setAnimationLoop((now)=>{
  if(playing&&equipment){const next=(startFrame+Math.floor((now-startTime)*fps/1000))%(Number(seek.max)+1);if(next!==frame)applyFrame(next);}
  controls.update();if(needsRender){renderer.render(scene,camera);needsRender=false;}
});
