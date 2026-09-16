"""Remove the central U-shaped remnant, leaving all six radial legs intact."""
import bmesh

def clean_center(body):
    mesh = body.data
    labels = mesh.attributes['RigRegion']
    eligible = {v.index for v in mesh.vertices if labels.data[v.index].value == 1 and v.co.z < .31}
    adjacency = [[] for _ in mesh.vertices]
    for edge in mesh.edges:
        a, b = edge.vertices
        adjacency[a].append(b); adjacency[b].append(a)
    groups = []
    while eligible:
        stack = [eligible.pop()]; group = []
        while stack:
            i = stack.pop(); group.append(i)
            for j in adjacency[i]:
                if j in eligible:
                    eligible.remove(j); stack.append(j)
        groups.append(group)
    candidates = [g for g in groups if len(g) > 100 and
                  max(abs(mesh.vertices[i].co.x) for i in g) < .19 and
                  max(mesh.vertices[i].co.z for i in g) < .27]
    assert len(candidates) == 1, 'Expected one central remnant; do not modify an unknown mesh'
    selected = candidates[0]
    bm = bmesh.new(); bm.from_mesh(mesh); bm.verts.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.verts[i] for i in selected], context='VERTS')
    new_boundaries = [e for e in bm.edges if e.is_boundary and all(v.co.z < .36 and v.co.xy.length < .27 for v in e.verts)]
    caps = bmesh.ops.holes_fill(bm, edges=new_boundaries, sides=0)['faces']
    for face in caps:
        face.material_index = 1  # Existing untextured, dark cloth lining.
        face.smooth = False
    bmesh.ops.recalc_face_normals(bm, faces=list(bm.faces))
    bm.to_mesh(mesh); bm.free(); mesh.update()
    return {'removed_vertices': len(selected), 'cap_faces': len(caps)}
