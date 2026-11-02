"""Lumina Vale art kit: creatures (3 species x 3 stages) + environment props.

Headless:
    blender --background --python tools/blender/build_kit.py
    blender --background --python tools/blender/build_kit.py -- creatures   # only creatures
    blender --background --python tools/blender/build_kit.py -- kit         # only props

Outputs GLB files straight into the Unity project:
    game/Assets/_Game/Resources/Models/<species>_<stage>.glb   (rigged + 10 clips)
    game/Assets/_Game/Resources/Kit/<prop>.glb

Conventions (match the C# side):
    * Creatures face Blender -Y (glTF forward). Feet at Z=0. Metres.
    * Buildings: door on the +Y side (faces the camera in game), pivot at footprint centre.
    * One flat colour per material; the game swaps every material for its toon shader and
      keeps the base colour, so colour regions = separate materials.
    * Clip names: Idle Walk Run Happy_Hop Eat Pet_Enjoy Refuse Sleep Attack Hit.

Shapes are built from metaballs (soft, clay-like unions), converted to mesh, then decimated
to a mobile budget (~3-6k tris per creature).
"""

from __future__ import annotations

import math
import random
import sys
from pathlib import Path

import bpy
import bmesh
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[2]
MODELS = ROOT / "game" / "Assets" / "_Game" / "Resources" / "Models"
KIT = ROOT / "game" / "Assets" / "_Game" / "Resources" / "Kit"
FPS = 24

# --------------------------------------------------------------------------------------
# Scene + material helpers
# --------------------------------------------------------------------------------------


def reset() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    _mats.clear()
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = 48


_mats: dict[str, bpy.types.Material] = {}
_blob_id = 0


def mat(name: str, rgb) -> bpy.types.Material:
    """Flat colour material; the name is kept so the game can find e.g. 'Window'."""
    key = f"{name}_{rgb}"
    if key in _mats:
        return _mats[key]
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
    bsdf.inputs["Roughness"].default_value = 0.7
    m.diffuse_color = (*rgb, 1.0)
    _mats[key] = m
    return m


def activate(obj) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj


def set_material(obj, material) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(material)


def smooth(obj) -> None:
    activate(obj)
    bpy.ops.object.shade_smooth()


def decimate(obj, ratio: float) -> None:
    if ratio >= 0.999:
        return
    activate(obj)
    mod = obj.modifiers.new("dec", "DECIMATE")
    mod.ratio = ratio
    bpy.ops.object.modifier_apply(modifier=mod.name)


def bevel(obj, width=0.03, segments=2) -> None:
    activate(obj)
    mod = obj.modifiers.new("bev", "BEVEL")
    mod.width = width
    mod.segments = segments
    mod.limit_method = "ANGLE"
    bpy.ops.object.modifier_apply(modifier=mod.name)


def tri_count(obj) -> int:
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def join(objs, name: str):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    out = bpy.context.active_object
    out.name = name
    return out


def blob(name: str, elements, material, resolution=0.035, target_tris=None):
    """Metaball union -> mesh. elements: list of (co, radius, (sx, sy, sz) or None)."""
    global _blob_id
    _blob_id += 1
    name = f"{name}_{_blob_id}"  # unique base name: metaballs sharing one merge into a family
    mb = bpy.data.metaballs.new(name)
    mb.resolution = resolution
    mb.render_resolution = resolution
    mb.threshold = 0.6
    obj = bpy.data.objects.new(name, mb)
    bpy.context.scene.collection.objects.link(obj)
    for co, radius, size in elements:
        e = mb.elements.new()
        e.co = Vector(co)
        e.radius = radius
        e.stiffness = 2.0
        if size is not None:
            e.type = "ELLIPSOID"
            e.size_x, e.size_y, e.size_z = size
    activate(obj)
    bpy.ops.object.convert(target="MESH")
    mesh = bpy.context.active_object
    mesh.name = name
    set_material(mesh, material)
    if target_tris:
        t = tri_count(mesh)
        if t > target_tris:
            decimate(mesh, target_tris / t)
    smooth(mesh)
    return mesh


def prim(kind: str, name: str, loc, scale=(1, 1, 1), rot=(0, 0, 0), material=None, **kw):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("segs", 16), ring_count=kw.get("rings", 10), radius=1, location=loc, rotation=rot)
    elif kind == "ico":
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=kw.get("subdiv", 2), radius=1, location=loc, rotation=rot)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("verts", 12), radius=1, depth=1, location=loc, rotation=rot)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("verts", 10), radius1=1, radius2=kw.get("top", 0.0), depth=1, location=loc, rotation=rot)
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_radius=1, minor_radius=kw.get("minor", 0.25), major_segments=kw.get("maj", 16), minor_segments=kw.get("mnr", 6), location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    if material is not None:
        set_material(obj, material)
    if kw.get("smooth", True):
        smooth(obj)
    return obj


def export(path: Path, objs, animations: bool) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    path.parent.mkdir(parents=True, exist_ok=True)
    kw = dict(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_yup=True,
        export_animations=animations,
        export_skins=animations,
        export_morph=False,
        export_lights=False,
        export_cameras=False,
    )
    if animations:
        kw.update(export_animation_mode="NLA_TRACKS", export_force_sampling=True)
    bpy.ops.export_scene.gltf(**kw)
    print(f"WROTE {path.relative_to(ROOT)}  {path.stat().st_size // 1024} KB")


# --------------------------------------------------------------------------------------
# Creatures
# --------------------------------------------------------------------------------------

BONES = ["Root", "Spine", "Head", "Ear_L", "Ear_R", "Arm_L", "Arm_R", "Foot_L", "Foot_R", "Tail"]

# Palettes: main, belly/cream, accent, deep accent
PALETTE = {
    "pipkin": dict(main=(0.97, 0.93, 0.8), belly=(1.0, 0.98, 0.9), accent=(0.45, 0.78, 0.38), deep=(0.3, 0.6, 0.3), extra=(0.98, 0.6, 0.72)),
    "marrow": dict(main=(0.36, 0.64, 0.95), belly=(0.88, 0.96, 1.0), accent=(0.6, 0.85, 1.0), deep=(0.24, 0.44, 0.78), extra=(1.0, 0.96, 0.9)),
    "solbit": dict(main=(0.97, 0.52, 0.24), belly=(1.0, 0.9, 0.72), accent=(1.0, 0.78, 0.22), deep=(0.82, 0.3, 0.16), extra=(1.0, 0.95, 0.55)),
}
INK = (0.1, 0.08, 0.14)
BLUSH = (1.0, 0.62, 0.66)


class Body:
    """Proportions for one stage. Baby: huge head, tiny body. Adult: taller, longer limbs."""

    def __init__(self, stage: int):
        self.stage = stage
        self.s = [0.82, 1.0, 1.22][stage]
        self.head_r = [0.36, 0.34, 0.33][stage] * self.s
        self.body_h = [0.3, 0.38, 0.46][stage] * self.s
        self.head_z = self.body_h + self.head_r * 0.92
        self.leg = [0.07, 0.1, 0.14][stage] * self.s


def creature_parts(species: str, stage: int):
    """Returns (parts, bone_for_part). Each part is a mesh object with one material."""
    p = PALETTE[species]
    b = Body(stage)
    s = b.s
    m_main, m_belly, m_acc, m_deep, m_extra = (mat(f"{species}_{k}", p[k]) for k in ("main", "belly", "accent", "deep", "extra"))
    m_ink, m_white, m_blush = mat("Ink", INK), mat("Shine", (1, 1, 1)), mat("Blush", BLUSH)
    parts, bones = [], []

    def add(obj, bone):
        parts.append(obj)
        bones.append(bone)

    hz, hr, bh = b.head_z, b.head_r, b.body_h
    # Core: one metaball union so head and body melt together like clay.
    core = [
        ((0, 0, bh * 0.55 + b.leg), bh * 0.95, (1.0, 0.92 if species != "marrow" else 1.15, 0.9)),
        ((0, 0, hz + b.leg * 0.6), hr * 1.45, (1.05, 0.98, 0.92)),
    ]
    if species == "marrow":  # rounder, seal-like
        core.append(((0, 0.12 * s, bh * 0.4 + b.leg), bh * 0.9, (1.0, 1.25, 0.75)))
    add(blob(f"{species}{stage}_core", core, m_main, target_tris=2400), "auto")

    # Belly / face patch.
    belly = [((0, -bh * 0.55, bh * 0.5 + b.leg), bh * 0.62, (0.85, 0.4, 0.95))]
    muzzle = [((0, -hr * 0.82, hz - hr * 0.22 + b.leg * 0.6), hr * 0.5, (1.0, 0.55, 0.62))]
    add(blob(f"{species}{stage}_belly", belly, m_belly, resolution=0.03, target_tris=500), "Spine")
    add(blob(f"{species}{stage}_muzzle", muzzle, m_belly, resolution=0.025, target_tris=350), "Head")

    # Face: big glossy eyes, highlight, blush.
    ez = hz + hr * 0.12 + b.leg * 0.6
    ex = hr * (0.42 if stage == 0 else 0.38)
    eye_r = hr * (0.2 if stage == 0 else 0.17)
    for side, bone in ((1, "Head"), (-1, "Head")):
        eye = prim("sphere", "eye", (side * ex, -hr * 0.86, ez), (eye_r * 0.82, eye_r * 0.5, eye_r * 1.12), material=m_ink, segs=14, rings=8)
        add(eye, bone)
        shine = prim("sphere", "shine", (side * ex + eye_r * 0.32, -hr * 0.96, ez + eye_r * 0.42), (eye_r * 0.32,) * 3, material=m_white, segs=8, rings=6)
        add(shine, bone)
        cheek = prim("sphere", "cheek", (side * hr * 0.62, -hr * 0.72, ez - hr * 0.36), (hr * 0.14, hr * 0.05, hr * 0.09), material=m_blush, segs=10, rings=6)
        add(cheek, bone)
    mouth = prim("torus", "mouth", (0, -hr * 0.98, ez - hr * 0.42), (hr * 0.09, hr * 0.06, hr * 0.06), rot=(math.radians(90), 0, 0), material=m_ink, minor=0.35)
    add(mouth, "Head")

    # Limbs.
    for side, arm, foot in ((1, "Arm_L", "Foot_L"), (-1, "Arm_R", "Foot_R")):
        if species == "marrow":
            flipper = blob("flipper", [((side * bh * 0.95, -0.02 * s, bh * 0.45 + b.leg), bh * 0.42, (1.3, 0.5, 0.28))], m_main, resolution=0.03, target_tris=300)
            add(flipper, arm)
        else:
            arm_o = blob("arm", [((side * bh * 0.9, -0.05 * s, bh * 0.55 + b.leg), bh * 0.3, (0.7, 0.7, 1.1))], m_main, resolution=0.03, target_tris=250)
            add(arm_o, arm)
        foot_o = blob("foot", [((side * bh * 0.42, -0.06 * s, b.leg * 0.6), bh * 0.32, (0.85, 1.25, 0.55))], m_main if species != "pipkin" else m_belly, resolution=0.03, target_tris=250)
        add(foot_o, foot)

    # Species features, growing with stage.
    if species == "pipkin":
        ear_len = [0.3, 0.42, 0.5][stage] * s
        for side, bone in ((1, "Ear_L"), (-1, "Ear_R")):
            leaf = blob("leafear", [((side * hr * 0.55, 0.02, hz + hr * 0.8 + ear_len * 0.4), ear_len * 0.55, (0.42, 0.16, 1.0))], m_acc, resolution=0.025, target_tris=300)
            add(leaf, bone)
        sprout = blob("sprout", [((0, 0, hz + hr * 1.1), hr * 0.18, (0.4, 0.4, 1.4)), ((0.06 * s, 0, hz + hr * 1.35), hr * 0.22, (1.0, 0.4, 0.3))], m_acc, resolution=0.02, target_tris=200)
        add(sprout, "Head")
        tail = blob("leaftail", [((0, bh * 0.75, bh * 0.4 + b.leg), bh * (0.32 + 0.12 * stage), (0.5, 1.2, 0.25))], m_acc, resolution=0.03, target_tris=250)
        add(tail, "Tail")
        if stage >= 2:
            for i in range(6):
                a = i / 6 * math.tau
                petal = prim("sphere", "petal", (math.cos(a) * hr * 0.45, math.sin(a) * hr * 0.45 + 0.02, hz + hr * 1.05), (hr * 0.16, hr * 0.16, hr * 0.06), material=m_extra, segs=10, rings=6)
                add(petal, "Head")
        if stage >= 1:
            mane = blob("mane", [((side * hr * 0.9, 0.05, hz - hr * 0.3), hr * 0.32, (0.5, 0.8, 0.8)) for side in (1, -1)], m_deep, resolution=0.03, target_tris=300)
            add(mane, "Head")
    elif species == "marrow":
        for side, bone in ((1, "Ear_L"), (-1, "Ear_R")):
            fin = blob("headfin", [((side * hr * 1.0, 0.05, hz + hr * 0.15), hr * (0.32 + 0.08 * stage), (0.9, 0.3, 0.55))], m_acc, resolution=0.025, target_tris=250)
            add(fin, bone)
        tail = blob("tailfin", [((side * bh * 0.32, bh * 1.15, bh * 0.25 + b.leg), bh * (0.32 + 0.1 * stage), (1.1, 0.6, 0.18)) for side in (1, -1)], m_acc, resolution=0.03, target_tris=350)
        add(tail, "Tail")
        if stage >= 1:
            shell = blob("shell", [((0, bh * 0.5, bh * 0.8 + b.leg), bh * 0.6, (0.95, 0.75, 0.5))], m_extra, resolution=0.03, target_tris=400)
            add(shell, "Spine")
            for i in range(3):
                ridge = prim("torus", "ridge", (0, bh * 0.5, bh * 0.8 + b.leg + bh * 0.12 * (i - 1)), (bh * 0.55 * (1 - abs(i - 1) * 0.25),) * 2 + (bh * 0.3,), material=m_deep, minor=0.08, maj=20)
                add(ridge, "Spine")
        if stage >= 2:
            pearl = prim("sphere", "pearl", (0, -hr * 0.55, hz + hr * 0.82), (hr * 0.16,) * 3, material=m_extra, segs=12, rings=8)
            add(pearl, "Head")
    else:  # solbit
        for side, bone in ((1, "Ear_L"), (-1, "Ear_R")):
            ear = prim("cone", "ear", (side * hr * 0.62, 0.02, hz + hr * 0.95), (hr * 0.28, hr * 0.2, hr * (0.55 + 0.12 * stage)), rot=(0, side * math.radians(-18), 0), material=m_main, verts=10)
            add(ear, bone)
            inner = prim("cone", "earinner", (side * hr * 0.62, -hr * 0.07, hz + hr * 0.92), (hr * 0.16, hr * 0.08, hr * (0.4 + 0.1 * stage)), rot=(0, side * math.radians(-18), 0), material=m_deep, verts=8)
            add(inner, bone)
        flame_h = [0.22, 0.32, 0.44][stage] * s
        flame = blob("flame", [((0, 0.02, hz + hr * 1.0 + flame_h * 0.3), flame_h * 0.6, (0.7, 0.7, 1.2)), ((0.02, 0.0, hz + hr * 1.0 + flame_h * 0.9), flame_h * 0.35, (0.6, 0.6, 1.3))], m_acc, resolution=0.025, target_tris=300)
        add(flame, "Head")
        tail = blob("tail", [((0, bh * 0.8, bh * 0.5 + b.leg), bh * 0.3, (0.6, 1.3, 0.6)), ((0, bh * 1.2, bh * 0.8 + b.leg), bh * (0.22 + 0.08 * stage), (0.7, 0.7, 1.0))], m_main, resolution=0.03, target_tris=300)
        add(tail, "Tail")
        tip = blob("tailflame", [((0, bh * 1.25, bh * 1.05 + b.leg), bh * (0.2 + 0.1 * stage), (0.8, 0.8, 1.3))], m_acc, resolution=0.025, target_tris=200)
        add(tip, "Tail")
        if stage >= 2:
            mane = blob("flamemane", [((math.cos(a) * hr * 0.95, math.sin(a) * hr * 0.4 + 0.06, hz - hr * 0.2), hr * 0.3, (0.6, 0.6, 1.0)) for a in (0.4, 1.2, 1.9, 2.7)], m_acc, resolution=0.03, target_tris=400)
            add(mane, "Head")
            crest = prim("cone", "crest", (0, -hr * 0.5, hz + hr * 0.85), (hr * 0.12, hr * 0.06, hr * 0.3), material=m_deep, verts=6)
            add(crest, "Head")
    return parts, bones, b


def make_rig(b: Body):
    data = bpy.data.armatures.new("RigData")
    arm = bpy.data.objects.new("Rig", data)
    bpy.context.scene.collection.objects.link(arm)
    activate(arm)
    bpy.ops.object.mode_set(mode="EDIT")
    s, hz, hr, bh, leg = b.s, b.head_z, b.head_r, b.body_h, b.leg

    def bone(name, head, tail, parent=None):
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = Vector(head), Vector(tail)
        if parent:
            eb.parent = data.edit_bones[parent]
        return eb

    bone("Root", (0, 0, 0), (0, 0, leg + 0.05))
    bone("Spine", (0, 0, leg + bh * 0.2), (0, 0, leg + bh), "Root")
    bone("Head", (0, 0, hz - hr * 0.6 + leg * 0.6), (0, 0, hz + hr + leg * 0.6), "Spine")
    bone("Ear_L", (hr * 0.5, 0, hz + hr * 0.6), (hr * 0.65, 0, hz + hr * 1.4), "Head")
    bone("Ear_R", (-hr * 0.5, 0, hz + hr * 0.6), (-hr * 0.65, 0, hz + hr * 1.4), "Head")
    bone("Arm_L", (bh * 0.7, -0.03, leg + bh * 0.8), (bh * 1.05, -0.05, leg + bh * 0.3), "Spine")
    bone("Arm_R", (-bh * 0.7, -0.03, leg + bh * 0.8), (-bh * 1.05, -0.05, leg + bh * 0.3), "Spine")
    bone("Foot_L", (bh * 0.42, 0, leg + bh * 0.15), (bh * 0.42, -0.08, 0.0), "Root")
    bone("Foot_R", (-bh * 0.42, 0, leg + bh * 0.15), (-bh * 0.42, -0.08, 0.0), "Root")
    bone("Tail", (0, bh * 0.5, leg + bh * 0.4), (0, bh * 1.3, leg + bh * 0.7), "Spine")
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


def seg_dist(p: Vector, a: Vector, b: Vector) -> float:
    ab = b - a
    t = max(0.0, min(1.0, (p - a).dot(ab) / max(ab.length_squared, 1e-9)))
    return (p - (a + ab * t)).length


def weight_parts(parts, bones, arm) -> None:
    """Deterministic skinning: feature parts follow one bone; the core blends the
    nearest two body bones by inverse distance (smooth, no heat-solver failures)."""
    segs = {pb.name: (arm.data.bones[pb.name].head_local.copy(), arm.data.bones[pb.name].tail_local.copy()) for pb in arm.pose.bones}
    body_bones = ["Root", "Spine", "Head", "Tail", "Arm_L", "Arm_R", "Foot_L", "Foot_R"]
    for obj, bone in zip(parts, bones):
        for name in BONES:
            obj.vertex_groups.new(name=name)
        for v in obj.data.vertices:
            co = obj.matrix_world @ v.co
            if bone != "auto":
                obj.vertex_groups[bone].add([v.index], 1.0, "REPLACE")
                continue
            ds = sorted(((seg_dist(co, *segs[n]), n) for n in body_bones))[:2]
            w = [1.0 / (d ** 4 + 1e-5) for d, _ in ds]
            total = sum(w)
            for (d, n), wi in zip(ds, w):
                obj.vertex_groups[n].add([v.index], wi / total, "REPLACE")


# ---- Animation -----------------------------------------------------------------------


def key(arm, frame: int, pose: dict) -> None:
    for name in BONES:
        pb = arm.pose.bones[name]
        loc, rot, scl = pose.get(name, ((0, 0, 0), (0, 0, 0), (1, 1, 1)))
        pb.location = loc
        pb.rotation_euler = [math.radians(r) for r in rot]
        pb.scale = scl
        pb.keyframe_insert("location", frame=frame)
        pb.keyframe_insert("rotation_euler", frame=frame)
        pb.keyframe_insert("scale", frame=frame)


def P(**bones):
    """P(Head=((loc),(rot deg),(scale))) with shorthand: a 3-tuple means rotation only."""
    out = {}
    for name, v in bones.items():
        if len(v) == 3 and not isinstance(v[0], tuple):
            out[name] = ((0, 0, 0), v, (1, 1, 1))
        else:
            loc, rot, *scl = v
            out[name] = (loc, rot, scl[0] if scl else (1, 1, 1))
    return out


def clip(arm, name: str, frames: dict[int, dict], length: int) -> None:
    if arm.animation_data is None:
        arm.animation_data_create()
    action = bpy.data.actions.new(name)
    arm.animation_data.action = action
    for f, pose in frames.items():
        key(arm, f, pose)
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, 1, action)
    strip.action_frame_start = 1
    strip.action_frame_end = length
    action.use_fake_user = True
    arm.animation_data.action = None


def animate(arm, b: Body, species: str) -> None:
    u = b.body_h  # unit for translations
    sway = 6 if species != "marrow" else 4
    clip(arm, "Idle", {
        1: P(Spine=((0, 0, 0), (0, 0, 0), (1.02, 1.02, 0.97)), Head=(0, 0, 2), Tail=(0, 0, 12), Ear_L=(0, 0, 0), Ear_R=(0, 0, 0)),
        13: P(Spine=((0, 0, 0), (0, 0, 0), (0.99, 0.99, 1.02)), Head=(3, 0, -2), Tail=(0, 0, -12), Ear_L=(0, 6, 0), Ear_R=(0, -6, 0)),
        25: P(Spine=((0, 0, 0), (0, 0, 0), (1.02, 1.02, 0.97)), Head=(0, 0, 2), Tail=(0, 0, 12)),
        37: P(Spine=((0, 0, 0), (0, 0, 0), (0.99, 0.99, 1.02)), Head=(-2, 0, 3), Tail=(0, 0, -12), Ear_L=(0, -4, 0), Ear_R=(0, 4, 0)),
        48: P(Spine=((0, 0, 0), (0, 0, 0), (1.02, 1.02, 0.97)), Head=(0, 0, 2), Tail=(0, 0, 12)),
    }, 48)
    step = u * 0.35

    def walk(name, n, lift, swing, bob):
        h = n // 2
        clip(arm, name, {
            1: P(Root=((0, 0, 0), (0, 0, sway), (1, 1, 1)), Foot_L=((0, -step, 0), (-swing, 0, 0)), Foot_R=((0, step, lift), (swing, 0, 0)),
                 Arm_L=(swing, 0, 0), Arm_R=(-swing, 0, 0), Head=(4, 0, -sway / 2), Tail=(0, 0, 18)),
            h // 2 + 1: P(Root=((0, 0, bob), (0, 0, 0), (1, 1, 1)), Head=(2, 0, 0)),
            h + 1: P(Root=((0, 0, 0), (0, 0, -sway), (1, 1, 1)), Foot_L=((0, step, lift), (swing, 0, 0)), Foot_R=((0, -step, 0), (-swing, 0, 0)),
                     Arm_L=(-swing, 0, 0), Arm_R=(swing, 0, 0), Head=(4, 0, sway / 2), Tail=(0, 0, -18)),
            h + h // 2 + 1: P(Root=((0, 0, bob), (0, 0, 0), (1, 1, 1)), Head=(2, 0, 0)),
            n: P(Root=((0, 0, 0), (0, 0, sway), (1, 1, 1)), Foot_L=((0, -step, 0), (-swing, 0, 0)), Foot_R=((0, step, lift), (swing, 0, 0)),
                 Arm_L=(swing, 0, 0), Arm_R=(-swing, 0, 0), Head=(4, 0, -sway / 2), Tail=(0, 0, 18)),
        }, n)

    walk("Walk", 20, u * 0.18, 22, u * 0.08)
    walk("Run", 12, u * 0.3, 34, u * 0.16)
    clip(arm, "Happy_Hop", {
        1: P(Root=((0, 0, 0), (0, 0, 0), (1.12, 1.12, 0.82))),
        5: P(Root=((0, 0, u * 0.7), (0, 0, 0), (0.92, 0.92, 1.12)), Arm_L=(0, -60, 70), Arm_R=(0, 60, -70), Ear_L=(0, 20, 0), Ear_R=(0, -20, 0), Tail=(30, 0, 0), Head=(-10, 0, 0)),
        10: P(Root=((0, 0, u * 0.95), (0, 0, 0), (1, 1, 1)), Arm_L=(0, -70, 80), Arm_R=(0, 70, -80), Head=(-12, 0, 0)),
        15: P(Root=((0, 0, u * 0.2), (0, 0, 0), (0.96, 0.96, 1.06))),
        18: P(Root=((0, 0, 0), (0, 0, 0), (1.15, 1.15, 0.8))),
        24: P(Root=((0, 0, 0), (0, 0, 0), (1, 1, 1))),
    }, 24)
    clip(arm, "Eat", {
        1: P(Head=(0, 0, 0)),
        6: P(Spine=(18, 0, 0), Head=(26, 0, 0), Tail=(0, 0, 20)),
        10: P(Spine=(14, 0, 0), Head=(18, 0, 4), Tail=(0, 0, -20)),
        14: P(Spine=(18, 0, 0), Head=(28, 0, -4), Tail=(0, 0, 20)),
        18: P(Spine=(14, 0, 0), Head=(18, 0, 4), Tail=(0, 0, -20)),
        24: P(Head=(0, 0, 0)),
    }, 24)
    clip(arm, "Pet_Enjoy", {
        1: P(Head=(0, 0, 0)),
        10: P(Head=(-8, 14, 10), Spine=((0, 0, 0), (0, 0, 0), (1.05, 1.05, 0.95)), Ear_L=(0, -15, 0), Ear_R=(0, 15, 0), Tail=(0, 0, 25)),
        20: P(Head=(-8, -14, -10), Spine=((0, 0, 0), (0, 0, 0), (1.05, 1.05, 0.95)), Ear_L=(0, -15, 0), Ear_R=(0, 15, 0), Tail=(0, 0, -25)),
        30: P(Head=(-8, 14, 10), Spine=((0, 0, 0), (0, 0, 0), (1.05, 1.05, 0.95)), Tail=(0, 0, 25)),
        36: P(Head=(0, 0, 0)),
    }, 36)
    clip(arm, "Refuse", {
        1: P(Head=(0, 0, 0)),
        5: P(Head=(6, 0, 30), Spine=(0, 0, -10), Arm_L=(0, 0, 20), Arm_R=(0, 0, -20), Ear_L=(0, 0, -30), Ear_R=(0, 0, 30)),
        10: P(Head=(6, 0, -30), Spine=(0, 0, 10)),
        15: P(Head=(6, 0, 30), Spine=(0, 0, -10)),
        24: P(Head=(0, 0, 0)),
    }, 24)
    clip(arm, "Sleep", {
        1: P(Root=((0, 0, -u * 0.3), (0, 0, 0), (1.1, 1.1, 0.8)), Head=(30, 0, 18), Ear_L=(0, 0, -40), Ear_R=(0, 0, 40), Tail=(0, 0, 70), Arm_L=(20, 0, -30), Arm_R=(20, 0, 30)),
        24: P(Root=((0, 0, -u * 0.32), (0, 0, 0), (1.14, 1.14, 0.76)), Head=(32, 0, 18), Ear_L=(0, 0, -42), Ear_R=(0, 0, 42), Tail=(0, 0, 70), Arm_L=(20, 0, -30), Arm_R=(20, 0, 30)),
        48: P(Root=((0, 0, -u * 0.3), (0, 0, 0), (1.1, 1.1, 0.8)), Head=(30, 0, 18), Ear_L=(0, 0, -40), Ear_R=(0, 0, 40), Tail=(0, 0, 70), Arm_L=(20, 0, -30), Arm_R=(20, 0, 30)),
    }, 48)
    clip(arm, "Attack", {
        1: P(Root=((0, 0, 0), (0, 0, 0), (1, 1, 1))),
        6: P(Root=((0, u * 0.4, 0), (-12, 0, 0), (1.1, 1.1, 0.85)), Head=(-15, 0, 0), Arm_L=(-60, 0, 0), Arm_R=(-60, 0, 0)),
        10: P(Root=((0, -u * 0.9, u * 0.25), (18, 0, 0), (0.9, 0.9, 1.15)), Head=(12, 0, 0), Arm_L=(80, 0, 0), Arm_R=(80, 0, 0), Tail=(40, 0, 0)),
        16: P(Root=((0, -u * 0.3, 0), (6, 0, 0), (1.05, 1.05, 0.95))),
        24: P(Root=((0, 0, 0), (0, 0, 0), (1, 1, 1))),
    }, 24)
    clip(arm, "Hit", {
        1: P(Root=((0, 0, 0), (0, 0, 0), (1, 1, 1))),
        4: P(Root=((0, u * 0.35, 0), (-20, 0, 8), (1.15, 1.15, 0.8)), Head=(-25, 0, 10), Ear_L=(0, 30, 0), Ear_R=(0, -30, 0)),
        10: P(Root=((0, u * 0.15, 0), (-8, 0, -4), (0.95, 0.95, 1.05)), Head=(-8, 0, -6)),
        18: P(Root=((0, 0, 0), (0, 0, 0), (1, 1, 1))),
    }, 18)


def build_creature(species: str, stage: int) -> Path:
    reset()
    parts, bones, b = creature_parts(species, stage)
    arm = make_rig(b)
    weight_parts(parts, bones, arm)
    mesh = join(parts, f"{species}_{stage}")
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mesh.parent = arm
    animate(arm, b, species)
    print(f"{species}_{stage}: {tri_count(mesh)} tris")
    out = MODELS / f"{species}_{stage}.glb"
    export(out, [arm, mesh], animations=True)
    return out


# --------------------------------------------------------------------------------------
# Environment kit
# --------------------------------------------------------------------------------------

BARK = (0.52, 0.36, 0.24)
LEAF = (0.36, 0.66, 0.34)
LEAF_LIGHT = (0.5, 0.78, 0.38)
PINE = (0.24, 0.5, 0.38)
BLOSSOM = (0.98, 0.72, 0.8)
CREAM = (0.97, 0.9, 0.78)
WOOD = (0.78, 0.56, 0.36)
DARK_WOOD = (0.48, 0.3, 0.2)
STONE = (0.72, 0.72, 0.7)


def tree(name: str, crown_rgb, crown_light, pine=False, seed=0) -> Path:
    reset()
    rnd = random.Random(seed)
    trunk = prim("cone", "trunk", (0, 0, 0.5), (0.16, 0.16, 1.0), material=mat("Bark", BARK), verts=8, top=0.6)
    roots = [prim("cone", "root", (math.cos(a) * 0.14, math.sin(a) * 0.14, 0.06), (0.08, 0.08, 0.14), rot=(math.radians(60) * math.sin(a), math.radians(60) * -math.cos(a), 0), material=mat("Bark", BARK), verts=6) for a in (0.3, 2.4, 4.4)]
    objs = [trunk] + roots
    if pine:
        for i in range(4):
            tier = prim("cone", "tier", (0, 0, 0.9 + i * 0.42), (0.75 - i * 0.15, 0.75 - i * 0.15, 0.7), rot=(0, 0, rnd.uniform(0, 1)), material=mat("Pine", tuple(c * (1 + i * 0.05) for c in PINE)), verts=9)
            objs.append(tier)
    else:
        clumps = [((0, 0, 1.45), 0.62, None)]
        for i in range(7):
            a = i / 7 * math.tau + rnd.uniform(-0.3, 0.3)
            r = rnd.uniform(0.35, 0.55)
            clumps.append(((math.cos(a) * r, math.sin(a) * r, 1.3 + rnd.uniform(-0.15, 0.3)), rnd.uniform(0.32, 0.45), None))
        objs.append(blob("crown", clumps, mat("Leaf", crown_rgb), resolution=0.06, target_tris=900))
        top = [((rnd.uniform(-0.15, 0.15), rnd.uniform(-0.15, 0.15), 1.85), 0.38, None), ((0.2, -0.2, 1.75), 0.26, None)]
        objs.append(blob("crown_top", top, mat("LeafLight", crown_light), resolution=0.05, target_tris=400))
    out = KIT / f"{name}.glb"
    export(out, [join(objs, name)], animations=False)
    return out


def box(name, loc, size, material, bev=0.03):
    o = prim("cube", name, loc, size, material=material, smooth=False)
    if bev > 0:
        bevel(o, bev, 2)
    return o


def gable_roof(w, d, h, rgb, overhang=0.35, thickness=0.12):
    """Two sloped slabs with overhang plus a ridge cap; ridge along X."""
    m = mat("Roof", rgb)
    half = d / 2 + overhang
    angle = math.atan2(h, half)
    slab_len = math.hypot(half, h)
    parts = []
    for side in (1, -1):
        slab = prim("cube", "slab", (0, side * half / 2, h / 2), (w + overhang * 2, slab_len, thickness), rot=(-side * angle, 0, 0), material=m, smooth=False)
        bevel(slab, 0.025, 2)
        parts.append(slab)
        # tile rows: thin raised strips for a hand-made look
        for i in range(1, 5):
            t = i / 5
            strip = prim("cube", "tiles", (0, side * half * (1 - t) * 0.98, h * t + thickness * 0.6), (w + overhang * 2, 0.05, 0.05), rot=(-side * angle, 0, 0), material=mat("RoofDark", tuple(c * 0.85 for c in rgb)), smooth=False)
            parts.append(strip)
    ridge = prim("cyl", "ridge", (0, 0, h + 0.02), (0.1, 0.1, w + overhang * 2), rot=(0, math.radians(90), 0), material=mat("RoofDark", tuple(c * 0.85 for c in rgb)), verts=8)
    parts.append(ridge)
    return parts


def building(kind: str, w: float, d: float, wall_h: float, wall_rgb, roof_rgb, door_x: float) -> Path:
    reset()
    objs = []
    # Stone footing, walls, timber frame.
    objs.append(box("footing", (0, 0, 0.12), (w + 0.12, d + 0.12, 0.24), mat("Stone", STONE), 0.04))
    objs.append(box("walls", (0, 0, 0.24 + wall_h / 2), (w, d, wall_h), mat("Wall", wall_rgb), 0.04))
    for x in (-w / 2, w / 2):
        for y in (-d / 2, d / 2):
            objs.append(box("beam", (x, y, 0.24 + wall_h / 2), (0.16, 0.16, wall_h + 0.04), mat("Timber", DARK_WOOD), 0.02))
    objs.append(box("band", (0, d / 2 + 0.01, 0.24 + wall_h * 0.98), (w + 0.1, 0.1, 0.14), mat("Timber", DARK_WOOD), 0.02))
    # Door on +Y (faces the camera in game).
    objs.append(box("doorframe", (door_x, d / 2 + 0.04, 0.24 + 0.68), (0.95, 0.1, 1.4), mat("Timber", DARK_WOOD), 0.03))
    objs.append(box("door", (door_x, d / 2 + 0.08, 0.24 + 0.62), (0.72, 0.06, 1.22), mat("Door", (0.62, 0.38, 0.24)), 0.02))
    objs.append(prim("sphere", "knob", (door_x + 0.24, d / 2 + 0.13, 0.84), (0.045,) * 3, material=mat("Brass", (0.95, 0.78, 0.35)), segs=8, rings=6))
    objs.append(box("step", (door_x, d / 2 + 0.4, 0.06), (1.1, 0.5, 0.12), mat("Stone", STONE), 0.03))
    # Windows: glass named "Window" so the game can light them at night.
    xs = [x for x in [-w / 2 + 0.9 + i * 1.5 for i in range(int(w // 1.5) + 1)] if abs(x - door_x) > 0.9 and x < w / 2 - 0.5]
    for x in xs:
        z = 0.24 + wall_h * 0.58
        objs.append(box("winframe", (x, d / 2 + 0.03, z), (0.72, 0.08, 0.66), mat("Trim", (1, 1, 1)), 0.02))
        objs.append(box("glass", (x, d / 2 + 0.06, z), (0.56, 0.04, 0.5), mat("Window", (0.55, 0.75, 0.9)), 0))
        objs.append(box("mullion", (x, d / 2 + 0.085, z), (0.04, 0.02, 0.5), mat("Trim", (1, 1, 1)), 0))
        objs.append(box("planter", (x, d / 2 + 0.18, z - 0.38), (0.7, 0.18, 0.14), mat("Timber", DARK_WOOD), 0.02))
        objs.append(blob("flowers", [((x + dx, d / 2 + 0.2, z - 0.28), 0.1, None) for dx in (-0.22, 0, 0.22)], mat("Flowers", BLOSSOM), resolution=0.03, target_tris=150))
        for side in (-1, 1):
            objs.append(box("shutter", (x + side * 0.48, d / 2 + 0.05, z), (0.22, 0.05, 0.64), mat("Shutter", tuple(c * 0.9 for c in roof_rgb)), 0.015))
    roof_h = wall_h * (0.75 if kind == "house" else 0.6)
    for part in gable_roof(w, d, roof_h, roof_rgb):
        part.location.z += 0.24 + wall_h
        objs.append(part)
    if kind == "house":
        objs.append(box("chimney", (w / 2 - 1.2, -0.5, 0.24 + wall_h + roof_h * 0.8), (0.5, 0.5, roof_h * 1.4), mat("Brick", (0.78, 0.5, 0.42)), 0.03))
        objs.append(box("chimcap", (w / 2 - 1.2, -0.5, 0.24 + wall_h + roof_h * 1.5), (0.62, 0.62, 0.1), mat("Stone", STONE), 0.02))
    else:
        for i, (x, y, z) in enumerate([(w / 2 + 0.35, d / 2 - 0.3, 0.25), (w / 2 + 0.35, d / 2 - 0.85, 0.25), (w / 2 + 0.35, d / 2 - 0.55, 0.75)]):
            objs.append(box("crate", (x, y, z), (0.5, 0.5, 0.5), mat("Crate", WOOD), 0.03))
    out = KIT / f"{kind}.glb"
    export(out, [join(objs, kind)], animations=False)
    return out


def pavilion(w: float, d: float) -> Path:
    reset()
    objs = [box("deck", (0, 0, 0.08), (w, d, 0.16), mat("Deck", (0.9, 0.84, 0.74)), 0.03)]
    for x in (-w / 2 + 0.25, w / 2 - 0.25):
        for y in (-d / 2 + 0.25, d / 2 - 0.25):
            objs.append(prim("cyl", "post", (x, y, 1.1), (0.11, 0.11, 2.0), material=mat("Post", WOOD), verts=10))
            objs.append(prim("torus", "postring", (x, y, 1.9), (0.14, 0.14, 0.14), material=mat("Gold", (0.95, 0.78, 0.35)), minor=0.3))
    for part in gable_roof(w, d, 1.0, (0.92, 0.7, 0.32), overhang=0.45):
        part.location.z += 2.05
        objs.append(part)
    # Bunting along the front edge.
    colors = [(0.95, 0.45, 0.45), (0.98, 0.85, 0.4), (0.45, 0.75, 0.95), (0.55, 0.85, 0.5)]
    for i in range(10):
        x = -w / 2 + 0.3 + i * (w - 0.6) / 9
        flag = prim("cone", "flag", (x, d / 2 + 0.3, 1.75 - 0.08 * math.sin(i / 9 * math.pi)), (0.12, 0.02, 0.18), rot=(math.radians(180), 0, 0), material=mat(f"Bunting{i % 4}", colors[i % 4]), verts=3, smooth=False)
        objs.append(flag)
    out = KIT / "pavilion.glb"
    export(out, [join(objs, "pavilion")], animations=False)
    return out


# --------------------------------------------------------------------------------------


def main(argv) -> int:
    which = argv[0] if argv else "all"
    written = []
    if which in ("all", "creatures"):
        for species in ("pipkin", "marrow", "solbit"):
            for stage in range(3):
                written.append(build_creature(species, stage))
    if which in ("all", "kit"):
        written.append(tree("tree_round", LEAF, LEAF_LIGHT, seed=1))
        written.append(tree("tree_blossom", BLOSSOM, (1.0, 0.86, 0.9), seed=2))
        written.append(tree("tree_pine", PINE, PINE, pine=True, seed=3))
        # Footprints match GlenMap.Buildings (rect minus 0.4 m margin); door columns relative to centre.
        written.append(building("house", 6.6, 4.6, 2.1, (0.97, 0.9, 0.78), (0.86, 0.33, 0.28), door_x=7.5 - 7.5))
        written.append(building("shed", 4.6, 3.6, 1.7, (0.8, 0.58, 0.36), (0.36, 0.5, 0.72), door_x=23.5 - 23.5))
        written.append(pavilion(5.6, 2.6))
    missing = [p for p in written if not p.exists()]
    if missing:
        print("MISSING", missing, file=sys.stderr)
        return 1
    print(f"KIT_READY ({len(written)} files)")
    return 0


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    sys.exit(main(args))
