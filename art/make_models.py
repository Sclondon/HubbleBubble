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
         hair="#ff7a2a", eyes=1.15, nose="button", chin=0.3, height=0.82, girth=0.85, hunch=0.0, hat_height=0.7,
         hat_bend=0.25, hair_style="pigtails", freckles=True, brim=0.52, flower="#ffd84a", ears=0.6),
    dict(name="witch_gristle", skin="#a9b49a", dress="#5a4a6a", trim="#3a2c48", hat="#4a3a2a", band="#8a6a4a",
         hair="#f2f0e8", eyes=0.85, nose="long", chin=1.2, height=0.92, girth=0.95, hunch=0.35, hat_height=0.8,
         hat_bend=0.9, hair_style="wild", shawl="#7a5a8a", brim=0.6, warts=3, ears=1.1),
    dict(name="witch_bella", skin="#7ab0f0", dress="#2a2a6a", trim="#141440", hat="#1a1a3a", band="#a8c8ff",
         hair="#1a1a28", eyes=1.0, nose="pointy", chin=0.9, height=1.12, girth=0.78, hunch=0.0, hat_height=1.35,
         hat_bend=0.15, hair_style="long", stars=True, brim=0.58, ears=1.0),
    dict(name="witch_bogwort", skin="#7a9a4a", dress="#5a6a32", trim="#38441e", hat="#3a5a32", band="#8a5a2a",
         hair="#3a5a2a", eyes=0.95, nose="bulb", chin=0.6, height=0.95, girth=1.4, hunch=0.1, hat_height=0.85,
         hat_bend=0.5, hair_style="wild", toadstool=True, brim=0.7, warts=2, ears=0.9),
    dict(name="witch_polly", skin="#c8a8f0", dress="#e8701a", trim="#9a3a10", hat="#ff8a1a", band="#3a8a2a",
         hair="#d8302a", eyes=1.1, nose="pointy", chin=0.7, height=0.98, girth=1.05, hunch=0.0, hat_height=0.95,
         hat_bend=0.6, hair_style="bob", brim=0.6, ears=0.9),
    dict(name="witch_esme", skin="#eceaff", dress="#f2f2ff", trim="#b8bce8", hat="#c8c8e8", band="#8a7ac8",
         hair="#b8c8ff", eyes=1.05, nose="hook", chin=0.8, height=1.02, girth=0.9, hunch=0.0, hat_height=1.0,
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

    # The head: an egg drawn down into a chin, cheeks pushed out
    chin = spec["chin"]

    def head_shape(v):
        front = max(0.0, -v.y / head_r.y)
        low = max(0.0, -v.z / head_r.z)
        v = v.copy()
        # The jaw narrows and juts forward and down into a point
        k = 1.0 - 0.35 * low ** 1.4 * chin
        v.x *= k
        v.y -= 0.12 * chin * low ** 2 * (0.4 + front)
        v.z -= 0.08 * chin * low ** 3
        return v
    head = egg("head", head_c, head_r, seg=20, rings=14, sub=1, shape=head_shape)
    skin = spec["skin"]
    paint(head, lit(plain(skin, shade(skin, -0.2), head_c.z - 0.4, head_c.z + 0.3), 0.3))
    parts.append(head)
    head_parts = []
    # The nose
    nose = spec["nose"]
    nb = head_c + F * Vector((0, -0.26, 0.02))
    if nose == "hook":
        np = [nb, nb + Vector((0, -0.18, 0.0)), nb + Vector((0, -0.31, -0.07)), nb + Vector((0, -0.33, -0.17))]
        nr = [0.075, 0.06, 0.045, 0.028]
    elif nose == "long":
        np = [nb, nb + Vector((0, -0.2, -0.03)), nb + Vector((0.02, -0.38, -0.1)), nb + Vector((0.04, -0.44, -0.2))]
        nr = [0.075, 0.055, 0.04, 0.025]
    elif nose == "pointy":
        np = [nb, nb + Vector((0, -0.16, -0.02)), nb + Vector((0, -0.28, 0.0))]
        nr = [0.07, 0.04, 0.012]
    elif nose == "bulb":
        np = [nb, nb + Vector((0, -0.1, -0.03)), nb + Vector((0, -0.16, -0.06))]
        nr = [0.07, 0.08, 0.09]
    else:
        np = [nb + Vector((0, 0.02, -0.03)), nb + Vector((0, -0.05, -0.05))]
        nr = [0.05, 0.055]
    nose_ob = grow("nose", np, [(i, i + 1) for i in range(len(np) - 1)], nr, sub=2)
    paint(nose_ob, lit(plain(shade(skin, 0.06), skin)))
    head_parts.append(nose_ob)
    for k in range(spec.get("warts", 1 if nose == "hook" else 0)):
        p = np[min(len(np) - 1, 1 + k % (len(np) - 1))]
        wart = egg("wart", p + Vector((0.04 if k % 2 == 0 else -0.04, -0.01, 0.02)), (0.028, 0.028, 0.028), seg=8, rings=6, sub=1)
        paint(wart, lambda co, n: lin("#9a7a3a"))
        head_parts.append(wart)
    # Pointed ears
    for sgn in (1, -1):
        e0 = head_c + F * Vector((sgn * 0.27, 0.02, 0.0))
        ear = grow("ear", [e0, e0 + Vector((sgn * 0.14, 0.03, 0.06)) * spec["ears"], e0 + Vector((sgn * 0.24, 0.06, 0.14)) * spec["ears"]],
                   [(0, 1), (1, 2)], [(0.07, 0.025), (0.05, 0.018), (0.01, 0.006)], sub=1)
        paint(ear, lit(plain(skin)))
        head_parts.append(ear)
    # Cheeks, freckles
    for sgn in (1, -1):
        ch = egg("cheek", head_c + F * Vector((sgn * 0.17, -0.22, -0.07)), (0.07, 0.04, 0.05), seg=10, rings=6, sub=1)
        paint(ch, lambda co, n, s=skin: lin(s).lerp(lin("#ff8a8a"), 0.3))
        head_parts.append(ch)
        if spec.get("freckles"):
            for k in range(4):
                f = egg("freckle", head_c + F * Vector((sgn * (0.12 + k % 2 * 0.06), -0.265 + k * 0.004, -0.02 - k * 0.025)),
                        (0.012, 0.006, 0.012), seg=6, rings=4, sub=0)
                paint(f, lambda co, n: lin("#c86a3a"))
                head_parts.append(f)
    # Brows, mean and bushy, on bones of their own
    brows = []
    for side, sgn in (("L", 1), ("R", -1)):
        bc = head_c + F * Vector((sgn * 0.13, -0.24, 0.33))
        brow = grow("brow_" + side, [bc - Vector((sgn * 0.08, -0.02, -0.02)), bc + Vector((sgn * 0.07, 0.03, 0.01))], [(0, 1)],
                    [(0.035, 0.022), (0.022, 0.015)], sub=1)
        paint(brow, lambda co, n: lin(spec["hair"]) * 0.7)
        group(brow, rigid("brow." + side))
        brows.append(brow)
    # The mouth, a dark slot she talks with, and maybe a tooth
    mouth_c = head_c + F * Vector((0, -0.25 - 0.04 * chin, -0.12 - 0.02 * chin))
    mouth = egg("mouth", mouth_c, (0.15, 0.06, 0.045), seg=14, rings=8, sub=1)
    paint(mouth, lambda co, n: lin("#40101e") if co.y < mouth_c.y - 0.02 else lin("#200810"))
    group(mouth, rigid("mouth"))
    mparts = [mouth]
    if spec.get("tooth", True):
        tooth = box("tooth", mouth_c + Vector((0.035, -0.035, 0.02)), (0.032, 0.02, 0.04), bevel=0.006)
        paint(tooth, lambda co, n: lin("#fff2b0"))
        group(tooth, rigid("mouth"))
        mparts.append(tooth)
    lip = grow("lip", [mouth_c + Vector((-0.12, 0.0, 0.015)), mouth_c + Vector((0, -0.035, 0.035)), mouth_c + Vector((0.12, 0.0, 0.015))],
               [(0, 1), (1, 2)], [0.018, 0.02, 0.018], sub=1)
    paint(lip, lit(plain(skin)))
    group(lip, rigid("head"))
    head_parts.append(lip)
    # Great goggling eyes, each a white with a pupil on a bone of its own (the game looks and blinks with them)
    eyes = []
    es = spec["eyes"] * 1.3
    eye_pos = {}
    for side, sgn in (("L", 1), ("R", -1)):
        ec = head_c + F * Vector((sgn * 0.115 * es, -0.235, 0.09))
        eye_pos[side] = ec
        white = egg("eye_" + side, ec, (0.11 * es, 0.075 * es, 0.13 * es), seg=16, rings=10, sub=1)
        paint(white, lambda co, n: lin("#fffbe8") * (0.85 + 0.15 * max(0.0, -n.y)))
        group(white, rigid("eye." + side))
        pc = ec + Vector((0, -0.068 * es, 0))
        pupil = egg("pupil_" + side, pc, (0.042 * es, 0.022 * es, 0.05 * es), seg=10, rings=6, sub=1)
        paint(pupil, lambda co, n: lin(INK))
        group(pupil, rigid("pupil." + side))
        shine = egg("shine_" + side, pc + Vector((-0.015 * es, -0.02, 0.022 * es)), (0.012 * es, 0.006, 0.012 * es), seg=6, rings=4, sub=0)
        paint(shine, lambda co, n: Vector((1, 1, 1)))
        group(shine, rigid("pupil." + side))
        eyes += [white, pupil, shine]

    # Hair: strands from under the hat, long, wild, in pigtails or a bob
    hair = []
    style = spec["hair_style"]
    hc = spec["hair"]
    n_strands = {"long": 13, "wild": 16, "bob": 14, "pigtails": 8}[style]
    for k in range(n_strands):
        a = -1.9 + 3.8 * k / (n_strands - 1)
        root = head_c + F * Vector((math.sin(a) * 0.29, math.cos(a) * 0.26, 0.17))
        out = Vector((math.sin(a), math.cos(a), 0))
        if style == "long":
            ln = rnd.uniform(0.7, 1.1)
            pts = [root, root + out * 0.1 + Vector((0, 0, -0.25 * ln)), root + out * 0.14 + Vector((rnd.uniform(-0.03, 0.03), 0.02, -0.55 * ln)), root + out * 0.17 + Vector((rnd.uniform(-0.05, 0.05), 0.06, -0.8 * ln))]
        elif style == "wild":
            j = Vector((rnd.uniform(-0.08, 0.08), rnd.uniform(-0.04, 0.08), rnd.uniform(-0.05, 0.05)))
            pts = [root, root + out * 0.16 + Vector((0, 0, -0.15)) + j, root + out * 0.28 + Vector((0, 0.04, -0.35)) + j * 2]
        elif style == "bob":
            pts = [root, root + out * 0.1 + Vector((0, 0, -0.18)), root + out * 0.12 + Vector((0, 0.0, -0.3))]
        else:
            pts = [root, root + out * 0.06 + Vector((0, 0, -0.12))]
        rad = [0.042, 0.034, 0.025, 0.014][:len(pts)]
        s_ob = grow("hair", pts, [(i, i + 1) for i in range(len(pts) - 1)], rad, sub=1)
        paint(s_ob, lit(plain(hc, shade(hc, -0.35), pts[-1].z, root.z)))
        hair.append(s_ob)
    if style == "pigtails":
        for sgn in (1, -1):
            r0 = head_c + F * Vector((sgn * 0.27, 0.06, 0.0))
            tail = grow("pigtail", [r0, r0 + Vector((sgn * 0.14, 0.04, -0.12)), r0 + Vector((sgn * 0.2, 0.06, -0.32))], [(0, 1), (1, 2)],
                        [0.06, 0.07, 0.03], sub=2)
            paint(tail, lit(plain(hc)))
            bow = egg("bow", r0 + Vector((sgn * 0.08, 0.02, -0.04)), (0.06, 0.04, 0.05), seg=8, rings=6, sub=1)
            paint(bow, lambda co, n: lin(spec["band"]))
            hair += [tail, bow]

    # The hat: a wide drooping brim, a band and buckle, and a cone that bends over at the top
    hat = []
    hb = head_c + F * Vector((0, 0.03, 0.27))
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
        bc = head_c + F * Vector((sgn * 0.13, -0.24, 0.33))
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

    # The ingredients, each on the table in its own dish, pot or stand (origin where it sits)
    # Eye of newt: a wooden bowl heaped with eyeballs
    ing = bowl("eye_bowl", (0, 0, 0), 0.2, 0.1, "#9a6a3a")
    for k, p in enumerate([(-0.07, 0.0, 0.12), (0.07, 0.02, 0.12), (0.0, -0.06, 0.15), (0.0, 0.07, 0.16), (0.02, -0.0, 0.22)]):
        ing.append(eyeball("eye", p, 0.07, look=Vector((rnd.uniform(-0.5, 0.5), -1, rnd.uniform(0, 0.6)))))
    out["ing_eye"] = ing
    # Toadstools growing from a mossy stump
    ing = []
    stump = lathe("stump", [(0.0, 0.19, 0.17), (0.12, 0.16, 0.15), (0.14, 0.15, 0.14)], seg=14, sub=1)
    paint(stump, lambda co, n: lin("#7a5a3a") if n.z < 0.7 else lin("#c8a070").lerp(lin("#5a8a3a"), 0.4 * (math.sin(co.x * 50) > 0.3)))
    ing.append(stump)
    for (x, y, hgt, r) in ((-0.06, 0.0, 0.2, 0.11), (0.08, 0.04, 0.15, 0.08), (0.02, -0.08, 0.11, 0.065)):
        st = tube("ts_stem", (x, y, 0.12), (x, y, 0.12 + hgt), r * 0.35, r * 0.3, seg=8, sub=1)
        paint(st, lambda co, n: lin("#f2e4c0"))
        cap = egg("ts_cap", (x, y, 0.12 + hgt), (r, r, r * 0.7), seg=14, rings=8, sub=1, shape=lambda v: Vector((v.x, v.y, max(v.z, -v.z * 0.1 - 0.005))))
        paint(cap, lambda co, n, cx=x, cy=y: lin("#fffbf0") if (n.z > 0.2 and math.sin((co.x - cx) * 70) * math.sin((co.y - cy) * 70) > 0.55) else (lin("#e8382a") if n.z > -0.3 else lin("#e8d8b0")))
        ing += [st, cap]
    out["ing_shroom"] = ing
    # Bat wings laid on a dish
    ing = bowl("wing_dish", (0, 0, 0), 0.24, 0.05, "#c8c0d8")
    wing = [(0, 0), (0.1, 0.06), (0.2, 0.05), (0.26, 0.1), (0.25, 0.02), (0.29, -0.04), (0.2, -0.03), (0.16, -0.1), (0.1, -0.04), (0.05, -0.08)]
    for k, (a, z) in enumerate(((0.3, 0.06), (2.6, 0.08))):
        wgo = flat("wing", wing, 0.012, (0, 0, z), Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(0.2, 3, "X"), sub=1)
        wgo.data.transform(Matrix.Translation((-math.cos(a) * 0.12, -math.sin(a) * 0.12, 0)))
        paint(wgo, lambda co, n: lin("#8a52c9").lerp(lin("#4c2a7e"), 0.5 * (1 - abs(n.z))))
        ing.append(wgo)
    out["ing_wing"] = ing
    # Frog legs on a plate
    ing = bowl("leg_plate", (0, 0, 0), 0.25, 0.04, "#e8e0c8")
    ing += frog_leg("leg", (-0.14, -0.03, 0.06), 1, 0.3)
    ing += frog_leg("leg", (-0.12, 0.08, 0.07), 1, -0.2)
    out["ing_leg"] = ing
    # A big hairy spider on a stone
    ing = []
    stone = egg("spider_stone", (0, 0, 0.05), (0.18, 0.15, 0.07), seg=12, rings=7, sub=1)
    paint(stone, lit(plain("#9a90a8", "#6a6078", 0.0, 0.1)))
    ing.append(stone)
    body = egg("spider_body", (0, 0.04, 0.17), (0.09, 0.11, 0.08), seg=12, rings=8, sub=1)
    paint(body, lambda co, n: lin("#2e2a4a") if not (abs(co.x) < 0.025 and co.z > 0.22) else lin("#e8303a"))
    head = egg("spider_head", (0, -0.07, 0.15), (0.055, 0.05, 0.05), seg=10, rings=6, sub=1)
    paint(head, lambda co, n: lin("#2e2a4a"))
    ing += [body, head]
    for sgn in (1, -1):
        for k in range(4):
            a = -0.9 + k * 0.6
            b0 = Vector((sgn * 0.03, -0.05 + k * 0.03, 0.15))
            knee = b0 + Vector((sgn * 0.12, math.sin(a) * 0.08, 0.09))
            foot = b0 + Vector((sgn * 0.2, math.sin(a) * 0.14, -0.06))
            lg = grow("spider_leg", [b0, knee, foot], [(0, 1), (1, 2)], [0.016, 0.014, 0.008], sub=1)
            paint(lg, lambda co, n: lin("#2e2a4a"))
            ing.append(lg)
        e = egg("spider_eye", (sgn * 0.022, -0.115, 0.17), (0.016, 0.012, 0.016), seg=8, rings=5, sub=0)
        paint(e, lambda co, n: Vector((1, 1, 1)))
        ing.append(e)
    out["ing_spider"] = ing
    # A moon petal flower in a clay pot, glowing
    ing = []
    pot = lathe("petal_pot", [(0.0, 0.1, 0.1), (0.14, 0.13, 0.13), (0.16, 0.15, 0.15), (0.18, 0.15, 0.15)], seg=14, sub=1)
    paint(pot, lit(plain("#c8703a", "#8a4a22", 0.0, 0.18)))
    soil = egg("petal_soil", (0, 0, 0.17), (0.13, 0.13, 0.02), seg=12, rings=4, sub=0)
    paint(soil, lambda co, n: lin("#3a2414"))
    stem = grow("petal_stem", [(0, 0, 0.17), (0.02, 0.0, 0.3), (0.0, -0.02, 0.4)], [(0, 1), (1, 2)], [0.014, 0.012, 0.01], sub=1)
    paint(stem, lambda co, n: lin("#4a9a3a"))
    ing += [pot, soil, stem]
    for k in range(6):
        a = 2 * math.pi * k / 6
        pet = egg("glow_petal", (math.cos(a) * 0.075, -0.02 + math.sin(a) * 0.075, 0.42), (0.075, 0.04, 0.015), seg=10, rings=5, sub=1)
        pet.data.transform(Matrix.Translation((math.cos(a) * 0.075, -0.02 + math.sin(a) * 0.075, 0.42)) @ Matrix.Rotation(a, 4, "Z") @ Matrix.Rotation(0.35, 4, "Y") @ Matrix.Translation((-math.cos(a) * 0.075, 0.02 - math.sin(a) * 0.075, -0.42)))
        paint(pet, lambda co, n: lin("#cfe0ff"))
        ing.append(pet)
    ctr = egg("glow_centre", (0, -0.02, 0.43), (0.035, 0.035, 0.025), seg=8, rings=5, sub=0)
    paint(ctr, lambda co, n: lin("#fff27a"))
    ing.append(ctr)
    out["ing_petal"] = ing
    # Ghost peppers heaped in a little basket
    ing = bowl("pepper_basket", (0, 0, 0), 0.2, 0.09, "#c8a05a", inside="#8a6a3a")
    for k in range(4):
        a = 2 * math.pi * k / 4 + 0.4
        b = Vector((math.cos(a) * 0.07, math.sin(a) * 0.07, 0.11 + k * 0.01))
        tip = b + Vector((math.cos(a + 1.2) * 0.12, math.sin(a + 1.2) * 0.12, -0.02))
        pp = grow("pepper", [b, b.lerp(tip, 0.5) + Vector((0, 0, 0.03)), tip], [(0, 1), (1, 2)], [0.045, 0.035, 0.008], sub=2)
        paint(pp, lit(plain("#fff4fa", "#e8c8dc", b.z - 0.04, b.z + 0.04)))
        st = grow("pepper_stem", [b, b - (tip - b).normalized() * 0.04 + Vector((0, 0, 0.02))], [(0, 1)], [0.012, 0.008], sub=1)
        paint(st, lambda co, n: lin("#4a9a3a"))
        ing += [pp, st]
        for sgn in (1, -1):
            side = (tip - b).cross(Vector((0, 0, 1))).normalized()
            dot = egg("pepper_eye", b.lerp(tip, 0.3) + side * 0.02 * sgn + Vector((0, 0, 0.035)), (0.008, 0.008, 0.006), seg=6, rings=4, sub=0)
            paint(dot, lambda co, n: lin(INK))
            ing.append(dot)
    out["ing_pepper"] = ing
    # Dragon scales fanned out on a velvet cushion
    ing = []
    cushion = egg("scale_cushion", (0, 0, 0.05), (0.2, 0.17, 0.06), seg=14, rings=8, sub=1,
                  shape=lambda v: Vector((v.x, v.y, v.z * (1.0 - 0.3 * (abs(v.x) / 0.2) ** 2))))
    paint(cushion, lit(plain("#a83a4a", "#6a1a2a", 0.0, 0.1)))
    ing.append(cushion)
    sc = [(0, 0.12), (0.08, 0.07), (0.07, -0.04), (0, -0.1), (-0.07, -0.04), (-0.08, 0.07)]
    for k in range(4):
        a = -0.6 + k * 0.4
        s = flat("scale", sc, 0.018, (math.sin(a) * 0.06, 0.02 - k * 0.01, 0.13 + k * 0.012), Matrix.Rotation(a, 3, "Z") @ Matrix.Rotation(1.25, 3, "X"), sub=1)
        paint(s, lambda co, n: lin("#ffa22e").lerp(lin("#ffd060"), max(0.0, -n.y)) )
        ing.append(s)
    out["ing_scale"] = ing
    # A jar not stocked yet: empty, with a cobweb over the top
    ing = bowl("empty_bowl", (0, 0, 0), 0.18, 0.1, "#6a5a6a")
    for k in range(6):
        a = math.pi * k / 6
        d = Vector((math.cos(a), math.sin(a), 0))
        web = tube("web", d * -0.18 + Vector((0, 0, 0.11)), d * 0.18 + Vector((0, 0, 0.11)), 0.004, 0.004, seg=4, sub=0)
        paint(web, lambda co, n: lin("#e8e8f0"))
        ing.append(web)
    for r in (0.06, 0.12):
        wr = ring("web_ring", (0, 0, 0.112), r, 0.003, seg=12, sides=3)
        paint(wr, lambda co, n: lin("#e8e8f0"))
        ing.append(wr)
    out["ing_empty"] = ing

    # The bellows: two boards hinged at the nozzle end, a leather bag between them.
    # Origin at the hinge; the nozzle points along -X. The game opens and shuts the top board.
    board = [(0, 0.08), (0.18, 0.15), (0.36, 0.15), (0.5, 0.08), (0.52, 0.0), (0.5, -0.08), (0.36, -0.15), (0.18, -0.15), (0, -0.08)]
    bottom = flat("bellows_bottom", board, 0.035, (0.02, 0, -0.05))
    topb = flat("bellows_top", board, 0.035, (0.02, 0, 0.05))
    for b in (bottom, topb):
        paint(b, lambda co, n: lin("#a8683a").lerp(lin("#d8a060"), 0.3 * max(0.0, n.z)) if abs(co.y) < 0.13 or True else lin("#a8683a"))
    bag = lathe("bellows_bag", [(-0.05, 0.001, 0.001), (0.0, 0.27, 0.14), (0.05, 0.001, 0.001)], seg=14, sub=1)
    bag.data.transform(Matrix.Translation((0.28, 0, 0)) @ Matrix.Diagonal((1.0, 1.0, 1.0, 1)))
    paint(bag, lambda co, n: lin("#8a2a1a") * (0.7 + 0.3 * max(0.0, n.z)))
    nozzle = tube("bellows_nozzle", (0.02, 0, 0), (-0.22, 0, 0), 0.045, 0.02, seg=10, sub=1)
    paint(nozzle, lit(plain("#f0c046", "#a8741a", -0.05, 0.05)))
    out_b = [bottom, bag, nozzle]
    for b, z in ((bottom, -0.07), (topb, 0.07)):
        hd = grow("bellows_handle", [(0.5, 0, z), (0.7, 0, z * 1.6)], [(0, 1)], [0.025, (0.04, 0.035)], sub=1)
        paint(hd, lit(plain("#6b3e22")))
        hd.name = "bellows_top_handle" if z > 0 else "bellows_bottom_handle"
        out_b.append(hd)
    top_handle = [o for o in out_b if o.name == "bellows_top_handle"][0]
    out_b.remove(top_handle)
    out["bellows"] = out_b
    out["bellows_top"] = [topb, top_handle]

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
        b = egg("rack_bottle", (x, 0, 0.15), (0.075, 0.075, 0.09), seg=12, rings=8, sub=1)
        nk = tube("rack_neck", (x, 0, 0.22), (x, 0, 0.3), 0.025, 0.025, seg=8, sub=0)
        ck = tube("rack_cork", (x, 0, 0.3), (x, 0, 0.34), 0.03, 0.028, seg=8, sub=0)
        paint(b, lambda co, n: lin("#c8eaf4").lerp(Vector((1, 1, 1)), 0.4 * max(0.0, -n.y)))
        paint(nk, lambda co, n: lin("#c8eaf4"))
        paint(ck, lambda co, n: lin("#c8925a"))
        rack += [b, nk, ck]
    out["bottles"] = rack
    # One filled bottle, flown to the customer; its liquid is its own piece so the game can colour it
    glass = egg("bottle", (0, 0, 0.13), (0.13, 0.13, 0.13), seg=14, rings=9, sub=1)
    paint(glass, lambda co, n: lin("#d8f0f8"))
    neck = tube("bottle_neck", (0, 0, 0.24), (0, 0, 0.36), 0.045, 0.045, seg=10, sub=0)
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
        if len(obs) > 1:
            obs = [join(obs, name)]
        else:
            obs[0].name = name
        groups[name] = obs[0]
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
        want = dict(filepath=os.path.join(ROOT, "models", name + ".glb"), export_format="GLB", export_yup=True,
                    export_animations=False, export_vertex_color="ACTIVE", export_all_vertex_colors=False,
                    export_active_vertex_color_when_no_material=True, export_colors=True, use_selection=True)
        bpy.ops.export_scene.gltf(**{k: v for k, v in want.items() if k in known})
        ob.location = loc
        print("wrote", name, "faces:", len(ob.data.polygons))


main()
