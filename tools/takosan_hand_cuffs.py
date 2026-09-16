"""Finish the lower sleeve opening after replacing the generated hand cluster."""
import bmesh

def finish_cuffs(body):
    bm=bmesh.new();bm.from_mesh(body.data)
    labels=bm.verts.layers.int['RigRegion']
    edges=[e for e in bm.edges if e.is_boundary and all(v[labels] in (2,3) and v.co.z<.50 for v in e.verts)]
    vertices={v for e in edges for v in e.verts}
    for v in vertices:
        v.co.z=(.252+.383*abs(v.co.x))/.924
    caps=bmesh.ops.holes_fill(bm,edges=edges,sides=0)['faces']
    for f in caps:f.material_index=1;f.smooth=False
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(body.data);bm.free();body.data.update()
    return {'cuff_boundary_vertices':len(vertices),'cuff_caps':len(caps)}
