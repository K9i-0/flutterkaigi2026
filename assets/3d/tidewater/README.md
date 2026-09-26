# Tidewater — adopted island geometry

Source: https://github.com/dgreenheck/tidewater
Revision: `4811ba48d795197de5621985f404e765c0b7c0ef`, seed 7.

The source project's MIT license is retained in `LICENSE-Tidewater`. This export uses original procedural island/village geometry. It does not bundle the scanned Poly Haven props, Rocketbox characters, audio, fonts or cloud textures.

- `island.glb`: 125 meshes, including terrain tiles, the village and pier. Basic vertex-color PBR; original procedural texture shading is not reproduced.
- `heights.bin`: 2048² little-endian float32 source heights after village foundation flattening. Samples at `origin + (index + 0.5) * texel`.
- `world.json`: provenance, coordinate convention inputs, collision boxes/cylinders, buildings and explicit omitted features.

Reproduce from repository root with `node 23_SOBAYA_TIDEWATER/tools/export_tidewater.mjs`. Optional first argument is a clean checkout at the pinned revision. The adapter executes upstream CPU generators without a browser or GPU. Outputs are canonical game inputs; games must reference these through relative symlinks rather than copies.

The display terrain samples at 4m; collision height retains 1m. This first export preserves island layout, not the full Tidewater material/vegetation/ocean appearance.
