import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';

void main(List<String> args) async {
  await build(args, (input, output) async {
    buildScenes(
      buildInput: input,
      buildOutput: output,
      inputFilePaths: [
        'assets/models/sobaya.glb',
        'assets/models/super_try.glb',
        'assets/models/light.glb',
        'assets/models/happoshu.glb',
        'assets/models/super_try_lane.glb',
        'assets/models/light_lane.glb',
        'assets/models/happoshu_lane.glb',
      ],
    );
  });
}
