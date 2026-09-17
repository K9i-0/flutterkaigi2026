import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

import { loadMug, mountMug, setMugGrip } from "./character-mug";

export type CharacterScene = {
  motion: (name: string) => void;
  mug: (enabled: boolean) => void;
  pause: (paused: boolean) => void;
  reset: () => void;
  dispose: () => void;
};

function release(root: THREE.Object3D) {
  const geometries = new Set<THREE.BufferGeometry>();
  const materials = new Set<THREE.Material>();
  const textures = new Set<THREE.Texture>();
  const skeletons = new Set<THREE.Skeleton>();
  root.traverse((object) => {
    if (object instanceof THREE.Mesh) {
      geometries.add(object.geometry);
      for (const material of Array.isArray(object.material) ? object.material : [object.material]) {
        materials.add(material);
        for (const value of Object.values(material)) if (value instanceof THREE.Texture) textures.add(value);
      }
    }
    if (object instanceof THREE.SkinnedMesh) skeletons.add(object.skeleton);
  });
  geometries.forEach((value) => value.dispose());
  materials.forEach((value) => value.dispose());
  textures.forEach((value) => {
    if (typeof ImageBitmap !== "undefined" && value.source.data instanceof ImageBitmap) value.source.data.close();
    value.dispose();
  });
  skeletons.forEach((value) => value.dispose());
}

export function createCharacterScene(
  host: HTMLElement,
  url: string,
  onReady: (motions: string[]) => void,
  onError: () => void,
  withMug = false,
): CharacterScene {
  const scene = new THREE.Scene();
  scene.background = new THREE.Color("#eee9dd");
  const camera = new THREE.PerspectiveCamera(34, 1, 0.01, 100);
  const renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1.25;
  renderer.domElement.setAttribute("aria-label", "ドラッグで回転、ピンチまたはホイールで拡大縮小");
  host.appendChild(renderer.domElement);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.enablePan = false;
  controls.maxPolarAngle = Math.PI * 0.51;
  scene.add(new THREE.HemisphereLight(0xfffaf0, 0x898b75, 2.6));
  const light = new THREE.DirectionalLight(0xffffff, 3.2);
  light.position.set(3, 5, 4);
  scene.add(light);
  const fill = new THREE.DirectionalLight(0xffffff, 1.4);
  fill.position.set(-3, 2, -3);
  scene.add(fill);
  const floor = new THREE.Mesh(new THREE.CircleGeometry(1.65, 64), new THREE.MeshStandardMaterial({ color: 0xd6d3c2, roughness: 1 }));
  floor.rotation.x = -Math.PI / 2;
  floor.position.y = -0.015;
  scene.add(floor);
  const abort = new AbortController();
  let disposed = false;
  let paused = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  let visible = true;
  let mixer: THREE.AnimationMixer | undefined;
  let model: THREE.Group | undefined;
  let mug: THREE.Group | undefined;
  let mugEnabled = withMug;
  let clips: THREE.AnimationClip[] = [];
  let current: THREE.AnimationAction | undefined;
  let height = 2;
  let width = 1;
  let frame = 0;
  let previous = 0;
  const reset = () => {
    const distance = Math.max(height * 0.66, width / Math.max(camera.aspect, 0.3) * 0.6) / Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
    controls.target.set(0, height * 0.49, 0);
    camera.position.set(0, height * 0.58, distance);
    controls.minDistance = height * 0.5;
    controls.maxDistance = distance * 2;
    controls.update();
  };
  const resize = () => {
    const { width: w, height: h } = host.getBoundingClientRect();
    if (!w || !h) return;
    renderer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    reset();
  };
  const observer = new ResizeObserver(resize);
  observer.observe(host);
  const intersection = new IntersectionObserver(([entry]) => { visible = entry.isIntersecting; });
  intersection.observe(host);
  const tick = (now: number) => {
    if (disposed) return;
    frame = requestAnimationFrame(tick);
    const delta = previous ? Math.min((now - previous) / 1000, 0.05) : 0;
    previous = now;
    if (document.hidden || !visible) return;
    if (!paused) mixer?.update(delta);
    if (withMug && model) setMugGrip(model, mugEnabled);
    controls.update();
    renderer.render(scene, camera);
  };
  const motion = (name: string) => {
    const clip = clips.find((candidate) => candidate.name === name);
    if (!clip || !mixer) return;
    if (paused) {
      mixer.stopAllAction();
      current = mixer.clipAction(clip).reset().play();
    } else {
      current?.fadeOut(0.2);
      current = mixer.clipAction(clip).reset().fadeIn(0.2).play();
    }
    mixer.update(0);
  };
  const contextLost = (event: Event) => { event.preventDefault(); onError(); };
  renderer.domElement.addEventListener("webglcontextlost", contextLost);
  resize();
  frame = requestAnimationFrame(tick);
  void (async () => {
    try {
      const response = await fetch(url, { signal: abort.signal });
      if (!response.ok) throw new Error(`Model HTTP ${response.status}`);
      const data = await response.arrayBuffer();
      if (disposed) return;
      const gltf = await new GLTFLoader().parseAsync(data, "");
      if (disposed) { release(gltf.scene); return; }
      model = gltf.scene;
      clips = gltf.animations;
      mixer = new THREE.AnimationMixer(model);
      motion(withMug ? "CharacterSheet_MugStand" : "Idle");
      if (withMug) {
        const loadedMug = await loadMug(abort.signal);
        if (disposed) { release(loadedMug); release(model); return; }
        try { mug = mountMug(model, loadedMug); } catch (error) { release(loadedMug); throw error; }
        mug.visible = mugEnabled;
        setMugGrip(model, mugEnabled);
      }
      model.updateMatrixWorld(true);
      const box = new THREE.Box3().setFromObject(model);
      const size = box.getSize(new THREE.Vector3());
      const center = box.getCenter(new THREE.Vector3());
      const scale = 2 / size.y;
      const pivot = new THREE.Group();
      pivot.scale.setScalar(scale);
      model.position.sub(new THREE.Vector3(center.x, box.min.y, center.z));
      pivot.add(model);
      scene.add(pivot);
      height = 2;
      width = size.x * scale;
      reset();
      onReady(clips.map((clip) => clip.name));
    } catch {
      if (!disposed) { if (model && !model.parent) release(model); onError(); }
    }
  })();
  return {
    motion,
    mug: (enabled) => { mugEnabled = enabled; if (mug) mug.visible = enabled; if (model) setMugGrip(model, enabled); },
    pause: (value) => { paused = value; },
    reset,
    dispose: () => {
      if (disposed) return;
      disposed = true;
      abort.abort();
      cancelAnimationFrame(frame);
      observer.disconnect();
      intersection.disconnect();
      controls.dispose();
      mixer?.stopAllAction();
      if (model) mixer?.uncacheRoot(model);
      release(scene);
      renderer.domElement.removeEventListener("webglcontextlost", contextLost);
      renderer.dispose();
      renderer.forceContextLoss();
      renderer.domElement.remove();
    },
  };
}
