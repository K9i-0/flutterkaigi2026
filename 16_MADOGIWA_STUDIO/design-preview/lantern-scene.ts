import * as THREE from "three";
import { LANTERN_LINES } from "./lantern-label";

export type LanternScene = { setLit: (lit: boolean) => void; dispose: () => void };

/** A small, self-contained WebGL scene. No postprocessing or shadow maps. */
export async function createLanternScene(
  host: HTMLElement,
  initialLit: boolean,
  onUnavailable: () => void,
): Promise<LanternScene | null> {
  const loader = new THREE.TextureLoader();
  const loaded = await Promise.allSettled([
    loader.loadAsync("/themes/sakaba/washi.webp"),

  ]);
  if (!host.isConnected || loaded.some((result) => result.status === "rejected")) {
    loaded.forEach((result) => { if (result.status === "fulfilled") result.value.dispose(); });
    return null;
  }
  const textures = loaded.map((result) => (result as PromiseFulfilledResult<THREE.Texture>).value);
  const [paper] = textures;
  paper.colorSpace = THREE.SRGBColorSpace;
  // Real text, drawn with the bundled font: exact wording in both renderers.
  try {
    const font = await new FontFace("Lantern Brush", "url(/themes/sakaba/lantern-lettering.ttf)").load();
    document.fonts.add(font);
  } catch { /* System Japanese serif remains legible if the font cannot load. */ }
  if (!host.isConnected) { paper.dispose(); return null; }
  const labelCanvas = document.createElement("canvas");
  labelCanvas.width = 512;
  labelCanvas.height = 768;
  const pen = labelCanvas.getContext("2d");
  if (!pen) { paper.dispose(); return null; }
  pen.font = '146px "Lantern Brush", "Yu Mincho", serif';
  pen.textAlign = "center";
  pen.textBaseline = "middle";
  pen.lineJoin = "round";
  pen.lineWidth = 14;
  pen.strokeStyle = "#ffcf9b";
  pen.fillStyle = "#090503";
  LANTERN_LINES.forEach((line, column) => {
    [...line].forEach((letter, row) => {
      const x = column === 0 ? 365 : 145;
      const y = (column === 0 ? 175 : 100) + row * 135;
      pen.lineWidth = 14;
      pen.strokeStyle = "#ffcf9b";
      pen.strokeText(letter, x, y);
      pen.lineWidth = 12;
      pen.strokeStyle = "#160d09";
      pen.strokeText(letter, x, y);
      pen.fillText(letter, x, y);
    });
  });
  const lettering = new THREE.CanvasTexture(labelCanvas);
  lettering.colorSpace = THREE.SRGBColorSpace;
  textures.push(lettering);
  let renderer: THREE.WebGLRenderer;
  try {
    renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, powerPreference: "low-power" });
  } catch {
    textures.forEach((texture) => texture.dispose());
    return null;
  }
  renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
  renderer.outputColorSpace = THREE.SRGBColorSpace;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 1;
  renderer.setClearColor(0, 0);
  renderer.domElement.setAttribute("aria-hidden", "true");
  host.append(renderer.domElement);

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(34, 1, 0.1, 25);
  camera.position.set(0, 0.05, 6.3);
  camera.lookAt(0, -0.03, 0);
  const hanger = new THREE.Group();
  hanger.position.y = 1.65;
  const lantern = new THREE.Group();
  lantern.position.y = -1.6;
  hanger.add(lantern);
  scene.add(hanger);
  const geometries: THREE.BufferGeometry[] = [];
  const materials: THREE.Material[] = [];
  function mesh(geometry: THREE.BufferGeometry, material: THREE.Material, parent: THREE.Group = lantern) {
    geometries.push(geometry);
    if (!materials.includes(material)) materials.push(material);
    const item = new THREE.Mesh(geometry, material);
    parent.add(item);
    return item;
  }
  const radius = (y: number) => {
    const t = THREE.MathUtils.clamp((y + 1.13) / 2.26, 0, 1);
    return 0.43 + 0.32 * Math.pow(Math.sin(Math.PI * t), 0.5);
  };
  const profile: THREE.Vector2[] = [];
  for (let i = 0; i <= 90; i++) {
    const y = -1.13 + i * 2.26 / 90;
    profile.push(new THREE.Vector2(radius(y) + Math.cos(i / 90 * Math.PI * 46) * 0.008, y));
  }
  const shadeMaterial = new THREE.MeshStandardMaterial({
    map: paper, color: 0xcd2417, roughness: 0.94,
    emissive: 0xff3210, emissiveMap: paper, emissiveIntensity: 0.7,
    side: THREE.DoubleSide,
  });
  mesh(new THREE.LatheGeometry(profile, 48), shadeMaterial);
  const bamboo = new THREE.MeshStandardMaterial({ color: 0x97271b, roughness: 0.85, emissive: 0xc52d12, emissiveIntensity: 0.25 });
  // Physical bamboo rings cast readable self-shading without a shadow map.
  for (let i = 0; i < 25; i++) {
    const y = -1.1 + i * 2.2 / 24;
    const ring = mesh(new THREE.TorusGeometry(radius(y) + 0.006, 0.005, 4, 48), bamboo);
    ring.rotation.x = Math.PI / 2;
    ring.position.y = y;
  }
  const lacquer = new THREE.MeshStandardMaterial({ color: 0x261b18, roughness: 0.45, metalness: 0.12 });
  for (const y of [-1.18, 1.18]) {
    const cap = mesh(new THREE.CylinderGeometry(0.445, 0.445, 0.13, 40), lacquer);
    cap.position.y = y;
    const lip = mesh(new THREE.TorusGeometry(0.442, 0.025, 6, 40), lacquer);
    lip.rotation.x = Math.PI / 2;
    lip.position.y = y + (y > 0 ? 0.07 : -0.07);
  }
  const wireMaterial = new THREE.MeshStandardMaterial({ color: 0x4b4132, metalness: 0.5, roughness: 0.7 });
  const wire = mesh(new THREE.TorusGeometry(0.32, 0.019, 6, 32, Math.PI), wireMaterial);
  wire.position.y = 1.22;
  const cord = mesh(new THREE.CylinderGeometry(0.018, 0.018, 0.34, 6), wireMaterial);
  cord.position.y = 1.68;

  // Vertical lettering follows the curved paper instead of floating on a flat plane.
  const decal = new THREE.PlaneGeometry(1, 1, 32, 26);
  const positions = decal.attributes.position;
  const uv = decal.attributes.uv;
  for (let i = 0; i < positions.count; i++) {
    const angle = (uv.getX(i) - 0.5) * 1.65;
    const y = (uv.getY(i) - 0.5) * 1.99 + 0.02;
    const r = radius(y) + 0.017;
    positions.setXYZ(i, Math.sin(angle) * r, y, Math.cos(angle) * r);
  }
  decal.computeVertexNormals();
  const ink = new THREE.MeshBasicMaterial({ map: lettering, transparent: true, alphaTest: 0.015, depthWrite: false, color: 0xffffff });
  mesh(decal, ink);
  // Fine ribs continue across the lettering, as they do under real paper.
  const seamInk = new THREE.MeshBasicMaterial({ color: 0x631c15, transparent: true, opacity: 0.16 });
  for (let i = 0; i < 17; i++) {
    const y = -0.77 + i * 0.096;
    const rib = mesh(new THREE.TorusGeometry(radius(y) + 0.022, 0.003, 3, 48), seamInk);
    rib.rotation.x = Math.PI / 2;
    rib.position.y = y;
  }
  scene.add(new THREE.HemisphereLight(0xfff4df, 0x40352b, 1.8));
  const key = new THREE.DirectionalLight(0xffedd1, 2.1);
  key.position.set(-2, 3, 5);
  scene.add(key);
  const glow = new THREE.PointLight(0xffa33d, 1.7, 5, 2);
  glow.position.set(0, 0, 1.1);
  lantern.add(glow);

  let lit = initialLit;
  let active = true;
  let visible = true;
  let frame = 0;
  let last = 0;
  let frames = 0;
  const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
  const draw = (time: number) => {
    const t = time / 1000;
    hanger.rotation.z = motion.matches ? -0.025 : Math.sin(t * 0.72) * 0.022 - 0.015;
    lantern.rotation.y = motion.matches ? -0.07 : Math.sin(t * 0.46) * 0.085 - 0.07;
    shadeMaterial.emissiveIntensity = lit ? 0.5 + (motion.matches ? 0 : Math.sin(t * 1.4) * 0.018) : 0;
    shadeMaterial.color.set(lit ? 0xcd2417 : 0x701a16);
    ink.color.set(lit ? 0xffffff : 0xb49a83);
    glow.intensity = lit ? 1.7 : 0;
    renderer.render(scene, camera);
    host.dataset.frames = String(++frames);
  };
  const tick = (time: number) => {
    if (!active || !visible || document.hidden || motion.matches) { frame = 0; return; }
    if (time - last >= 1000 / 30) { draw(time); last = time; }
    frame = requestAnimationFrame(tick);
  };
  function refresh() {
    cancelAnimationFrame(frame);
    frame = 0;
    if (!active || !visible || document.hidden) return;
    draw(performance.now());
    if (!motion.matches) frame = requestAnimationFrame(tick);
  }
  const resize = new ResizeObserver(() => {
    const { width, height } = host.getBoundingClientRect();
    if (!width || !height || !active) return;
    renderer.setSize(width, height, false);
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    refresh();
  });
  resize.observe(host);
  const intersection = new IntersectionObserver(([entry]) => {
    visible = entry.isIntersecting;
    host.dataset.visible = String(visible);
    refresh();
  });
  intersection.observe(host);
  const contextLost = (event: Event) => { event.preventDefault(); dispose(); onUnavailable(); };
  renderer.domElement.addEventListener("webglcontextlost", contextLost);
  document.addEventListener("visibilitychange", refresh);
  motion.addEventListener("change", refresh);
  function dispose() {
    if (!active) return;
    active = false;
    cancelAnimationFrame(frame);
    resize.disconnect();
    intersection.disconnect();
    document.removeEventListener("visibilitychange", refresh);
    motion.removeEventListener("change", refresh);
    renderer.domElement.removeEventListener("webglcontextlost", contextLost);
    geometries.forEach((geometry) => geometry.dispose());
    materials.forEach((material) => material.dispose());
    textures.forEach((texture) => texture.dispose());
    renderer.dispose();
    renderer.domElement.remove();
    delete host.dataset.frames;
    delete host.dataset.visible;
  }
  return {
    setLit(next) { lit = next; refresh(); },
    dispose,
  };
}
