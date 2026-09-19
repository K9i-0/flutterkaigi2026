import * as THREE from "three";
import { GLTFLoader } from "three/addons/loaders/GLTFLoader.js";
import { OrbitControls } from "three/addons/controls/OrbitControls.js";

import { loadMug, mountMug, setMugGrip } from "./character-mug";
import { detailDistance, DetailTapGesture, posedHeadBounds } from "./character-3d-focus";

export type CharacterScene = {
  motion: (name: string) => void;
  mug: (enabled: boolean) => void;
  pause: (paused: boolean) => void;
  reset: () => void;
  face: () => void;
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
  renderer.domElement.setAttribute("aria-label", "ドラッグで回転、2本指または右ドラッグで移動、ピンチやホイールで拡大。見たい場所をダブルタップでアップ");
  host.appendChild(renderer.domElement);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enableDamping = true;
  controls.enablePan = true;
  controls.screenSpacePanning = true;
  controls.zoomToCursor = true;
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
  const clearMomentum = () => {
    controls.enableDamping = false;
    controls.update();
    controls.enableDamping = true;
  };
  const reset = () => {
    clearMomentum();
    const distance = Math.max(height * 0.66, width / Math.max(camera.aspect, 0.3) * 0.6) / Math.tan(THREE.MathUtils.degToRad(camera.fov / 2));
    controls.target.set(0, height * 0.49, 0);
    camera.position.set(0, height * 0.58, distance);
    controls.minDistance = height * 0.07;
    controls.maxDistance = distance * 2;
    controls.update();
  };
  const focus = (point: THREE.Vector3, radius: number, front = false, depth = 0) => {
    clearMomentum();
    const direction = front ? new THREE.Vector3(0, 0, 1) : camera.position.clone().sub(controls.target).normalize();
    const distance = THREE.MathUtils.clamp(detailDistance(camera, radius) + depth, controls.minDistance, controls.maxDistance);
    controls.target.copy(point);
    camera.position.copy(point).addScaledVector(direction, distance);
    controls.update();
  };
  const face = () => {
    if (!model) return;
    const bounds = posedHeadBounds(model);
    if (!bounds.isEmpty()) {
      const size = bounds.getSize(new THREE.Vector3());
      focus(bounds.getCenter(new THREE.Vector3()), Math.max(size.x, size.y) * 0.58, true, size.z * 0.5);
      return;
    }
    model.updateWorldMatrix(true, true);
    const leftEye = model.getObjectByName("Eye_L");
    const rightEye = model.getObjectByName("Eye_R");
    if (leftEye && rightEye) {
      const eyes = new THREE.Box3().setFromObject(leftEye).union(new THREE.Box3().setFromObject(rightEye));
      focus(eyes.getCenter(new THREE.Vector3()), Math.max(eyes.getSize(new THREE.Vector3()).x * 0.7, height * 0.25), true);
      return;
    }
    const head = model.getObjectByName("Head");
    const point = head ? head.getWorldPosition(new THREE.Vector3()).add(new THREE.Vector3(0, height * 0.045, 0))
      : new THREE.Vector3(0, height * 0.86, 0);
    focus(point, height * 0.12, true);
  };
  const raycaster = new THREE.Raycaster();
  const pickDetail = (x: number, y: number) => {
    if (!model) return;
    const bounds = renderer.domElement.getBoundingClientRect();
    if (!bounds.width || !bounds.height) return;
    model.updateWorldMatrix(true, false);
    model.updateMatrixWorld(true);
    model.traverse((object) => {
      if (object instanceof THREE.SkinnedMesh) {
        object.skeleton.update();
        // Animated hands can move outside their previous/rest-pose bounding sphere.
        object.computeBoundingSphere();
        if (object.boundingBox) object.computeBoundingBox();
      }
    });
    camera.updateMatrixWorld();
    raycaster.setFromCamera(new THREE.Vector2((x - bounds.left) / bounds.width * 2 - 1, 1 - (y - bounds.top) / bounds.height * 2), camera);
    const hit = raycaster.intersectObject(model, true).find(({ object }) => {
      for (let parent: THREE.Object3D | null = object; parent; parent = parent.parent) if (!parent.visible) return false;
      return true;
    });
    if (hit) focus(hit.point, height * 0.075);
  };
  const taps = new DetailTapGesture();
  const tap = (event: PointerEvent) => ({ x: event.clientX, y: event.clientY, time: event.timeStamp, kind: event.pointerType });
  const pointerDown = (event: PointerEvent) => {
    if (event.button === 0) taps.down(event.pointerId, tap(event));
  };
  const pointerMove = (event: PointerEvent) => taps.move(event.clientX, event.clientY);
  const pointerUp = (event: PointerEvent) => {
    if (taps.up(event.pointerId, tap(event))) pickDetail(event.clientX, event.clientY);
  };
  const pointerCancel = (event: PointerEvent) => taps.cancel(event.pointerId);
  const canvas = renderer.domElement;
  canvas.addEventListener("pointerdown", pointerDown);
  canvas.addEventListener("pointermove", pointerMove);
  canvas.addEventListener("pointerup", pointerUp);
  canvas.addEventListener("pointercancel", pointerCancel);
  canvas.addEventListener("lostpointercapture", pointerCancel);
  let sized = false;
  const resize = () => {
    const { width: w, height: h } = host.getBoundingClientRect();
    if (!w || !h) return;
    renderer.setSize(w, h);
    camera.aspect = w / h;
    camera.updateProjectionMatrix();
    // Preserve the chosen detail when mobile browser chrome or the dialog resizes.
    if (!sized) { reset(); sized = true; }
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
    face,
    dispose: () => {
      if (disposed) return;
      disposed = true;
      abort.abort();
      cancelAnimationFrame(frame);
      observer.disconnect();
      intersection.disconnect();
      controls.dispose();
      canvas.removeEventListener("pointerdown", pointerDown);
      canvas.removeEventListener("pointermove", pointerMove);
      canvas.removeEventListener("pointerup", pointerUp);
      canvas.removeEventListener("pointercancel", pointerCancel);
      canvas.removeEventListener("lostpointercapture", pointerCancel);
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
