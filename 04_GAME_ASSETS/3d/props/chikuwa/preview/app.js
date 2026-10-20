import * as T from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
const $=id=>document.getElementById(id), stage=$('stage');
const renderer=new T.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=1.3;stage.prepend(renderer.domElement);
const scene=new T.Scene();scene.background=new T.Color('#151a19');
const pmrem=new T.PMREMGenerator(renderer),env=new RoomEnvironment();scene.environment=pmrem.fromScene(env,.04).texture;env.dispose();pmrem.dispose();
const camera=new T.PerspectiveCamera(36,1,.01,100),controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.minDistance=1.2;controls.maxDistance=22;
scene.add(new T.HemisphereLight(0xeef3ed,0x544a3a,1.1));const light=new T.DirectionalLight(0xffe7c9,3);light.position.set(0,4,3);scene.add(light);
const rim=new T.DirectionalLight(0xe7dfff,1.7);rim.position.set(-3,1,-2);scene.add(rim);
const entries=[];let paused=false,time=0,ready=false;
function reset(){camera.position.set(3.7,3.0,6.6);controls.target.set(0,0,0);controls.update();}reset();
try{
 for(const [i,name] of ['chikuwa','chikuwa_toxic'].entries()){
  const gltf=await new GLTFLoader().loadAsync(`./models/${name}.glb`);
  const group=new T.Group();group.add(gltf.scene);group.rotation.z=-Math.PI/2;group.position.z=i===0?.7:-.7;scene.add(group);
  const bones=[];gltf.scene.traverse(n=>{if(n.isBone&&n.name.startsWith('Bend_')){bones.push(n);n.userData.restQuaternion=n.quaternion.clone();n.userData.animatedQuaternion=n.quaternion.clone();}if(n.isMesh){n.userData.colorMap=n.material.map;n.userData.roughnessMap=n.material.roughnessMap;}});bones.sort((a,b)=>a.name.localeCompare(b.name));
  const helper=new T.SkeletonHelper(gltf.scene);helper.visible=false;helper.material.depthTest=false;helper.renderOrder=10;scene.add(helper);
  const mixer=new T.AnimationMixer(gltf.scene);const action=mixer.clipAction(gltf.animations[0]);action.play();
  entries.push({group,bones,helper,mixer,action,gltf});
 }
 ready=true;$('status').textContent='読み込み完了 · 通常版 / 毒版とも同じメッシュと骨格。ゲームへの組み込み前の造形試作です。';
}catch(e){$('error').textContent='モデルを読み込めませんでした: '+e.message;console.error(e);}
$('pause').onclick=()=>{paused=!paused;$('pause').textContent=paused?'再生':'一時停止';};
$('reset').onclick=reset;
$('strength').oninput=()=>{$('strengthValue').textContent=(+$('strength').value).toFixed(2)+'×';};
$('speed').oninput=()=>{$('speedValue').textContent=(+$('speed').value).toFixed(1)+'×';};
$('bones').onchange=()=>entries.forEach(e=>e.helper.visible=$('bones').checked&&e.group.visible);
$('wire').onchange=()=>entries.forEach(e=>e.gltf.scene.traverse(n=>{if(n.isMesh)n.material.wireframe=$('wire').checked;}));
$('clay').onchange=()=>entries.forEach(e=>e.gltf.scene.traverse(n=>{if(n.isMesh){n.material.map=$('clay').checked?null:n.userData.colorMap;n.material.color.set($('clay').checked?'#b9afa0':'#ffffff');n.material.needsUpdate=true;}}));
$('view').onchange=()=>{entries.forEach((e,i)=>{e.group.visible=$('view').value==='both'||$('view').value===(i===0?'normal':'toxic');e.group.position.z=$('view').value==='both'?(i===0?.7:-.7):0;e.helper.visible=$('bones').checked&&e.group.visible;});reset();if($('view').value!=='both')camera.position.multiplyScalar(.7);};
$('end').onclick=()=>{camera.position.set(5,.4,.35);controls.target.set(0,0,0);controls.update();};
$('small').onclick=()=>{camera.position.set(4,5,17);controls.target.set(0,0,0);controls.update();};
function resize(){const w=stage.clientWidth,h=stage.clientHeight;renderer.setSize(w,h);camera.aspect=w/h;camera.updateProjectionMatrix();}new ResizeObserver(resize).observe(stage);resize();
let last=performance.now();renderer.setAnimationLoop(now=>{const dt=Math.min((now-last)/1000,.05);last=now;if(!paused)time+=dt*+$('speed').value;for(const e of entries){for(const b of e.bones)b.quaternion.copy(b.userData.animatedQuaternion);e.mixer.setTime(time);for(const b of e.bones){b.userData.animatedQuaternion.copy(b.quaternion);b.quaternion.copy(b.userData.restQuaternion).slerp(b.userData.animatedQuaternion,+$('strength').value);}}controls.update();renderer.render(scene,camera);});
window.chikuwaInspect=()=>({ready,paused,time,models:entries.map(e=>({visible:e.group.visible,bones:e.bones.length,rotations:e.bones.map(b=>b.quaternion.toArray()),clips:e.gltf.animations.map(a=>({name:a.name,duration:a.duration})),triangles:(()=>{let n=0;e.gltf.scene.traverse(o=>{if(o.isMesh)n+=(o.geometry.index?.count??o.geometry.attributes.position.count)/3;});return n;})()}))});
