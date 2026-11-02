"""Lumina Vale creatures v2: well-defined silhouettes instead of metaball blobs.

    blender --background --python tools/blender/creatures.py            # all 9
    blender --background --python tools/blender/creatures.py -- pipkin  # one line

Bodies are built as a vertex skeleton (spine, neck, legs, tail) run through Skin +
Subdivision modifiers, which gives one connected, organic mesh with real necks, knees and
tails. Heads, eyes and every species feature (leaves, antlers, gills, fins, flames, wings)
are crisp separate shapes. Rig landmarks come from the same skeleton, so bones line up.

Original designs (ids match SpeciesId in C#):
    pipkin  Bloom: Fawnlet -> Thicketfawn -> Grovestag
    marrow  Tide:  Axolet  -> Ripplemander -> Tidewyrm
    solbit  Ember: Cindercub -> Blazemane -> Solarion
Creatures face Blender -Y, feet at Z=0.
"""

from __future__ import annotations

import math
import sys
from pathlib import Path

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_kit as K  # noqa: E402  (helpers: reset, mat, prim, join, export, weight/animate)

INK = (0.09, 0.07, 0.12)
WHITE = (1, 1, 1)
BLUSH = (1.0, 0.6, 0.66)


# --------------------------------------------------------------------------------------
# Shape helpers
# --------------------------------------------------------------------------------------


def skin_body(name, verts, edges, material, subdiv=2, max_tris=5200):
    """verts: list of (co, (rx, ry)). Returns one smooth connected mesh."""
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([v[0] for v in verts], edges, [])
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    K.activate(obj)
    skin = obj.modifiers.new("skin", "SKIN")
    skin.use_smooth_shade = True
    for i, (_, r) in enumerate(verts):
        obj.data.skin_vertices[0].data[i].radius = r
    obj.data.skin_vertices[0].data[0].use_root = True
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = subdiv
    bpy.ops.object.modifier_apply(modifier=skin.name)
    bpy.ops.object.modifier_apply(modifier=sub.name)
    K.set_material(obj, material)
    t = K.tri_count(obj)
    if t > max_tris:
        K.decimate(obj, max_tris / t)
    K.smooth(obj)
    return obj


def leaf(name, length, width, loc, rot_deg, material, thickness=0.012, fold=0.25, tip=1.0, segs=10):
    """Pointed leaf / ear / fin / flame tongue lying in local XZ (+Z is the tip), with a
    folded midrib so it reads as a shape and not a disc."""
    verts, faces = [], []
    for i in range(segs + 1):
        t = i / segs
        w = math.sin(math.pi * t ** 0.85) * width * (1 - t * (1 - tip) * 0.5)
        z = t * length
        verts += [(-w, abs(w) * fold, z), (0, 0, z), (w, abs(w) * fold, z)]
    for i in range(segs):
        a = i * 3
        faces += [(a, a + 1, a + 4, a + 3), (a + 1, a + 2, a + 5, a + 4)]
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.scene.collection.objects.link(obj)
    K.activate(obj)
    sol = obj.modifiers.new("sol", "SOLIDIFY")
    sol.thickness = thickness
    sol.offset = 0
    sub = obj.modifiers.new("sub", "SUBSURF")
    sub.levels = 1
    bpy.ops.object.modifier_apply(modifier=sol.name)
    bpy.ops.object.modifier_apply(modifier=sub.name)
    obj.rotation_euler = Euler([math.radians(a) for a in rot_deg], "XYZ")
    obj.location = Vector(loc)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    K.set_material(obj, material)
    K.smooth(obj)
    return obj


def flame(name, height, width, loc, rot_deg, outer, inner):
    """Two-layer flame tongue: orange outer, yellow core slightly in front."""
    a = leaf(name, height, width, loc, rot_deg, outer, thickness=0.03, fold=0.6, tip=0.2)
    off = Euler([math.radians(r) for r in rot_deg], "XYZ").to_matrix() @ Vector((0, -0.012, 0))
    b = leaf(name + "_core", height * 0.62, width * 0.55, Vector(loc) + off, rot_deg, inner, thickness=0.03, fold=0.6, tip=0.2)
    return [a, b]


def branch(name, points, radius, material):
    """Thin skinned branch (antlers, horn): points is a chain, can fork via (parent_idx, co)."""
    verts = [(points[0][1], (radius, radius))]
    edges = []
    for parent, co in points[1:]:
        verts.append((co, (radius * 0.8, radius * 0.8)))
        edges.append((parent, len(verts) - 1))
    return skin_body(name, verts, edges, material, subdiv=1, max_tris=900)


class Built:
    """Parts + bone assignment + rig landmarks for one creature."""

    def __init__(self):
        self.parts, self.bones = [], []
        self.lm = {}
        self.unit = 0.3

    def add(self, objs, bone="auto"):
        for o in objs if isinstance(objs, (list, tuple)) else [objs]:
            self.parts.append(o)
            self.bones.append(bone)


def face(b: Built, head_c: Vector, head_r: Vector, palette, eye_scale=1.0, eye_color=(0.2, 0.55, 0.35), muzzle=None, smile=False):
    """Big readable eyes with coloured iris + two highlights, nose, cheeks."""
    m_ink, m_white, m_iris, m_blush = K.mat("Ink", INK), K.mat("Shine", WHITE), K.mat("Iris", eye_color), K.mat("Blush", BLUSH)
    front = head_c.y - head_r.y * 0.86
    ex, ez = head_r.x * 0.46, head_c.z + head_r.z * 0.12
    er = min(head_r.x, head_r.z) * 0.24 * eye_scale
    for side in (1, -1):
        x = side * ex
        y = front + abs(x) / head_r.x * head_r.y * 0.22
        b.add(K.prim("sphere", "eye", (x, y, ez), (er * 0.78, er * 0.35, er), material=m_ink, segs=16, rings=10), "Head")
        b.add(K.prim("sphere", "iris", (x, y - er * 0.2, ez - er * 0.12), (er * 0.5, er * 0.2, er * 0.62), material=m_iris, segs=12, rings=8), "Head")
        b.add(K.prim("sphere", "shine", (x + side * er * 0.25, y - er * 0.36, ez + er * 0.42), (er * 0.26,) * 3, material=m_white, segs=8, rings=6), "Head")
        b.add(K.prim("sphere", "shine2", (x - side * er * 0.2, y - er * 0.34, ez - er * 0.4), (er * 0.12,) * 3, material=m_white, segs=6, rings=4), "Head")
        b.add(K.prim("sphere", "cheek", (side * head_r.x * 0.7, front + head_r.y * 0.25, ez - er * 1.25), (er * 0.5, er * 0.15, er * 0.3), material=m_blush, segs=10, rings=6), "Head")
    if muzzle:
        mc, mr, mm = muzzle
        b.add(K.prim("sphere", "muzzle", mc, mr, material=mm, segs=18, rings=12), "Head")
        nose_y = mc[1] - mr[1] * 0.92
        b.add(K.prim("sphere", "nose", (0, nose_y, mc[2] + mr[2] * 0.45), (mr[0] * 0.28, mr[1] * 0.16, mr[2] * 0.22), material=m_ink, segs=10, rings=6), "Head")
    if smile:
        b.add(K.prim("torus", "smile", (0, front - 0.004, ez - er * 1.6), (head_r.x * 0.32, 0.02, head_r.z * 0.12), rot=(math.radians(90), 0, 0), material=m_ink, minor=0.12, maj=24), "Head")


# --------------------------------------------------------------------------------------
# Body plans
# --------------------------------------------------------------------------------------


def quadruped(b: Built, name, m_main, s, body_len, leg_h, chest_r, hip_r, neck_len, neck_tilt, tail, leg_r=None, chubby=1.0):
    """Generic four-legged skeleton. Returns (chest, neck_top) for attaching the head."""
    leg_r = leg_r or chest_r * 0.36
    hip = Vector((0, body_len / 2, leg_h + hip_r * 0.4))
    chest = Vector((0, -body_len / 2, leg_h + chest_r * 0.5))
    mid = (hip + chest) / 2 + Vector((0, 0, 0.01))
    neck_top = chest + Vector((0, -math.sin(neck_tilt) * neck_len, math.cos(neck_tilt) * neck_len))
    verts = [
        (hip, (hip_r * chubby, hip_r * 0.95)),           # 0 root
        (mid, (chest_r * 0.95 * chubby, chest_r * 0.9)),  # 1
        (chest, (chest_r * chubby, chest_r)),            # 2
        (neck_top, (chest_r * 0.55, chest_r * 0.55)),    # 3
    ]
    edges = [(0, 1), (1, 2), (2, 3)]
    legs = {}
    for side, (anchor_i, anchor, name_front) in [(1, (2, chest, True)), (-1, (2, chest, True)), (1, (0, hip, False)), (-1, (0, hip, False))]:
        x = side * (chest_r if name_front else hip_r) * 0.62
        top = Vector((x, anchor.y, anchor.z - 0.02))
        knee = Vector((x * 1.05, anchor.y + (0.02 if name_front else -0.03) * s, leg_h * 0.5))
        foot = Vector((x * 1.05, anchor.y - 0.03 * s, leg_r * 0.6))
        i0 = len(verts)
        verts += [(top, (leg_r * 1.2, leg_r * 1.2)), (knee, (leg_r, leg_r)), (foot, (leg_r * 1.1, leg_r * 1.25))]
        edges += [(anchor_i, i0), (i0, i0 + 1), (i0 + 1, i0 + 2)]
        legs[(name_front, side)] = (top, foot)
    t0 = hip + Vector((0, hip_r * 0.6, hip_r * 0.1))
    last = 0
    for i, (dy, dz, r) in enumerate(tail):
        p = t0 + Vector((0, dy * s, dz * s))
        verts.append((p, (r * s, r * s)))
        edges.append((last, len(verts) - 1))
        last = len(verts) - 1
    tail_end = verts[last][0]
    b.add(skin_body(name, verts, edges, m_main), "auto")
    b.lm.update(root=(Vector((0, 0, 0)), hip), spine=(hip, chest), tail=(t0, tail_end),
                arm_l=legs[(True, 1)], arm_r=legs[(True, -1)], foot_l=legs[(False, 1)], foot_r=legs[(False, -1)])
    b.unit = leg_h + chest_r
    return chest, neck_top


def biped_chibi(b: Built, name, m_main, s, body_h, body_r, leg_len, arm_len, tail):
    """Upright baby body: short legs, stubby arms, pear torso."""
    pelvis = Vector((0, 0.02 * s, leg_len + body_r * 0.6))
    chest = Vector((0, -0.01 * s, pelvis.z + body_h))
    verts = [(pelvis, (body_r, body_r * 0.95)), (chest, (body_r * 0.8, body_r * 0.75))]
    edges = [(0, 1)]
    for side in (1, -1):
        hip = Vector((side * body_r * 0.5, pelvis.y, pelvis.z - body_r * 0.4))
        foot = Vector((side * body_r * 0.55, pelvis.y - 0.03 * s, body_r * 0.22))
        i = len(verts)
        verts += [(hip, (body_r * 0.32, body_r * 0.32)), (foot, (body_r * 0.32, body_r * 0.42))]
        edges += [(0, i), (i, i + 1)]
        b.lm["foot_l" if side > 0 else "foot_r"] = (hip, foot)
        sh = Vector((side * body_r * 0.72, chest.y, chest.z - body_r * 0.15))
        hand = sh + Vector((side * arm_len * 0.55, -arm_len * 0.35, -arm_len * 0.6))
        i = len(verts)
        verts += [(sh, (body_r * 0.22, body_r * 0.22)), (hand, (body_r * 0.2, body_r * 0.2))]
        edges += [(1, i), (i, i + 1)]
        b.lm["arm_l" if side > 0 else "arm_r"] = (sh, hand)
    t0 = pelvis + Vector((0, body_r * 0.8, -body_r * 0.2))
    last = 0
    for dy, dz, r in tail:
        verts.append((t0 + Vector((0, dy * s, dz * s)), (r * s, r * s)))
        edges.append((last, len(verts) - 1))
        last = len(verts) - 1
    b.add(skin_body(name, verts, edges, m_main), "auto")
    b.lm.update(root=(Vector((0, 0, 0)), pelvis), spine=(pelvis, chest), tail=(t0, verts[last][0]))
    b.unit = pelvis.z + body_h * 0.5
    return chest


def head(b: Built, center, radii, material):
    center, radii = Vector(center), Vector(radii)
    b.add(K.prim("sphere", "head", center, radii, material=material, segs=28, rings=18), "Head")
    b.lm["head"] = (center - Vector((0, 0, radii[2] * 0.8)), center + Vector((0, 0, radii[2] * 1.1)))
    return Vector(center), Vector(radii)


# --------------------------------------------------------------------------------------
# Species
# --------------------------------------------------------------------------------------


def bloom(stage: int) -> Built:
    b = Built()
    m_coat, m_cream, m_leaf, m_leaf_dark = K.mat("FawnCoat", (0.84, 0.62, 0.42)), K.mat("FawnCream", (1.0, 0.94, 0.82)), K.mat("Leaf", (0.42, 0.76, 0.36)), K.mat("LeafDark", (0.28, 0.58, 0.3))
    m_bloom, m_bark, m_hoof = K.mat("Blossom", (0.98, 0.66, 0.78)), K.mat("Antler", (0.62, 0.46, 0.32)), K.mat("Hoof", (0.36, 0.26, 0.22))
    s = [0.8, 1.0, 1.25][stage]
    if stage == 0:
        chest, neck = quadruped(b, "body", m_coat, s, 0.22, 0.12, 0.13, 0.13, 0.08, 0.3, [(0.06, 0.06, 0.05)], chubby=1.1)
        hc, hr = head(b, (0, chest.y - 0.05, neck.z + 0.13), (0.17, 0.16, 0.16), m_coat)
    elif stage == 1:
        chest, neck = quadruped(b, "body", m_coat, s, 0.38, 0.3, 0.13, 0.12, 0.18, 0.35, [(0.06, 0.07, 0.05)])
        hc, hr = head(b, (0, neck.y - 0.05, neck.z + 0.08), (0.13, 0.15, 0.12), m_coat)
    else:
        chest, neck = quadruped(b, "body", m_coat, s, 0.6, 0.55, 0.16, 0.15, 0.32, 0.3, [(0.07, 0.08, 0.06)], leg_r=0.045)
        hc, hr = head(b, (0, neck.y - 0.08, neck.z + 0.08), (0.12, 0.17, 0.12), m_coat)
    # Cream belly and spots.
    b.add(K.prim("sphere", "belly", (0, chest.y + 0.05, chest.z - 0.06 * s), (0.1 * s, 0.16 * s, 0.07 * s), material=m_cream), "Spine")
    for i, (x, y) in enumerate([(0.06, 0.0), (-0.07, 0.06), (0.05, 0.1), (-0.04, -0.06)]):
        b.add(K.prim("sphere", "spot", (x * s, chest.y + 0.1 * s + y * s, chest.z + 0.1 * s), (0.025 * s, 0.025 * s, 0.012 * s), material=m_cream, segs=10, rings=6), "Spine")
    face(b, hc, hr, None, eye_scale=1.15 if stage == 0 else 1.0, eye_color=(0.36, 0.24, 0.14),
         muzzle=((0, hc.y - hr.y * 0.8, hc.z - hr.z * 0.35), (hr.x * 0.5, hr.y * 0.4, hr.z * 0.38), m_cream))
    # Leaf ears.
    ear_len = [0.17, 0.2, 0.2][stage] * s
    for side, bone in ((1, "Ear_L"), (-1, "Ear_R")):
        b.add(leaf("ear", ear_len, ear_len * 0.32, (side * hr.x * 0.75, hc.y + 0.01, hc.z + hr.z * 0.35), (0, side * 62, 0), m_leaf), bone)
        b.lm["ear_l" if side > 0 else "ear_r"] = (Vector((side * hr.x * 0.7, hc.y, hc.z + hr.z * 0.35)), Vector((side * (hr.x + ear_len), hc.y, hc.z + hr.z * 0.8)))
    if stage == 0:
        b.add(branch("sprout", [(None, (0, hc.y, hc.z + hr.z * 0.9)), (0, (0.01, hc.y, hc.z + hr.z * 1.3))], 0.012, m_leaf_dark), "Head")
        for side in (1, -1):
            b.add(leaf("sproutleaf", 0.09, 0.035, (0.01, hc.y, hc.z + hr.z * 1.25), (0, side * 70, 0), m_leaf), "Head")
    if stage >= 1:
        # Leaf mane down the neck.
        for i in range(5):
            t = i / 4
            p = hc.lerp(chest, t)
            b.add(leaf("mane", 0.1 * s, 0.035 * s, (0, p.y + 0.06 * s, p.z + 0.06 * s), (-20 - t * 30, 0, (-1) ** i * 12), m_leaf_dark), "Head" if t < 0.5 else "Spine")
        b.add(leaf("tailleaf", 0.14 * s, 0.05 * s, (0, b.lm["tail"][1].y, b.lm["tail"][1].z), (-60, 0, 0), m_leaf), "Tail")
    if stage == 1:
        for side in (1, -1):
            base = Vector((side * hr.x * 0.4, hc.y, hc.z + hr.z * 0.85))
            b.add(branch("bud", [(None, base), (0, base + Vector((side * 0.02, 0, 0.06)))], 0.016, m_bark), "Head")
            b.add(leaf("budleaf", 0.07, 0.03, base + Vector((side * 0.02, 0, 0.06)), (0, side * 40, 0), m_leaf), "Head")
    if stage == 2:
        for side in (1, -1):
            base = Vector((side * hr.x * 0.45, hc.y + 0.02, hc.z + hr.z * 0.8))
            pts = [(None, base), (0, base + Vector((side * 0.06, 0.02, 0.14))), (1, base + Vector((side * 0.16, 0.05, 0.26))),
                   (1, base + Vector((side * 0.02, -0.04, 0.27))), (2, base + Vector((side * 0.2, 0.0, 0.38))), (2, base + Vector((side * 0.27, 0.08, 0.31)))]
            b.add(branch("antler", pts, 0.02, m_bark), "Head")
            for tip in (pts[3][1], pts[4][1], pts[5][1]):
                b.add(K.prim("ico", "blossom", tip, (0.035,) * 3, material=m_bloom, subdiv=1), "Head")
                b.add(leaf("antlerleaf", 0.07, 0.025, tip, (30, side * 50, 0), m_leaf), "Head")
        for key in ("arm_l", "arm_r", "foot_l", "foot_r"):
            foot = b.lm[key][1]
            b.add(K.prim("cyl", "hoof", (foot.x, foot.y, 0.025), (0.05, 0.05, 0.05), material=m_hoof, verts=12), key.replace("arm_l", "Arm_L").replace("arm_r", "Arm_R").replace("foot_l", "Foot_L").replace("foot_r", "Foot_R"))
    return b


def tide(stage: int) -> Built:
    b = Built()
    m_skin, m_belly, m_gill, m_fin = K.mat("TideSkin", (0.42, 0.7, 0.95)), K.mat("TideBelly", (0.86, 0.96, 1.0)), K.mat("Gill", (1.0, 0.56, 0.68)), K.mat("Fin", (0.64, 0.86, 1.0))
    m_spots, m_pearl = K.mat("TideSpot", (0.26, 0.46, 0.82)), K.mat("Pearl", (1.0, 0.97, 0.9))
    s = [0.8, 1.0, 1.2][stage]
    if stage == 0:
        chest = biped_chibi(b, "body", m_skin, s, 0.12, 0.14, 0.06, 0.1, [(0.1, -0.02, 0.07), (0.2, 0.0, 0.04)])
        hc, hr = head(b, (0, chest.y - 0.01, chest.z + 0.16), (0.22, 0.17, 0.15), m_skin)
    elif stage == 1:
        chest, neck = quadruped(b, "body", m_skin, s, 0.42, 0.12, 0.12, 0.12, 0.06, 0.6, [(0.12, 0.0, 0.08), (0.24, 0.02, 0.05), (0.34, 0.03, 0.03)], leg_r=0.04)
        hc, hr = head(b, (0, chest.y - 0.12, chest.z + 0.1), (0.17, 0.15, 0.12), m_skin)
    else:
        chest, neck = quadruped(b, "body", m_skin, s, 0.7, 0.2, 0.15, 0.13, 0.2, 0.45, [(0.15, 0.02, 0.1), (0.3, 0.06, 0.07), (0.45, 0.1, 0.05), (0.58, 0.16, 0.03)], leg_r=0.045)
        hc, hr = head(b, (0, neck.y - 0.08, neck.z + 0.06), (0.16, 0.17, 0.12), m_skin)
    b.add(K.prim("sphere", "belly", (0, chest.y - 0.02, chest.z - 0.05 * s), (0.11 * s, 0.13 * s, 0.09 * s), material=m_belly), "Spine")
    face(b, hc, hr, None, eye_scale=1.1, eye_color=(0.12, 0.3, 0.6), smile=True)
    # Frilly gills: three fronds per side, longer each stage.
    g = [0.09, 0.13, 0.18][stage] * s
    for side, bone in ((1, "Ear_L"), (-1, "Ear_R")):
        for i, ang in enumerate((25, 0, -25)):
            base = (side * hr.x * 0.9, hc.y + 0.02, hc.z + hr.z * 0.15 + i * 0.03 - 0.03)
            b.add(leaf("gill", g * (1.0 - abs(i - 1) * 0.15), g * 0.28, base, (ang, side * 78, 0), m_gill, fold=0.5), bone)
        b.lm["ear_l" if side > 0 else "ear_r"] = (Vector((side * hr.x * 0.8, hc.y, hc.z)), Vector((side * (hr.x + g), hc.y, hc.z + 0.04)))
    tail_end = b.lm["tail"][1]
    b.add(leaf("tailfin", 0.12 * s + stage * 0.06, 0.06 * s + stage * 0.02, (0, tail_end.y - 0.06, tail_end.z - 0.04), (-80, 0, 0), m_fin, thickness=0.01, fold=0.1), "Tail")
    for i in range(3 + stage * 2):
        t = i / (2 + stage * 2)
        p = b.lm["spine"][1].lerp(tail_end, t)
        b.add(K.prim("sphere", "spot", (((-1) ** i) * 0.05 * s, p.y, p.z + 0.08 * s), (0.02 * s, 0.02 * s, 0.01 * s), material=m_spots, segs=8, rings=5), "Spine")
    if stage >= 1:
        n = 4 if stage == 1 else 7
        for i in range(n):
            t = i / (n - 1)
            p = b.lm["spine"][1].lerp(tail_end, t * 0.85)
            h = (0.06 + 0.05 * math.sin(math.pi * t) * stage) * s
            b.add(leaf("dorsal", h, h * 0.45, (0, p.y, p.z + 0.07 * s), (-12, 0, 0), m_fin, thickness=0.01, fold=0.1), "Spine" if t < 0.5 else "Tail")
    if stage == 2:
        b.add(K.prim("sphere", "pearl", (0, hc.y - hr.y * 0.65, hc.z + hr.z * 0.75), (0.035,) * 3, material=m_pearl, segs=14, rings=10), "Head")
        b.add(K.prim("torus", "pearlring", (0, hc.y - hr.y * 0.62, hc.z + hr.z * 0.75), (0.045, 0.045, 0.02), rot=(math.radians(80), 0, 0), material=m_gill, minor=0.25), "Head")
    return b


def ember(stage: int) -> Built:
    b = Built()
    m_fur, m_cream, m_flame, m_core, m_dark = K.mat("EmberFur", (0.98, 0.56, 0.26)), K.mat("EmberCream", (1.0, 0.9, 0.72)), K.mat("Flame", (1.0, 0.46, 0.12)), K.mat("FlameCore", (1.0, 0.86, 0.3)), K.mat("EmberDark", (0.72, 0.28, 0.16))
    s = [0.8, 1.0, 1.25][stage]
    if stage == 0:
        chest, neck = quadruped(b, "body", m_fur, s, 0.22, 0.1, 0.13, 0.13, 0.06, 0.2, [(0.08, 0.06, 0.035), (0.13, 0.13, 0.03)], chubby=1.1)
        hc, hr = head(b, (0, chest.y - 0.04, neck.z + 0.14), (0.18, 0.16, 0.16), m_fur)
    elif stage == 1:
        chest, neck = quadruped(b, "body", m_fur, s, 0.4, 0.26, 0.13, 0.12, 0.12, 0.25, [(0.1, 0.06, 0.035), (0.2, 0.16, 0.03), (0.26, 0.26, 0.03)])
        hc, hr = head(b, (0, neck.y - 0.04, neck.z + 0.09), (0.14, 0.14, 0.13), m_fur)
    else:
        chest, neck = quadruped(b, "body", m_fur, s, 0.55, 0.42, 0.17, 0.14, 0.16, 0.2, [(0.12, 0.06, 0.04), (0.24, 0.18, 0.035), (0.3, 0.32, 0.03)], leg_r=0.055)
        hc, hr = head(b, (0, neck.y - 0.05, neck.z + 0.09), (0.15, 0.15, 0.14), m_fur)
    b.add(K.prim("sphere", "chest", (0, chest.y - 0.06 * s, chest.z - 0.02), (0.09 * s, 0.07 * s, 0.1 * s), material=m_cream), "Spine")
    face(b, hc, hr, None, eye_scale=1.15 if stage == 0 else 1.0, eye_color=(0.75, 0.38, 0.1),
         muzzle=((0, hc.y - hr.y * 0.78, hc.z - hr.z * 0.3), (hr.x * 0.45, hr.y * 0.32, hr.z * 0.3), m_cream))
    # Round ears with dark inner.
    for side, bone in ((1, "Ear_L"), (-1, "Ear_R")):
        ec = (side * hr.x * 0.72, hc.y + 0.02, hc.z + hr.z * 0.75)
        b.add(K.prim("sphere", "ear", ec, (hr.x * 0.26, hr.x * 0.12, hr.x * 0.28), material=m_fur, segs=14, rings=8), bone)
        b.add(K.prim("sphere", "earin", (ec[0], ec[1] - 0.012, ec[2]), (hr.x * 0.16, hr.x * 0.06, hr.x * 0.18), material=m_dark, segs=12, rings=6), bone)
        b.lm["ear_l" if side > 0 else "ear_r"] = (Vector((ec[0], ec[1], ec[2] - 0.04)), Vector((ec[0], ec[1], ec[2] + 0.06)))
    tail_end = b.lm["tail"][1]
    b.add(flame("tailflame", (0.09 + 0.05 * stage) * s, (0.045 + 0.015 * stage) * s, tail_end, (0, 0, 0), m_flame, m_core), "Tail")
    if stage == 0:
        b.add(flame("tuft", 0.11, 0.05, (0, hc.y, hc.z + hr.z * 0.85), (-10, 0, 0), m_flame, m_core), "Head")
    else:
        # Flame mane: ring of tongues behind the head, fuller at stage 2.
        n = 8 if stage == 1 else 14
        for i in range(n):
            a = (i / n) * math.tau
            r = hr.x * (1.05 if stage == 1 else 1.15)
            p = (math.cos(a) * r, hc.y + 0.05, hc.z + math.sin(a) * r * 0.95)
            if stage == 1 and math.sin(a) < -0.3:
                continue
            ln = (0.1 if stage == 1 else 0.14) * s * (1.2 if math.sin(a) > 0.5 else 1.0)
            b.add(flame("mane", ln, ln * 0.45, p, (-15, -math.degrees(a) + 90, 0), m_flame, m_core), "Head")
    if stage == 2:
        b.add(flame("crest", 0.12, 0.05, (0, hc.y - 0.03, hc.z + hr.z * 0.95), (-15, 0, 0), m_core, K.mat("CrestWhite", (1, 0.98, 0.85))), "Head")
        for side, bone in ((1, "Arm_L"), (-1, "Arm_R")):
            base = b.lm["spine"][1] + Vector((side * 0.12, 0.06, 0.1))
            for i, ang in enumerate((20, 40, 60)):
                b.add(flame("wing", 0.22 - i * 0.03, 0.06, base + Vector((side * 0.02 * i, 0.03 * i, 0)), (-30 - i * 10, side * ang, 0), m_flame, m_core), "Spine")
        for key in ("arm_l", "arm_r", "foot_l", "foot_r"):
            foot = b.lm[key][1]
            b.add(K.prim("sphere", "paw", (foot.x, foot.y - 0.01, 0.03), (0.055, 0.065, 0.035), material=m_cream, segs=12, rings=8),
                  {"arm_l": "Arm_L", "arm_r": "Arm_R", "foot_l": "Foot_L", "foot_r": "Foot_R"}[key])
    return b


# --------------------------------------------------------------------------------------
# Rig, weights, export
# --------------------------------------------------------------------------------------


def make_rig(lm):
    data = bpy.data.armatures.new("RigData")
    arm = bpy.data.objects.new("Rig", data)
    bpy.context.scene.collection.objects.link(arm)
    K.activate(arm)
    bpy.ops.object.mode_set(mode="EDIT")

    def bone(name, ht, parent=None):
        h, t = Vector(ht[0]), Vector(ht[1])
        if (t - h).length < 0.01:
            t = h + Vector((0, 0, 0.05))
        eb = data.edit_bones.new(name)
        eb.head, eb.tail = h, t
        if parent:
            eb.parent = data.edit_bones[parent]

    bone("Root", lm["root"])
    bone("Spine", lm["spine"], "Root")
    bone("Head", lm["head"], "Spine")
    bone("Ear_L", lm["ear_l"], "Head")
    bone("Ear_R", lm["ear_r"], "Head")
    bone("Arm_L", lm["arm_l"], "Spine")
    bone("Arm_R", lm["arm_r"], "Spine")
    bone("Foot_L", lm["foot_l"], "Root")
    bone("Foot_R", lm["foot_r"], "Root")
    bone("Tail", lm["tail"], "Spine")
    bpy.ops.object.mode_set(mode="OBJECT")
    for pb in arm.pose.bones:
        pb.rotation_mode = "XYZ"
    return arm


class Unit:
    def __init__(self, u):
        self.body_h = u


NAMES = {"pipkin": bloom, "marrow": tide, "solbit": ember}


def build(species: str, stage: int) -> Path:
    K.reset()
    b = NAMES[species](stage)
    arm = make_rig(b.lm)
    K.weight_parts(b.parts, b.bones, arm)
    mesh = K.join(b.parts, f"{species}_{stage}")
    mod = mesh.modifiers.new("Armature", "ARMATURE")
    mod.object = arm
    mesh.parent = arm
    t = K.tri_count(mesh)
    if t > 7000:
        K.decimate(mesh, 7000 / t)  # keeps vertex groups
    K.animate(arm, Unit(b.unit * 0.6), species)
    print(f"{species}_{stage}: {K.tri_count(mesh)} tris")
    out = K.MODELS / f"{species}_{stage}.glb"
    K.export(out, [arm, mesh], animations=True)
    return out


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    which = args or list(NAMES)
    for sp in which:
        for st in range(3):
            build(sp, st)
    print("CREATURES_READY")
