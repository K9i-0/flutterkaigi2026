import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    buildScenes(
      buildInput: input,
      buildOutput: output,
      inputFilePaths: [
        'assets/models/sobaya_motion.glb',
        'assets/models/fukuchan_motion.glb',
      ],
      compressTextures: true,
    );
    await buildMaterials(buildInput: input, buildOutput: output);
  });
}
