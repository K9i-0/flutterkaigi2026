"""Two baked garment helpers keep the loose shirt clear of raised thighs."""
import bpy,numpy as np
from mathutils import Vector


def relax_hem_weights(body):
    """Blend the generated shirt/pants seam across connected waist vertices.

    Texture thresholding in setup_hem can put adjacent vertices entirely on
    the hem and thigh respectively. A raised knee then stretches tiny seam
    edges into spikes. Relax only this waist band, preserving rest geometry,
    UVs and the weights on the legs, hands and shoulders.
    Apply once to the rig_v2 baseline before baking the game rig.
    """
    count = len(body.data.vertices)
    weights = np.zeros((count, len(body.vertex_groups)), dtype=np.float64)
    neighbors = [[] for _ in range(count)]
    for edge in body.data.edges:
        a, b = edge.vertices
        neighbors[a].append(b)
        neighbors[b].append(a)
    def smooth(value):
        v = max(0, min(1, value))
        return v * v * (3 - 2 * v)
    amount = {}
    for vertex in body.data.vertices:
        for group in vertex.groups:
            weights[vertex.index, group.group] = group.weight
        x, y, z = vertex.co
        # The raised thigh lifts the front cloth. Pulling the rear hem forward
        # as well exposes the inside of the generated waistband.
        front = smooth((.08 - y) / .18)
        for name in ['ShirtHem.L', 'ShirtHem.R']:
            group = body.vertex_groups[name].index
            rear = weights[vertex.index, group] * (1 - front)
            weights[vertex.index, group] -= rear
            weights[vertex.index, body.vertex_groups['Hips'].index] += rear
        # Keep the waistband on the pelvis; introduce thigh rotation below
        # it gradually instead of allowing the raised leg to open the waist.
        pelvis = smooth((z - .80) / .15) * smooth((.30 - abs(x)) / .035)
        for name in ['Thigh.L', 'Thigh.R']:
            group = body.vertex_groups[name].index
            transferred = weights[vertex.index, group] * pelvis
            weights[vertex.index, group] -= transferred
            weights[vertex.index, body.vertex_groups['Hips'].index] += transferred
        blend = (smooth((z - .80) / .07) * smooth((1.20 - z) / .08)
                 * smooth((.30 - abs(x)) / .035))
        if blend and neighbors[vertex.index]:
            amount[vertex.index] = .55 * blend
    for _ in range(16):
        updated = weights.copy()
        for index, blend in amount.items():
            updated[index] = ((1 - blend) * weights[index]
                              + blend * weights[neighbors[index]].mean(axis=0))
        weights = updated
    for index in amount:
        for group in body.vertex_groups:
            group.remove([index])
        chosen = np.argsort(weights[index])[-4:]
        total = weights[index, chosen].sum()
        for group_index in chosen:
            weight = weights[index, group_index] / total
            if weight > 1e-6:
                body.vertex_groups[int(group_index)].add([index], float(weight), 'REPLACE')
    return {'method': '16 connected-neighbor relaxation passes on waist weights',
            'vertices': len(amount), 'maximum_influences': 4}


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
