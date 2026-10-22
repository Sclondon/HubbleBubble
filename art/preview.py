# Renders a model's .blend from a few sides, in its painted colours, for looking at.
#   blender --background art/<name>.blend --python art/preview.py -- <out.png>
import math
import sys

import bpy
from mathutils import Vector

out = sys.argv[sys.argv.index("--") + 1]
scene = bpy.context.scene
scene.render.engine = "BLENDER_WORKBENCH"
scene.display.shading.light = "STUDIO"
scene.display.shading.color_type = "VERTEX"
scene.display.shading.show_cavity = False
scene.render.resolution_x = 700
scene.render.resolution_y = 1000
scene.render.film_transparent = False
world = bpy.data.worlds.new("w") if not scene.world else scene.world
scene.world = world
world.color = (0.12, 0.1, 0.16)
lo = Vector((1e9, 1e9, 1e9))
hi = -lo
for o in scene.objects:
    if o.type == "MESH":
        for c in o.bound_box:
            p = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
mid = (lo + hi) / 2
size = max((hi - lo).length, 0.1)
cam_data = bpy.data.cameras.new("c")
cam_data.type = "ORTHO"
cam_data.ortho_scale = max(hi.z - lo.z, (hi.x - lo.x) * 1.4) * 1.08
cam = bpy.data.objects.new("c", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
views = [(-math.pi / 2, "front"), (-math.pi / 2 + 0.7, "three"), (0.0, "side")]
paths = []
for k, (a, name) in enumerate(views):
    d = Vector((math.cos(a), math.sin(a), 0.25)).normalized()
    cam.location = mid + d * size * 2
    cam.rotation_euler = (mid - cam.location).to_track_quat("-Z", "Y").to_euler()
    p = out.replace(".png", "_%d.png" % k)
    scene.render.filepath = p
    bpy.ops.render.render(write_still=True)
    paths.append(p)
print("rendered", paths)
