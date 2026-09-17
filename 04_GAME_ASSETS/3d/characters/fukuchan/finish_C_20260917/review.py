import bpy,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
QA=OUT/'qa';QA.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
bpy.context.scene.render.fps=30
bpy.ops.import_scene.gltf(filepath=str(OUT/'fukuchan_finished.glb'))
sc = bpy.context.scene
sc.render.engine = 'CYCLES'
sc.cycles.samples = 24
sc.cycles.use_denoising = True
sc.render.resolution_percentage = 100
sc.view_settings.view_transform = 'AgX'
world = bpy.data.worlds.new('ReviewStudio')
world.use_nodes = True
world.node_tree.nodes['Background'].inputs[0].default_value = (.42,.45,.48,1)
world.node_tree.nodes['Background'].inputs[1].default_value = .55
sc.world = world
cam = bpy.data.objects.new('ReviewCamera', bpy.data.cameras.new('ReviewCamera'))
sc.collection.objects.link(cam)
cam.data.type = 'ORTHO'
sc.camera = cam
for name, pos, power, size in [('Key',(-3,-4,5),550,5),('Fill',(4,-1,3),350,4),('Rim',(1,3,4),500,3)]:
    lamp = bpy.data.lights.new(name,'AREA')
    lamp.energy = power
    lamp.shape = 'DISK'
    lamp.size = size
    obj = bpy.data.objects.new(name,lamp)
    sc.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (Vector((0,0,1))-obj.location).to_track_quat('-Z','Y').to_euler()
def render(name, direction, target=(0,0,.85), size=1.94):
    point = Vector(target)
    cam.location = point + Vector(direction).normalized()*5
    cam.rotation_euler = (point-cam.location).to_track_quat('-Z','Y').to_euler()
    cam.data.ortho_scale = size
    sc.render.resolution_x = 900
    sc.render.resolution_y = 1000
    sc.render.image_settings.file_format = 'PNG'
    sc.render.filepath = str(QA / (name+'.png'))
    bpy.ops.render.render(write_still=True)
for name, direction in ([] if '--quick' in sys.argv else [('front',(0,-1,0)),('three_quarter',(.6,-1,0)),('left',(1,0,0)),('back',(0,1,0)),('right',(-1,0,0))]):
    render(name, direction)
for name, direction in [('face_front',(0,-1,0)),('face_three_quarter',(.6,-1,0)),('face_profile',(1,0,0))]:
    render(name, direction, (0,0,1.535), .43)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / 'fukuchan_finished_review.blend'))
render('badge', (0,-1,0), (0,0,1.032), .18)
print('FINISHED_REVIEW_DONE',flush=True)
