import * as T from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {TakosanFloatMotion} from './takosan_float_motion.mjs?v=2';
const $=id=>document.getElementById(id),scene=new T.Scene();scene.background=new T.Color('#101c29');scene.fog=new T.Fog('#101c29',12,35);
const renderer=new T.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.toneMapping=T.ACESFilmicToneMapping;$('stage').append(renderer.domElement);
const camera=new T.PerspectiveCamera(36,1,.05,70),controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;
function view(x,y,z){camera.position.set(x,y,z);controls.target.set(0,1.1,0);controls.update();}view(3,2.1,5.3);
scene.add(new T.HemisphereLight(0xd8f2ff,0x64717d,2.7));const key=new T.DirectionalLight(0xffeddb,3.5);key.position.set(3,5,4);scene.add(key);const rim=new T.DirectionalLight(0x7fe7ee,2);rim.position.set(-3,3,-3);scene.add(rim);
const grid=new T.GridHelper(60,120,0x466475,0x233949);scene.add(grid);
const path=new T.Group(),pivot=new T.Group();path.add(pivot);scene.add(path);
let motion,skeleton,paused=false,time=0,distance=0;
try{const gltf=await new GLTFLoader().loadAsync('/04_GAME_ASSETS/3d/characters/takosan/rig_radial_v6_lined/takosan.glb?rim=3');pivot.add(gltf.scene);motion=new TakosanFloatMotion(gltf.scene,pivot);skeleton=new T.SkeletonHelper(gltf.scene);skeleton.visible=false;scene.add(skeleton);$('status').textContent='6本の触手 · 18関節';}catch(e){$('error').textContent='読み込みに失敗しました: '+e.message;throw e;}
$('pause').onclick=()=>{paused=!paused;$('pause').textContent=paused?'再生':'一時停止';};
$('front').onclick=()=>view(0,1.7,5.8);$('side').onclick=()=>view(5.8,1.8,0);$('angle').onclick=()=>view(3,2.1,5.3);
const notes={sway:'6本のタイミングをずらした、柔らかい浮遊。',wave:'根元から先端へ、さらに隣の触手へ波を送る。',pulse:'6本を同時に曲げ伸ばしする、周期的なひと漕ぎ。',alternate:'3本ずつ交互に曲げ伸ばしする、泳ぎ続ける動き。',curl:'根元を抑え、先端ほど大きく円を描く。'};
function describe(){$('patternNote').textContent=notes[$('pattern').value];$('strengthValue').textContent=(+$('strength').value).toFixed(1)+'倍';}
$('pattern').onchange=describe;$('strength').oninput=describe;describe();
$('hood').onclick=()=>{camera.position.set(0,1.30,1.35);controls.target.set(0,1.30,.22);controls.update();};
$('above').onclick=()=>view(1.7,3.5,3.2);$('below').onclick=()=>view(1.5,-1.5,2.8);
$('bones').onchange=()=>skeleton.visible=$('bones').checked;
for(const b of document.querySelectorAll('[data-speed]'))b.onclick=()=>{$('auto').checked=false;$('speed').value=b.dataset.speed;};$('speed').oninput=()=>{$('auto').checked=false;};
function resize(){const w=$('stage').clientWidth,h=$('stage').clientHeight;renderer.setSize(w,h);camera.aspect=w/h;camera.updateProjectionMatrix();}addEventListener('resize',resize);resize();
let last=performance.now();renderer.setAnimationLoop(now=>{const dt=Math.min((now-last)/1000,.05);last=now;if(!paused){time+=dt;if($('auto').checked)$('speed').value=1.5-1.5*Math.cos(time*.5);const state=motion.update(dt,+$('speed').value,$('mode').value,$('pattern').value,+$('strength').value,!$('isolate').checked);distance+=state.speed*dt;grid.position.z=$('travel').checked?0:-(distance%.5);
if($('travel').checked){const a=distance/1.4;path.position.set(1.4*Math.sin(a),0,1.4*Math.cos(a));path.rotation.y=a+Math.PI/2;}else{path.position.set(0,0,0);path.rotation.y=0;}
$('speedValue').textContent=state.speed.toFixed(2)+' m/s';$('status').textContent='前傾 '+state.lean.toFixed(1)+'° · 触手 '+state.tentacleCount+'/18関節 駆動中';}controls.update();renderer.render(scene,camera);});
