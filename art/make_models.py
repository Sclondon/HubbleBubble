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


## While on (the witches), everything is built low-poly: no subdivision, fewer sides, flat-shaded faces
LOW = False


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
    if LOW:
        sub = 0
        smooth = False
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


def lathe(name, rings, seg=24, sub=1, cap_top=True, cap_bottom=True, wobble=None, shape=None):
    if LOW:
        sub = 0
        seg = max(7, seg // 2)
    """Spun round Z: `rings` is a list of (z, radius_x, radius_y, y_offset). `wobble(angle, z)` adds to the radius;
    `shape(angle)` scales it (a soft pentagon, say)."""
    bm = bmesh.new()
    loops = []
    for (z, rx, ry, *rest) in rings:
        off = rest[0] if rest else 0.0
        loop = []
        for j in range(seg):
            a = 2 * math.pi * j / seg
            w = wobble(a, z) if wobble else 0.0
            k = shape(a) if shape else 1.0
            loop.append(bm.verts.new((math.cos(a) * (rx + w) * k, off + math.sin(a) * (ry + w) * k, z)))
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
        p.use_smooth = not LOW
    return ob


def egg(name, centre, radii, seg=16, rings=10, sub=1, shape=None):
    """A ball, squashed to `radii`; `shape(v)` may move each vertex (local to the centre) afterwards"""
    if LOW:
        sub = 0
        seg = max(6, seg // 2 + 1)
        rings = max(4, rings // 2 + 1)
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
        p.use_smooth = not LOW
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
        p.use_smooth = not LOW
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
        col.data[v.index].color = (c.x, c.y, c.z, c[3] if len(c) > 3 else 1.0)
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
    global LOW
    LOW = True
    try:
        _build_witch(spec)
    finally:
        LOW = False


def _build_witch(spec):
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
    if style == "long":
        # Long hair in a few broad chunky locks down the back and over the shoulders
        for sgn in (1, -1):
            side = box("hair_lock", head_c + F * Vector((sgn * 0.27, 0.02, -0.38)), (0.1, 0.3, 0.78), bevel=0.02,
                       rot=Matrix.Rotation(-sgn * 0.1, 3, "Y"))
            paint(side, lambda co, n: lin(hc) * (0.7 + 0.3 * max(0.0, -n.y)))
            hair.append(side)
        back = box("hair_back", head_c + F * Vector((0, 0.2, -0.42)), (0.58, 0.14, 0.86), bevel=0.02)
        paint(back, lambda co, n: lin(hc) * 0.8)
        hair.append(back)
        for k in range(4):
            tip = egg("hair_tip", head_c + F * Vector((-0.21 + k * 0.14, 0.2, -0.86)), (0.08, 0.07, 0.1), seg=6, rings=4, sub=0)
            paint(tip, lambda co, n: lin(hc) * 0.75)
            hair.append(tip)
    elif style == "wild":
        # Wild hair as big puffs bursting out from under the hat
        for k in range(9):
            a = -2.0 + 4.0 * k / 8.0
            c_ = head_c + F * Vector((math.sin(a) * 0.32, math.cos(a) * 0.28 + 0.04, -0.12 + 0.06 * math.sin(k * 2.1)))
            r_ = 0.13 + 0.05 * ((k * 7) % 3) / 2.0
            puff = egg("hair_puff", c_, (r_, r_ * 0.9, r_ * 0.85), seg=6, rings=4, sub=0)
            paint(puff, lambda co, n: lin(hc) * (0.7 + 0.3 * max(0.0, n.z)))
            hair.append(puff)
    n_strands = 0
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

    # The cauldron, after Banjo-Kazooie's: a fat round pot of rusty copper-brown, warm where the
    # light falls and dark underneath, a thick band of rim studded with rivets, flat golden handles
    # either side and four stubby round feet. Nothing else on it.
    # The rim is at about 1.36-1.40 and the brew sits at 1.24 inside it (the game puts the brew's surface there).
    BROWN, BROWN_L, BROWN_D = "#a8522c", "#f0944c", "#4a2214"
    # Not round: a soft hexagon, low poly (twelve sides, no smoothing), a flat side to the front (-Y).
    # The game's brew follows the same shape (Brew.pent).
    def pent(a):
        return 1.0 + 0.06 * math.cos(6.0 * a)
    belly = lathe("cauldron", [(0.26, 0.2, 0.2), (0.32, 0.55, 0.55), (0.46, 0.84, 0.84), (0.7, 1.0, 1.0), (0.95, 1.02, 1.02),
                               (1.12, 0.94, 0.94), (1.2, 0.9, 0.9)], seg=12, sub=0, cap_top=False, shape=pent)

    def copper(co, n):
        up = max(0.0, n.z) * 0.5 + max(0.0, min(1.0, (co.z - 0.3) / 0.9)) * 0.5
        c = lin(BROWN_D).lerp(lin(BROWN), min(1.0, up * 1.6)).lerp(lin(BROWN_L), max(0.0, up - 0.55) * 1.4)
        # a little rust, mottled
        rust = math.sin(co.x * 9.0 + co.z * 4.0) * math.sin(co.y * 11.0 - co.z * 6.0)
        if rust > 0.55:
            c = c.lerp(lin("#5a2a18"), 0.35)
        return c
    paint(belly, copper)
    inside = lathe("cauldron_in", [(0.9, 0.7, 0.7), (1.1, 0.82, 0.82), (1.25, 0.8, 0.8), (1.36, 0.8, 0.8)], seg=12, sub=0, cap_top=False, shape=pent)
    paint(inside, lambda co, n: lin("#120806"))
    rim = lathe("cauldron_rim", [(1.12, 0.92, 0.92), (1.17, 0.97, 0.97), (1.35, 0.97, 0.97), (1.4, 0.93, 0.93), (1.41, 0.86, 0.86),
                                 (1.39, 0.8, 0.8), (1.33, 0.79, 0.79)], seg=12, sub=0, cap_top=False, cap_bottom=False, shape=pent)
    paint(rim, lambda co, n: lin("#4a2214").lerp(lin("#8a4a28"), max(0.0, n.z) * 0.7 + 0.15))
    extra = [rim]
    for k in range(12):
        a = 2 * math.pi * k / 12
        rivet = egg("cauldron_rivet", (math.cos(a) * 0.975 * pent(a), math.sin(a) * 0.975 * pent(a), 1.26), (0.04, 0.04, 0.04), seg=6, rings=4, sub=0)
        paint(rivet, lambda co, n: lin("#9a94a8").lerp(lin("#f0ecf8"), max(0.0, n.z) * 0.8))
        extra.append(rivet)
    for sgn in (1, -1):
        # A flat golden tab of a handle, with a dark slot through it
        tab = box("cauldron_handle", (sgn * 1.04 * pent(0 if sgn > 0 else math.pi), 0, 1.02), (0.1, 0.36, 0.42), bevel=0.04)
        paint(tab, lambda co, n: lin("#c8781e").lerp(lin("#ffcf5a"), max(0.0, n.z) * 0.5 + max(0.0, abs(n.x)) * 0.4))
        slot = box("cauldron_slot", (sgn * 1.09 * pent(0 if sgn > 0 else math.pi), 0, 1.08), (0.04, 0.2, 0.14), bevel=0.02)
        paint(slot, lambda co, n: lin("#3a1a0a"))
        extra += [tab, slot]
    for k in range(4):
        a = 2 * math.pi * k / 4 + math.pi / 4
        foot = egg("cauldron_foot", (math.cos(a) * 0.48, math.sin(a) * 0.48, 0.14), (0.19, 0.19, 0.16), seg=8, rings=5, sub=0)
        paint(foot, lambda co, n: lin(BROWN_D).lerp(lin(BROWN), max(0.0, n.z) * 0.8 + 0.1))
        extra.append(foot)
    # The drain tap, built into the belly low on the front left: a riveted brass plate on the iron, a
    # stubby pipe out of it and a spout turned down. Its handle is a model of its own (cauldron_tap_handle,
    # origin at its pivot) so the game can turn it. (The game's Hut.TAP_HANDLE and TAP_SPOUT match.)
    ta = math.atan2(-0.8, -0.62)
    td = Vector((math.cos(ta), math.sin(ta), 0))
    tr = 1.0 * pent(ta)
    tp = Vector((td.x * tr, td.y * tr, 0.78))
    plate = egg("tap_plate", tp, (0.15, 0.15, 0.15), seg=10, rings=6, sub=0, shape=lambda v: Vector((v.x, v.y, v.z)))
    plate.scale = (1, 1, 1)
    plate.data.transform(Matrix.Translation(tp) @ Matrix.Rotation(ta, 4, "Z") @ Matrix.Diagonal((0.25, 1.0, 1.0, 1.0)) @ Matrix.Translation(-tp))
    paint(plate, lambda co, n: lin("#a8701e").lerp(lin("#e8b040"), max(0.0, n.z) * 0.6))
    extra.append(plate)
    for k in range(4):
        aa = math.pi / 4 + k * math.pi / 2
        off = Vector((-td.y, td.x, 0)) * math.cos(aa) * 0.1 + Vector((0, 0, math.sin(aa) * 0.1))
        rv = egg("tap_rivet", tp + td * 0.04 + off, (0.022, 0.022, 0.022), seg=6, rings=4, sub=0)
        paint(rv, lambda co, n: lin("#f0d890"))
        extra.append(rv)
    pipe_ = tube("tap_pipe", tp - td * 0.05, tp + td * 0.22, 0.055, 0.05, seg=8)
    paint(pipe_, lambda co, n: lin("#b87a22").lerp(lin("#f0c050"), max(0.0, n.z) * 0.6))
    spout = tube("tap_spout", tp + td * 0.2, tp + td * 0.24 + Vector((0, 0, -0.13)), 0.05, 0.04, seg=8)
    paint(spout, lambda co, n: lin("#b87a22"))
    collar_ = tube("tap_collar", tp + td * 0.08 + Vector((0, 0, 0.03)), tp + td * 0.08 + Vector((0, 0, 0.08)), 0.04, 0.035, seg=8)
    paint(collar_, lambda co, n: lin("#8a5a1a"))
    extra += [pipe_, spout, collar_]
    out["cauldron_tap_handle"] = [tube("tap_stem", (0, 0, 0), (0, 0, 0.07), 0.015, 0.015, seg=6),
                                  box("tap_lever", (0, 0, 0.08), (0.18, 0.035, 0.035), bevel=0.008)]
    paint(out["cauldron_tap_handle"][0], lambda co, n: lin("#8a5a1a"))
    paint(out["cauldron_tap_handle"][1], lambda co, n: lin("#e8b040").lerp(lin("#a87a2a"), 0.4 * max(0.0, -n.z)))
    print("tap handle pivot", tp + td * 0.08 + Vector((0, 0, 0.08)), "spout", tp + td * 0.24 + Vector((0, 0, -0.13)), "angle", ta)
    out["cauldron"] = [belly, inside] + extra

    # The fire pit: low-poly logs (six-sided, flat-shaded) laid in a star under the pot with their ends
    # poking out, burnt black toward the fire with glowing cracks, bark still on at the ends and pale
    # sawn faces; a bed of grey ash, embers in it
    pit = []
    ash = egg("ash", (0, 0, 0.0), (1.2, 1.15, 0.06), seg=12, rings=4, sub=0, shape=lambda v: Vector((v.x, v.y, max(v.z, 0.0))))
    paint(ash, lambda co, n: lin("#4a4448").lerp(lin("#2a2428"), min(1.0, math.hypot(co.x, co.y) / 1.2)))
    pit.append(ash)

    def burnt(co, n):
        r = math.hypot(co.x, co.y)
        char = max(0.0, min(1.0, (1.15 - r) / 0.55))
        c = lin("#6b4024").lerp(lin("#3a2414"), 0.4 * (math.sin(co.z * 40.0) > 0.3))
        c = c.lerp(lin("#140c08"), char)
        crack = math.sin(co.x * 23.0 + co.y * 7.0) * math.sin(co.y * 19.0 - co.z * 31.0)
        if char > 0.35 and crack > 0.72:
            c = lin("#ff6a1a").lerp(lin("#ffc84a"), (crack - 0.72) * 3.0)
        if n.z < -0.5:
            c = c * 0.5
        return c

    for k in range(6):
        a = math.tau * k / 6 + 0.25
        d = Vector((math.cos(a), math.sin(a), 0))
        inner = d * 0.15 + Vector((0, 0, 0.22 + (k % 2) * 0.1))
        outer = d * 1.35 + Vector((0, 0, 0.1))
        bm = bmesh.new()
        axis = outer - inner
        rot = Vector((0, 0, 1)).rotation_difference(axis.normalized()).to_matrix().to_4x4()
        spin = Matrix.Rotation(k * 0.5, 4, "Z")
        bmesh.ops.create_cone(bm, cap_ends=True, cap_tris=False, segments=6, radius1=0.12, radius2=0.105, depth=axis.length,
                              matrix=Matrix.Translation((inner + outer) / 2) @ rot @ spin)
        me = bpy.data.meshes.new("log")
        bm.to_mesh(me)
        bm.free()
        log = link(bpy.data.objects.new("log", me))
        for p in log.data.polygons:
            p.use_smooth = False
        paint(log, burnt)
        pit.append(log)
        # The sawn face at the outer end, pale with a ring
        face = egg("log_end", outer + d * 0.004, (0.09, 0.09, 0.09), seg=6, rings=3, sub=0)
        face.scale = (1, 1, 1)
        paint(face, lambda co, n: lin("#c89a6a").lerp(lin("#8a5a32"), 0.5 * (abs(math.sin(math.hypot(co.x, co.y) * 90.0)) > 0.8)))
        pit.append(face)
    for k in range(12):
        a = k * 2.3
        r = 0.3 + (k % 4) * 0.2
        em = egg("glow_ember", (math.cos(a) * r, math.sin(a) * r, 0.05), (0.06, 0.06, 0.03), seg=5, rings=3, sub=0)
        paint(em, lambda co, n: lin("#ff8a2a"))
        pit.append(em)
    out["firepit"] = pit

    # A shelf curving round behind the pot, below the serving counter, for the ingredients to
    # stand on in an arc: a curved plank on brackets, a lip along its front. Centred on the
    # cauldron; it runs from -66 to +66 degrees about the far side (the -Y side here).
    shelf = []
    r_in, r_out, top_z = 1.55, 2.0, 1.12
    a0, a1 = math.radians(-66), math.radians(66)
    bm = bmesh.new()
    seg = 28
    rows = []
    for i in range(seg + 1):
        t = a0 + (a1 - a0) * i / seg
        d = Vector((math.sin(t), -math.cos(t), 0))
        rows.append([bm.verts.new(d * r_in + Vector((0, 0, top_z))), bm.verts.new(d * r_out + Vector((0, 0, top_z))),
                     bm.verts.new(d * r_out + Vector((0, 0, top_z - 0.08))), bm.verts.new(d * r_in + Vector((0, 0, top_z - 0.08)))])
    for i in range(seg):
        for j in range(4):
            bm.faces.new((rows[i][j], rows[i + 1][j], rows[i + 1][(j + 1) % 4], rows[i][(j + 1) % 4]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    me = bpy.data.meshes.new("shelf_arc")
    bm.to_mesh(me)
    bm.free()
    plank = link(bpy.data.objects.new("shelf_arc", me))
    paint(plank, lambda co, n: lin("#a8683a").lerp(lin("#7a4624"), 0.25 * (math.sin(math.atan2(co.x, -co.y) * 40) > 0.6)) * (0.7 + 0.3 * max(0.0, n.z)))
    shelf.append(plank)
    for i in range(seg + 1):
        pass
    lip_pts = []
    for i in range(13):
        t = a0 + (a1 - a0) * i / 12
        lip_pts.append(Vector((math.sin(t), -math.cos(t), 0)) * (r_in + 0.02) + Vector((0, 0, top_z + 0.03)))
    lip_ob = grow("shelf_lip", lip_pts, [(i, i + 1) for i in range(12)], [0.025] * 13, sub=0)
    paint(lip_ob, lambda co, n: lin("#7a4624"))
    shelf.append(lip_ob)
    for k in range(5):
        t = a0 + (a1 - a0) * k / 4
        d = Vector((math.sin(t), -math.cos(t), 0))
        post = grow("shelf_post", [d * 1.78 + Vector((0, 0, 0.0)), d * 1.78 + Vector((0, 0, top_z - 0.08))], [(0, 1)], [0.05, 0.045], sub=0)
        paint(post, lambda co, n: lin("#6b3e22"))
        shelf.append(post)
    out["shelf_arc"] = shelf

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

    # Eye of newt: a heap of eyeballs, glistening, piled on a little dish, all looking every which way
    ing = []
    dish = lathe("eyedish", [(0.0, 0.12, 0.12), (0.02, 0.17, 0.17), (0.05, 0.2, 0.2), (0.06, 0.19, 0.19)], seg=18, sub=1)
    paint(dish, lambda co, n: lin("#6a5a7a").lerp(lin("#9a8aaa"), max(0.0, n.z) * 0.6))
    ing.append(dish)
    heap = [(-0.08, -0.04, 0.1), (0.07, -0.05, 0.1), (0.0, 0.07, 0.1), (-0.06, 0.07, 0.1), (0.09, 0.05, 0.1),
            (-0.02, -0.01, 0.18), (0.05, 0.02, 0.19), (-0.06, 0.01, 0.2), (0.01, 0.0, 0.27)]
    for k, p in enumerate(heap):
        ing.append(eyeball("eye", p, 0.055 if k < 5 else 0.05, iris=["#3ac0a8", "#e8b030", "#c8402a", "#8a52c9"][k % 4],
                           look=Vector((rnd.uniform(-0.8, 0.8), rnd.uniform(-1.0, -0.2), rnd.uniform(-0.2, 0.8)))))
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

    # Bat wing: a whole little dried bat pinned out on a board, both wings spread, so it reads at a
    # glance: scalloped leathery wings on their finger bones, a furry body, big pointed ears
    ing = []
    board = box("wing_board", (0, 0.05, 0.24), (0.62, 0.03, 0.4), bevel=0.01, rot=Matrix.Rotation(-0.25, 3, "X"))
    paint(board, lit(plain("#e0c08a")))
    leg_b = box("wing_board_foot", (0, 0.1, 0.03), (0.3, 0.12, 0.05), bevel=0.01)
    paint(leg_b, lit(plain("#6b3e22")))
    ing += [board, leg_b]
    tilt = Matrix.Translation((0, 0.0, 0.26)) @ Matrix.Rotation(math.pi / 2 - 0.25, 4, "X") @ Matrix.Diagonal((1.25, 1.25, 1.25, 1.0))
    for sgn in (1, -1):
        # the wing's edge: from the shoulder out along the top to the wrist, then scallops between
        # the finger tips back down to the body
        pts = [(0.03, 0.03), (0.12, 0.09), (0.22, 0.08)]
        tips = [(0.25, 0.02), (0.23, -0.07), (0.15, -0.11), (0.06, -0.1)]
        last = pts[-1]
        for t in tips:
            mid = ((last[0] + t[0]) / 2 * 0.8, (last[1] + t[1]) / 2 * 0.8 - 0.01)
            pts += [mid, t]
            last = t
        pts.append((0.02, -0.05))
        outline = [(sgn * x, y) for x, y in pts]
        if sgn < 0:
            outline.reverse()
        memb = flat("wing_membrane", outline, 0.01, (0, 0, 0), None, sub=1)
        memb.data.transform(tilt)
        paint(memb, lambda co, n: lin("#a070e8").lerp(lin("#6a3ab0"), 0.4))
        ing.append(memb)
        for t in tips + [(0.22, 0.08)]:
            bone_ = tube("wing_bone", (sgn * 0.12, 0.09, 0.0), (sgn * t[0], t[1], 0.0), 0.007, 0.004, seg=5)
            bone_.data.transform(tilt)
            paint(bone_, lambda co, n: lin("#f0e0ff"))
            ing.append(bone_)
    body = egg("bat_body", (0, 0, 0), (0.045, 0.03, 0.08), seg=10, rings=7, sub=1)
    body.data.transform(tilt)
    paint(body, lambda co, n: lin("#3a2a2a"))
    head = egg("bat_head", (0, 0.11, 0.0), (0.04, 0.035, 0.035), seg=10, rings=6, sub=1)
    head.data.transform(tilt)
    paint(head, lambda co, n: lin("#3a2a2a"))
    ing += [body, head]
    for sgn in (1, -1):
        ear = flat("bat_ear", [(0, 0), (sgn * 0.035, 0.07), (sgn * 0.045, 0.0)] if sgn > 0 else [(0, 0), (sgn * 0.045, 0.0), (sgn * 0.035, 0.07)],
                   0.008, (sgn * 0.012, 0.13, 0.005), None, sub=0)
        ear.data.transform(tilt)
        paint(ear, lambda co, n: lin("#4a3030"))
        eye_ = egg("bat_eye", (sgn * 0.016, 0.115, 0.03), (0.008, 0.008, 0.006), seg=6, rings=4, sub=0)
        eye_.data.transform(tilt)
        paint(eye_, lambda co, n: lin("#ff4a3a"))
        ing += [ear, eye_]
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

    # Spider: a big fat black spider squatting on a mossy stone, eight jointed legs splayed out, a red
    # hourglass on her back, a cluster of red eyes (no web, no hoop: the spider is the whole picture)
    ing = []
    stone_ = egg("spider_stone", (0, 0, 0.04), (0.17, 0.14, 0.06), seg=10, rings=6, sub=1)
    paint(stone_, lambda co, n: lin("#6a6a72").lerp(lin("#4a8a3a"), 0.6 if n.z > 0.6 else 0.0))
    ing.append(stone_)
    sb = Vector((0, 0.0, 0.16))
    body = egg("spider_body", sb + Vector((0, 0.05, 0.02)), (0.085, 0.1, 0.075), seg=14, rings=10, sub=1)
    paint(body, lambda co, n: lin("#e8202a") if (abs(co.x) < 0.025 and n.z > 0.5 and abs(abs(co.y - 0.05) - 0.025) < 0.02) else lin("#1a1626").lerp(lin("#3a3450"), 0.4 * max(0.0, n.z)))
    head = egg("spider_head", sb + Vector((0, -0.07, 0.0)), (0.05, 0.05, 0.045), seg=10, rings=6, sub=1)
    paint(head, lambda co, n: lin("#1a1626"))
    ing += [body, head]
    for sgn in (1, -1):
        for k in range(4):
            a = -0.9 + k * 0.6
            hip = sb + Vector((sgn * 0.03, -0.06 + k * 0.03, -0.01))
            out_d = Vector((sgn * math.cos(a), math.sin(a), 0))
            knee = hip + out_d * 0.11 + Vector((0, 0, 0.09))
            foot_ = hip + out_d * 0.24 + Vector((0, 0, -0.12))
            lg = grow("spider_leg", [hip, knee, foot_], [(0, 1), (1, 2)], [0.016, 0.013, 0.006], sub=1)
            paint(lg, lambda co, n: lin("#1a1626"))
            ing.append(lg)
        for e_ in range(2):
            e = egg("spider_eye", sb + Vector((sgn * (0.014 + e_ * 0.016), -0.115, 0.015 + e_ * 0.012)), (0.011, 0.008, 0.011), seg=8, rings=5, sub=0)
            paint(e, lambda co, n: lin("#ff3a3a"))
            ing.append(e)
        fang = grow("spider_fang", [sb + Vector((sgn * 0.015, -0.11, -0.015)), sb + Vector((sgn * 0.01, -0.13, -0.05))], [(0, 1)], [0.01, 0.002], sub=0)
        paint(fang, lambda co, n: lin("#f2e8d0"))
        ing.append(fang)
    out["ing_spider"] = ing

    # Moon petals: a flower whose head is a big glowing crescent moon, ringed with pale crescent
    # petals, on a tall stem in a blue pot
    ing = []
    pot = lathe("petal_pot", [(0.0, 0.08, 0.08), (0.12, 0.12, 0.12), (0.14, 0.135, 0.135), (0.16, 0.13, 0.13)], seg=16, sub=1)
    paint(pot, lambda co, n: lin("#3a5ab0").lerp(lin("#7aa0f0"), 0.4 * max(0.0, n.z)) if not (0.1 < co.z < 0.125) else lin("#f2c840"))
    soil = egg("petal_soil", (0, 0, 0.15), (0.12, 0.12, 0.02), seg=12, rings=4, sub=0)
    paint(soil, lambda co, n: lin("#3a2414"))
    stem = grow("petal_stem", [(0, 0, 0.15), (0.03, 0.0, 0.3), (0.0, -0.02, 0.42)], [(0, 1), (1, 2)], [0.014, 0.012, 0.011], sub=1)
    paint(stem, lambda co, n: lin("#5aaa4a"))
    leaf = flat("petal_leaf", [(0, 0), (0.07, 0.03), (0.13, 0.0), (0.07, -0.025)], 0.006, (0.02, 0.0, 0.25), Matrix.Rotation(-0.6, 3, "Y"), sub=1)
    paint(leaf, lambda co, n: lin("#6ac84a"))
    ing += [pot, soil, stem, leaf]

    def crescent_pts(r_out, r_in, off):
        c_ = []
        for i in range(15):
            th = -1.35 + 2.7 * i / 14.0
            c_.append((math.cos(th) * r_out, math.sin(th) * r_out))
        for i in range(15):
            th = 1.15 - 2.3 * i / 14.0
            c_.append((math.cos(th) * r_in + off, math.sin(th) * r_in))
        return c_
    for k in range(6):
        a = 2 * math.pi * k / 6
        pet = flat("glow_petal", crescent_pts(0.075, 0.05, 0.024), 0.008, (0, 0, 0), None, sub=1)
        pet.data.transform(Matrix.Translation((0, -0.03, 0.47)) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(a, 4, "Z") @ Matrix.Translation((0.1, 0, 0)))
        paint(pet, lambda co, n: lin("#c8d8ff"))
        ing.append(pet)
    moon_ = flat("glow_centre", crescent_pts(0.085, 0.07, 0.035), 0.03, (0, 0, 0), None, sub=1)
    moon_.data.transform(Matrix.Translation((0, -0.045, 0.47)) @ Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Rotation(2.6, 4, "Z"))
    paint(moon_, lambda co, n: lin("#fff27a"))
    ing.append(moon_)
    out["ing_petal"] = ing

    # Ghost peppers: three big wrinkly chillies, pale as ghosts, standing in a little dish, each with
    # hollow black eyes and a wailing mouth, green stalks on top
    ing = bowl("pepper_dish", (0, 0, 0), 0.19, 0.04, "#8a6a9a")
    for k in range(3):
        x = (k - 1) * 0.1
        lean = (k - 1) * 0.25
        b = Vector((x, 0.0, 0.03))
        tip = b + Vector((math.sin(lean) * 0.05 + 0.03, -0.02, 0.3 - abs(k - 1) * 0.05))
        mid = b.lerp(tip, 0.45) + Vector((0.025, 0, 0))
        pp = grow("pepper", [b + Vector((0, 0, 0.0)), mid, tip], [(0, 1), (1, 2)], [0.012, 0.055, 0.045], sub=2)
        paint(pp, lambda co, n: lin("#f4f0ff").lerp(lin("#b8b0e8"), 0.35 * max(0.0, -n.y) + 0.2 * (math.sin(co.z * 70.0) > 0.6)))
        st = grow("pepper_stem", [tip, tip + Vector((0.02, 0, 0.05)), tip + Vector((0.05, 0, 0.06))], [(0, 1), (1, 2)], [0.02, 0.012, 0.008], sub=1)
        paint(st, lambda co, n: lin("#4a9a3a"))
        ing += [pp, st]
        face_c = mid + Vector((0, -0.05, 0.02))
        for sgn in (1, -1):
            dot = egg("pepper_eye", face_c + Vector((sgn * 0.017, 0, 0.025)), (0.011, 0.008, 0.016), seg=6, rings=4, sub=0)
            paint(dot, lambda co, n: lin("#140d12"))
            ing.append(dot)
        mouth = egg("pepper_mouth", face_c + Vector((0, 0, -0.018)), (0.01, 0.008, 0.018), seg=6, rings=4, sub=0)
        paint(mouth, lambda co, n: lin("#140d12"))
        ing.append(mouth)
    out["ing_pepper"] = ing

    # Dragon scales: a patch of dragon hide on a little stand, rows of overlapping green scales
    # edged with gold, a ridge of spikes down its middle
    ing = []
    base = lathe("scale_base", [(0.0, 0.13, 0.1), (0.03, 0.13, 0.1), (0.04, 0.11, 0.085)], seg=16, sub=1)
    paint(base, lit(plain("#6a3a2a")))
    ing.append(base)
    shield = [(0, 0.06), (0.045, 0.04), (0.055, 0.0), (0.035, -0.04), (0, -0.065), (-0.035, -0.04), (-0.055, 0.0), (-0.045, 0.04)]
    tip_rot = Matrix.Rotation(1.2, 3, "X")
    for row in range(4):
        for colk in range(4 - (row % 2)):
            x = -0.15 + colk * 0.1 + (0.05 if row % 2 else 0.0)
            z = 0.4 - row * 0.085
            sc = flat("scale", shield, 0.018, (x, -0.01 * row, z), tip_rot, sub=1)
            paint(sc, lambda co, n: lin("#3ac08a").lerp(lin("#0a5a4a"), 0.5 * max(0.0, -n.y)) if math.hypot(co.x % 0.1 - 0.05, 0) < 0.04 else lin("#f2c840"))
            ing.append(sc)
    for k in range(4):
        spike = grow("scale_spike", [(0, -0.05, 0.12 + k * 0.08), (0, -0.1, 0.15 + k * 0.08)], [(0, 1)], [0.02, 0.003], sub=0)
        paint(spike, lambda co, n: lin("#f2c840"))
        ing.append(spike)
    post = tube("scale_post", (0, 0.04, 0.03), (0, 0.04, 0.4), 0.015, 0.015, seg=8)
    paint(post, lambda co, n: lin("#5a3418"))
    ing.append(post)
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


    # The balcony off the side of the hut, where brews are tried out: a round deck of planks on stilts
    # over the swamp, a chalked circle on it, a crooked twig railing round its front, and the hut's
    # wall behind with the door out to it, a lantern on a post. The middle of the deck (where the
    # witch stands) is the origin; the hut is on the +Y side (behind her as the camera sees it).
    tower = []
    rnd_t = random.Random(31)
    # The deck: planks side by side, cut to the round, a chalk circle and star on them
    for k in range(16):
        x = -2.4 + k * 0.32
        half = math.sqrt(max(0.05, 2.45 ** 2 - (x + 0.16) ** 2)) * 0.94
        plank = box("plank", (x + 0.16, 0, -0.05), (0.3, half * 2, 0.1), bevel=0.012)
        pshade = ((k * 7) % 5) * 0.1
        paint(plank, lambda co, n, s=pshade: lin("#9a6236").lerp(lin("#5a3418"), s + 0.3 * max(0.0, -n.z)))
        tower.append(plank)
    for big, thick in ((1.05, 0.03), (0.92, 0.022)):
        chalk = ring("glow_chalk", (0, 0, 0.005), big, thick, seg=40, sides=4)
        paint(chalk, lambda co, n: lin("#c8c0e8"))
        tower.append(chalk)
    for j in range(5):
        a1 = math.pi / 2 + j * 4 * math.pi / 5
        a2 = math.pi / 2 + (j + 1) * 4 * math.pi / 5
        p1 = Vector((math.cos(a1), math.sin(a1), 0)) * 0.92
        p2 = Vector((math.cos(a2), math.sin(a2), 0)) * 0.92
        mid = (p1 + p2) / 2
        d = p2 - p1
        line = box("glow_chalk", (mid.x, mid.y, 0.006), (d.length, 0.035, 0.008), rot=Matrix.Rotation(math.atan2(d.y, d.x), 3, "Z"))
        paint(line, lambda co, n: lin("#c8c0e8"))
        tower.append(line)
    # Stilts down into the dark, and the twig railing round the front
    for k in range(7):
        a = math.pi + math.pi * k / 6 + rnd_t.uniform(-0.1, 0.1)
        p = Vector((math.cos(a) * 2.35, math.sin(a) * 2.15, 0))
        stilt = tube("stilt", p + Vector((0, 0, -6.0)), p + Vector((0, 0, -0.1)), 0.11, 0.1, seg=8)
        paint(stilt, lambda co, n: lin("#3a2414"))
        post = tube("rail_post", p + Vector((0, 0, -0.05)), p + Vector((rnd_t.uniform(-0.05, 0.05), 0, 0.95)), 0.06, 0.05, seg=7)
        paint(post, lambda co, n: lin("#6a4426").lerp(lin("#8a5a32"), max(0.0, n.z)))
        tower += [stilt, post]
    pts = []
    for k in range(25):
        a = math.pi * 0.92 + math.pi * 1.16 * k / 24
        pts.append(Vector((math.cos(a) * 2.35, math.sin(a) * 2.15, 0.9 + 0.05 * math.sin(k * 1.7))))
    for k in range(len(pts) - 1):
        rail = tube("rail", pts[k], pts[k + 1], 0.045, 0.045, seg=6)
        paint(rail, lambda co, n: lin("#7a4e2a"))
        low = tube("rail_low", pts[k] - Vector((0, 0, 0.45)), pts[k + 1] - Vector((0, 0, 0.45)), 0.03, 0.03, seg=5)
        paint(low, lambda co, n: lin("#5a3a1e"))
        tower += [rail, low]
    # The hut's wall behind: rough planks, a beam, a round-topped door standing open
    wall = box("hut_wall", (0, 2.45, 2.0), (6.0, 0.3, 4.0))
    paint(wall, lambda co, n: lin("#6a4428").lerp(lin("#4a2c18"), ((math.floor(co.x / 0.4) * 5) % 4) * 0.15) * (0.6 if abs(co.x / 0.4 - round(co.x / 0.4)) < 0.06 else 1.0))
    door = box("glow_door", (0.0, 2.32, 1.05), (1.0, 0.04, 2.1))
    paint(door, lambda co, n: lin("#8a4a1a").lerp(lin("#d8803a"), max(0.0, 1.0 - co.z / 2.1)))
    jamb_l = box("door_jamb", (-0.58, 2.26, 1.05), (0.14, 0.12, 2.2))
    jamb_r = box("door_jamb", (0.58, 2.26, 1.05), (0.14, 0.12, 2.2))
    lintel = box("door_jamb", (0.0, 2.26, 2.18), (1.3, 0.14, 0.16))
    leaf = box("door_leaf", (-0.95, 1.95, 1.05), (0.08, 0.95, 2.05), rot=Matrix.Rotation(0.0, 3, "Z"))
    for ob in (jamb_l, jamb_r, lintel):
        paint(ob, lambda co, n: lin("#8a5a32"))
    paint(leaf, lambda co, n: lin("#4f8a3a").lerp(lin("#35602a"), 0.3 * (math.sin(co.z * 14) > 0.9)))
    roof = box("hut_roof", (0, 2.0, 4.1), (6.6, 1.6, 0.25), rot=Matrix.Rotation(-0.35, 3, "X"))
    paint(roof, lambda co, n: lin("#6a5a3a").lerp(lin("#8a7a4a"), max(0.0, n.z) * 0.5))
    tower += [wall, door, jamb_l, jamb_r, lintel, leaf, roof]
    # A lantern on a post, and a couple of candles on the deck
    lpost = tube("lantern_post", (1.9, 0.9, 0.0), (1.9, 0.9, 2.1), 0.05, 0.045, seg=8)
    paint(lpost, lambda co, n: lin("#3a2414"))
    arm = tube("lantern_arm", (1.9, 0.9, 2.05), (1.55, 0.9, 2.05), 0.03, 0.03, seg=6)
    paint(arm, lambda co, n: lin("#3a2414"))
    lantern = box("glow_lantern", (1.55, 0.9, 1.8), (0.18, 0.18, 0.26), bevel=0.02)
    paint(lantern, lambda co, n: lin("#ffc060"))
    tower += [lpost, arm, lantern]
    for k, (x, y) in enumerate(((-1.6, -0.6), (1.3, -1.2), (-0.9, 1.4))):
        candle = tube("candle", (x, y, 0.0), (x, y, 0.22 + k * 0.06), 0.06, 0.055, seg=8)
        paint(candle, lambda co, n: lin("#f4ecd0"))
        flame_ = egg("glow_flame", (x, y, 0.3 + k * 0.06), (0.04, 0.04, 0.08), seg=8, rings=5, sub=0)
        paint(flame_, lambda co, n: lin("#ffd060"))
        tower += [candle, flame_]
    out["tower_top"] = tower



    # The swamp, as a little diorama on a round of earth cut away at the sides: a murky pool with
    # lily pads, a crooked dead tree, reeds, a rotten log, mossy stones, a corner of a graveyard and
    # a hump where the moon flowers grow. Where each ingredient is gathered is left clear for it.
    sw = []
    rnd_s = random.Random(47)
    base = lathe("swamp_base", [(-0.9, 3.2, 3.0), (-0.1, 3.3, 3.1), (0.0, 3.25, 3.05)], seg=40, sub=0)

    def earth(co, n):
        if n.z > 0.5:
            # Grass and mud on top, darker toward the pool
            r = math.hypot(co.x + 0.6, co.y - 0.2)
            c = lin("#5a7a32").lerp(lin("#3a4a22"), max(0.0, 1.0 - r / 1.6) * 0.8)
            if math.sin(co.x * 13) * math.sin(co.y * 11) > 0.6:
                c = c.lerp(lin("#7a9a3a"), 0.4)
            return c
        # The cut side, in layers of soil
        band = math.floor((co.z + 0.9) / 0.18)
        return [lin("#5a3a22"), lin("#7a5030"), lin("#4a2e1a"), lin("#6a4428"), lin("#3a2414")][band % 5] * (0.8 + 0.2 * abs(n.x))
    sb = base.modifiers.new("sub", "SUBSURF")
    sb.subdivision_type = "SIMPLE"
    sb.levels = 3
    base = bake(base)
    paint(base, earth)
    sw.append(base)
    # The pool, sunk a little, murky green, with lily pads and a ring of reeds
    pool = egg("swamp_pool", (-0.6, 0.2, 0.01), (1.3, 1.0, 0.02), seg=28, rings=6, sub=1)
    paint(pool, lambda co, n: lin("#3a6a4a").lerp(lin("#1a3a2a"), min(1.0, math.hypot(co.x + 0.6, co.y - 0.2) * 0.5)))
    sw.append(pool)
    for k in range(6):
        a = k * 1.1 + 0.3
        p = Vector((-0.6 + math.cos(a) * rnd_s.uniform(0.3, 0.9), 0.2 + math.sin(a) * rnd_s.uniform(0.2, 0.7), 0.035))
        pad = lathe("lilypad", [(0.0, 0.16, 0.16), (0.015, 0.16, 0.16)], seg=14, sub=0)
        pad.data.transform(Matrix.Translation(p))
        paint(pad, lambda co, n: lin("#6aba4a") if n.z > 0.5 else lin("#3a7a2a"))
        sw.append(pad)
        if k % 3 == 0:
            fl = egg("lily_flower", p + Vector((0.04, 0, 0.05)), (0.05, 0.05, 0.04), seg=8, rings=5, sub=0)
            paint(fl, lambda co, n: lin("#ffb0d0"))
            sw.append(fl)
    for k in range(18):
        a = 2 * math.pi * k / 18 + rnd_s.uniform(-0.1, 0.1)
        rr = rnd_s.uniform(1.05, 1.35)
        b0 = Vector((-0.6 + math.cos(a) * rr * 1.25, 0.2 + math.sin(a) * rr, 0.0))
        if b0.y < -0.4 and abs(b0.x + 0.6) < 0.6:
            continue
        reed = grow("reed", [b0, b0 + Vector((rnd_s.uniform(-0.05, 0.05), 0, rnd_s.uniform(0.35, 0.7)))], [(0, 1)], [0.018, 0.006], sub=0)
        paint(reed, lambda co, n: lin("#7a9a3a").lerp(lin("#4a6a2a"), 0.5))
        sw.append(reed)
        if k % 4 == 0:
            cat = egg("cattail", b0 + Vector((0, 0, 0.55)), (0.025, 0.025, 0.07), seg=6, rings=4, sub=0)
            paint(cat, lambda co, n: lin("#6a4428"))
            sw.append(cat)
    # The crooked dead tree at the back, with a branch for bats to hang from
    tree_pts = [(1.4, 1.5, 0.0), (1.35, 1.45, 0.7), (1.5, 1.5, 1.4), (1.3, 1.4, 2.0)]
    trunk = grow("tree", tree_pts, [(0, 1), (1, 2), (2, 3)], [0.22, 0.16, 0.12, 0.05], sub=1)
    paint(trunk, lambda co, n: lin("#5a4438").lerp(lin("#3a2a24"), 0.5 * (math.sin(co.z * 20) > 0)))
    sw.append(trunk)
    for (a, b, r) in (((1.45, 1.48, 1.2), (0.7, 1.3, 1.6), 0.07), ((1.42, 1.46, 1.7), (2.0, 1.2, 2.2), 0.05), ((1.35, 1.42, 0.5), (1.9, 1.7, 0.7), 0.06)):
        br = grow("branch", [a, b], [(0, 1)], [r, 0.015], sub=1)
        paint(br, lambda co, n: lin("#4a3830"))
        sw.append(br)
    # A rotten log on the left where toadstools grow
    log = grow("log", [(-2.3, -0.6, 0.12), (-1.6, -1.2, 0.12)], [(0, 1)], [0.17, 0.15], sub=1)
    paint(log, lambda co, n: lin("#6a4a2a").lerp(lin("#5a7a32"), 0.6 if n.z > 0.6 else 0.0))
    sw.append(log)
    # Mossy stones, a mound for the moon flowers, and a corner of graveyard
    for k in range(7):
        a = rnd_s.uniform(0, 2 * math.pi)
        rr = rnd_s.uniform(1.8, 2.8)
        p = Vector((math.cos(a) * rr, math.sin(a) * rr * 0.9, 0.05))
        s_ = rnd_s.uniform(0.12, 0.25)
        st = egg("stone", p, (s_, s_ * 0.9, s_ * 0.6), seg=9, rings=6, sub=1, shape=lambda v: v * (1.0 + 0.15 * math.sin(v.x * 30)))
        paint(st, lambda co, n: lin("#8a8298").lerp(lin("#5a8a3a"), 0.6 if n.z > 0.5 else 0.0))
        sw.append(st)
    mound = egg("mound", (0.9, -1.4, 0.0), (0.6, 0.5, 0.25), seg=14, rings=8, sub=1)
    paint(mound, lambda co, n: lin("#4a6a3a").lerp(lin("#7aa8ff"), 0.15))
    sw.append(mound)
    for k, (x, y) in enumerate(((-2.0, 1.4), (-2.4, 0.9), (-1.6, 1.9))):
        grave = box("grave", (x, y, 0.22), (0.3, 0.1, 0.45), bevel=0.06, rot=Matrix.Rotation(rnd_s.uniform(-0.2, 0.2), 3, "Y") @ Matrix.Rotation(0.4, 3, "Z"))
        paint(grave, lambda co, n: lin("#9a96a8").lerp(lin("#6a6678"), 0.4 * max(0.0, -n.z)))
        sw.append(grave)
    # Old bones where the dragon lay
    for k in range(4):
        rib = grow("rib", [(2.1, -0.4 + k * 0.22, 0.02), (2.35, -0.4 + k * 0.22, 0.25), (2.55, -0.4 + k * 0.22, 0.05)], [(0, 1), (1, 2)], [0.035, 0.03, 0.02], sub=1)
        paint(rib, lambda co, n: lin("#f2ead2"))
        sw.append(rib)
    skull = egg("dragon_skull", (2.3, 0.6, 0.12), (0.25, 0.18, 0.14), seg=10, rings=7, sub=1)
    paint(skull, lambda co, n: lin("#f2ead2"))
    sw.append(skull)
    out["swamp"] = sw

    # The stirring spoon, built at the size it's used (no squashing in the game, so the bowl stays
    # round). Origin at the top end; it runs along +Y to a big round wooden bowl, dished on the -Z side.
    stick = tube("stick", (0, 0, 0), (0, 0.8, 0), 0.05, 0.042, seg=10, sub=1)
    paint(stick, lambda co, n: lin("#b07a40"))
    # the neck thickening into the bowl
    neck = tube("stick_neck", (0, 0.76, 0), (0, 0.86, -0.01), 0.042, 0.06, seg=10, sub=0)
    paint(neck, lambda co, n: lin("#a87038"))

    def bowl_shape(v):
        # the back a deep round belly, the front pushed in to a hollow with a thick lip
        z = -abs(v.z) if v.z > 0 else v.z
        if v.z > 0:
            z = -abs(v.z) * 0.55 + 0.012
        return Vector((v.x, v.y, z))
    blade = egg("stick_blade", (0, 0.98, -0.02), (0.11, 0.15, 0.085), seg=18, rings=10, sub=1, shape=bowl_shape)
    paint(blade, lambda co, n: lin("#c08848"))
    knob = egg("stick_knob", (0, -0.025, 0), (0.07, 0.06, 0.07), seg=10, rings=6, sub=0)
    paint(knob, lambda co, n: lin("#7a4a24"))
    out["stick"] = [stick, neck, blade, knob]

    # The wand standing in a jar of sand; the wand is its own piece (origin at its grip)
    wjar = lathe("wand_jar", [(0.0, 0.08, 0.08), (0.12, 0.1, 0.1), (0.16, 0.07, 0.07), (0.2, 0.07, 0.07)], seg=14, sub=1, cap_top=True)
    paint(wjar, lit(plain("#6a8aa8", "#3a5a78", 0.0, 0.2)))
    out["wand_jar"] = [wjar]
    wand = tube("wand", (0, 0, 0), (0, 0, 0.42), 0.016, 0.012, seg=8, sub=1)
    paint(wand, lambda co, n: lin("#3a2418"))
    star = flat("glow_star", [(math.cos(2 * math.pi * k / 10 + math.pi / 2) * (0.07 if k % 2 == 0 else 0.03),
                               math.sin(2 * math.pi * k / 10 + math.pi / 2) * (0.07 if k % 2 == 0 else 0.03)) for k in range(10)],
                0.025, (0, 0, 0.48), Matrix.Rotation(math.pi / 2, 3, "X"), sub=0)
    paint(star, lambda co, n: lin("#fff27a"))
    out["wand"] = [wand, star]

    # The bottles are jars like the Eye of Newt's, empty, three on a tray
    rack = [box("rack", (0, 0, 0.03), (0.62, 0.22, 0.06), bevel=0.012)]
    paint(rack[0], lit(plain("#8a5228")))
    for k in range(3):
        x = (k - 1) * 0.2
        for part in jar("rack_jar%d" % k, 0.085, 0.22):
            part.data.transform(Matrix.Translation((x, 0, 0.06)))
            rack.append(part)
    out["bottles"] = rack
    # One filled jar, flown to whoever it's for; its liquid is its own piece so the game can colour it
    out["potion"] = jar("potion_jar", 0.15, 0.36)
    liquid = lathe("liquid", [(0.02, 0.138, 0.138), (0.25, 0.138, 0.138)], seg=16, sub=0)
    paint(liquid, lambda co, n: Vector((1, 1, 1)) * (0.75 + 0.25 * max(0.0, n.z)))
    out["potion_liquid"] = [liquid]

    # One of each ingredient, as it's picked up and carried to the pot
    out["one_eye"] = [eyeball("one_eye", (0, 0, 0.07), 0.07, look=Vector((0.2, -1, 0.3)))]
    st = grow("one_shroom_stem", [(0, 0, 0.0), (0.01, 0, 0.1), (0.0, 0, 0.17)], [(0, 1), (1, 2)], [0.045, 0.035, 0.04], sub=2)
    paint(st, lambda co, n: lin("#fff4dc"))
    cap = egg("one_shroom_cap", (0, 0, 0.18), (0.12, 0.12, 0.085), seg=16, rings=10, sub=1,
              shape=lambda v: Vector((v.x, v.y, max(v.z, -0.004) if v.z > -0.004 else v.z * 0.15)))
    paint(cap, lambda co, n: (lin("#fffbf0") if (n.z > 0.15 and math.sin(co.x * 58) * math.sin(co.y * 58 + 1.0) > 0.55) else lin("#ff4a3a")) if n.z > -0.2 else lin("#f0dcb0"))
    out["one_shroom"] = [st, cap]
    pivot1 = Vector((0, 0, 0.0))
    tips1 = [Vector((-0.2, 0, 0.12)), Vector((-0.24, 0, -0.02)), Vector((-0.16, 0, -0.14)), Vector((0.02, 0, -0.16)), Vector((0.16, 0, -0.1))]
    outline1 = []
    for i in range(len(tips1)):
        outline1.append((tips1[i].x, tips1[i].z))
        if i < len(tips1) - 1:
            m = (tips1[i] + tips1[i + 1]) / 2 * 0.7
            outline1.append((m.x, m.z))
    outline1.append((0.04, 0.06))
    memb1 = flat("one_wing", outline1, 0.01, (0, 0, 0.15), Matrix.Rotation(math.pi / 2, 3, "X"), sub=1)
    paint(memb1, lambda co, n: lin("#9a5ad8").lerp(lin("#4c2a7e"), min(1.0, (co - Vector((0, 0, 0.15))).length * 3.5)))
    wing_parts = [memb1]
    for t in tips1:
        bone_ = grow("one_wing_bone", [Vector((0, 0.01, 0.15)), Vector((t.x, 0.01, t.z + 0.15))], [(0, 1)], [0.012, 0.005], sub=1)
        paint(bone_, lambda co, n: lin("#3a2050"))
        wing_parts.append(bone_)
    out["one_wing"] = wing_parts
    out["one_leg"] = frog_leg("one_leg", (-0.12, 0, 0.04), 1, 0.0)
    sp = []
    body1 = egg("one_spider_body", (0, 0.02, 0.06), (0.075, 0.09, 0.06), seg=12, rings=8, sub=1)
    paint(body1, lambda co, n: lin("#e8303a") if (abs(co.x) < 0.02 and co.z > 0.1) else lin("#3a3260"))
    head1 = egg("one_spider_head", (0, -0.08, 0.06), (0.045, 0.04, 0.04), seg=10, rings=6, sub=1)
    paint(head1, lambda co, n: lin("#2e2a4a"))
    sp += [body1, head1]
    for sgn in (1, -1):
        for k in range(4):
            hip = Vector((sgn * 0.03, -0.04 + k * 0.03, 0.06))
            knee = hip + Vector((sgn * 0.08, (k - 1.5) * 0.03, 0.06))
            foot = hip + Vector((sgn * 0.14, (k - 1.5) * 0.05, -0.05))
            lg = grow("one_spider_leg", [hip, knee, foot], [(0, 1), (1, 2)], [0.012, 0.01, 0.005], sub=1)
            paint(lg, lambda co, n: lin("#2e2a4a"))
            sp.append(lg)
    out["one_spider"] = sp
    crescent1 = []
    for i in range(13):
        th = -1.3 + 2.6 * i / 12.0
        crescent1.append((math.cos(th) * 0.11, math.sin(th) * 0.11))
    for i in range(13):
        th = -1.1 + 2.2 * (1.0 - i / 12.0)
        crescent1.append((math.cos(th) * 0.07 + 0.035, math.sin(th) * 0.07))
    out["one_petal"] = [flat("glow_one_petal", crescent1, 0.01, (0, 0, 0.08), Matrix.Rotation(math.pi / 2, 3, "X"), sub=1)]
    paint(out["one_petal"][0], lambda co, n: lin("#e0ecff"))
    petal_stem = grow("one_petal_stem", [(0.0, 0.0, 0.0), (0.02, 0.0, 0.06)], [(0, 1)], [0.01, 0.008], sub=0)
    paint(petal_stem, lambda co, n: lin("#5aaa4a"))
    out["one_petal"].append(petal_stem)
    pp1 = grow("one_pepper", [(-0.08, 0, 0.06), (0.0, 0, 0.1), (0.07, 0, 0.07), (0.12, 0, 0.12)], [(0, 1), (1, 2), (2, 3)], [0.045, 0.04, 0.022, 0.004], sub=2)
    paint(pp1, lambda co, n: lin("#fffafc"))
    stem1 = grow("one_pepper_stem", [(-0.08, 0, 0.06), (-0.12, 0, 0.1)], [(0, 1)], [0.015, 0.008], sub=1)
    paint(stem1, lambda co, n: lin("#4a9a3a"))
    eyes1 = []
    for sgn in (1, -1):
        dot = egg("one_pepper_eye", (-0.02 + sgn * 0.0, sgn * 0.022, 0.13), (0.01, 0.01, 0.007), seg=6, rings=4, sub=0)
        paint(dot, lambda co, n: lin(INK))
        eyes1.append(dot)
    out["one_pepper"] = [pp1, stem1] + eyes1
    shield1 = [(0, 0.16), (0.09, 0.11), (0.11, 0.02), (0.08, -0.08), (0, -0.13), (-0.08, -0.08), (-0.11, 0.02), (-0.09, 0.11)]
    one_scale = flat("one_scale", shield1, 0.025, (0, 0, 0.13), Matrix.Rotation(math.pi / 2, 3, "X"), sub=2)
    paint(one_scale, lambda co, n: lin("#ffb83a").lerp(lin("#ff5a1a"), max(0.0, min(1.0, (0.2 - co.z) * 4.0))))
    out["one_scale"] = [one_scale]

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

    # A dial thermometer clipped to the pot, its stem out of the back of the dial and down into the
    # brew: a brass rim, a cream face with the heats round it in colour (cold, warm, hot, roaring, and
    # boiling over in red), ticks, and a needle of its own (the game turns it). The face looks down -Y
    # (toward whoever's at the pot); heat 0 is down and to the left, 100 down and to the right.
    R = 0.16
    BANDS = [(0, 22, "#7fb8ff"), (22, 47, "#ffd84a"), (47, 72, "#ff9a2e"), (72, 92, "#ff4a2a"), (92, 100, "#c8104a")]
    thermo = []
    rim_t = ring("dial_rim", (0, 0, 0), R, 0.022, seg=32, sides=8, rot=Matrix.Rotation(math.pi / 2, 3, "X"))
    paint(rim_t, lambda co, n: lin("#a8782a").lerp(lin("#ffd870"), max(0.0, n.z) * 0.6 + max(0.0, -n.y) * 0.3))
    back = lathe("dial_back", [(-0.03, R * 0.98, R * 0.98), (0.0, R, R)], seg=32, sub=0)
    back.data.transform(Matrix.Rotation(math.pi / 2, 4, "X"))
    paint(back, lambda co, n: lin("#6a4a1a"))
    face = lathe("dial_face", [(0.0, R * 0.95, R * 0.95), (0.001, R * 0.95, R * 0.95)], seg=32, sub=0)
    face.data.transform(Matrix.Rotation(math.pi / 2, 4, "X") @ Matrix.Translation((0, 0, 0.004)))
    paint(face, lambda co, n: lin("#f6ecd0"))
    thermo += [rim_t, back, face]
    steps = 54
    for k in range(steps):
        h = (k + 0.5) / steps * 100.0
        col = next(c for a, b, c in BANDS if a <= h <= b)
        th = math.radians(-135.0 + 270.0 * h / 100.0)
        p = Vector((math.sin(th), 0, math.cos(th))) * R * 0.76
        seg_box = box("glow_band" if h > 92 else "dial_band", (p.x, -0.012, p.z), (R * 0.1, 0.004, R * 0.2),
                      rot=Matrix.Rotation(th, 3, "Y"))
        paint(seg_box, lambda co, n, c=col: lin(c))
        thermo.append(seg_box)
    for k in range(11):
        th = math.radians(-135.0 + 27.0 * k)
        p = Vector((math.sin(th), 0, math.cos(th))) * R * 0.56
        tick = box("dial_tick", (p.x, -0.013, p.z), (0.008, 0.004, R * (0.16 if k % 5 == 0 else 0.09)), rot=Matrix.Rotation(th, 3, "Y"))
        paint(tick, lambda co, n: lin("#3a2414"))
        thermo.append(tick)
    stem = tube("dial_stem", (0, 0.02, 0), (0, 0.62, 0), 0.016, 0.01, seg=8)
    paint(stem, lambda co, n: lin("#9a94a8").lerp(lin("#e8e4f0"), max(0.0, n.z) * 0.7))
    collar = tube("dial_collar", (0, 0.0, 0), (0, 0.07, 0), 0.04, 0.03, seg=10)
    paint(collar, lambda co, n: lin("#a8782a"))
    clip = box("dial_clip", (0, 0.3, -0.05), (0.05, 0.12, 0.1), bevel=0.01)
    paint(clip, lambda co, n: lin("#7a7488"))
    thermo += [stem, collar, clip]
    out["thermometer"] = thermo
    needle = [box("needle", (0, -0.02, R * 0.32), (0.012, 0.006, R * 0.72)),
              egg("needle_hub", (0, -0.024, 0), (0.022, 0.012, 0.022), seg=10, rings=6, sub=0)]
    paint(needle[0], lambda co, n: lin("#c81a1a"))
    paint(needle[1], lambda co, n: lin("#3a2414"))
    out["thermometer_needle"] = needle

    # The island the hut stands on, after Banjo-Kazooie's Spiral Mountain and Gruntilda's Lair: a
    # grassy meadow (a dirt path winding out from the hut's window, a yellow flower field, round
    # cottages) ringed by flat-topped plateaus and tall rock pillars, their grass tops hanging over the
    # brown cliffs in drips, waterfalls off them, big round-crowned trees, and behind it all the lair:
    # a mossy mountain carved into a witch's face, glowing green eyes and a great open mouth a rope
    # bridge runs into. Blender's +Y is out of the hut's window (the game's -Z).
    # Every corner's alpha says what it's made of for shaders/isle.gdshader: 1 plain, 0.9 grass,
    # 0.8 rock, 0.7 water, 0.6 flowers, 0.5 leaves, 0.3 glowing.
    from mathutils import noise as mnoise
    isle = []
    PATH = [Vector((0, 3.5)), Vector((0.5, 8)), Vector((-2, 13)), Vector((1, 18)), Vector((-1, 24)), Vector((2, 30))]
    GRASS, ROCK, WATER, FLOWERS, LEAVES, GLOWING = 0.9, 0.8, 0.7, 0.6, 0.5, 0.3

    def m(c, a):
        c = lin(c)
        return Vector((c.x, c.y, c.z, a))

    def path_d(x, y):
        best = 99.0
        for i in range(len(PATH) - 1):
            a, b = PATH[i], PATH[i + 1]
            d = b - a
            t = max(0.0, min(1.0, (Vector((x, y)) - a).dot(d) / d.length_squared))
            best = min(best, (Vector((x, y)) - (a + d * t)).length)
        return best

    def ground_h(x, y):
        r = math.hypot(x, y)
        h = 0.35 * mnoise.noise(Vector((x * 0.08, y * 0.08, 0.3)))
        h *= max(0.0, min(1.0, (r - 5.0) / 8.0))
        h *= 0.3 + 0.7 * min(1.0, path_d(x, y) / 4.0)
        return h - 0.08
    bm = bmesh.new()
    bmesh.ops.create_grid(bm, x_segments=80, y_segments=80, size=110.0)
    for v in bm.verts:
        v.co.z = ground_h(v.co.x, v.co.y)
    me = bpy.data.meshes.new("isle_ground")
    bm.to_mesh(me)
    bm.free()
    ground = link(bpy.data.objects.new("isle_ground", me))

    def ground_col(co, n):
        pd = path_d(co.x, co.y)
        if pd < 1.2:
            return m(lin("#b08a5a").lerp(lin("#8a6a40"), 0.5 + 0.5 * mnoise.noise(Vector((co.x, co.y, 2.0)))), 1.0)
        # the yellow flower field
        if ((co.x + 2.0) / 7.0) ** 2 + ((co.y - 37.0) / 3.5) ** 2 < 1.0:
            return m("#d8c838", FLOWERS)
        return m(lin("#3aa82a").lerp(lin("#2a8a22"), 0.5 + 0.5 * mnoise.noise(Vector((co.x * 0.2, co.y * 0.2, 5.0)))), GRASS)
    paint(ground, ground_col)
    isle.append(ground)

    rnd_i = random.Random(71)

    def plateau(cx, cy, r, h, seed, grass="#3cb02c", rock="#a8743a", base=-0.5, spikes=16):
        """A flat-topped rock: brown cliffs all round, a grass lid on top hanging over in drips"""
        rr = random.Random(seed)
        n = spikes
        outline = []
        for j in range(n):
            a = math.tau * j / n
            k = 1.0 + 0.16 * mnoise.noise(Vector((math.cos(a) * 1.3 + seed, math.sin(a) * 1.3, seed * 0.7)))
            outline.append((a, r * k))
        # the cliffs, a little ragged going up
        bm = bmesh.new()
        rings = []
        zs = [base, h * 0.35, h * 0.7, h]
        for zi, z in enumerate(zs):
            ring = []
            for j, (a, rad) in enumerate(outline):
                wob = 1.0 + (rr.uniform(-0.06, 0.06) if 0 < zi < len(zs) - 1 else 0.0)
                ring.append(bm.verts.new((cx + math.cos(a) * rad * wob, cy + math.sin(a) * rad * wob, z)))
            rings.append(ring)
        for i in range(len(rings) - 1):
            for j in range(n):
                bm.faces.new((rings[i][j], rings[i][(j + 1) % n], rings[i + 1][(j + 1) % n], rings[i + 1][j]))
        me = bpy.data.meshes.new("cliff")
        bm.to_mesh(me)
        bm.free()
        cliff = link(bpy.data.objects.new("cliff", me))
        paint(cliff, lambda co, nn: m(lin(rock).lerp(lin(rock) * 0.6, 0.5 + 0.5 * mnoise.noise(Vector((co.x * 0.3, co.y * 0.3, co.z * 0.2)))), ROCK))
        # the grass lid, a touch domed and wider than the cliffs
        bm = bmesh.new()
        mid = bm.verts.new((cx, cy, h + 0.25))
        lip = [bm.verts.new((cx + math.cos(a) * rad * 1.04, cy + math.sin(a) * rad * 1.04, h + 0.03)) for a, rad in outline]
        for j in range(n):
            bm.faces.new((mid, lip[j], lip[(j + 1) % n]))
        me = bpy.data.meshes.new("lid")
        bm.to_mesh(me)
        bm.free()
        lid = link(bpy.data.objects.new("lid", me))
        paint(lid, lambda co, nn: m(grass, GRASS))
        # the drips: the lid's edge hanging down the cliff in points, long and short
        bm = bmesh.new()
        top, bot = [], []
        steps = n * 3
        for j in range(steps):
            t = j / steps
            jj = int(t * n)
            f = t * n - jj
            a0, r0 = outline[jj]
            a1, r1 = outline[(jj + 1) % n]
            a = a0 + (((a1 - a0 + math.pi) % math.tau) - math.pi) * f
            rad = (r0 + (r1 - r0) * f) * 1.045
            drip = rr.uniform(0.7, 1.6) if j % 3 == 1 else rr.uniform(0.15, 0.4)
            drip *= min(1.0, h / 4.0) + 0.3
            top.append(bm.verts.new((cx + math.cos(a) * rad, cy + math.sin(a) * rad, h + 0.05)))
            bot.append(bm.verts.new((cx + math.cos(a) * rad * 0.995, cy + math.sin(a) * rad * 0.995, h - drip)))
        for j in range(steps):
            bm.faces.new((top[j], top[(j + 1) % steps], bot[(j + 1) % steps], bot[j]))
        me = bpy.data.meshes.new("drips")
        bm.to_mesh(me)
        bm.free()
        drips = link(bpy.data.objects.new("drips", me))
        paint(drips, lambda co, nn: m(lin(grass).lerp(lin(grass) * 0.55, max(0.0, min(1.0, (h - co.z) / 1.2))), GRASS))
        return [cliff, lid, drips]

    def waterfall(cx, cy, r, h, toward):
        """Water pouring off a plateau's edge facing `toward`, into a pool"""
        d = (Vector(toward) - Vector((cx, cy))).normalized()
        side = Vector((-d.y, d.x))
        at = Vector((cx, cy)) + d * r * 0.92
        w = 1.4
        bm = bmesh.new()
        vs = []
        for zi in range(5):
            z = h + 0.1 - (h + 0.4) * zi / 4.0
            push = 0.5 + 0.9 * (zi / 4.0) ** 0.5
            p = at + d * push
            vs.append((bm.verts.new((p.x - side.x * w, p.y - side.y * w, z)), bm.verts.new((p.x + side.x * w, p.y + side.y * w, z))))
        for zi in range(4):
            bm.faces.new((vs[zi][0], vs[zi][1], vs[zi + 1][1], vs[zi + 1][0]))
        me = bpy.data.meshes.new("waterfall")
        bm.to_mesh(me)
        bm.free()
        fall = link(bpy.data.objects.new("waterfall", me))
        paint(fall, lambda co, nn: m("#9ad0ff", WATER))
        pc = at + d * 2.6
        pool = egg("pool", (pc.x, pc.y, 0.0), (3.0, 2.6, 0.12), seg=14, rings=4, sub=0)
        paint(pool, lambda co, nn: m("#3a7ae8", WATER))
        return [fall, pool]

    def tree(x, y, s=1.0):
        """A Spiral Mountain tree: a tall bare trunk and one big lumpy round crown"""
        z = ground_h(x, y)
        trunk = tube("tree_trunk", (x, y, z - 0.3), (x, y, z + 3.6 * s), 0.42 * s, 0.3 * s, seg=7)
        paint(trunk, lambda co, n: m("#6a3e1e", ROCK))
        sd = rnd_i.uniform(0, 50)
        crown = egg("tree_crown", (x, y, z + 4.6 * s), (2.1 * s, 2.1 * s, 1.9 * s), seg=12, rings=8, sub=0,
                    shape=lambda v: v * (1.0 + 0.16 * mnoise.noise(Vector((v.x * 0.9 + sd, v.y * 0.9, v.z * 0.9)))))
        paint(crown, lambda co, n: m(lin("#3ac02a").lerp(lin("#1a6a1a"), 0.6 * max(0.0, -n.z)), LEAVES))
        return [trunk, crown]

    # The plateaus round the meadow (centre x, y, radius, height), some with a second tier
    for i, (cx, cy, r, h) in enumerate([(-25, 12, 7, 5), (-28, 24, 9, 7), (-22, 38, 6, 4.5), (-28, 24, 5, 11),
                                        (24, 8, 6, 4), (25, 20, 8, 6.5), (26, 36, 7, 5), (25, 20, 4.5, 10),
                                        (-18, 54, 8, 4.5), (22, 56, 9, 5), (9, 38, 3, 2.2), (-30, -4, 8, 6), (28, -6, 8, 5.5)]):
        isle += plateau(cx, cy, r, h, i + 1)
    # Tall rock pillars
    for i, (cx, cy, r, h) in enumerate([(15, 40, 2.5, 11), (-7, 41, 2.8, 9), (14, 49, 2.0, 13)]):
        isle += plateau(cx, cy, r, h, 40 + i, spikes=11)
    # A ring of high cliffs closing the world in
    for k in range(16):
        a = math.tau * k / 16 + 0.1
        if abs(((a - math.pi / 2 + math.pi) % math.tau) - math.pi) < 0.75:
            continue  # (not in front of the lair)
        isle += plateau(math.cos(a) * 72, math.sin(a) * 72, 15, rnd_i.uniform(9, 16), 60 + k, grass="#2a9a24", rock="#946430")
    isle += waterfall(-28, 24, 9, 7, (0, 18))
    isle += waterfall(25, 20, 8, 6.5, (0, 18))
    isle += waterfall(-18, 54, 8, 4.5, (0, 20))
    for x, y, s in [(-6, 8, 1.0), (6, 7, 0.9), (-18, 17, 1.1), (17, 17, 1.0), (-9, 33, 1.0), (10, 31, 1.1), (-6, 19, 0.85),
                    (7, 21, 0.95), (12, 45, 1.2), (-13, 36, 1.0), (19, 46, 1.1), (-2, 50, 1.3), (-14, 3, 1.0), (14, 2, 0.9)]:
        isle += tree(x, y, s)

    # The lair: a great mossy mountain with a witch's face carved in the side facing the hut
    LX, LY = 4.0, 80.0

    def lair_r(z):
        return max(2.0, 26.0 - z * 0.42)
    mount = lathe("lair", [(z, lair_r(z), lair_r(z)) for z in [-1, 4, 9, 14, 19, 24, 30, 36, 42, 50, 56]], seg=26, sub=0,
                  wobble=lambda a, z: 2.2 * mnoise.noise(Vector((math.cos(a) * 2.0, math.sin(a) * 2.0, z * 0.12))))
    for vtx in mount.data.vertices:
        k = max(0.0, vtx.co.z - 30.0) / 26.0
        vtx.co.x += 9.0 * k * k
    mount.data.transform(Matrix.Translation((LX, LY, 0)))
    paint(mount, lambda co, n: m(lin("#4a8a38").lerp(lin("#2e6028"), 0.5 + 0.5 * mnoise.noise(Vector((co.x * 0.1, co.y * 0.1, co.z * 0.1)))), ROCK))
    isle.append(mount)

    def front(z, dx=0.0):
        """A point on the lair's face, `dx` across it, at height z"""
        return Vector((LX + dx, LY - math.sqrt(max(1.0, lair_r(z) ** 2 - dx * dx)) + 1.2, z))
    face = []
    for sx in (-1, 1):
        e = front(17, sx * 6.0)
        sock = egg("eye_socket", e, (3.4, 1.2, 2.4), seg=12, rings=6, sub=0)
        paint(sock, lambda co, n: m("#0e1a0e", 1.0))
        ball = egg("eye", e + Vector((0, -0.7, 0)), (2.4, 0.8, 1.8), seg=12, rings=6, sub=0)
        paint(ball, lambda co, n: m("#5aff6a", GLOWING))
        pupil = egg("pupil", e + Vector((sx * -0.3, -1.4, -0.2)), (0.9, 0.5, 1.2), seg=8, rings=5, sub=0)
        paint(pupil, lambda co, n: m("#0a2a0a", 1.0))
        b0 = front(20.5, sx * 2.5)
        b1 = front(21.5, sx * 9.5)
        brow = tube("brow", b0 + Vector((0, -1.0, -0.6)), b1 + Vector((0, -0.6, 0.6)), 1.0, 0.7, seg=7)
        paint(brow, lambda co, n: m("#b88a3a", ROCK))
        face += [sock, ball, pupil, brow]
    n0 = front(16.5)
    nose = tube("nose", n0 + Vector((0, 1.0, 0)), n0 + Vector((0, -8.0, -5.0)), 2.6, 0.5, seg=9)
    paint(nose, lambda co, n: m("#5aa040", ROCK))
    wart = egg("wart", n0 + Vector((1.4, -4.5, -2.2)), (0.9, 0.9, 0.9), seg=8, rings=5, sub=0)
    paint(wart, lambda co, n: m("#5a8a3a", ROCK))
    mo = front(8.0)
    mouth = egg("mouth", mo + Vector((0, -0.4, 0)), (6.5, 1.4, 3.2), seg=16, rings=8, sub=0)
    paint(mouth, lambda co, n: m("#c82a1a", GLOWING))
    lips = lathe("lips", [(-0.6, 7.2, 3.8), (0.6, 7.2, 3.8)], seg=18, sub=0, cap_top=False, cap_bottom=False)
    lips.data.transform(Matrix.Translation(mo + Vector((0, -0.6, 0))) @ Matrix.Rotation(math.pi / 2, 4, "X"))
    paint(lips, lambda co, n: m("#2a4a1e", ROCK))
    face += [nose, wart, mouth, lips]
    for k in range(5):
        tx = -4.0 + k * 2.0
        tooth = box("tooth", (mo.x + tx, mo.y - 1.6, mo.z + 2.0 - abs(tx) * 0.12), (0.9, 0.5, 1.4))
        paint(tooth, lambda co, n: m("#f0ead0", 1.0))
        face.append(tooth)
    isle += face
    # The rope bridge from the tallest pillar into the mouth
    b0 = Vector((14.0, 49.0, 13.0))
    b1 = mo + Vector((0, -1.0, -2.2))
    for k in range(18):
        t = (k + 0.5) / 18
        p = b0.lerp(b1, t) + Vector((0, 0, -1.2 * math.sin(t * math.pi)))
        plank = box("plank", p, (1.8, 0.45, 0.12), rot=Matrix.Rotation(math.atan2(b1.x - b0.x, b1.y - b0.y), 3, "Z"))
        paint(plank, lambda co, n: m("#8a5a2a", 1.0))
        isle.append(plank)
    for sx in (-0.95, 0.95):
        prev = None
        for k in range(9):
            t = k / 8
            p = b0.lerp(b1, t) + Vector((sx, 0, 0.9 - 1.2 * math.sin(t * math.pi)))
            if prev is not None:
                rope = tube("rope", prev, p, 0.06, 0.06, seg=6)
                paint(rope, lambda co, n: m("#c8a060", 1.0))
                isle.append(rope)
            prev = p

    def cottage(x, y, wall, roof, turn):
        z = ground_h(x, y)
        walls = lathe("cottage_wall", [(0.0, 2.2, 2.2), (2.6, 2.1, 2.1)], seg=12, sub=0, cap_top=False)
        walls.data.transform(Matrix.Translation((x, y, z - 0.2)))
        paint(walls, lambda co, n: m(lin(wall) * (0.75 + 0.25 * max(0.0, n.x * 0.5 + 0.5)), 1.0))
        lean = Vector((math.cos(turn) * 0.4, math.sin(turn) * 0.4, 0))
        cone = lathe("cottage_roof", [(2.3, 3.0, 3.0), (2.9, 2.4, 2.4), (4.2, 1.2, 1.2), (5.4, 0.15, 0.15)], seg=12, sub=0)
        for vtx in cone.data.vertices:
            k = max(0.0, (vtx.co.z - 2.3) / 3.1)
            vtx.co += lean * k * k
        cone.data.transform(Matrix.Translation((x, y, z - 0.2)))
        paint(cone, lambda co, n: m(lin(roof).lerp(lin(roof) * 0.55, 0.5 * (math.sin(co.z * 9.0) > 0.4)), 1.0))
        door = box("cottage_door", (x + math.cos(turn) * 2.15, y + math.sin(turn) * 2.15, z + 0.7), (0.9, 0.2, 1.5), rot=Matrix.Rotation(turn + math.pi / 2, 3, "Z"))
        paint(door, lambda co, n: m("#5a3418", 1.0))
        win = box("cottage_window", (x + math.cos(turn + 0.9) * 2.15, y + math.sin(turn + 0.9) * 2.15, z + 1.6), (0.6, 0.2, 0.6), rot=Matrix.Rotation(turn + 0.9 + math.pi / 2, 3, "Z"))
        paint(win, lambda co, n: m("#ffd070", GLOWING))
        chim = tube("cottage_chimney", (x - 1.0, y, z + 3.4), (x - 1.0, y, z + 5.2), 0.3, 0.3, seg=6)
        paint(chim, lambda co, n: m("#8a6a5a", 1.0))
        return [walls, cone, door, win, chim]
    for x, y, wall, roof, turn in [(-13, 8, "#f0e8d0", "#4a6ad8", -0.5), (13, 9, "#e8d0b0", "#d84a4a", -2.6),
                                   (-15, 28, "#f0e0c8", "#e8b030", -0.6), (17, 29, "#d8c8e8", "#8a4ac8", -2.4)]:
        isle += cottage(x, y, wall, roof, turn)
    for i in range(len(PATH) - 1):
        p = PATH[i].lerp(PATH[i + 1], 0.5) + Vector((1.8, 0))
        z = ground_h(p.x, p.y)
        post = tube("lamp_post", (p.x, p.y, z - 0.2), (p.x, p.y, z + 2.2), 0.08, 0.07, seg=6)
        paint(post, lambda co, n: m("#3a2a20", 1.0))
        lamp = box("lamp", (p.x, p.y, z + 2.35), (0.3, 0.3, 0.4))
        paint(lamp, lambda co, n: m("#ffc860", GLOWING))
        isle += [post, lamp]
    # The hut's own roof: a crooked cone of dark shingles over the round wall, the periscope out of it
    roof_ = lathe("hut_roof", [(5.9, 4.2, 4.2), (6.6, 3.6, 3.6), (8.4, 2.0, 2.0), (10.6, 0.25, 0.25)], seg=14, sub=0)
    for vtx in roof_.data.vertices:
        k = max(0.0, (vtx.co.z - 5.9) / 4.7)
        vtx.co += Vector((0.9, -0.5, 0)) * k * k
    roof_.data.transform(Matrix.Translation((0, -0.25, 0)))
    paint(roof_, lambda co, n: m(lin("#4a3a6a").lerp(lin("#2a2040"), 0.5 * (math.sin(co.z * 8.0) > 0.3)), 1.0))
    pipe = tube("periscope", (-1.2, 0.6, 7.0), (-1.2, 0.6, 11.0), 0.18, 0.18, seg=8)
    paint(pipe, lambda co, n: m("#c8902a", 1.0))
    head_ = box("periscope_head", (-1.2, 0.85, 11.1), (0.4, 0.7, 0.4))
    paint(head_, lambda co, n: m("#c8902a", 1.0))
    lens = box("lens", (-1.2, 1.21, 11.1), (0.25, 0.05, 0.25))
    paint(lens, lambda co, n: m("#a8e0ff", GLOWING))
    isle += [roof_, pipe, head_, lens]
    out["island"] = isle

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
