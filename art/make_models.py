# Builds every model in Hubble Bubble: Granny Grumblewart and the witches who come to her window,
# the ingredients on her table, the bellows, the stirring stick, the wand, the bottles, the book and
# the cauldron. Writes an editable .blend for each into art/ and a .glb into models/.
#
#   blender --background --python art/make_models.py -- <project folder> [only]
#
# Blender's own space: Z up, a witch faces -Y, her left hand is +X.
#
# The witches are each one smooth mesh, skinned to a skeleton: bodies are lathed, limbs and noses
# grown with the Skin modifier, all of it smoothed with subdivision, then painted (colour on the
# corners, no textures, the way the old console games did it). The game moves the bones itself:
# arms reach with two-bone IK, eyes look and blink, the mouth talks.

import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Matrix, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:]
ROOT = ARGS[0]
ONLY = ARGS[1] if len(ARGS) > 1 else ""


def lin(c):
    if isinstance(c, Vector):
        return c.copy()
    c = c.lstrip("#")
    out = []
    for i in (0, 2, 4):
        v = int(c[i:i + 2], 16) / 255.0
        out.append(v / 12.92 if v <= 0.04045 else ((v + 0.055) / 1.055) ** 2.4)
    return Vector((out[0], out[1], out[2]))


def shade(c, k):
    """A colour (hex) made lighter (k > 0) or darker (k < 0)"""
    v = lin(c)
    if k >= 0:
        return v.lerp(Vector((1, 1, 1)), k)
    return v * (1.0 + k)


def fresh():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def bake(ob):
    """Applies an object's modifiers: a new object with the result, the old one removed"""
    dg = bpy.context.evaluated_depsgraph_get()
    me = bpy.data.meshes.new_from_object(ob.evaluated_get(dg))
    out = link(bpy.data.objects.new(ob.name, me))
    bpy.data.objects.remove(ob)
    return out


def grow(name, points, edges, radii, sub=2, smooth=True):
    """A limb, a nose, a strand of hair: the Skin modifier round a line of points, then smoothed"""
    me = bpy.data.meshes.new(name)
    me.from_pydata([tuple(p) for p in points], edges, [])
    ob = link(bpy.data.objects.new(name, me))
    ob.modifiers.new("skin", "SKIN")
    for i, r in enumerate(radii):
        rr = r if isinstance(r, (tuple, list)) else (r, r)
        me.skin_vertices[0].data[i].radius = rr
    me.skin_vertices[0].data[0].use_root = True
    if sub:
        ob.modifiers.new("sub", "SUBSURF").levels = sub
    ob = bake(ob)
    if smooth:
        for p in ob.data.polygons:
            p.use_smooth = True
    return ob


def lathe(name, rings, seg=24, sub=1, cap_top=True, cap_bottom=True, wobble=None):
    """Spun round Z: `rings` is a list of (z, radius_x, radius_y, y_offset). `wobble(angle, z)` adds to the radius."""
    bm = bmesh.new()
    loops = []
    for (z, rx, ry, *rest) in rings:
        off = rest[0] if rest else 0.0
        loop = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            w = wobble(a, z) if wobble else 0.0
            loop.append(bm.verts.new((math.cos(a) * (rx + w), off + math.sin(a) * (ry + w), z)))
        loops.append(loop)
    for i in range(len(loops) - 1):
        for j in range(seg):
            a, b = loops[i][j], loops[i][(j + 1) % seg]
            c, d = loops[i + 1][(j + 1) % seg], loops[i + 1][j]
            bm.faces.new((a, b, c, d))
    if cap_bottom:
        bm.faces.new(list(reversed(loops[0])))
    if cap_top:
        bm.faces.new(loops[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    if sub:
        ob.modifiers.new("sub", "SUBSURF").levels = sub
        ob = bake(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def egg(name, centre, radii, seg=16, rings=10, sub=1, shape=None):
    """A ball, squashed to `radii`; `shape(v)` may move each vertex (local to the centre) afterwards"""
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2]))
        if shape:
            v.co = shape(v.co)
        v.co += Vector(centre)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    if sub:
        ob.modifiers.new("sub", "SUBSURF").levels = sub
        ob = bake(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def tube(name, a, b, ra, rb, seg=12, sub=1, caps=True):
    sub = 0  # (smoothing a capped tube pulls its ends to points)
    seg = max(seg, 10)
    a, b = Vector(a), Vector(b)
    d = b - a
    bm = bmesh.new()
    rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
    m = Matrix.Translation((a + b) / 2) @ rot
    bmesh.ops.create_cone(bm, cap_ends=caps, cap_tris=False, segments=seg, radius1=ra, radius2=rb, depth=d.length, matrix=m)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    if sub:
        ob.modifiers.new("sub", "SUBSURF").levels = sub
        ob = bake(ob)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def box(name, centre, size, bevel=0.0, rot=None):
    bm = bmesh.new()
    m = Matrix.Translation(Vector(centre))
    if rot:
        m = m @ rot.to_4x4()
    m = m @ Matrix.Diagonal((size[0], size[1], size[2], 1))
    bmesh.ops.create_cube(bm, size=1.0, matrix=m)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    if bevel:
        bv = ob.modifiers.new("bevel", "BEVEL")
        bv.width = bevel
        bv.segments = 2
        ob = bake(ob)
    return ob


def paint(ob, fn):
    """Paints every corner: fn(position, normal) -> linear colour Vector"""
    me = ob.data
    if "Col" not in me.color_attributes:
        me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
    col = me.color_attributes["Col"]
    for v in me.vertices:
        c = fn(v.co, v.normal)
        col.data[v.index].color = (c.x, c.y, c.z, 1.0)
    me.color_attributes.active_color = col
    me.color_attributes.render_color_index = me.color_attributes.find("Col")
    return ob


def plain(hex_top, hex_bottom=None, z0=0.0, z1=1.0):
    """A colour fading from `hex_bottom` at z0 to `hex_top` at z1"""
    top = lin(hex_top)
    bottom = lin(hex_bottom or hex_top)

    def fn(co, n):
        t = max(0.0, min(1.0, (co.z - z0) / max(0.0001, z1 - z0)))
        return bottom.lerp(top, t)
    return fn


def lit(fn, amount=0.25):
    """Darkens what faces down and lightens what faces up a little, like light from above"""
    def out(co, n):
        c = fn(co, n)
        return c * (1.0 - amount * 0.5 + amount * 0.5 * n.z)
    return out


def join(obs, name):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in obs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = obs[0]
    bpy.ops.object.join()
    out = bpy.context.view_layer.objects.active
    out.name = name
    out.data.name = name
    return out


def group(ob, weights):
    """Gives every vertex of `ob` to bones: weights(co) -> {bone: weight}"""
    groups = {}
    for v in ob.data.vertices:
        for bone, w in weights(v.co).items():
            if w <= 0.0001:
                continue
            if bone not in groups:
                groups[bone] = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
            groups[bone].add([v.index], w, "REPLACE")
    return ob


def rigid(bone):
    return lambda co: {bone: 1.0}


def nearest(segments, sharp=6.0):
    """Weights by distance to bone segments {bone: (a, b)}, blended near the joints"""
    def fn(co):
        out = {}
        for bone, (a, b) in segments.items():
            ab = b - a
            t = max(0.0, min(1.0, (co - a).dot(ab) / ab.length_squared))
            d = (co - (a + ab * t)).length + 0.02
            out[bone] = 1.0 / d ** sharp
        total = sum(out.values())
        return {k: v / total for k, v in out.items()}
    return fn


def export(name, objects=None):
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    os.makedirs(os.path.join(ROOT, "art"), exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", name + ".blend"))
    want = dict(filepath=os.path.join(ROOT, "models", name + ".glb"), export_format="GLB", export_yup=True,
                export_animations=False, export_skins=True, export_vertex_color="ACTIVE",
                export_all_vertex_colors=False, export_active_vertex_color_when_no_material=True,
                export_colors=True, use_selection=False, export_apply=False)
    known = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    bpy.ops.export_scene.gltf(**{k: v for k, v in want.items() if k in known})
    faces = sum(len(o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print("wrote", name, "faces:", faces)


# ---------------------------------------------------------------------------------------------
# Witches

GRUMBLEWART = dict(
    name="witch_grumblewart", skin="#8fd04c", dress="#8a55c8", trim="#4c2a7e", hat="#5a3296", band="#f2c840",
    hair="#4a4a5e", eyes=1.0, nose="hook", chin=1.0, height=1.0, girth=1.0, hunch=0.0, hat_height=1.05,
    hat_bend=0.45, hair_style="long", patches=True, shawl="#5a4470", brim=0.62, tooth=True, ears=1.0,
)

CUSTOMERS = [
    dict(name="witch_hattie", skin="#ffcfaa", dress="#3a9a5a", trim="#22603a", hat="#2a6a3a", band="#e8473a",
         hair="#ff7a2a", eyes=1.15, nose="button", chin=0.4, iris="#5ac84a", height=0.82, girth=0.85, hunch=0.0, hat_height=0.7,
         hat_bend=0.25, hair_style="pigtails", freckles=True, brim=0.52, flower="#ffd84a", ears=0.6),
    dict(name="witch_gristle", skin="#a9b49a", dress="#5a4a6a", trim="#3a2c48", hat="#4a3a2a", band="#8a6a4a",
         hair="#f2f0e8", eyes=0.85, nose="long", chin=1.4, iris="#e8e040", height=0.92, girth=0.95, hunch=0.35, hat_height=0.8,
         hat_bend=0.9, hair_style="wild", shawl="#7a5a8a", brim=0.6, warts=3, ears=1.1),
    dict(name="witch_bella", skin="#9ad84a", dress="#1c1a30", trim="#0a0a16", hat="#1a2450", band="#ff4aa8",
         hair="#ff4aa8", eyes=1.0, nose="long", chin=1.3, height=1.18, girth=0.7, hunch=0.0, hat_height=1.2,
         hat_bend=0.2, hair_style="bob", stars=True, brim=0.72, ears=1.0, iris="#ff9a2a"),
    dict(name="witch_bogwort", skin="#7a9a4a", dress="#5a6a32", trim="#38441e", hat="#3a5a32", band="#8a5a2a",
         hair="#3a5a2a", eyes=0.95, nose="bulb", chin=0.6, height=0.95, girth=1.4, hunch=0.1, hat_height=0.85,
         hat_bend=0.5, hair_style="bun", toadstool=True, brim=0.7, warts=2, ears=0.9),
    dict(name="witch_polly", skin="#c8a8f0", dress="#e8701a", trim="#9a3a10", hat="#ff8a1a", band="#3a8a2a",
         hair="#d8302a", eyes=1.1, nose="pointy", chin=0.9, iris="#ffd040", height=0.98, girth=1.05, hunch=0.0, hat_height=0.95,
         hat_bend=0.6, hair_style="bob", brim=0.6, ears=0.9),
    dict(name="witch_esme", skin="#eceaff", dress="#f2f2ff", trim="#b8bce8", hat="#c8c8e8", band="#8a7ac8",
         hair="#b8c8ff", eyes=1.05, nose="hook", chin=0.9, iris="#7ad0ff", height=1.02, girth=0.9, hunch=0.0, hat_height=1.0,
         hat_bend=0.35, hair_style="long", ragged=True, brim=0.6, ears=1.0),
]

INK = "#1a1018"


def build_witch(spec):
    fresh()
    rnd = random.Random(spec["name"])
    h = spec["height"]
    g = spec["girth"]
    hunch = spec.get("hunch", 0.0)
    hip_z, waist_z, chest_z, neck_z = 0.86 * h, 1.05 * h, 1.33 * h, 1.5 * h
    head_c = Vector((0, -hunch * 0.28, 1.86 * h))
    head_r = Vector((0.36, 0.33, 0.37))
    F = 1.18  # the face, scaled up with the head
    sh_z = 1.41 * h
    sh_x = 0.26 * g ** 0.5

    def bent(z):
        """How far forward a hunched witch leans at height z"""
        return -hunch * max(0.0, (z - waist_z) / (neck_z - waist_z)) ** 2 * 0.28

    parts = []

    # The body: a dress spun round, belled at the hem, nipped at the waist, up to a bodice and collar
    ragged = spec.get("ragged", False)
    prof = [
        (0.0, 0.62, 0.55), (0.06, 0.6, 0.53), (0.35, 0.52, 0.46), (0.7, 0.4, 0.34), (hip_z, 0.31, 0.26),
        (waist_z, 0.23, 0.19), ((waist_z + chest_z) / 2, 0.27, 0.21), (chest_z, 0.29, 0.21),
        (sh_z, 0.22, 0.17), (neck_z, 0.1, 0.09),
    ]
    rings = [(z, rx * g, ry * g, bent(z)) for z, rx, ry in prof]

    def hem(a, z):
        if z > 0.1:
            return 0.0
        if ragged:
            return 0.05 * math.sin(a * 9) + 0.03 * math.sin(a * 23)
        return 0.025 * math.sin(a * 7)
    body = lathe("body", rings, seg=20, sub=1, wobble=hem)
    dress, trim = spec["dress"], spec["trim"]

    def body_col(co, n):
        c = lin(trim).lerp(lin(dress), min(1.0, max(0.0, co.z / (0.6 * h))))
        if abs(co.z - (waist_z + 0.02)) < 0.05 * h:
            c = lin("#2a1a14")
        return c * (0.8 + 0.2 * max(0.0, n.z * 0.5 + 0.5))
    paint(body, body_col)
    group(body, lambda co: _spine_weights(co, hip_z, waist_z, chest_z, neck_z))
    parts.append(body)
    # Pointed boots with curled toes peeping out under the hem
    for sgn in (1, -1):
        x = sgn * 0.13 * g
        boot = grow("boot", [(x, -0.3 * g, 0.08), (x * 1.05, -0.58 * g, 0.08), (x * 1.15, -0.8 * g, 0.12), (x * 1.15, -0.86 * g, 0.24)],
                    [(0, 1), (1, 2), (2, 3)], [(0.12, 0.09), (0.1, 0.075), (0.05, 0.045), (0.022, 0.022)], sub=1)
        paint(boot, lit(plain("#3a2a3a", "#1a1018", 0.0, 0.2)))
        group(boot, rigid("hips"))
        parts.append(boot)
    # A big buckle, patches, a shawl
    buckle = box("buckle", (0, -0.2 * g + bent(waist_z), waist_z + 0.02), (0.16, 0.05, 0.12), bevel=0.012)
    paint(buckle, lit(plain(spec["band"])))
    group(buckle, rigid("hips"))
    parts.append(buckle)
    if spec.get("patches"):
        for (x, z, c) in ((0.22, 0.5, "#3fa070"), (-0.28, 0.28, "#d06a3a")):
            r = 0.52 * g - z * 0.12
            p = box("patch", (x * g, -math.sqrt(max(0.01, r * r - (x * g) ** 2)) * 0.88, z * h), (0.17, 0.03, 0.15), bevel=0.01,
                    rot=Matrix.Rotation(x * 1.6, 3, "Z"))
            paint(p, lit(plain(c)))
            group(p, rigid("hips"))
            parts.append(p)
    if spec.get("shawl"):
        shawl = lathe("shawl", [(sh_z - 0.16 * h, 0.33 * g, 0.26 * g, bent(sh_z)), (sh_z - 0.04, 0.3 * g, 0.24 * g, bent(sh_z)),
                                (sh_z + 0.04, 0.18 * g, 0.15 * g, bent(sh_z)), (neck_z, 0.11, 0.1, bent(neck_z))], seg=20, sub=2,
                      wobble=lambda a, z: 0.025 * math.sin(a * 6) if z < sh_z - 0.1 else 0.0)
        paint(shawl, lit(plain(spec["shawl"], shade(spec["shawl"], -0.3), sh_z - 0.2, neck_z)))
        group(shawl, lambda co: _spine_weights(co, hip_z, waist_z, chest_z, neck_z))
        parts.append(shawl)
    if spec.get("stars"):
        for k in range(9):
            a = rnd.uniform(0, 2 * math.pi)
            z = rnd.uniform(0.1, 0.8) * h
            r = (0.55 - z / h * 0.25) * g
            s = egg("star", (math.cos(a) * r, math.sin(a) * r * 0.9, z), (0.03, 0.03, 0.03), seg=6, rings=4, sub=0)
            paint(s, lambda co, n: lin("#fff27a"))
            group(s, rigid("hips"))
            parts.append(s)

    # Arms: a skinny limb grown through shoulder, elbow, wrist and fingers, with a bell sleeve over it
    arm_bones = {}
    for side, sgn in (("L", 1), ("R", -1)):
        s = Vector((sgn * sh_x * g ** 0.5, bent(sh_z), sh_z))
        e = s + Vector((sgn * 0.16, -0.03, -0.32)) * h
        w = e + Vector((sgn * 0.1, -0.08, -0.3)) * h
        hand_end = w + Vector((sgn * 0.03, -0.03, -0.14)) * h
        arm_bones[side] = (s, e, w, hand_end)
        skin = spec["skin"]
        pts = [s, e, w, w + (hand_end - w) * 0.5]
        radii = [0.085 * g ** 0.5, 0.06, 0.045, (0.06, 0.035)]
        edges = [(0, 1), (1, 2), (2, 3)]
        # Long knobbly fingers and a thumb off the hand
        palm = len(pts) - 1
        side_v = Vector((0, -1, 0)).cross(hand_end - w).normalized()
        for k in range(4):
            off = side_v * ((k - 1.5) * 0.028)
            f1 = hand_end + off + (hand_end - w).normalized() * 0.03
            f2 = f1 + (hand_end - w).normalized() * 0.07 + Vector((0, -0.03, 0))
            pts += [f1, f2]
            edges += [(palm, len(pts) - 2), (len(pts) - 2, len(pts) - 1)]
            radii += [0.016, 0.01]
        t1 = w + (hand_end - w) * 0.5 + Vector((0, -0.05, 0)) + side_v * 0.04
        pts.append(t1)
        edges.append((palm, len(pts) - 1))
        radii.append(0.016)
        arm = grow("arm_" + side, pts, edges, radii, sub=1)
        sleeve = lathe("sleeve_" + side, [(0, 0.1, 0.1), (0.18, 0.11, 0.11), (0.34, 0.16, 0.15), (0.4, 0.17, 0.16)], seg=14, sub=1,
                       cap_top=False, cap_bottom=True)
        # Lay the sleeve along the upper arm and down over the elbow, opening at the forearm
        up = (w - s).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(up).to_matrix().to_4x4()
        sleeve.data.transform(Matrix.Translation(s - up * 0.04) @ rot @ Matrix.Diagonal((g ** 0.5, g ** 0.5, h * 1.2, 1)))
        paint(arm, lit(plain(skin, shade(skin, -0.25), w.z - 0.2, s.z)))
        paint(sleeve, lambda co, n, d=dress: lin(d) * (0.75 + 0.25 * max(0.0, n.z * 0.5 + 0.5)))
        segs = {"upper." + side: (s, e), "fore." + side: (e, w), "hand." + side: (w, hand_end + (hand_end - w) * 0.6)}
        group(arm, nearest(segs))
        group(sleeve, nearest({"upper." + side: (s, e), "fore." + side: (e, w)}))
        parts += [arm, sleeve]

    # The head, the way the old console witches had it: long, drawn down into a chin that juts
    # forward, cheekbones, the crown all hair (no bald pates under the hats)
    chin = spec["chin"]
    hair_col = spec["hair"]

    def head_shape(v):
        low = max(0.0, -v.z / head_r.z)
        high = max(0.0, v.z / head_r.z)
        front = max(0.0, -v.y / head_r.y)
        v = v.copy()
        k = 1.0 - 0.55 * low ** 1.25 * min(chin, 1.2)
        v.x *= k * (1.0 + 0.08 * front * (1.0 - low))
        v.y -= (0.1 + 0.32 * chin) * low ** 2 * (0.3 + front)
        v.z -= 0.2 * chin * low ** 2.2
        v.y += 0.04 * high
        return v
    head = egg("head", head_c, head_r, seg=16, rings=12, sub=1, shape=head_shape)
    skin = spec["skin"]
    crown_z = head_c.z + 0.1 * F

    def head_col(co, n):
        # Hair over the crown and round the back; skin on the face
        if co.z > crown_z or (co.y > head_c.y + 0.05 and co.z > head_c.z - 0.2):
            return lin(hair_col) * (0.75 + 0.25 * max(0.0, n.z))
        return lin(skin).lerp(lin(skin) * 0.7, max(0.0, -n.z) * 0.6) * (0.85 + 0.15 * max(0.0, -n.y))
    paint(head, head_col)
    parts.append(head)
    head_parts = []
    # The nose: long, the hook kind longest of all
    nose = spec["nose"]
    nb = head_c + F * Vector((0, -0.27, 0.0))
    if nose == "hook":
        np = [nb, nb + Vector((0, -0.2, 0.01)), nb + Vector((0, -0.38, -0.06)), nb + Vector((0, -0.44, -0.18))]
        nr = [0.07, 0.055, 0.035, 0.012]
    elif nose == "long":
        np = [nb, nb + Vector((0, -0.24, -0.04)), nb + Vector((0.02, -0.46, -0.12)), nb + Vector((0.04, -0.56, -0.2))]
        nr = [0.07, 0.05, 0.032, 0.008]
    elif nose == "pointy":
        np = [nb, nb + Vector((0, -0.2, -0.04)), nb + Vector((0, -0.36, -0.06))]
        nr = [0.065, 0.038, 0.006]
    elif nose == "bulb":
        np = [nb, nb + Vector((0, -0.12, -0.04)), nb + Vector((0, -0.19, -0.08))]
        nr = [0.07, 0.08, 0.09]
    else:
        np = [nb + Vector((0, 0.02, -0.04)), nb + Vector((0, -0.07, -0.06))]
        nr = [0.05, 0.05]
    nose_ob = grow("nose", np, [(i, i + 1) for i in range(len(np) - 1)], nr, sub=1)
    paint(nose_ob, lit(plain(skin)))
    head_parts.append(nose_ob)
    for k in range(spec.get("warts", 1 if nose == "hook" else 0)):
        p = np[min(len(np) - 1, 1 + k % (len(np) - 1))]
        wart = egg("wart", p + Vector((0.035 if k % 2 == 0 else -0.035, -0.01, 0.02)), (0.026, 0.026, 0.026), seg=8, rings=6, sub=0)
        paint(wart, lambda co, n: lin("#9a7a3a"))
        head_parts.append(wart)
    # Pointed ears
    for sgn in (1, -1):
        e0 = head_c + F * Vector((sgn * 0.26, 0.02, 0.02))
        ear = grow("ear", [e0, e0 + Vector((sgn * 0.14, 0.03, 0.06)) * spec["ears"], e0 + Vector((sgn * 0.24, 0.06, 0.14)) * spec["ears"]],
                   [(0, 1), (1, 2)], [(0.065, 0.022), (0.045, 0.016), (0.01, 0.006)], sub=1)
        paint(ear, lit(plain(skin)))
        head_parts.append(ear)
        if spec.get("freckles"):
            for k in range(4):
                f = egg("freckle", head_c + F * Vector((sgn * (0.11 + k % 2 * 0.05), -0.27, -0.06 - k * 0.022)),
                        (0.012, 0.006, 0.012), seg=6, rings=4, sub=0)
                paint(f, lambda co, n: lin("#c86a3a"))
                head_parts.append(f)
    # Brows, thick and cross, on bones of their own
    brows = []
    for side, sgn in (("L", 1), ("R", -1)):
        bc = head_c + F * Vector((sgn * 0.13, -0.24, 0.17))
        brow = grow("brow_" + side, [bc + Vector((-sgn * 0.08, -0.02, -0.03)), bc + Vector((sgn * 0.07, 0.02, 0.03))], [(0, 1)],
                    [(0.03, 0.02), (0.018, 0.012)], sub=1)
        paint(brow, lambda co, n: lin(hair_col) * 0.6)
        group(brow, rigid("brow." + side))
        brows.append(brow)
    # A wide grin full of crooked teeth (it opens and shuts on its bone when she talks)
    mouth_c = head_c + F * Vector((0, -0.25 - 0.08 * chin, -0.17 - 0.05 * chin))
    smile = [mouth_c + Vector((sgn * 0.14, 0.04, 0.035)) for sgn in (-1,)] + [mouth_c + Vector((0, -0.02, 0.0))] + [mouth_c + Vector((0.14, 0.04, 0.035))]
    mouth = grow("mouth", smile, [(0, 1), (1, 2)], [(0.025, 0.012), (0.045, 0.02), (0.025, 0.012)], sub=1)
    paint(mouth, lambda co, n: lin("#5a0c18"))
    group(mouth, rigid("mouth"))
    mparts = [mouth]
    rnd2 = random.Random(spec["name"] + "teeth")
    for k in range(5 if spec.get("tooth", True) else 2):
        t = (k + 0.5) / 5.0 if spec.get("tooth", True) else 0.3 + k * 0.4
        x = (t - 0.5) * 0.22
        top = mouth_c + Vector((x, -0.035 + abs(x) * 0.25, 0.022 + abs(x) * 0.18))
        tooth = grow("tooth", [top, top + Vector((0, -0.004, -0.035 - rnd2.uniform(0, 0.012)))], [(0, 1)], [(0.014, 0.008), 0.003], sub=0)
        paint(tooth, lambda co, n: lin("#fff6d8"))
        group(tooth, rigid("mouth"))
        mparts.append(tooth)
    lip = grow("lip", [mouth_c + Vector((-0.16, 0.03, 0.05)), mouth_c + Vector((0, -0.04, 0.035)), mouth_c + Vector((0.16, 0.03, 0.05))],
               [(0, 1), (1, 2)], [0.016, 0.02, 0.016], sub=1)
    paint(lip, lit(plain(skin)))
    head_parts.append(lip)
    # Eyes with some form to them: almond whites slanted up at the outer corners, a yellow iris and
    # a slit pupil (on a bone, to look about), a heavy lid over the top of each
    eyes = []
    es = spec["eyes"]
    eye_pos = {}
    iris = spec.get("iris", "#f2b81a")
    for side, sgn in (("L", 1), ("R", -1)):
        ec = head_c + F * Vector((sgn * 0.12 * es ** 0.5, -0.255, 0.07))
        eye_pos[side] = ec
        slant = Matrix.Rotation(-sgn * 0.3, 4, "Y")
        white = egg("eye_" + side, (0, 0, 0), (0.1 * es, 0.05, 0.062 * es), seg=14, rings=8, sub=1,
                    shape=lambda v: Vector((v.x, v.y, v.z * (1.0 - 0.35 * (v.x * sgn / (0.1 * es)) ** 2))))
        white.data.transform(Matrix.Translation(ec) @ slant)
        paint(white, lambda co, n: lin("#fffbe8") * (0.82 + 0.18 * max(0.0, -n.y)))
        group(white, rigid("eye." + side))
        pc = ec + Vector((0, -0.04, -0.004))
        iris_ob = egg("iris_" + side, pc, (0.042 * es, 0.016, 0.046 * es), seg=12, rings=6, sub=1)
        paint(iris_ob, lambda co, n, pc=pc: lin(iris).lerp(lin(iris) * 0.45, min(1.0, (co - pc).length / (0.046 * es))))
        group(iris_ob, rigid("pupil." + side))
        slit = egg("pupil_" + side, pc + Vector((0, -0.012, 0)), (0.012 * es, 0.01, 0.036 * es), seg=8, rings=6, sub=0)
        paint(slit, lambda co, n: lin(INK))
        group(slit, rigid("pupil." + side))
        shine = egg("shine_" + side, pc + Vector((-0.015 * es, -0.022, 0.018 * es)), (0.009 * es, 0.005, 0.009 * es), seg=6, rings=4, sub=0)
        paint(shine, lambda co, n: Vector((1, 1, 1)))
        group(shine, rigid("pupil." + side))
        # The lid: a hood of skin over the top of the eye, lower toward the nose (a mean look)
        lid = egg("lid_" + side, (0, 0, 0), (0.115 * es, 0.062, 0.05 * es), seg=14, rings=8, sub=1,
                  shape=lambda v: Vector((v.x, v.y, max(v.z, 0.0) if v.z > 0 else v.z * 0.15)))
        lid.data.transform(Matrix.Translation(ec + Vector((0, -0.004, 0.024 * es))) @ slant @ Matrix.Rotation(sgn * 0.0, 4, "Y")
                           @ Matrix.Rotation(-0.25, 4, "X"))
        paint(lid, lambda co, n: lin(skin) * (0.8 + 0.2 * max(0.0, n.z)))
        group(lid, rigid("head"))
        eyes += [white, iris_ob, slit, shine, lid]

    # Hair: a full head of it under the hat, then the style
    hair = []
    style = spec["hair_style"]
    hc = hair_col
    cap = egg("hair_cap", head_c + F * Vector((0, 0.03, 0.06)), (head_r.x * 1.08, head_r.y * 1.1, head_r.z * 0.95), seg=16, rings=10, sub=1,
              shape=lambda v: v if (v.z > -0.02 or v.y > 0.02) else v * Vector((0.9, 0.6, 0.6)))
    paint(cap, lambda co, n: lin(hc) * (0.7 + 0.3 * max(0.0, n.z)))
    hair.append(cap)
    if style == "bob":
        # A blunt bob, cut square at the jaw, a fringe across the brow (like Mingella's)
        for sgn in (1, -1):
            panel = box("hair_panel", head_c + F * Vector((sgn * 0.27, -0.06, -0.08)), (0.09, 0.42, 0.46), bevel=0.03,
                        rot=Matrix.Rotation(-sgn * 0.12, 3, "Z"))
            paint(panel, lambda co, n: lin(hc) * (0.75 + 0.25 * max(0.0, -n.y)))
            hair.append(panel)
        back = box("hair_back", head_c + F * Vector((0, 0.2, -0.08)), (0.56, 0.12, 0.46), bevel=0.03)
        paint(back, lambda co, n: lin(hc) * 0.8)
        hair.append(back)
    elif style == "bun":
        bun = egg("hair_bun", head_c + F * Vector((0, 0.3, 0.05)), (0.15, 0.13, 0.15), seg=12, rings=8, sub=1)
        paint(bun, lambda co, n: lin(hc) * (0.75 + 0.25 * max(0.0, n.z)))
        hair.append(bun)
    n_strands = {"long": 13, "wild": 14, "bob": 0, "pigtails": 6, "bun": 6}.get(style, 10)
    for k in range(n_strands):
        a = -1.9 + 3.8 * k / max(1, n_strands - 1)
        root = head_c + F * Vector((math.sin(a) * 0.29, math.cos(a) * 0.26, 0.0))
        out = Vector((math.sin(a), math.cos(a), 0))
        if style == "long":
            ln = rnd.uniform(0.75, 1.1)
            pts = [root, root + out * 0.08 + Vector((0, 0, -0.3 * ln)), root + out * 0.11 + Vector((rnd.uniform(-0.03, 0.03), 0.03, -0.62 * ln)),
                   root + out * 0.13 + Vector((rnd.uniform(-0.05, 0.05), 0.06, -0.85 * ln))]
            rad = [0.05, 0.04, 0.028, 0.012]
        elif style == "wild":
            j = Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.04, 0.08), rnd.uniform(-0.05, 0.08)))
            pts = [root, root + out * 0.18 + Vector((0, 0, -0.08)) + j, root + out * 0.32 + Vector((0, 0.04, -0.2)) + j * 2]
            rad = [0.05, 0.035, 0.008]
        else:
            pts = [root, root + out * 0.05 + Vector((0, 0, -0.16))]
            rad = [0.045, 0.02]
        s_ob = grow("hair", pts, [(i, i + 1) for i in range(len(pts) - 1)], rad, sub=1)
        paint(s_ob, lit(plain(hc, shade(hc, -0.35), pts[-1].z, root.z)))
        hair.append(s_ob)
    if style == "pigtails":
        for sgn in (1, -1):
            r0 = head_c + F * Vector((sgn * 0.27, 0.06, -0.02))
            tail = grow("pigtail", [r0, r0 + Vector((sgn * 0.14, 0.04, -0.12)), r0 + Vector((sgn * 0.2, 0.06, -0.34))], [(0, 1), (1, 2)],
                        [0.06, 0.07, 0.025], sub=1)
            paint(tail, lit(plain(hc)))
            bow = egg("bow", r0 + Vector((sgn * 0.08, 0.02, -0.04)), (0.06, 0.04, 0.05), seg=8, rings=6, sub=1)
            paint(bow, lambda co, n: lin(spec["band"]))
            hair += [tail, bow]

    # The hat: a wide drooping brim, a band and buckle, and a cone that bends over at the top
    hat = []
    hb = head_c + F * Vector((0, 0.03, 0.31))
    brim_r = spec["brim"] * 1.12
    brim = lathe("brim", [(0.0, brim_r, brim_r * 0.95), (0.03, brim_r * 0.98, brim_r * 0.93), (0.05, 0.32, 0.3), (0.06, 0.3, 0.29)],
                 seg=24, sub=1, wobble=lambda a, z: 0.03 * math.sin(a * 3))
    # Droop the brim's edge
    for v in brim.data.vertices:
        r = math.hypot(v.co.x, v.co.y)
        v.co.z -= max(0.0, r - 0.3) ** 2 * 0.6
    brim.data.transform(Matrix.Translation(hb))
    hat_c = spec["hat"]
    paint(brim, lit(plain(hat_c, shade(hat_c, -0.35), hb.z - 0.08, hb.z + 0.05)))
    hat.append(brim)
    hh = spec["hat_height"]
    bend = spec["hat_bend"]
    cone_pts = [hb + Vector((0, 0, 0.02)), hb + Vector((0, 0.02, 0.35 * hh)), hb + Vector((0, 0.06 + bend * 0.05, 0.65 * hh)),
                hb + Vector((0, 0.15 + bend * 0.25, 0.88 * hh)), hb + Vector((0, 0.3 + bend * 0.4, 0.92 * hh - bend * 0.12))]
    cone = grow("cone", cone_pts, [(i, i + 1) for i in range(len(cone_pts) - 1)], [0.31, 0.24, 0.15, 0.07, 0.015], sub=1)
    paint(cone, lit(plain(shade(hat_c, 0.12), hat_c, hb.z, hb.z + hh)))
    hat.append(cone)
    band = lathe("band", [(0.0, 0.315, 0.305), (0.1, 0.3, 0.29)], seg=22, sub=1, cap_top=False, cap_bottom=False)
    band.data.transform(Matrix.Translation(hb + Vector((0, 0, 0.04))))
    paint(band, lit(plain(spec["band"])))
    hat.append(band)
    buck = box("hat_buckle", hb + Vector((0, -0.31, 0.09)), (0.13, 0.03, 0.11), bevel=0.01)
    paint(buck, lambda co, n: lin("#f2c840") if abs(co.x) > 0.035 or abs(co.z - hb.z - 0.09) > 0.03 else lin(hat_c) * 0.5)
    hat.append(buck)
    if spec.get("flower"):
        for k in range(5):
            a = 2 * math.pi * k / 5
            pet = egg("petal", hb + Vector((0.22 + math.cos(a) * 0.05, -0.2, 0.12 + math.sin(a) * 0.05)), (0.035, 0.02, 0.035), seg=8, rings=5, sub=0)
            paint(pet, lambda co, n: lin(spec["flower"]))
            hat.append(pet)
    if spec.get("stars"):
        for k in range(6):
            t = 0.15 + k * 0.13
            p = cone_pts[min(4, int(t * 4))].lerp(cone_pts[min(4, int(t * 4) + 1)], (t * 4) % 1.0)
            a = k * 2.1
            r = 0.3 * (1 - t) + 0.03
            st = egg("hat_star", p + Vector((math.cos(a) * r, math.sin(a) * r, 0)), (0.035, 0.035, 0.035), seg=6, rings=4, sub=0)
            paint(st, lambda co, n: lin("#fff27a"))
            hat.append(st)
    if spec.get("toadstool"):
        stem = tube("ts_stem", hb + Vector((0.2, -0.1, 0.05)), hb + Vector((0.22, -0.1, 0.2)), 0.04, 0.035, seg=8)
        cap = egg("ts_cap", hb + Vector((0.22, -0.1, 0.22)), (0.1, 0.1, 0.06), seg=12, rings=8, sub=1,
                  shape=lambda v: Vector((v.x, v.y, max(v.z, -0.01))))
        paint(stem, lambda co, n: lin("#f0e2c0"))
        paint(cap, lambda co, n: lin("#fffbf0") if (math.sin(co.x * 60) * math.sin(co.y * 60) > 0.6) else lin("#e8382a"))
        hat += [stem, cap]

    for ob in head_parts + hair:
        group(ob, rigid("head"))
    group(head, rigid("head"))
    for ob in hat:
        group(ob, rigid("hat"))

    witch = join(parts + head_parts + hair + hat + eyes + brows + mparts, spec["name"])

    # The skeleton
    arm_data = bpy.data.armatures.new(spec["name"] + "_rig")
    rig = link(bpy.data.objects.new("rig", arm_data))
    bpy.context.view_layer.objects.active = rig
    bpy.ops.object.mode_set(mode="EDIT")
    eb = arm_data.edit_bones

    def bone(name, head, tail, parent=None):
        b = eb.new(name)
        b.head = Vector(head)
        b.tail = Vector(tail)
        if parent:
            b.parent = eb[parent]
        return b
    bone("hips", (0, 0, hip_z), (0, bent(waist_z), waist_z))
    bone("spine", (0, bent(waist_z), waist_z), (0, bent(chest_z), chest_z), "hips")
    bone("chest", (0, bent(chest_z), chest_z), (0, bent(neck_z), neck_z), "spine")
    bone("neck", (0, bent(neck_z), neck_z), head_c + F * Vector((0, 0.02, -0.22)), "chest")
    bone("head", head_c + F * Vector((0, 0.02, -0.22)), head_c + F * Vector((0, 0.02, 0.2)), "neck")
    bone("hat", hb, hb + Vector((0, 0, 0.4)), "head")
    bone("mouth", mouth_c, mouth_c + Vector((0, -0.08, 0)), "head")
    for side, sgn in (("L", 1), ("R", -1)):
        ec = eye_pos[side]
        bone("eye." + side, ec, ec + Vector((0, -0.08, 0)), "head")
        bone("pupil." + side, ec + Vector((0, -0.06, 0)), ec + Vector((0, -0.12, 0)), "eye." + side)
        bc = head_c + F * Vector((sgn * 0.13, -0.24, 0.17))
        bone("brow." + side, bc, bc + Vector((0, -0.06, 0)), "head")
        s, e, w, he = arm_bones[side]
        bone("upper." + side, s, e, "chest")
        bone("fore." + side, e, w, "upper." + side)
        bone("hand." + side, w, he + (he - w) * 0.6, "fore." + side)
    bpy.ops.object.mode_set(mode="OBJECT")
    witch.parent = rig
    mod = witch.modifiers.new("rig", "ARMATURE")
    mod.object = rig
    export(spec["name"])


def _spine_weights(co, hip_z, waist_z, chest_z, neck_z):
    """The body bends with hips, spine, chest and neck, blended between them by height"""
    if co.z <= hip_z:
        return {"hips": 1.0}
    stops = [("hips", hip_z), ("spine", waist_z), ("chest", chest_z), ("neck", neck_z)]
    for i in range(len(stops) - 1):
        (b0, z0), (b1, z1) = stops[i], stops[i + 1]
        if co.z <= z1:
            t = (co.z - z0) / (z1 - z0)
            t = t * t * (3 - 2 * t)
            return {b0: 1.0 - t, b1: t}
    return {"neck": 1.0}


# ---------------------------------------------------------------------------------------------

def main():
    if ONLY in ("", "witches", "grumblewart"):
        build_witch(GRUMBLEWART)
    if ONLY in ("", "witches", "customers"):
        for spec in CUSTOMERS:
            build_witch(spec)
    if ONLY in ("", "props"):
        build_props()


def flat(name, outline, thick, centre=(0, 0, 0), rot=None, sub=1):
    """A flat shape (a wing, a scale, a page) from an outline in its own XY, given thickness"""
    bm = bmesh.new()
    vs = [bm.verts.new((x, y, 0)) for x, y in outline]
    bm.faces.new(vs)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    so = ob.modifiers.new("solid", "SOLIDIFY")
    so.thickness = thick
    so.offset = 0
    if sub:
        ob.modifiers.new("sub", "SUBSURF").levels = sub
    ob = bake(ob)
    m = Matrix.Translation(Vector(centre))
    if rot:
        m = m @ rot.to_4x4()
    ob.data.transform(m)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def ring(name, centre, big, small, seg=24, sides=8, rot=None):
    bm = bmesh.new()
    loops = []
    for i in range(seg):
        a = 2 * math.pi * i / seg
        loop = []
        for j in range(sides):
            b = 2 * math.pi * j / sides
            out = Vector((math.cos(a), math.sin(a), 0))
            p = out * (big + math.cos(b) * small) + Vector((0, 0, math.sin(b) * small))
            loop.append(bm.verts.new(p))
        loops.append(loop)
    for i in range(seg):
        for j in range(sides):
            bm.faces.new((loops[i][j], loops[(i + 1) % seg][j], loops[(i + 1) % seg][(j + 1) % sides], loops[i][(j + 1) % sides]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = link(bpy.data.objects.new(name, me))
    m = Matrix.Translation(Vector(centre))
    if rot:
        m = m @ rot.to_4x4()
    ob.data.transform(m)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def bowl(name, centre, r, depth, col, inside=None, seg=18):
    """An open bowl or dish: lathed wall, rim rolled over, darker inside"""
    c = Vector(centre)
    outer = lathe(name, [(0.0, r * 0.55, r * 0.55), (depth * 0.4, r * 0.9, r * 0.9), (depth, r, r)], seg=seg, sub=1, cap_top=False)
    inner = lathe(name + "_in", [(depth * 0.98, r * 0.93, r * 0.93), (depth * 0.45, r * 0.8, r * 0.8), (depth * 0.15, r * 0.45, r * 0.45)], seg=seg, sub=1,
                  cap_top=False, cap_bottom=True)
    for v in inner.data.vertices:
        pass
    rim = ring(name + "_rim", (0, 0, depth), r * 0.965, r * 0.04, seg=seg * 2, sides=6)
    for o in (outer, inner, rim):
        o.data.transform(Matrix.Translation(c))
    paint(outer, lit(plain(col, shade(col, -0.35), c.z, c.z + depth)))
    paint(inner, lambda co, n: shade(inside or col, -0.45))
    paint(rim, lit(plain(shade(col, 0.15))))
    return [outer, inner, rim]


def eyeball(name, centre, r, iris="#3ac0a8", look=Vector((0, -1, 0.3))):
    c = Vector(centre)
    look = look.normalized()

    def col(co, n):
        d = (co - c).normalized()
        k = d.dot(look)
        if k > 0.93:
            return lin(INK)
        if k > 0.78:
            return lin(iris)
        # Red veins running round the white
        vein = math.sin(d.x * 40) * math.sin(d.z * 37 + d.y * 20)
        return lin("#fbf3e0").lerp(lin("#d8303a"), 0.6 if vein > 0.93 else 0.0)
    e = egg(name, c, (r, r, r), seg=16, rings=10, sub=1)
    paint(e, col)
    return e


def frog_leg(name, base, sgn, rot_z=0.0):
    b = Vector(base)
    r = Matrix.Rotation(rot_z, 3, "Z")
    pts = [b, b + r @ Vector((0.1, 0.0, 0.05)), b + r @ Vector((0.2, 0.0, 0.03)), b + r @ Vector((0.27, 0.0, 0.02))]
    leg = grow(name, pts, [(0, 1), (1, 2), (2, 3)], [0.06, 0.045, 0.025, 0.02], sub=2)
    paint(leg, lit(plain("#a8e870", "#5aa83a", b.z, b.z + 0.08)))
    toes = []
    tip = pts[-1]
    for k in range(3):
        a = rot_z + (k - 1) * 0.5
        t = grow(name + "_toe", [tip, tip + Vector((math.cos(a) * 0.09, math.sin(a) * 0.09, 0))], [(0, 1)], [0.012, (0.03, 0.008)], sub=1)
        paint(t, lambda co, n: lin("#c8f090"))
        toes.append(t)
    return [leg] + toes


def build_props():
    fresh()
    out = {}
    rnd = random.Random(11)
    IRON, IRON_L = "#2c2634", "#5d5470"

    # The cauldron: a fat iron belly on three stubby feet, a rolled lip, a dark inside, two ring handles.
    # The rim is at 1.36 and the brew sits at 1.24 inside it (the game puts the brew's surface there).
    belly = lathe("cauldron", [(0.32, 0.2, 0.2), (0.4, 0.55, 0.55), (0.6, 0.86, 0.86), (0.85, 0.98, 0.98), (1.08, 0.94, 0.94),
                               (1.25, 0.84, 0.84), (1.33, 0.8, 0.8)], seg=28, sub=2, cap_top=False,
                  wobble=lambda a, z: 0.008 * math.sin(a * 13 + z * 20))

    def iron(co, n):
        c = lin(IRON).lerp(lin(IRON_L), max(0.0, n.z) * 0.6 + max(0.0, (co.z - 0.3) / 1.0) * 0.25)
        if 0.5 < co.z < 0.62 and math.sin(math.atan2(co.y, co.x) * 7) > 0.85:
            c = c.lerp(lin("#4a7a5a"), 0.5)
        return c
    paint(belly, iron)
    inside = lathe("cauldron_in", [(0.9, 0.7, 0.7), (1.1, 0.84, 0.84), (1.25, 0.8, 0.8), (1.33, 0.78, 0.78)], seg=28, sub=1, cap_top=False)
    paint(inside, lambda co, n: lin("#0e0a12"))
    lip = ring("cauldron_lip", (0, 0, 1.36), 0.81, 0.07, seg=40, sides=8)
    paint(lip, lambda co, n: lin(IRON_L).lerp(lin("#8a80a0"), max(0.0, n.z) * 0.6))
    feet = []
    for k in range(3):
        a = 2 * math.pi * k / 3 + 0.5
        top = Vector((math.cos(a) * 0.5, math.sin(a) * 0.5, 0.45))
        foot = grow("cauldron_foot", [top, top * Vector((1.25, 1.25, 0)) + Vector((0, 0, 0.12)), top * Vector((1.35, 1.35, 0)) + Vector((0, 0, 0.02))],
                    [(0, 1), (1, 2)], [0.09, 0.07, (0.1, 0.06)], sub=1)
        paint(foot, lit(plain(IRON_L, IRON, 0.0, 0.45)))
        feet.append(foot)
    for sgn in (1, -1):
        h = ring("cauldron_handle", (sgn * 0.99, 0, 1.15), 0.13, 0.03, seg=16, sides=6, rot=Matrix.Rotation(math.pi / 2, 3, "X"))
        paint(h, lit(plain(IRON_L)))
        feet.append(h)
        lug = egg("cauldron_lug", (sgn * 0.93, 0, 1.26), (0.06, 0.08, 0.06), seg=10, rings=6, sub=0)
        paint(lug, lit(plain(IRON_L)))
        feet.append(lug)
    out["cauldron"] = [belly, inside, lip] + feet

    # The fire pit: a ring of stones and a few logs crossed under the pot
    pit = []
    for k in range(11):
        a = 2 * math.pi * k / 11
        r = rnd.uniform(0.18, 0.25)
        st = egg("stone", (math.cos(a) * 1.08, math.sin(a) * 1.0, r * 0.45), (r, r * 0.85, r * 0.6), seg=10, rings=6, sub=1,
                 shape=lambda v: v * (1.0 + 0.12 * math.sin(v.x * 30) * math.sin(v.y * 27)))
        sh = rnd.uniform(0.0, 1.0)
        paint(st, lit(plain(shade("#8a8098", 0.1 * sh), shade("#5a5068", -0.2), 0.0, r)))
        pit.append(st)
    for k in range(4):
        a = math.pi * k / 4 + 0.3
        d = Vector((math.cos(a), math.sin(a), 0))
        log = tube("log", -d * 0.72 + Vector((0, 0, 0.1 + k * 0.03)), d * 0.72 + Vector((0, 0, 0.12 + k * 0.03)), 0.09, 0.085, seg=10, sub=1)
        paint(log, lambda co, n: lin("#6b4024").lerp(lin("#2a1810"), 0.6 if abs(co.x) + abs(co.y) < 0.35 else 0.0) * (0.8 + 0.2 * n.z))
        pit.append(log)
    out["firepit"] = pit

    # The table in front of the pot: a thick top with two raised steps along the back, so three
    # rows of things stand one behind another (the back step highest), on chunky legs
    table = []
    top = box("table_top", (0, 0, 0.76), (2.6, 1.55, 0.12), bevel=0.03)
    step1 = box("table_step", (0, 0.06, 0.91), (2.5, 0.5, 0.18), bevel=0.025)
    step2 = box("table_step2", (0, 0.52, 1.0), (2.5, 0.46, 0.36), bevel=0.025)

    def planks(co, n):
        k = (math.floor((co.x + 2.0) / 0.42) % 3) * 0.07
        grain = 0.04 * math.sin(co.x * 3 + co.y * 40)
        return shade("#a8683a", -k + grain) * (0.75 + 0.25 * max(0.0, n.z))
    paint(top, planks)
    paint(step1, lambda co, n: shade("#9a5e34", 0.03 * math.sin(co.x * 20)) * (0.75 + 0.25 * max(0.0, n.z)))
    paint(step2, lambda co, n: shade("#8a5230", 0.03 * math.sin(co.x * 23)) * (0.75 + 0.25 * max(0.0, n.z)))
    table += [top, step1, step2]
    for sx in (-1.15, 1.15):
        for sy in (-0.65, 0.65):
            leg = tube("table_leg", (sx, sy, 0.0), (sx, sy, 0.72), 0.08, 0.07, seg=8, sub=1)
            paint(leg, lit(plain("#7a4624", "#4a2a14", 0.0, 0.7)))
            table.append(leg)
    out["table"] = table

    # The ingredients, in the manner of Ocarina of Time's items: chunky, bright, readable from afar,
    # colour graded across each piece. Pieces named glass_* are see-through and glow_* shine by
    # themselves (the game dresses them so). Origin where each sits on the table.

    def jar(name, r, h, tint="#bfe8f0"):
        """A glass jar with a thick rim and a cork"""
        g = lathe("glass_" + name, [(0.0, r * 0.9, r * 0.9), (0.02, r, r), (h * 0.8, r, r), (h * 0.92, r * 0.72, r * 0.72),
                                     (h, r * 0.74, r * 0.74)], seg=16, sub=1, cap_top=False)
        paint(g, lambda co, n: lin(tint).lerp(Vector((1, 1, 1)), 0.35 * max(0.0, -n.y)))
        lip = ring(name + "_lip", (0, 0, h), r * 0.76, r * 0.08, seg=20, sides=6)
        paint(lip, lambda co, n: lin(tint).lerp(Vector((1, 1, 1)), 0.5))
        cork = lathe(name + "_cork", [(h - 0.02, r * 0.62, r * 0.62), (h + 0.06, r * 0.66, r * 0.66), (h + 0.08, r * 0.6, r * 0.6)], seg=12, sub=1)
        paint(cork, lit(plain("#d8a060", "#a8703a", h, h + 0.08)))
        return [g, lip, cork]

    # Eye of newt: a big jar of eyeballs bobbing in green pickle
    ing = jar("eyejar", 0.15, 0.36, "#c8f0e0")
    pickle = lathe("pickle", [(0.02, 0.135, 0.135), (0.24, 0.14, 0.14)], seg=14, sub=0)
    paint(pickle, lambda co, n: lin("#6ad0a0") * (0.7 + 0.3 * co.z / 0.24))
    ing.append(pickle)
    for k, p in enumerate([(-0.05, -0.02, 0.08), (0.06, 0.01, 0.12), (-0.02, -0.06, 0.19), (0.04, 0.04, 0.26), (-0.06, 0.04, 0.3)]):
        ing.append(eyeball("eye", p, 0.06, iris=["#3ac0a8", "#e8b030", "#c8402a"][k % 3],
                           look=Vector((rnd.uniform(-0.6, 0.6), -1, rnd.uniform(-0.2, 0.6)))))
    out["ing_eye"] = ing

    # Toadstools: three fat red-capped mushrooms on a mossy root, grass round them
    ing = []
    root = grow("ts_root", [(-0.17, 0.02, 0.03), (-0.05, 0.0, 0.06), (0.08, 0.02, 0.05), (0.18, -0.01, 0.03)], [(0, 1), (1, 2), (2, 3)],
                [0.06, 0.08, 0.07, 0.04], sub=2)
    paint(root, lambda co, n: lin("#6a4428").lerp(lin("#5aa83a"), 0.8 if n.z > 0.5 else 0.0))
    ing.append(root)
    for (x, y, hgt, r, lean) in ((-0.05, 0.0, 0.26, 0.13, 0.1), (0.1, 0.03, 0.18, 0.09, -0.25), (0.0, -0.08, 0.12, 0.07, 0.35)):
        top = Vector((x + lean * 0.15, y, 0.06 + hgt))
        stem = grow("ts_stem", [(x, y, 0.05), (x + lean * 0.05, y, 0.06 + hgt * 0.5), top], [(0, 1), (1, 2)],
                    [r * 0.45, r * 0.35, r * 0.38], sub=2)
        paint(stem, lambda co, n: lin("#fff4dc").lerp(lin("#d8c8a0"), 0.3 * (1 - n.z)))
        skirt = ring("ts_skirt", top - Vector((0, 0, 0.03 + r * 0.2)), r * 0.42, r * 0.08, seg=14, sides=5)
        paint(skirt, lambda co, n: lin("#fff4dc"))
        cap = egg("ts_cap", top, (r, r, r * 0.72), seg=16, rings=10, sub=1,
                  shape=lambda v: Vector((v.x, v.y, max(v.z, -0.004) if v.z > -0.004 else v.z * 0.15)))
        cx, cy = top.x, top.y
        paint(cap, lambda co, n, cx=cx, cy=cy, r=r: (lin("#fffbf0") if (n.z > 0.15 and (math.sin((co.x - cx) / r * 7.0) * math.sin((co.y - cy) / r * 7.0 + 1.0)) > 0.55)
                                                    else lin("#ff4a3a").lerp(lin("#b81c18"), 0.6 * max(0.0, 1 - n.z))) if n.z > -0.2 else lin("#f0dcb0"))
        ing += [stem, skirt, cap]
    for k in range(7):
        a = k * 0.9
        b = Vector((math.cos(a) * 0.17, math.sin(a) * 0.09, 0.02))
        blade = grow("grass", [b, b + Vector((math.cos(a) * 0.03, 0, 0.09 + 0.03 * (k % 3)))], [(0, 1)], [(0.015, 0.006), (0.002, 0.002)], sub=0)
        paint(blade, lambda co, n: lin("#7ad84a").lerp(lin("#3a8a2a"), 0.5))
        ing.append(blade)
    out["ing_shroom"] = ing

    # Bat wing: one great leathery wing pinned on a little wooden stand, its finger bones showing
    ing = []
    stand = box("wing_stand", (0, 0.04, 0.02), (0.3, 0.12, 0.04), bevel=0.01)
    paint(stand, lit(plain("#8a5228")))
    post = tube("wing_post", (0, 0.04, 0.04), (0, 0.04, 0.2), 0.012, 0.012, seg=8)
    paint(post, lambda co, n: lin("#6b3e22"))
    ing += [stand, post]
    pivot = Vector((0, 0.03, 0.2))
    tips = [Vector((-0.24, 0.0, 0.34)), Vector((-0.28, 0.0, 0.18)), Vector((-0.2, 0.0, 0.05)), Vector((0.02, 0.0, 0.02)),
            Vector((0.22, 0.0, 0.08)), Vector((0.27, 0.0, 0.24)), Vector((0.2, 0.0, 0.36))]
    outline = []
    for i in range(len(tips)):
        outline.append((tips[i].x, tips[i].z))
        if i < len(tips) - 1:
            m = (tips[i] + tips[i + 1]) / 2 * 0.72 + pivot * 0.28
            outline.append((m.x, m.z))
    outline.append((0.0, 0.4))
    memb = flat("wing_membrane", outline, 0.01, (0, 0.04, 0), Matrix.Rotation(math.pi / 2, 3, "X"), sub=1)
    paint(memb, lambda co, n: lin("#9a5ad8").lerp(lin("#4c2a7e"), min(1.0, (co - pivot).length * 3.0)))
    ing.append(memb)
    for t in tips[:3] + tips[4:]:
        bone_ = grow("wing_bone", [pivot + Vector((0, 0.03, 0)), Vector((t.x, 0.06, t.z))], [(0, 1)], [0.012, 0.006], sub=1)
        paint(bone_, lambda co, n: lin("#3a2050"))
        ing.append(bone_)
    claw = grow("wing_claw", [Vector((0.0, 0.06, 0.4)), Vector((0.03, 0.06, 0.45))], [(0, 1)], [0.012, 0.002], sub=0)
    paint(claw, lambda co, n: lin("#f2e8d0"))
    ing.append(claw)
    out["ing_wing"] = ing

    # Frog legs: a pair tied with twine, hung over the edge of a little plate
    ing = bowl("leg_plate", (0, 0, 0), 0.2, 0.035, "#f0e8d4")
    for sgn, a in ((1, 0.25), (-1, -0.2)):
        hip = Vector((sgn * 0.02, 0.0, 0.08))
        knee = hip + Vector((sgn * 0.09, -0.06, 0.12))
        ankle = knee + Vector((sgn * 0.05, -0.04, -0.13))
        leg = grow("leg", [hip, knee, ankle], [(0, 1), (1, 2)], [0.055, 0.035, 0.02], sub=2)
        paint(leg, lambda co, n: lin("#a8f070").lerp(lin("#4aa03a"), 0.6 * max(0.0, -n.y)) if co.z > 0.06 else lin("#d8f0a0"))
        ing.append(leg)
        for t in range(3):
            ta = a + (t - 1) * 0.55
            toe_end = ankle + Vector((math.sin(ta) * 0.09 * sgn, -math.cos(ta) * 0.09, -0.02))
            toe = grow("leg_toe", [ankle, toe_end], [(0, 1)], [0.014, 0.01], sub=1)
            paint(toe, lambda co, n: lin("#c8f090"))
            pad = egg("leg_pad", toe_end, (0.018, 0.018, 0.01), seg=8, rings=5, sub=0)
            paint(pad, lambda co, n: lin("#ffe8a0"))
            ing += [toe, pad]
    twine = ring("leg_twine", (0, 0.0, 0.085), 0.05, 0.012, seg=12, sides=5)
    paint(twine, lambda co, n: lin("#d8b070"))
    ing.append(twine)
    out["ing_leg"] = ing

    # Spider: a big fat spider on her web, strung in a wooden hoop
    ing = []
    hoop = ring("spider_hoop", (0, 0.03, 0.24), 0.2, 0.014, seg=24, sides=6, rot=Matrix.Rotation(math.pi / 2, 3, "X"))
    paint(hoop, lambda co, n: lin("#9a6430"))
    foot = box("spider_foot", (0, 0.03, 0.02), (0.22, 0.1, 0.04), bevel=0.01)
    paint(foot, lit(plain("#7a4624")))
    ing += [hoop, foot]
    c = Vector((0, 0.03, 0.24))
    for k in range(8):
        a = math.pi * 2 * k / 8
        d = Vector((math.cos(a), 0, math.sin(a)))
        s_ = tube("web", c, c + d * 0.2, 0.0025, 0.0025, seg=4)
        paint(s_, lambda co, n: lin("#f0f0ff"))
        ing.append(s_)
    for r in (0.06, 0.11, 0.16):
        wr = ring("web_ring", c, r, 0.0022, seg=16, sides=3, rot=Matrix.Rotation(math.pi / 2, 3, "X"))
        paint(wr, lambda co, n: lin("#f0f0ff"))
        ing.append(wr)
    sb = c + Vector((0, -0.03, 0.0))
    body = egg("spider_body", sb + Vector((0, 0, -0.03)), (0.075, 0.06, 0.09), seg=14, rings=10, sub=1)
    paint(body, lambda co, n: lin("#e8303a") if (abs(co.x) < 0.02 and abs(co.z - (sb.z - 0.04)) < 0.035 and co.y < sb.y - 0.03) else lin("#3a3260").lerp(lin("#14102a"), 0.6 * max(0.0, -n.z)))
    head = egg("spider_head", sb + Vector((0, -0.01, 0.07)), (0.045, 0.04, 0.04), seg=10, rings=6, sub=1)
    paint(head, lambda co, n: lin("#2e2a4a"))
    ing += [body, head]
    for sgn in (1, -1):
        for k in range(4):
            a = 0.9 - k * 0.55
            hip = sb + Vector((sgn * 0.03, -0.01, 0.05 - k * 0.025))
            knee = hip + Vector((sgn * 0.08, -0.04, math.sin(a) * 0.08 + 0.04))
            foot_ = hip + Vector((sgn * 0.15, 0.0, math.sin(a) * 0.14))
            lg = grow("spider_leg", [hip, knee, foot_], [(0, 1), (1, 2)], [0.012, 0.01, 0.005], sub=1)
            paint(lg, lambda co, n: lin("#2e2a4a"))
            ing.append(lg)
        e = egg("spider_eye", sb + Vector((sgn * 0.016, -0.045, 0.08)), (0.012, 0.008, 0.012), seg=8, rings=5, sub=0)
        paint(e, lambda co, n: lin("#ff4a4a"))
        ing.append(e)
    out["ing_spider"] = ing

    # Moon petals: a pale flower whose petals are little crescent moons, glowing, in a blue pot
    ing = []
    pot = lathe("petal_pot", [(0.0, 0.08, 0.08), (0.12, 0.12, 0.12), (0.14, 0.135, 0.135), (0.16, 0.13, 0.13)], seg=16, sub=1)
    paint(pot, lambda co, n: lin("#3a5ab0").lerp(lin("#7aa0f0"), 0.4 * max(0.0, n.z)) if not (0.1 < co.z < 0.125) else lin("#f2c840"))
    soil = egg("petal_soil", (0, 0, 0.15), (0.12, 0.12, 0.02), seg=12, rings=4, sub=0)
    paint(soil, lambda co, n: lin("#3a2414"))
    stem = grow("petal_stem", [(0, 0, 0.15), (0.03, 0.0, 0.3), (0.0, -0.02, 0.42)], [(0, 1), (1, 2)], [0.012, 0.011, 0.01], sub=1)
    paint(stem, lambda co, n: lin("#5aaa4a"))
    leaf = flat("petal_leaf", [(0, 0), (0.06, 0.025), (0.11, 0.0), (0.06, -0.02)], 0.006, (0.02, 0.0, 0.25), Matrix.Rotation(-0.6, 3, "Y"), sub=1)
    paint(leaf, lambda co, n: lin("#6ac84a"))
    ing += [pot, soil, stem, leaf]
    for k in range(5):
        a = 2 * math.pi * k / 5
        crescent = []
        for i in range(13):
            t = i / 12.0
            th = -1.3 + 2.6 * t
            crescent.append((math.cos(th) * 0.07, math.sin(th) * 0.07))
        for i in range(13):
            t = 1.0 - i / 12.0
            th = -1.1 + 2.2 * t
            crescent.append((math.cos(th) * 0.045 + 0.022, math.sin(th) * 0.045))
        pet = flat("glow_petal", crescent, 0.008, (0, 0, 0), None, sub=1)
        pet.data.transform(Matrix.Translation((0, -0.02, 0.43)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(0.5, 4, "Y") @ Matrix.Translation((0.05, 0, 0)))
        paint(pet, lambda co, n: lin("#e0ecff").lerp(lin("#9ac0ff"), 0.4))
        ing.append(pet)
    ctr = egg("glow_centre", (0, -0.02, 0.44), (0.03, 0.03, 0.022), seg=8, rings=5, sub=0)
    paint(ctr, lambda co, n: lin("#fff27a"))
    ing.append(ctr)
    out["ing_petal"] = ing

    # Ghost peppers: a heap of white chillies with spooky little faces in a wicker basket, a wisp over them
    ing = []
    basket = lathe("pepper_basket", [(0.0, 0.11, 0.1), (0.08, 0.17, 0.15), (0.1, 0.18, 0.16)], seg=18, sub=1, cap_top=False)
    paint(basket, lambda co, n: lin("#d8a85a").lerp(lin("#8a5a2a"), 0.5 * (math.sin(math.atan2(co.y, co.x) * 18) * math.sin(co.z * 120) > 0)))
    rim = ring("pepper_rim", (0, 0, 0.1), 0.175, 0.015, seg=24, sides=6)
    paint(rim, lambda co, n: lin("#b07a3a"))
    ing += [basket, rim]
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.3
        b = Vector((math.cos(a) * 0.06, math.sin(a) * 0.05, 0.1 + k * 0.012))
        tip = b + Vector((math.cos(a + 1.3) * 0.12, math.sin(a + 1.3) * 0.1, 0.0))
        pp = grow("pepper", [b, b.lerp(tip, 0.45) + Vector((0, 0, 0.03)), b.lerp(tip, 0.8) + Vector((0, 0, 0.0)), tip + Vector((0, 0, 0.04))],
                  [(0, 1), (1, 2), (2, 3)], [0.04, 0.035, 0.02, 0.004], sub=2)
        paint(pp, lambda co, n: lin("#fffafc").lerp(lin("#e8c8dc"), 0.4 * max(0.0, -n.z)))
        st = grow("pepper_stem", [b, b - (tip - b).normalized() * 0.03 + Vector((0, 0, 0.03))], [(0, 1)], [0.014, 0.008], sub=1)
        paint(st, lambda co, n: lin("#4a9a3a"))
        ing += [pp, st]
        side = (tip - b).cross(Vector((0, 0, 1))).normalized()
        for sgn in (1, -1):
            dot = egg("pepper_eye", b.lerp(tip, 0.3) + side * 0.015 * sgn + Vector((0, 0, 0.04)), (0.009, 0.009, 0.006), seg=6, rings=4, sub=0)
            paint(dot, lambda co, n: lin(INK))
            ing.append(dot)
    wisp = grow("glow_wisp", [(0.02, 0, 0.16), (-0.03, 0.0, 0.25), (0.03, 0.0, 0.33), (0.0, 0.0, 0.38)], [(0, 1), (1, 2), (2, 3)],
                [0.035, 0.03, 0.02, 0.004], sub=1)
    paint(wisp, lambda co, n: lin("#e8f0ff"))
    ing.append(wisp)
    out["ing_pepper"] = ing

    # Dragon scales: one great shining scale propped up on a stand, two small ones at its foot
    ing = []
    base = lathe("scale_base", [(0.0, 0.12, 0.09), (0.03, 0.12, 0.09), (0.04, 0.1, 0.075)], seg=16, sub=1)
    paint(base, lit(plain("#6a3a2a")))
    ing.append(base)
    shield = [(0, 0.2), (0.11, 0.14), (0.14, 0.02), (0.1, -0.1), (0, -0.16), (-0.1, -0.1), (-0.14, 0.02), (-0.11, 0.14)]
    big = flat("scale", shield, 0.03, (0, 0.0, 0.22), Matrix.Rotation(1.35, 3, "X"), sub=2)
    paint(big, lambda co, n: lin("#ffb83a").lerp(lin("#ff5a1a"), max(0.0, min(1.0, (0.3 - co.z) * 3.0))).lerp(lin("#fff0a0"), 0.5 * max(0.0, -n.y) ** 4))
    ridge = grow("scale_ridge", [(0, -0.02, 0.08), (0, -0.04, 0.22), (0, -0.05, 0.36)], [(0, 1), (1, 2)], [0.012, 0.016, 0.006], sub=1)
    paint(ridge, lambda co, n: lin("#ffe080"))
    ing += [big, ridge]
    for k, x in enumerate((-0.09, 0.1)):
        sm = flat("scale_small", [(px * 0.45, py * 0.45) for px, py in shield], 0.02, (x, -0.07, 0.03), Matrix.Rotation(0.3 + k * 0.4, 3, "Z"), sub=1)
        paint(sm, lambda co, n: lin("#ff9a2e").lerp(lin("#ffe080"), 0.4 * max(0.0, n.z)))
        ing.append(sm)
    out["ing_scale"] = ing

    # A place on the table not stocked yet: an empty dish under a cobweb
    ing = bowl("empty_bowl", (0, 0, 0), 0.17, 0.08, "#6a5a6a")
    for k in range(6):
        a = math.pi * k / 6
        d = Vector((math.cos(a), math.sin(a), 0))
        web = tube("web", d * -0.17 + Vector((0, 0, 0.09)), d * 0.17 + Vector((0, 0, 0.09)), 0.004, 0.004, seg=4)
        paint(web, lambda co, n: lin("#e8e8f0"))
        ing.append(web)
    for r in (0.06, 0.12):
        wr = ring("web_ring", (0, 0, 0.092), r, 0.003, seg=12, sides=3)
        paint(wr, lambda co, n: lin("#e8e8f0"))
        ing.append(wr)
    out["ing_empty"] = ing

    # The bellows: two pear-shaped boards with handles, hinged at the brass nozzle, pleated
    # leather between. Origin at the hinge; the nozzle points along -X. The game opens the top board.
    pear = [(0, 0.06), (0.12, 0.12), (0.28, 0.17), (0.42, 0.15), (0.5, 0.07), (0.52, 0.0), (0.5, -0.07), (0.42, -0.15), (0.28, -0.17), (0.12, -0.12), (0, -0.06)]
    bottom = flat("bellows_bottom", pear, 0.035, (0.02, 0, -0.06), sub=1)
    topb = flat("bellows_top", pear, 0.035, (0.02, 0, 0.06), sub=1)
    for b in (bottom, topb):
        paint(b, lambda co, n: lin("#b87a40").lerp(lin("#e0a868"), 0.4 * max(0.0, n.z)) if not (0.22 < co.x < 0.34 and abs(co.y) < 0.05) else lin("#f2c840"))
    pleats = []
    for k in range(3):
        z = -0.035 + k * 0.035
        pl = flat("bellows_pleat", [(px * 0.97, py * 0.97) for px, py in pear], 0.02, (0.03, 0, z), sub=1)
        paint(pl, lambda co, n: lin("#9a3a22").lerp(lin("#5a1a10"), 0.3 * (k % 2)))
        pleats.append(pl)
    nozzle = tube("bellows_nozzle", (0.04, 0, 0), (-0.24, 0, 0), 0.045, 0.018, seg=12)
    paint(nozzle, lit(plain("#f0c046", "#a8741a", -0.05, 0.05)))
    collar = ring("bellows_collar", (0.03, 0, 0), 0.05, 0.015, seg=12, sides=5, rot=Matrix.Rotation(math.pi / 2, 3, "Y"))
    paint(collar, lambda co, n: lin("#f0c046"))
    out_b = [bottom, nozzle, collar] + pleats
    top_handle = None
    for b, z in ((bottom, -0.08), (topb, 0.08)):
        hd = grow("bellows_handle", [(0.5, 0, z), (0.66, 0, z * 1.4), (0.74, 0, z * 1.4)], [(0, 1), (1, 2)], [0.026, 0.03, (0.045, 0.035)], sub=1)
        paint(hd, lit(plain("#6b3e22")))
        if z > 0:
            top_handle = hd
        else:
            out_b.append(hd)
    out["bellows"] = out_b
    out["bellows_top"] = [topb, top_handle]


    # The top of the witches' tower, where brews are tried out: a round stone floor with a chalked
    # circle, a ring of battlements, a trapdoor, a lectern for the book, a pennant on a pole.
    # Its middle (where the witch stands) is the origin.
    tower = []
    rnd_t = random.Random(31)
    floor_ = lathe("tower_floor", [(-0.6, 3.0, 3.0), (-0.1, 3.0, 3.0), (0.0, 2.95, 2.95)], seg=32, sub=0)

    def flags(co, n):
        r = math.hypot(co.x, co.y)
        a = math.atan2(co.y, co.x)
        if n.z > 0.5:
            # Flagstones in rings, the chalk circle and its star
            ring_k = math.floor(r / 0.6)
            cell = math.floor(a * (3 + ring_k * 2) / math.pi)
            shade_k = 0.06 * ((ring_k * 7 + cell * 3) % 4)
            c = lin("#8a8298").lerp(lin("#5a5468"), shade_k * 2)
            if abs(r - 1.05) < 0.035 or abs(r - 0.92) < 0.025:
                c = lin("#f0ecf8")
            for k in range(5):
                p1 = Vector((math.cos(math.pi / 2 + k * 4 * math.pi / 5), math.sin(math.pi / 2 + k * 4 * math.pi / 5), 0)) * 0.92
                p2 = Vector((math.cos(math.pi / 2 + (k + 1) * 4 * math.pi / 5), math.sin(math.pi / 2 + (k + 1) * 4 * math.pi / 5), 0)) * 0.92
                d = p2 - p1
                t = max(0.0, min(1.0, (Vector((co.x, co.y, 0)) - p1).dot(d) / d.length_squared))
                if (Vector((co.x, co.y, 0)) - (p1 + d * t)).length < 0.025:
                    c = lin("#f0ecf8")
            return c
        return lin("#6a6278") * (0.7 + 0.3 * max(0.0, n.z))
    # A finer floor so the chalk shows: subdivide it flat
    sub_floor = floor_.modifiers.new("sub", "SUBSURF")
    sub_floor.subdivision_type = "SIMPLE"
    sub_floor.levels = 3
    floor_ = bake(floor_)
    paint(floor_, flags)
    tower.append(floor_)
    wall = lathe("tower_wall", [(-30.0, 3.4, 3.4), (-3.0, 3.1, 3.1), (0.6, 3.1, 3.1), (0.6, 2.75, 2.75), (0.0, 2.75, 2.75)], seg=40, sub=0, cap_top=False, cap_bottom=False)

    def stones(co, n):
        a = math.atan2(co.y, co.x)
        row = math.floor(co.z / 0.3)
        col_k = math.floor(a * 12 / math.pi + (0.5 if row % 2 else 0.0))
        k = ((row * 5 + col_k * 3) % 5) * 0.05
        mortar = abs(co.z / 0.3 - round(co.z / 0.3)) < 0.06
        c = lin("#7a7090").lerp(lin("#4a4460"), k * 2.5)
        return c * (0.55 if mortar else 1.0)
    paint(wall, stones)
    tower.append(wall)
    for k in range(16):
        a = 2 * math.pi * k / 16
        merlon = box("merlon", (math.cos(a) * 2.93, math.sin(a) * 2.93, 0.95), (0.5, 0.36, 0.7), bevel=0.03, rot=Matrix.Rotation(a, 3, "Z"))
        paint(merlon, lambda co, n, s=rnd_t.uniform(0, 0.15): lin("#857b9a").lerp(lin("#5a5470"), s + 0.2 * max(0.0, -n.z)))
        tower.append(merlon)
    trap = box("trapdoor", (1.7, 0.9, 0.02), (0.7, 0.7, 0.04), bevel=0.01, rot=Matrix.Rotation(0.4, 3, "Z"))
    paint(trap, lambda co, n: lin("#8a5228") if (math.sin(co.x * 25) > -0.8) else lin("#5a3418"))
    ringpull = ring("trap_ring", (1.62, 0.78, 0.05), 0.06, 0.012, seg=12, sides=5)
    paint(ringpull, lambda co, n: lin("#3a3346"))
    tower += [trap, ringpull]
    lectern = grow("lectern", [(-1.6, 1.0, 0.0), (-1.6, 1.0, 0.9)], [(0, 1)], [0.07, 0.05], sub=0)
    paint(lectern, lambda co, n: lin("#6b3e22"))
    top_l = box("lectern_top", (-1.6, 1.0, 0.95), (0.5, 0.36, 0.05), bevel=0.01, rot=Matrix.Rotation(-0.4, 3, "X"))
    paint(top_l, lambda co, n: lin("#8a5228"))
    tower += [lectern, top_l]
    pole = tube("pole", (2.2, -1.6, 0.0), (2.2, -1.6, 3.2), 0.04, 0.035, seg=8)
    paint(pole, lambda co, n: lin("#5a3418"))
    pennant = flat("pennant", [(0, 0), (0.9, -0.18), (0.0, -0.4)], 0.01, (2.2, -1.6, 3.15), Matrix.Rotation(math.pi / 2, 3, "X") @ Matrix.Rotation(0.4, 3, "Y"), sub=1)
    paint(pennant, lambda co, n: lin("#8a55c8"))
    tower += [pole, pennant]
    for k, (x, y) in enumerate(((-2.2, -1.2), (2.3, 0.9), (-0.6, 2.4))):
        candle = tube("candle", (x, y, 0.0), (x, y, 0.25 + k * 0.06), 0.06, 0.055, seg=8)
        paint(candle, lambda co, n: lin("#f4ecd0"))
        flame_ = egg("glow_flame", (x, y, 0.32 + k * 0.06), (0.04, 0.04, 0.08), seg=8, rings=5, sub=0)
        paint(flame_, lambda co, n: lin("#ffd060"))
        tower += [candle, flame_]
    out["tower_top"] = tower


    # The stirring stick: a long wooden paddle. Origin at the top end; it runs along +Y to the blade.
    stick = tube("stick", (0, 0, 0), (0, 1.25, 0), 0.04, 0.035, seg=10, sub=1)
    paint(stick, lambda co, n: lin("#b07a40").lerp(lin("#7a4a24"), 0.5 * (math.sin(co.y * 30) > 0.7)))
    blade = egg("stick_blade", (0, 1.38, 0), (0.1, 0.18, 0.03), seg=12, rings=8, sub=1)
    paint(blade, lambda co, n: lin("#9a6430"))
    knob = egg("stick_knob", (0, -0.02, 0), (0.055, 0.055, 0.055), seg=10, rings=6, sub=0)
    paint(knob, lambda co, n: lin("#7a4a24"))
    out["stick"] = [stick, blade, knob]

    # The wand standing in a jar of sand; the wand is its own piece (origin at its grip)
    jar = lathe("wand_jar", [(0.0, 0.08, 0.08), (0.12, 0.1, 0.1), (0.16, 0.07, 0.07), (0.2, 0.07, 0.07)], seg=14, sub=1, cap_top=True)
    paint(jar, lit(plain("#6a8aa8", "#3a5a78", 0.0, 0.2)))
    out["wand_jar"] = [jar]
    wand = tube("wand", (0, 0, 0), (0, 0, 0.42), 0.016, 0.012, seg=8, sub=1)
    paint(wand, lambda co, n: lin("#3a2418"))
    star = flat("glow_star", [(math.cos(2 * math.pi * k / 10 + math.pi / 2) * (0.07 if k % 2 == 0 else 0.03),
                               math.sin(2 * math.pi * k / 10 + math.pi / 2) * (0.07 if k % 2 == 0 else 0.03)) for k in range(10)],
                0.025, (0, 0, 0.48), Matrix.Rotation(math.pi / 2, 3, "X"), sub=0)
    paint(star, lambda co, n: lin("#fff27a"))
    out["wand"] = [wand, star]

    # A rack of empty bottles waiting to be filled
    rack = [box("rack", (0, 0, 0.03), (0.56, 0.2, 0.06), bevel=0.012)]
    paint(rack[0], lit(plain("#8a5228")))
    for k in range(3):
        x = (k - 1) * 0.17
        b = egg("glass_rack_bottle", (x, 0, 0.15), (0.075, 0.075, 0.09), seg=12, rings=8, sub=1)
        nk = tube("glass_rack_neck", (x, 0, 0.22), (x, 0, 0.3), 0.025, 0.025, seg=8, sub=0)
        ck = tube("rack_cork", (x, 0, 0.3), (x, 0, 0.34), 0.03, 0.028, seg=8, sub=0)
        paint(b, lambda co, n: lin("#c8eaf4").lerp(Vector((1, 1, 1)), 0.4 * max(0.0, -n.y)))
        paint(nk, lambda co, n: lin("#c8eaf4"))
        paint(ck, lambda co, n: lin("#c8925a"))
        rack += [b, nk, ck]
    out["bottles"] = rack
    # One filled bottle, flown to the customer; its liquid is its own piece so the game can colour it
    glass = egg("glass_bottle", (0, 0, 0.13), (0.13, 0.13, 0.13), seg=14, rings=9, sub=1)
    paint(glass, lambda co, n: lin("#d8f0f8"))
    neck = tube("glass_bottle_neck", (0, 0, 0.24), (0, 0, 0.36), 0.045, 0.045, seg=10, sub=0)
    paint(neck, lambda co, n: lin("#d8f0f8"))
    cork = tube("bottle_cork", (0, 0, 0.36), (0, 0, 0.42), 0.055, 0.05, seg=10, sub=0)
    paint(cork, lambda co, n: lin("#c8925a"))
    liquid = egg("liquid", (0, -0.002, 0.12), (0.125, 0.125, 0.105), seg=14, rings=8, sub=1)
    paint(liquid, lambda co, n: Vector((1, 1, 1)) * (0.75 + 0.25 * max(0.0, n.z)))
    out["potion"] = [glass, neck, cork]
    out["potion_liquid"] = [liquid]

    # The recipe book, open on a little stand
    stand = box("book_stand", (0, 0.03, 0.06), (0.42, 0.24, 0.08), bevel=0.015, rot=Matrix.Rotation(0.0, 3, "Z"))
    paint(stand, lit(plain("#6b3e22")))
    book = []
    for sgn in (1, -1):
        cover = box("book_cover", (sgn * 0.13, 0.0, 0.14), (0.27, 0.34, 0.025), bevel=0.008,
                    rot=Matrix.Rotation(-0.55, 3, "X") @ Matrix.Rotation(sgn * 0.12, 3, "Y"))
        paint(cover, lit(plain("#8a2a3a")))
        page = box("book_page", (sgn * 0.12, -0.005, 0.16), (0.24, 0.31, 0.03), bevel=0.01,
                   rot=Matrix.Rotation(-0.55, 3, "X") @ Matrix.Rotation(sgn * 0.18, 3, "Y"))
        paint(page, lambda co, n: lin("#f4e4bc") if math.sin(co.z * 160) < 0.85 else lin("#8a6a4a"))
        book += [cover, page]
    out["book"] = [stand] + book

    # Each prop to a .glb of its own (the .blend keeps them all)
    os.makedirs(os.path.join(ROOT, "models"), exist_ok=True)
    groups = {}
    for name, obs in out.items():
        solid = [o for o in obs if not o.name.startswith(("glass_", "glow_"))]
        glass = [o for o in obs if o.name.startswith("glass_")]
        glow = [o for o in obs if o.name.startswith("glow_")]
        main_ob = join(solid, name) if len(solid) > 1 else solid[0]
        main_ob.name = name
        for kind, parts in (("glass", glass), ("glow", glow)):
            if parts:
                extra = join(parts, name + "_" + kind) if len(parts) > 1 else parts[0]
                extra.name = name + "_" + kind
                extra.parent = main_ob
        groups[name] = main_ob
    # Spread them out in the .blend so they can be looked at
    for k, (name, ob) in enumerate(groups.items()):
        ob.location.x = (k % 6) * 1.2
        ob.location.y = (k // 6) * 1.2
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT, "art", "props.blend"))
    known = bpy.ops.export_scene.gltf.get_rna_type().properties.keys()
    for name, ob in groups.items():
        loc = ob.location.copy()
        ob.location = (0, 0, 0)
        for o in bpy.context.selected_objects:
            o.select_set(False)
        ob.select_set(True)
        for child in ob.children:
            child.select_set(True)
        want = dict(filepath=os.path.join(ROOT, "models", name + ".glb"), export_format="GLB", export_yup=True,
                    export_animations=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                    export_active_vertex_color_when_no_material=True, export_colors=True, use_selection=True)
        bpy.ops.export_scene.gltf(**{k: v for k, v in want.items() if k in known})
        ob.location = loc
        print("wrote", name, "faces:", len(ob.data.polygons))


main()
