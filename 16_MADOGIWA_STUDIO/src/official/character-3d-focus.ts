import * as THREE from "three";

/** Fit a detail in both portrait and landscape viewports. */
export function detailDistance(camera: THREE.PerspectiveCamera, radius: number) {
  const vertical = THREE.MathUtils.degToRad(camera.fov / 2);
  const horizontal = Math.atan(Math.tan(vertical) * camera.aspect);
  return radius / Math.sin(Math.min(vertical, horizontal));
}

/** Use the actual posed head, including large non-human heads and their hair. */
export function posedHeadBounds(model: THREE.Object3D) {
  model.updateWorldMatrix(true, false);
  // SkinnedMesh updates its inverse bind transform in updateMatrixWorld.
  model.updateMatrixWorld(true);
  const head = model.getObjectByName("Head");
  const bones = new Set<THREE.Object3D>();
  head?.traverse((object) => bones.add(object));
  const box = new THREE.Box3();
  const point = new THREE.Vector3();
  model.traverse((object) => {
    if (!(object instanceof THREE.SkinnedMesh)) return;
    const indices = object.geometry.getAttribute("skinIndex");
    const weights = object.geometry.getAttribute("skinWeight");
    if (!indices || !weights) return;
    object.skeleton.update();
    for (let i = 0; i < indices.count; i++) {
      let influence = 0;
      for (let c = 0; c < 4; c++) if (bones.has(object.skeleton.bones[indices.getComponent(i, c)])) influence += weights.getComponent(i, c);
      if (influence > 0.5) box.expandByPoint(object.getVertexPosition(i, point).applyMatrix4(object.matrixWorld));
    }
  });
  return box;
}

type Tap = { x: number; y: number; time: number; kind: string };

/** A drag, long press, cancellation, or multi-touch gesture cannot select a detail. */
export class DetailTapGesture {
  private pointers = new Set<number>();
  private start?: Tap;
  private previous?: Tap;

  down(id: number, tap: Tap) {
    this.pointers.add(id);
    if (this.pointers.size === 1) this.start = tap;
    else this.cancelTap();
  }

  move(x: number, y: number) {
    if (this.start && Math.hypot(x - this.start.x, y - this.start.y) > 8) this.cancelTap();
  }

  up(id: number, tap: Tap) {
    const tracked = this.pointers.delete(id);
    if (!tracked || this.pointers.size || !this.start) return false;
    const start = this.start;
    this.start = undefined;
    if (tap.time - start.time > 280 || Math.hypot(tap.x - start.x, tap.y - start.y) > 8) {
      this.previous = undefined;
      return false;
    }
    const previous = this.previous;
    const match = !!previous && tap.kind === previous.kind && tap.time - previous.time < 340
      && Math.hypot(tap.x - previous.x, tap.y - previous.y) < 24;
    this.previous = match ? undefined : tap;
    return match;
  }

  cancel(id: number) {
    if (this.pointers.delete(id)) this.cancelTap();
  }

  private cancelTap() {
    this.start = undefined;
    this.previous = undefined;
  }
}
