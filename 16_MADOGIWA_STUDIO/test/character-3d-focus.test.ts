import { describe, expect, it } from "vitest";
import * as THREE from "three";
import { detailDistance, DetailTapGesture, posedHeadBounds } from "../src/official/character-3d-focus";

const tap = (time: number, x = 100, y = 100, kind = "touch") => ({ time, x, y, kind });

describe("detail inspection gestures", () => {
  it("accepts touch and mouse double taps, including normal capture release", () => {
    for (const kind of ["touch", "mouse"]) {
      const g = new DetailTapGesture();
      g.down(1, tap(0, 100, 100, kind));
      expect(g.up(1, tap(60, 100, 100, kind))).toBe(false);
      g.cancel(1); // lostpointercapture follows an ordinary pointerup
      g.down(2, tap(180, 104, 102, kind));
      expect(g.up(2, tap(220, 104, 102, kind))).toBe(true);
    }
  });
  it("does not select after dragging away and back", () => {
    const g = new DetailTapGesture();
    g.down(1, tap(0)); g.up(1, tap(40));
    g.down(1, tap(100)); g.move(140, 100); g.move(100, 100);
    expect(g.up(1, tap(160))).toBe(false);
    g.down(1, tap(200));
    expect(g.up(1, tap(240))).toBe(false);
  });
  it("does not interpret pinch or two-finger pan as a double tap", () => {
    const g = new DetailTapGesture();
    g.down(1, tap(0)); g.up(1, tap(40));
    g.down(1, tap(80)); g.down(2, tap(90, 120));
    expect(g.up(2, tap(130, 120))).toBe(false);
    expect(g.up(1, tap(140))).toBe(false);
    g.down(1, tap(180));
    expect(g.up(1, tap(220))).toBe(false);
  });
  it("rejects cancelled, long, distant and delayed taps", () => {
    for (const action of ["cancel", "long", "distant", "late"]) {
      const g = new DetailTapGesture();
      g.down(1, tap(0)); g.up(1, tap(40));
      g.down(1, tap(100, action === "distant" ? 150 : 100));
      if (action === "cancel") g.cancel(1);
      expect(g.up(1, tap(action === "long" || action === "late" ? 500 : 150, action === "distant" ? 150 : 100))).toBe(false);
    }
  });
});

describe("detail framing", () => {
  it("measures a posed head instead of including the torso or assuming human proportions", () => {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute("position", new THREE.Float32BufferAttribute([-1, 1, 0, 1, 3, 0, 0, -5, 0], 3));
    geometry.setAttribute("skinIndex", new THREE.Uint16BufferAttribute([1, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 0], 4));
    geometry.setAttribute("skinWeight", new THREE.Float32BufferAttribute([1, 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0], 4));
    const mesh = new THREE.SkinnedMesh(geometry, new THREE.MeshBasicMaterial());
    const root = new THREE.Bone(), head = new THREE.Bone(); head.name = "Head";
    root.add(head); mesh.add(root); mesh.bind(new THREE.Skeleton([root, head]));
    head.position.y = 1;
    const group = new THREE.Group(); group.add(mesh); group.scale.setScalar(2);
    const box = posedHeadBounds(group);
    expect(box.min.toArray()).toEqual([-2, 4, 0]);
    expect(box.max.toArray()).toEqual([2, 8, 0]);
  });
  it("fits the same detail in narrow mobile and wide desktop views", () => {
    for (const aspect of [.55, 1, 1.8]) {
      const camera = new THREE.PerspectiveCamera(34, aspect, .01, 100);
      const target = new THREE.Vector3(.7, 1.8, -.2), radius = .24;
      camera.position.copy(target).add(new THREE.Vector3(0, 0, detailDistance(camera, radius)));
      camera.lookAt(target); camera.updateMatrixWorld();
      const center = target.clone().project(camera);
      expect(Math.abs(center.x) + Math.abs(center.y)).toBeLessThan(1e-6);
      for (const offset of [new THREE.Vector3(radius, 0, 0), new THREE.Vector3(0, radius, 0)]) {
        const edge = target.clone().add(offset).project(camera);
        expect(Math.max(Math.abs(edge.x), Math.abs(edge.y))).toBeLessThanOrEqual(1);
      }
    }
  });
});
