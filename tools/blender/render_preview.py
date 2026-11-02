"""Render turnaround previews of creature GLBs to PNG (for reviewing art without Unity).

    blender --background --python tools/blender/render_preview.py -- out_dir model1.glb model2.glb ...
"""

import math
import sys
from pathlib import Path

import bpy
from mathutils import Vector

args = sys.argv[sys.argv.index("--") + 1:]
out_dir = Path(args[0])
out_dir.mkdir(parents=True, exist_ok=True)

for path in args[1:]:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=path)
    objs = [o for o in bpy.context.scene.objects if o.type == "MESH"]
    lo = Vector((1e9,) * 3)
    hi = Vector((-1e9,) * 3)
    for o in objs:
        for c in o.bound_box:
            w = o.matrix_world @ Vector(c)
            lo = Vector(map(min, lo, w))
            hi = Vector(map(max, hi, w))
    center = (lo + hi) / 2
    size = max(hi - lo)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_WORKBENCH"
    scene.display.shading.light = "STUDIO"
    scene.display.shading.color_type = "MATERIAL"
    scene.display.shading.show_cavity = True
    scene.display.shading.show_object_outline = True
    scene.render.resolution_x = 512
    scene.render.resolution_y = 512
    scene.render.film_transparent = False
    scene.world = bpy.data.worlds.new("w")
    scene.world.color = (0.85, 0.9, 0.95)
    cam_data = bpy.data.cameras.new("cam")
    cam_data.type = "ORTHO"
    cam_data.ortho_scale = size * 1.25
    cam = bpy.data.objects.new("cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    name = Path(path).stem
    # Front (models face -Y), three-quarter, side.
    for label, yaw in (("front", 0), ("threeq", 40), ("side", 90)):
        a = math.radians(yaw)
        d = size * 3
        cam.location = center + Vector((math.sin(a) * d, -math.cos(a) * d, size * 0.35))
        direction = center - cam.location
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        scene.render.filepath = str(out_dir / f"{name}_{label}.png")
        bpy.ops.render.render(write_still=True)
    print("RENDERED", name)
