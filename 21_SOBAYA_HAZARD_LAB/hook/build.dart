import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    // flutter_scene:init:start
    // Import .glb and .fscene sources under assets/, loadable by source path
    // with loadScene (and hot-reloadable). A no-op when there are no scenes.
    buildScenes(
      buildInput: input,
      buildOutput: output,
      // Discovery deliberately excludes symlinks. Keep the canonical GLB shared.
      inputFilePaths: [
        'assets/models/sobaya.glb',
        'assets/models/beer_mug.glb',
        'assets/models/village.glb',
        'assets/models/farm.glb',
        'assets/models/mountain.glb',
        'assets/models/items.glb',
        'assets/models/fukuchan.glb',
        'assets/models/yametaro.glb',
        'assets/models/takosan.glb',
      ],
      compressTextures: true,
    );
    // Compile .fmat materials under assets/, loadable by source path with
    // loadFmatMaterial (and hot-reloadable). A no-op when there are none.
    await buildMaterials(buildInput: input, buildOutput: output);
    // flutter_scene:init:end
  });
}
