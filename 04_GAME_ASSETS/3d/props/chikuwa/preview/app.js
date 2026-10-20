import * as T from 'three';
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {OrbitControls} from 'three/addons/controls/OrbitControls.js';
import {RectAreaLightUniformsLib} from 'three/addons/lights/RectAreaLightUniformsLib.js';
import {RoomEnvironment} from 'three/addons/environments/RoomEnvironment.js';
const $=id=>document.getElementById(id),stage=$('stage');
const renderer=new T.WebGLRenderer({antialias:true});renderer.setPixelRatio(Math.min(devicePixelRatio,2));renderer.toneMapping=T.ACESFilmicToneMapping;renderer.toneMappingExposure=.9;renderer.shadowMap.enabled=true;renderer.shadowMap.type=T.PCFSoftShadowMap;stage.append(renderer.domElement);
const scene=new T.Scene();scene.background=new T.Color('#e2ded7');
const pmrem=new T.PMREMGenerator(renderer),env=new RoomEnvironment();scene.environment=pmrem.fromScene(env,.06).texture;scene.environmentIntensity=.25;env.dispose();pmrem.dispose();
const camera=new T.OrthographicCamera(-1.65,1.65,2.2,-2.2,.01,100),controls=new OrbitControls(camera,renderer.domElement);controls.enableDamping=true;controls.minDistance=1.2;controls.maxDistance=24;controls.maxPolarAngle=Math.PI*.49;
scene.add(new T.HemisphereLight(0xffffff,0xb5a68d,.25));
const light=new T.DirectionalLight(0xfff4e5,.4);light.position.set(-2,6,4);light.castShadow=true;light.shadow.mapSize.set(2048,2048);light.shadow.camera.left=-4;light.shadow.camera.right=4;light.shadow.camera.top=4;light.shadow.camera.bottom=-4;light.shadow.normalBias=.018;light.shadow.bias=-.0001;light.shadow.radius=4;scene.add(light);
RectAreaLightUniformsLib.init();const softbox=new T.RectAreaLight(0xfff4e7,3.5,3.5,3.5);softbox.position.set(-1.5,4,3);softbox.lookAt(0,.3,0);scene.add(softbox);
const floor=new T.Mesh(new T.PlaneGeometry(200,200),new T.MeshStandardMaterial({color:'#e2ded7',roughness:1}));floor.rotation.x=-Math.PI/2;floor.position.y=-.01;floor.receiveShadow=true;scene.add(floor);
const sets=new Map(),loader=new GLTFLoader();let entries=[],version='v3',paused=true,time=0,ready=false,loading=false;
const visibleIndex=i=>i===0;
const modelPath=(name,v)=>`./models/${name}${v==='v1'?'':'_'+v}.glb`;
const variantName=()=>$('variant').value==='toxic'?'chikuwa_toxic':'chikuwa';
function reset(){camera.position.set(3.1,3.0,9);camera.zoom=1;camera.updateProjectionMatrix();controls.target.set(0,.30,0);controls.update();}
function updateAppearance(){
 for(const e of entries){e.group.visible=visibleIndex(e.index);e.group.position.z=0;e.helper.visible=$('bones').checked&&e.group.visible;
 e.gltf.scene.traverse(n=>{if(n.isMesh){n.material.wireframe=$('wire').checked;n.material.map=$('clay').checked?null:n.userData.colorMap;n.material.normalMap=$('clay').checked?null:n.userData.normalMap;n.material.roughnessMap=$('clay').checked?null:n.userData.roughnessMap;n.material.roughness=$('clay').checked?.6:n.userData.roughness;if($('clay').checked)n.material.color.set('#b9afa0');else n.material.color.copy(n.userData.baseColor);n.material.needsUpdate=true;}});}
}
async function selectVersion(v){
 if(loading)return;loading=true;ready=false;$('version').disabled=true;$('status').textContent='モデルを読み込み中…';$('error').textContent='';
 try{
  const key=v+'_'+variantName();
  if(!sets.has(key)){
   const result=[];
   for(const [index,name] of [variantName()].entries()){
    const gltf=await loader.loadAsync(modelPath(name,v));
    const group=new T.Group();group.add(gltf.scene);group.rotation.z=-Math.PI/2;group.position.y=.30;group.visible=false;scene.add(group);
    const bones=[];gltf.scene.traverse(n=>{if(n.isBone&&n.name.startsWith('Bend_')){bones.push(n);n.userData.restQuaternion=n.quaternion.clone();n.userData.animatedQuaternion=n.quaternion.clone();}if(n.isMesh){n.userData.colorMap=n.material.map;n.userData.baseColor=n.material.color.clone();n.userData.normalMap=n.material.normalMap;n.userData.roughnessMap=n.material.roughnessMap;n.userData.roughness=n.material.roughness;n.castShadow=true;n.receiveShadow=true;}});bones.sort((a,b)=>a.name.localeCompare(b.name));
    const helper=new T.SkeletonHelper(gltf.scene);helper.visible=false;helper.material.depthTest=false;helper.renderOrder=10;scene.add(helper);
    const mixer=new T.AnimationMixer(gltf.scene);mixer.clipAction(gltf.animations[0]).play();
    result.push({group,bones,helper,mixer,gltf,index});
   }
   sets.set(key,result);
  }
  for(const e of entries){e.group.visible=false;e.helper.visible=false;}
  entries=sets.get(key);version=v;updateAppearance();ready=true;$('displayMode').value='3d';$('displayMode').disabled=v!=='v3'||variantName()!=='chikuwa';displayMode();
  $('versionTitle').textContent=v==='game'?'ゲーム版 · 32,320三角形':v==='v3'?'Blender 造形版 v3':v==='v2'?'Blender 改良版 v2':'Blender 初稿 v1';
  $('versionNote').textContent=v==='game'?'ゲーム用の軽量版。通常と毒は同じメッシュ・ボーン・アニメーションで、色だけを変えています。':v==='v3'?'焼き皮の膨らみと溝を、高密度のメッシュと細部の法線で再現。色を外して形状だけでも比較できます。':v==='v2'?'リング状のしわをなくし、薄い焼き皮と自然な色むらへ。目標画像を基準にした改良版です。':'比較用に残した初稿。節のようなしわと規則的な表面を、改良版と見比べられます。';
  const tris=triangleCount(entries[0]);$('stats').textContent=`1体 ${tris.toLocaleString()} 三角形 · 8変形ボーン · 1.6秒ループ`;
  $('normalDownload').href=modelPath(variantName(),v);
  $('normalDownload').textContent=(variantName()==='chikuwa'?'通常版':'毒版')+' GLB ↓';
  document.querySelector('.target .hint').textContent=(variantName()==='chikuwa'?'通常':'毒')+'ちくわの部分を表示 · 元画像は下のリンクから';
  document.querySelector('.target img').style.transform=variantName()==='chikuwa'?'translateY(-7.5%)':'translateY(-51%)';
  $('status').textContent='読み込み完了。ゲーム版は鉄骨キャッチで使うモデルです。';
 }catch(e){$('error').textContent='モデルを読み込めませんでした: '+e.message;console.error(e);$('version').value=version;}finally{loading=false;$('version').disabled=false;}
}
function triangleCount(e){let n=0;e.gltf.scene.traverse(o=>{if(o.isMesh)n+=(o.geometry.index?.count??o.geometry.attributes.position.count)/3;});return n;}
function displayMode(){
 const isRender=$('displayMode').value==='render';$('renderView').style.display=isRender?'flex':'none';$('viewerHint').textContent=isRender?'実際のGLBをCyclesでレンダリング · 回転は3D表示へ':'ドラッグ：回転 ／ ホイール：拡大 ／ 右ドラッグ：移動';
 for(const id of ['pause','straight','strength','speed','lighting','clay','bones','wire','reset','close','end','small'])$(id).disabled=isRender;
 $('versionTitle').textContent=isRender?'Blender 静止画 · 同じGLB':version==='game'?'ゲーム版 · 32,320三角形':version==='v3'?'Blender 造形版 v3':version==='v2'?'Blender 改良版 v2':'Blender 初稿 v1';
}
$('displayMode').onchange=displayMode;
function strengthLabel(){$('strengthValue').textContent=(+$('strength').value).toFixed(2)+'×';}
$('pause').onclick=()=>{paused=!paused;if(!paused&&+$('strength').value===0){$('strength').value=.7;strengthLabel();}$('pause').textContent=paused?'動かす':'一時停止';};
$('straight').onclick=()=>{paused=true;$('pause').textContent='動かす';$('strength').value=0;strengthLabel();};
$('strength').oninput=strengthLabel;$('speed').oninput=()=>{$('speedValue').textContent=(+$('speed').value).toFixed(1)+'×';};
$('variant').onchange=()=>selectVersion($('version').value);
$('version').onchange=()=>selectVersion($('version').value);
for(const id of ['bones','wire','clay'])$(id).onchange=updateAppearance;
$('reset').onclick=reset;
$('lighting').onchange=()=>{const r=$('lighting').value==='raking';light.position.set(r?-5:-2,r?1.0:6,r?1:4);light.intensity=r?2.2:.4;softbox.visible=!r;scene.environmentIntensity=r?.15:.25;};
$('close').onclick=()=>{camera.zoom=2.2;camera.updateProjectionMatrix();controls.target.set(0,.3,0);controls.update();};
$('end').onclick=()=>{camera.position.set(5,1,.25);camera.zoom=1.5;camera.updateProjectionMatrix();controls.target.set(0,.3,0);controls.update();};
$('small').onclick=()=>{camera.position.set(3.1,3.0,9);camera.zoom=.4;camera.updateProjectionMatrix();controls.target.set(0,.15,0);controls.update();};
function resize(){renderer.setSize(stage.clientWidth,stage.clientHeight);const aspect=stage.clientWidth/stage.clientHeight;camera.left=-1.65;camera.right=1.65;camera.top=1.65/aspect;camera.bottom=-1.65/aspect;camera.updateProjectionMatrix();}new ResizeObserver(resize).observe(stage);resize();reset();
let last=performance.now();renderer.setAnimationLoop(now=>{const dt=Math.min((now-last)/1000,.05);last=now;if(!paused)time+=dt*+$('speed').value;for(const e of entries){for(const b of e.bones)b.quaternion.copy(b.userData.animatedQuaternion);e.mixer.setTime(time);for(const b of e.bones){b.userData.animatedQuaternion.copy(b.quaternion);b.quaternion.copy(b.userData.restQuaternion).slerp(b.userData.animatedQuaternion,+$('strength').value);}}controls.update();renderer.render(scene,camera);});
window.chikuwaInspect=()=>({ready,version,paused,time,models:entries.map(e=>({visible:e.group.visible,bones:e.bones.length,rotations:e.bones.map(b=>b.quaternion.toArray()),clips:e.gltf.animations.map(a=>({name:a.name,duration:a.duration})),triangles:triangleCount(e)}))});
await selectVersion('game');
