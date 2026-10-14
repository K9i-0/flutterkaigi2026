"""Stage a completely local Three.js viewer and the same sampler used by Remotion."""
import shutil
import subprocess
from pathlib import Path

project = Path(__file__).resolve().parent
public = project / "public"
for name in ("rig-preview.html", "rig-viewer.js", "camera-preview.html", "camera-viewer.js"):
    shutil.copy2(project / "viewer" / name, public / name)
modules = (
    "build/three.module.js", "build/three.core.js",
    "examples/jsm/loaders/GLTFLoader.js",
    "examples/jsm/utils/BufferGeometryUtils.js",
    "examples/jsm/utils/SkeletonUtils.js",
    "examples/jsm/controls/OrbitControls.js",
)
for module in modules:
    destination = public / "vendor" / "three" / module
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(project / "node_modules" / "three" / module, destination)
subprocess.run([str(project / "node_modules/.bin/tsc"), "src/rig-sampler.ts", "src/camera-equipment.ts",
                "--target", "ES2020", "--module", "ESNext", "--moduleResolution", "Bundler",
                "--skipLibCheck", "--outDir", "public/riglib"], cwd=project, check=True)
# The Remotion bundler resolves .ts imports; native browser ES modules need .js.
equipment_module = public / "riglib/camera-equipment.js"
equipment_module.write_text(equipment_module.read_text().replace("'./rig-sampler'", "'./rig-sampler.js'"))
(public / "riglib/package.json").write_text('{"type":"module"}\n')
print("Local viewer: http://127.0.0.1:8138/rig-preview.html")
print("Camera viewer: http://127.0.0.1:8138/camera-preview.html")
