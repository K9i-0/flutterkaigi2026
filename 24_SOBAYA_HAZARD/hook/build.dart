import 'package:flutter_scene/build_hooks.dart';
import 'package:hooks/hooks.dart';
void main(List<String> args) async {
  await build(args,(input,output) async {
    buildScenes(buildInput: input,buildOutput:output,inputFilePaths:[
      'assets/models/yard.glb','assets/models/fukuchan.glb','assets/models/sobaya.glb']);
    await buildMaterials(buildInput:input,buildOutput:output);
  });
}
