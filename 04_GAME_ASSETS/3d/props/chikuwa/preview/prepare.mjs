import {mkdir,copyFile} from 'node:fs/promises';
import {dirname,join} from 'node:path';
import {fileURLToPath} from 'node:url';
const base=dirname(fileURLToPath(import.meta.url));
const paths=['build/three.module.js','build/three.core.js','examples/jsm/loaders/GLTFLoader.js','examples/jsm/controls/OrbitControls.js','examples/jsm/environments/RoomEnvironment.js','examples/jsm/utils/BufferGeometryUtils.js','examples/jsm/lights/RectAreaLightUniformsLib.js','examples/jsm/lights/RectAreaLightTexturesLib.js','LICENSE'];
for(const p of paths){const dest=join(base,'vendor',p.replace('build/','').replace('examples/jsm/','addons/'));await mkdir(dirname(dest),{recursive:true});await copyFile(join(base,'node_modules/three',p),dest);}
console.log('Three.js preview dependencies ready.');
