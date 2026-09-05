"""Two baked garment helpers keep the loose shirt clear of raised thighs."""
import bpy,numpy as np
from mathutils import Vector


def setup_hem(body,rig):
    bpy.context.view_layer.objects.active=rig
    bpy.ops.object.mode_set(mode='EDIT')
    for side,s in [('L',1),('R',-1)]:
        b=rig.data.edit_bones.new('ShirtHem.'+side)
        b.head=(s*.12,-.13,1.04);b.tail=(s*.12,-.13,1.12);b.parent=rig.data.edit_bones['Hips']
        b.align_roll(Vector((0,-1,0)))
    bpy.ops.object.mode_set(mode='OBJECT')
    for side in ['L','R']:
        body.vertex_groups.new(name='ShirtHem.'+side)
        rig.pose.bones['ShirtHem.'+side].rotation_mode='QUATERNION'
    shader=body.data.materials[0].node_tree.nodes.get('Principled BSDF')
    image=shader.inputs['Base Color'].links[0].from_node.image
    pixels=np.empty(len(image.pixels),dtype=np.float32);image.pixels.foreach_get(pixels)
    pixels=pixels.reshape(image.size[1],image.size[0],4)
    uv=body.data.uv_layers.active.data
    cloth=set()
    for p in body.data.polygons:
        c=p.center
        if not (.90<c.z<1.19 and all(abs(body.data.vertices[i].co.x)<.265 for i in p.vertices)):continue
        coord=sum((uv[i].uv for i in p.loop_indices),Vector((0,0)))/len(p.loop_indices)
        color=pixels[int(coord.y*image.size[1])%image.size[1],int(coord.x*image.size[0])%image.size[0],:3]
        if min(color)>.45:cloth.update(p.vertices)
    for index in cloth:
        v=body.data.vertices[index];z=v.co.z
        amount=max(0,min(1,(1.17-z)/.13));amount=amount*amount*(3-2*amount)
        if not amount:continue
        original={body.vertex_groups[g.group].name:g.weight*(1-amount) for g in v.groups}
        right=max(0,min(1,(.055-v.co.x)/.11));right=right*right*(3-2*right)
        original['ShirtHem.R']=amount*right;original['ShirtHem.L']=amount*(1-right)
        for g in body.vertex_groups:g.remove([index])
        for n,w in original.items():
            if w>1e-6:body.vertex_groups[n].add([index],w,'REPLACE')
    bpy.context.view_layer.objects.active=body
    bpy.ops.object.vertex_group_limit_total(limit=4);bpy.ops.object.vertex_group_normalize_all(lock_active=False)
    print('GARMENT_VERTICES',len(cloth),flush=True)


def animate_hem(rig):
    for side in ['L','R']:
        hem=rig.pose.bones.get('ShirtHem.'+side)
        if hem is None:continue
        thigh=rig.pose.bones['Thigh.'+side]
        direction=(thigh.tail-thigh.head).normalized()
        amount=max(0,min(1,(-direction.y-.12)/.60))
        # The loose front hem lifts and moves away as the thigh approaches.
        delta=Vector((0,-.065*amount,.055*amount))
        hem.location=hem.bone.matrix_local.to_3x3().inverted()@delta
    bpy.context.view_layer.update()
