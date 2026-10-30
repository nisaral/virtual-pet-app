"""Headless Blender builder for Lumina Vale GLB pets and glen stage.

Run:
  blender --background --python tools/build_3d_assets.py
"""

from __future__ import annotations

import math
import os
import sys
from pathlib import Path

import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "models"
FPS = 24


def reset_scene() -> None:
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.unit_settings.system = "METRIC"


def link(obj: bpy.types.Object) -> bpy.types.Object:
    col = bpy.context.scene.collection
    if obj.name not in col.objects:
        col.objects.link(obj)
    bpy.context.view_layer.objects.active = obj
    return obj


def new_mesh(name: str, verts, faces) -> bpy.types.Object:
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    return link(obj)


def ico_sphere(name: str, radius: float, loc, scale=None, subdiv=2) -> bpy.types.Object:
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdiv, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    if scale is not None:
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def uv_sphere(name: str, radius: float, loc, scale=None, segs=16, rings=10) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segs, ring_count=rings, radius=radius, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    if scale is not None:
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def cone(name: str, radius1: float, depth: float, loc, rot=(0, 0, 0), verts=8) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=radius1, radius2=0.0, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def cylinder(name: str, radius: float, depth: float, loc, rot=(0, 0, 0), verts=12) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth, location=loc, rotation=rot)
    obj = bpy.context.active_object
    obj.name = name
    return obj


def cube(name: str, size: float, loc, scale=None) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cube_add(size=size, location=loc)
    obj = bpy.context.active_object
    obj.name = name
    if scale is not None:
        obj.scale = scale
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return obj


def mat(name: str, color, roughness=0.48, emission=0.04, metallic=0.0) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.use_nodes = True
    nt = material.node_tree
    principled = nt.nodes.get("Principled BSDF")
    r, g, b = color
    principled.inputs["Base Color"].default_value = (r, g, b, 1)
    principled.inputs["Roughness"].default_value = roughness
    principled.inputs["Metallic"].default_value = metallic
    if "Specular IOR Level" in principled.inputs:
        principled.inputs["Specular IOR Level"].default_value = 0.22
    elif "Specular" in principled.inputs:
        principled.inputs["Specular"].default_value = 0.22
    if "Emission Color" in principled.inputs:
        principled.inputs["Emission Color"].default_value = (r, g, b, 1)
        principled.inputs["Emission Strength"].default_value = emission
    elif "Emission" in principled.inputs:
        principled.inputs["Emission"].default_value = (r, g, b, 1)
    material.diffuse_color = (r, g, b, 1)
    return material


def assign(obj: bpy.types.Object, material: bpy.types.Material) -> None:
    obj.data.materials.clear()
    obj.data.materials.append(material)


def shade_smooth(obj: bpy.types.Object) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    bpy.ops.object.shade_smooth()
    mesh = obj.data
    if hasattr(mesh, "use_auto_smooth"):
        mesh.use_auto_smooth = True
        mesh.auto_smooth_angle = math.radians(55)


def apply_subdiv(obj: bpy.types.Object, levels: int = 1) -> None:
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    mod = obj.modifiers.new("subdiv", "SUBSURF")
    mod.levels = levels
    mod.render_levels = levels + 1
    bpy.ops.object.modifier_apply(modifier=mod.name)


def join_named(name: str, objects: list[bpy.types.Object]) -> bpy.types.Object:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.join()
    joined = bpy.context.active_object
    joined.name = name
    return joined


def bone(arm, name: str, head, tail, parent: str | None = None):
    b = arm.edit_bones.new(name)
    b.head = Vector(head)
    b.tail = Vector(tail)
    b.use_connect = False
    b.roll = 0
    if parent:
        b.parent = arm.edit_bones[parent]
    return b


def make_armature() -> bpy.types.Object:
    arm_data = bpy.data.armatures.new("RigData")
    arm = bpy.data.objects.new("Rig", arm_data)
    link(arm)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    bone(arm_data, "Root", (0, 0, 0), (0, 0, 0.12))
    bone(arm_data, "Spine", (0, 0, 0.18), (0, 0, 0.52), "Root")
    bone(arm_data, "Head", (0, 0.02, 0.58), (0, 0.04, 0.92), "Spine")
    bone(arm_data, "Ear_L", (0.12, 0.0, 0.88), (0.22, -0.02, 1.18), "Head")
    bone(arm_data, "Ear_R", (-0.12, 0.0, 0.88), (-0.22, -0.02, 1.18), "Head")
    bone(arm_data, "Arm_L", (0.22, 0.04, 0.48), (0.38, 0.08, 0.22), "Spine")
    bone(arm_data, "Arm_R", (-0.22, 0.04, 0.48), (-0.38, 0.08, 0.22), "Spine")
    bone(arm_data, "Foot_L", (0.14, 0.02, 0.16), (0.16, 0.12, 0.02), "Root")
    bone(arm_data, "Foot_R", (-0.14, 0.02, 0.16), (-0.16, 0.12, 0.02), "Root")
    bone(arm_data, "Tail", (0, -0.12, 0.28), (0, -0.38, 0.18), "Spine")
    bpy.ops.object.mode_set(mode="OBJECT")
    for pbone in arm.pose.bones:
        pbone.rotation_mode = "XYZ"
    return arm


def bind(mesh: bpy.types.Object, arm: bpy.types.Object) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    mesh.select_set(True)
    arm.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.parent_set(type="ARMATURE_AUTO")


def new_action(arm: bpy.types.Object, name: str) -> bpy.types.Action:
    if arm.animation_data is None:
        arm.animation_data_create()
    action = bpy.data.actions.new(name)
    arm.animation_data.action = action
    return action


def insert(arm: bpy.types.Object, frame: int, poses: dict) -> None:
    bpy.context.scene.frame_set(frame)
    for name, data in poses.items():
        bone = arm.pose.bones[name]
        bone.rotation_mode = "XYZ"
        loc = data.get("loc", (0.0, 0.0, 0.0))
        rot = data.get("rot", (0.0, 0.0, 0.0))
        scale = data.get("scale", (1.0, 1.0, 1.0))
        bone.location = loc
        bone.rotation_euler = rot
        bone.scale = scale
        bone.keyframe_insert("location", frame=frame)
        bone.keyframe_insert("rotation_euler", frame=frame)
        bone.keyframe_insert("scale", frame=frame)


def rest_pose() -> dict:
    names = ["Root", "Spine", "Head", "Ear_L", "Ear_R", "Arm_L", "Arm_R", "Foot_L", "Foot_R", "Tail"]
    return {n: {"loc": (0, 0, 0), "rot": (0, 0, 0), "scale": (1, 1, 1)} for n in names}


def lerp_pose(a: dict, b: dict, t: float) -> dict:
    out = {}
    for name in a:
        la, ra, sa = a[name]["loc"], a[name]["rot"], a[name]["scale"]
        lb, rb, sb = b[name]["loc"], b[name]["rot"], b[name]["scale"]
        out[name] = {
            "loc": tuple(la[i] + (lb[i] - la[i]) * t for i in range(3)),
            "rot": tuple(ra[i] + (rb[i] - ra[i]) * t for i in range(3)),
            "scale": tuple(sa[i] + (sb[i] - sa[i]) * t for i in range(3)),
        }
    return out


def push_nla(arm: bpy.types.Object, action: bpy.types.Action, name: str, start: int, end: int) -> None:
    if arm.animation_data is None:
        arm.animation_data_create()
    track = arm.animation_data.nla_tracks.new()
    track.name = name
    strip = track.strips.new(name, start, action)
    strip.frame_end = end
    strip.action_frame_start = start
    strip.action_frame_end = end
    action.use_fake_user = True


def make_cycles(arm: bpy.types.Object) -> None:
    r = rest_pose()

    idle = new_action(arm, "Idle")
    breathe = dict(r)
    breathe["Spine"] = {"loc": (0, 0, 0.012), "rot": (0.04, 0, 0), "scale": (1.045, 1.02, 1.05)}
    breathe["Ear_L"] = {"loc": (0, 0, 0), "rot": (0.12, 0.08, 0.05), "scale": (1, 1, 1)}
    breathe["Ear_R"] = {"loc": (0, 0, 0), "rot": (0.08, -0.1, -0.04), "scale": (1, 1, 1)}
    sway = dict(r)
    sway["Root"] = {"loc": (0.03, 0, 0), "rot": (0, 0, 0.06), "scale": (1, 1, 1)}
    sway["Tail"] = {"loc": (0, 0, 0), "rot": (0.1, 0.2, 0), "scale": (1, 1, 1)}
    insert(arm, 1, r)
    insert(arm, 20, breathe)
    insert(arm, 40, sway)
    insert(arm, 60, r)
    push_nla(arm, idle, "Idle", 1, 60)

    hop = new_action(arm, "Happy_Hop")
    crouch = dict(r)
    crouch["Root"] = {"loc": (0, 0, -0.08), "rot": (0.18, 0, 0), "scale": (1.08, 1.08, 0.86)}
    crouch["Ear_L"] = {"loc": (0, 0, 0), "rot": (0.4, 0.1, 0), "scale": (1, 1, 1)}
    crouch["Ear_R"] = {"loc": (0, 0, 0), "rot": (0.4, -0.1, 0), "scale": (1, 1, 1)}
    air = dict(r)
    air["Root"] = {"loc": (0.05, 0.12, 0.42), "rot": (0, 0, math.pi), "scale": (0.94, 0.94, 1.12)}
    air["Ear_L"] = {"loc": (0, 0, 0), "rot": (-0.45, 0.2, 0), "scale": (1, 1, 1.1)}
    air["Ear_R"] = {"loc": (0, 0, 0), "rot": (-0.45, -0.2, 0), "scale": (1, 1, 1.1)}
    air["Arm_L"] = {"loc": (0, 0, 0), "rot": (-0.8, 0, 0.4), "scale": (1, 1, 1)}
    air["Arm_R"] = {"loc": (0, 0, 0), "rot": (-0.8, 0, -0.4), "scale": (1, 1, 1)}
    land = dict(r)
    land["Root"] = {"loc": (0, 0, -0.04), "rot": (0, 0, math.tau), "scale": (1.06, 1.06, 0.9)}
    insert(arm, 1, r)
    insert(arm, 10, crouch)
    insert(arm, 24, air)
    insert(arm, 36, land)
    insert(arm, 45, r)
    push_nla(arm, hop, "Happy_Hop", 1, 45)

    eat = new_action(arm, "Eat")
    lean = dict(r)
    lean["Spine"] = {"loc": (0, 0.05, 0), "rot": (0.45, 0, 0), "scale": (1, 1, 1)}
    lean["Head"] = {"loc": (0, 0.04, -0.02), "rot": (0.55, 0, 0), "scale": (1, 1, 1)}
    chomp = dict(lean)
    chomp["Head"] = {"loc": (0, 0.05, -0.03), "rot": (0.85, 0, 0), "scale": (1.04, 1.04, 0.92)}
    openm = dict(lean)
    openm["Head"] = {"loc": (0, 0.05, 0.01), "rot": (0.2, 0, 0), "scale": (1, 1, 1.04)}
    nod = dict(r)
    nod["Head"] = {"loc": (0, 0, 0), "rot": (0.35, 0, 0), "scale": (1, 1, 1)}
    insert(arm, 1, r)
    insert(arm, 10, lean)
    insert(arm, 18, chomp)
    insert(arm, 24, openm)
    insert(arm, 30, chomp)
    insert(arm, 38, nod)
    insert(arm, 50, r)
    push_nla(arm, eat, "Eat", 1, 50)

    enjoy = new_action(arm, "Pet_Enjoy")
    lean_in = dict(r)
    lean_in["Head"] = {"loc": (0, 0.08, -0.02), "rot": (0.35, 0, 0), "scale": (1, 1, 0.96)}
    lean_in["Spine"] = {"loc": (0, 0.04, 0), "rot": (0.18, 0, 0), "scale": (1, 1, 1)}
    squint = dict(lean_in)
    squint["Head"] = {"loc": (0, 0.1, -0.03), "rot": (0.42, 0.12, 0), "scale": (1.02, 1.02, 0.94)}
    wag = dict(lean_in)
    wag["Tail"] = {"loc": (0, 0, 0), "rot": (0.2, 0.7, 0), "scale": (1, 1, 1)}
    wag2 = dict(lean_in)
    wag2["Tail"] = {"loc": (0, 0, 0), "rot": (0.2, -0.7, 0), "scale": (1, 1, 1)}
    insert(arm, 1, r)
    insert(arm, 8, lean_in)
    insert(arm, 16, squint)
    insert(arm, 22, wag)
    insert(arm, 28, wag2)
    insert(arm, 34, wag)
    insert(arm, 40, r)
    push_nla(arm, enjoy, "Pet_Enjoy", 1, 40)

    refuse = new_action(arm, "Refuse")
    away = dict(r)
    away["Head"] = {"loc": (0, -0.02, 0), "rot": (-0.15, 0.55, 0.1), "scale": (1, 1, 1)}
    away["Spine"] = {"loc": (0, -0.02, 0), "rot": (0, 0.18, 0), "scale": (1, 1, 1)}
    left = dict(away)
    left["Head"] = {"loc": (0, -0.02, 0), "rot": (-0.1, 0.7, 0.15), "scale": (1, 1, 1)}
    right = dict(away)
    right["Head"] = {"loc": (0, -0.02, 0), "rot": (-0.1, -0.55, -0.12), "scale": (1, 1, 1)}
    insert(arm, 1, r)
    insert(arm, 8, away)
    insert(arm, 16, left)
    insert(arm, 24, right)
    insert(arm, 30, left)
    insert(arm, 35, r)
    push_nla(arm, refuse, "Refuse", 1, 35)

    sleep = new_action(arm, "Sleep")
    curl = dict(r)
    curl["Root"] = {"loc": (0, 0.05, -0.1), "rot": (0.9, 0, 0.4), "scale": (1.05, 1.08, 0.88)}
    curl["Head"] = {"loc": (0.02, 0.06, -0.04), "rot": (0.55, 0.3, 0), "scale": (1, 1, 1)}
    curl["Ear_L"] = {"loc": (0, 0, 0), "rot": (0.5, 0.1, 0), "scale": (1, 1, 1)}
    curl["Ear_R"] = {"loc": (0, 0, 0), "rot": (0.5, -0.1, 0), "scale": (1, 1, 1)}
    curl["Tail"] = {"loc": (0, 0, 0), "rot": (0.6, 0.4, 0), "scale": (1, 1, 1)}
    deep = dict(curl)
    deep["Spine"] = {"loc": (0, 0, 0.01), "rot": (0.08, 0, 0), "scale": (1.06, 1.04, 1.05)}
    insert(arm, 1, curl)
    insert(arm, 40, deep)
    insert(arm, 80, curl)
    push_nla(arm, sleep, "Sleep", 1, 80)

    walk = new_action(arm, "Walk")
    a = dict(r)
    a["Root"] = {"loc": (0, 0, 0.04), "rot": (0.08, 0, 0.04), "scale": (1, 1, 1)}
    a["Foot_L"] = {"loc": (0, 0.08, 0.04), "rot": (-0.5, 0, 0), "scale": (1, 1, 1)}
    a["Foot_R"] = {"loc": (0, -0.06, 0), "rot": (0.35, 0, 0), "scale": (1, 1, 1)}
    a["Arm_L"] = {"loc": (0, 0, 0), "rot": (0.45, 0, 0), "scale": (1, 1, 1)}
    a["Arm_R"] = {"loc": (0, 0, 0), "rot": (-0.45, 0, 0), "scale": (1, 1, 1)}
    a["Tail"] = {"loc": (0, 0, 0), "rot": (0.1, 0.25, 0), "scale": (1, 1, 1)}
    b = dict(r)
    b["Root"] = {"loc": (0, 0, 0.04), "rot": (0.08, 0, -0.04), "scale": (1, 1, 1)}
    b["Foot_L"] = {"loc": (0, -0.06, 0), "rot": (0.35, 0, 0), "scale": (1, 1, 1)}
    b["Foot_R"] = {"loc": (0, 0.08, 0.04), "rot": (-0.5, 0, 0), "scale": (1, 1, 1)}
    b["Arm_L"] = {"loc": (0, 0, 0), "rot": (-0.45, 0, 0), "scale": (1, 1, 1)}
    b["Arm_R"] = {"loc": (0, 0, 0), "rot": (0.45, 0, 0), "scale": (1, 1, 1)}
    b["Tail"] = {"loc": (0, 0, 0), "rot": (0.1, -0.25, 0), "scale": (1, 1, 1)}
    insert(arm, 1, a)
    insert(arm, 8, b)
    insert(arm, 16, a)
    insert(arm, 23, b)
    insert(arm, 30, a)
    push_nla(arm, walk, "Walk", 1, 30)

    arm.animation_data.action = None


def paint_color(obj: bpy.types.Object, color) -> None:
    mesh = obj.data
    attr = mesh.color_attributes.get("Color")
    if attr is None:
        attr = mesh.color_attributes.new(name="Color", type="FLOAT_COLOR", domain="POINT")
    r, g, b = color
    for i in range(len(mesh.vertices)):
        attr.data[i].color = (r, g, b, 1.0)


def sproutkit_parts() -> list[bpy.types.Object]:
    leaf = mat("SproutLeaf", (0.42, 0.78, 0.38), emission=0.06)
    cream = mat("SproutCream", (0.95, 0.93, 0.78), roughness=0.55)
    blush = mat("SproutBlush", (0.95, 0.55, 0.58), emission=0.05)
    ink = mat("SproutInk", (0.12, 0.1, 0.16), roughness=0.35)
    body = uv_sphere("body", 0.38, (0, 0.02, 0.38), scale=(1.05, 0.9, 0.95))
    assign(body, cream)
    head = uv_sphere("head", 0.32, (0, 0.06, 0.78))
    assign(head, cream)
    muzzle = uv_sphere("muzzle", 0.14, (0, 0.22, 0.7), scale=(1.1, 0.9, 0.7))
    assign(muzzle, cream)
    ear_l = uv_sphere("earL", 0.12, (0.16, -0.02, 1.08), scale=(0.55, 0.35, 1.55))
    ear_r = uv_sphere("earR", 0.12, (-0.16, -0.02, 1.08), scale=(0.55, 0.35, 1.55))
    assign(ear_l, leaf)
    assign(ear_r, leaf)
    leaf_tuft = cone("tuft", 0.09, 0.22, (0, -0.02, 1.12), rot=(0.2, 0, 0), verts=6)
    assign(leaf_tuft, leaf)
    eye_l = uv_sphere("eyeL", 0.055, (0.1, 0.26, 0.82))
    eye_r = uv_sphere("eyeR", 0.055, (-0.1, 0.26, 0.82))
    assign(eye_l, ink)
    assign(eye_r, ink)
    cheek_l = uv_sphere("cheekL", 0.06, (0.18, 0.18, 0.7))
    cheek_r = uv_sphere("cheekR", 0.06, (-0.18, 0.18, 0.7))
    assign(cheek_l, blush)
    assign(cheek_r, blush)
    arm_l = uv_sphere("armL", 0.1, (0.32, 0.08, 0.36), scale=(0.7, 0.7, 1.1))
    arm_r = uv_sphere("armR", 0.1, (-0.32, 0.08, 0.36), scale=(0.7, 0.7, 1.1))
    assign(arm_l, cream)
    assign(arm_r, cream)
    foot_l = uv_sphere("footL", 0.11, (0.14, 0.12, 0.1), scale=(0.9, 1.3, 0.55))
    foot_r = uv_sphere("footR", 0.11, (-0.14, 0.12, 0.1), scale=(0.9, 1.3, 0.55))
    assign(foot_l, cream)
    assign(foot_r, cream)
    tail = uv_sphere("tail", 0.12, (0, -0.28, 0.28))
    assign(tail, leaf)
    return [body, head, muzzle, ear_l, ear_r, leaf_tuft, eye_l, eye_r, cheek_l, cheek_r, arm_l, arm_r, foot_l, foot_r, tail]


def aquapup_parts() -> list[bpy.types.Object]:
    tide = mat("AquaTide", (0.32, 0.62, 0.92), emission=0.07)
    belly = mat("AquaBelly", (0.86, 0.94, 0.98), roughness=0.5)
    ink = mat("AquaInk", (0.1, 0.16, 0.28), roughness=0.3)
    body = uv_sphere("body", 0.42, (0, 0.04, 0.36), scale=(1.15, 1.45, 0.85))
    assign(body, tide)
    head = uv_sphere("head", 0.3, (0, 0.28, 0.62))
    assign(head, tide)
    chest = uv_sphere("chest", 0.28, (0, 0.16, 0.34), scale=(0.9, 1.0, 0.8))
    assign(chest, belly)
    snout = uv_sphere("snout", 0.12, (0, 0.48, 0.56), scale=(1.1, 1.2, 0.7))
    assign(snout, belly)
    eye_l = uv_sphere("eyeL", 0.05, (0.1, 0.46, 0.7))
    eye_r = uv_sphere("eyeR", 0.05, (-0.1, 0.46, 0.7))
    assign(eye_l, ink)
    assign(eye_r, ink)
    flip_l = uv_sphere("flipL", 0.14, (0.38, 0.06, 0.22), scale=(1.3, 0.45, 0.25))
    flip_r = uv_sphere("flipR", 0.14, (-0.38, 0.06, 0.22), scale=(1.3, 0.45, 0.25))
    assign(flip_l, tide)
    assign(flip_r, tide)
    foot_l = uv_sphere("footL", 0.1, (0.12, 0.22, 0.08), scale=(0.8, 1.4, 0.4))
    foot_r = uv_sphere("footR", 0.1, (-0.12, 0.22, 0.08), scale=(0.8, 1.4, 0.4))
    assign(foot_l, tide)
    assign(foot_r, tide)
    tail = uv_sphere("tail", 0.16, (0, -0.42, 0.22), scale=(1.6, 0.55, 0.28))
    assign(tail, tide)
    whisk_l = cube("whiskL", 0.04, (0.16, 0.52, 0.54), scale=(1.8, 0.15, 0.12))
    whisk_r = cube("whiskR", 0.04, (-0.16, 0.52, 0.54), scale=(1.8, 0.15, 0.12))
    assign(whisk_l, ink)
    assign(whisk_r, ink)
    return [body, head, chest, snout, eye_l, eye_r, flip_l, flip_r, foot_l, foot_r, tail, whisk_l, whisk_r]


def embercub_parts() -> list[bpy.types.Object]:
    ember = mat("EmberFur", (0.96, 0.48, 0.22), emission=0.08)
    cream = mat("EmberCream", (0.98, 0.9, 0.72), roughness=0.52)
    flame = mat("EmberFlame", (1.0, 0.72, 0.18), emission=0.35, roughness=0.3)
    ink = mat("EmberInk", (0.18, 0.08, 0.05), roughness=0.32)
    body = uv_sphere("body", 0.42, (0, 0.02, 0.4), scale=(1.15, 0.95, 1.0))
    assign(body, ember)
    head = uv_sphere("head", 0.34, (0, 0.08, 0.82))
    assign(head, ember)
    snout = uv_sphere("snout", 0.14, (0, 0.28, 0.72), scale=(1.15, 1.0, 0.7))
    assign(snout, cream)
    belly = uv_sphere("belly", 0.26, (0, 0.16, 0.36), scale=(0.95, 0.8, 0.85))
    assign(belly, cream)
    ear_l = uv_sphere("earL", 0.12, (0.2, 0.0, 1.08), scale=(0.85, 0.55, 0.85))
    ear_r = uv_sphere("earR", 0.12, (-0.2, 0.0, 1.08), scale=(0.85, 0.55, 0.85))
    assign(ear_l, ember)
    assign(ear_r, ember)
    tuft = cone("flame", 0.1, 0.28, (0, -0.02, 1.16), rot=(0.15, 0, 0), verts=5)
    assign(tuft, flame)
    eye_l = uv_sphere("eyeL", 0.05, (0.11, 0.3, 0.88))
    eye_r = uv_sphere("eyeR", 0.05, (-0.11, 0.3, 0.88))
    assign(eye_l, ink)
    assign(eye_r, ink)
    arm_l = uv_sphere("armL", 0.13, (0.38, 0.08, 0.38), scale=(0.75, 0.7, 1.05))
    arm_r = uv_sphere("armR", 0.13, (-0.38, 0.08, 0.38), scale=(0.75, 0.7, 1.05))
    assign(arm_l, ember)
    assign(arm_r, ember)
    foot_l = uv_sphere("footL", 0.13, (0.16, 0.12, 0.1), scale=(0.9, 1.2, 0.55))
    foot_r = uv_sphere("footR", 0.13, (-0.16, 0.12, 0.1), scale=(0.9, 1.2, 0.55))
    assign(foot_l, ember)
    assign(foot_r, ember)
    tail = uv_sphere("tail", 0.12, (0, -0.32, 0.32), scale=(0.7, 1.3, 0.7))
    assign(tail, ember)
    return [body, head, snout, belly, ear_l, ear_r, tuft, eye_l, eye_r, arm_l, arm_r, foot_l, foot_r, tail]


def export_glb(path: Path, objects: list[bpy.types.Object]) -> None:
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        for child in obj.children_recursive:
            child.select_set(True)
    bpy.context.view_layer.objects.active = objects[0]
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(path),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_animations=True,
        export_animation_mode="NLA_TRACKS",
        export_nla_strips=True,
        export_force_sampling=True,
        export_skins=True,
        export_morph=False,
        export_lights=False,
        export_cameras=False,
        export_yup=True,
    )


def build_pet(kind: str) -> Path:
    reset_scene()
    builders = {
        "sproutkit": sproutkit_parts,
        "aquapup": aquapup_parts,
        "embercub": embercub_parts,
    }
    parts = builders[kind]()
    mesh = join_named(kind, parts)
    shade_smooth(mesh)
    apply_subdiv(mesh, 1)
    paint_color(mesh, {"sproutkit": (0.55, 0.82, 0.45), "aquapup": (0.4, 0.68, 0.92), "embercub": (0.95, 0.5, 0.24)}[kind])
    arm = make_armature()
    bind(mesh, arm)
    make_cycles(arm)
    out = OUT / f"{kind}.glb"
    export_glb(out, [arm, mesh])
    print(f"WROTE {out} bytes={out.stat().st_size}")
    return out


def build_glen() -> Path:
    reset_scene()
    moss = mat("Moss", (0.38, 0.62, 0.32), roughness=0.7, emission=0.03)
    stone = mat("Stone", (0.55, 0.52, 0.46), roughness=0.82)
    gold = mat("GoldTrim", (0.86, 0.68, 0.28), roughness=0.35, metallic=0.35, emission=0.08)
    bark = mat("Bark", (0.38, 0.24, 0.14), roughness=0.8)
    pine = mat("Pine", (0.22, 0.42, 0.24), roughness=0.6)
    blossom = mat("Blossom", (0.95, 0.62, 0.72), emission=0.08)
    dirt = mat("Dirt", (0.45, 0.38, 0.22), roughness=0.85)
    water = mat("Pond", (0.35, 0.7, 0.82), roughness=0.18, emission=0.05)

    ground = uv_sphere("hills", 2.4, (0, 0, -1.7), scale=(1.6, 1.6, 0.42), segs=24, rings=12)
    assign(ground, moss)
    far = uv_sphere("farHills", 3.2, (0, -1.4, -2.6), scale=(1.8, 1.4, 0.35), segs=20, rings=10)
    assign(far, mat("FarHill", (0.48, 0.7, 0.4), roughness=0.75))
    pedestal = cylinder("pedestal", 0.55, 0.22, (0, 0, 0.12), verts=16)
    assign(pedestal, stone)
    cap = cylinder("cap", 0.62, 0.06, (0, 0, 0.24), verts=16)
    assign(cap, gold)
    moss_pad = uv_sphere("pad", 0.5, (0, 0, 0.3), scale=(1.1, 1.1, 0.22))
    assign(moss_pad, moss)

    trees = []
    spots = [(1.6, -0.8, 0.0), (-1.7, -0.6, 0.0), (1.9, 0.9, 0.0), (-2.0, 0.7, 0.0), (0.9, -1.6, 0.0)]
    for i, (x, y, _) in enumerate(spots):
        trunk = cylinder(f"trunk{i}", 0.08, 0.7, (x, y, 0.45), verts=8)
        assign(trunk, bark)
        if i % 2 == 0:
            crown = cone(f"pine{i}", 0.42, 1.1, (x, y, 1.15), verts=7)
            assign(crown, pine)
        else:
            crown = uv_sphere(f"blossom{i}", 0.42, (x, y, 1.05), scale=(1.1, 1.1, 0.85))
            assign(crown, blossom)
        trees.extend([trunk, crown])

    rocks = []
    for i, loc in enumerate([(0.7, 0.55, 0.08), (-0.8, 0.4, 0.06), (0.3, -0.7, 0.05)]):
        rock = uv_sphere(f"rock{i}", 0.16 + i * 0.03, loc, scale=(1.2, 0.9, 0.55))
        assign(rock, stone)
        rocks.append(rock)

    path = cube("path", 1.0, (0, 0.9, 0.02), scale=(0.35, 1.6, 0.04))
    assign(path, dirt)
    pond = uv_sphere("pond", 0.55, (-1.1, 0.9, 0.02), scale=(1.4, 1.0, 0.08))
    assign(pond, water)

    parts = [ground, far, pedestal, cap, moss_pad, path, pond] + trees + rocks
    mesh = join_named("glen_stage", parts)
    shade_smooth(mesh)
    apply_subdiv(mesh, 1)
    out = OUT / "glen_stage.glb"
    export_glb(out, [mesh])
    print(f"WROTE {out} bytes={out.stat().st_size}")
    return out


def main() -> int:
    OUT.mkdir(parents=True, exist_ok=True)
    written = []
    for kind in ("sproutkit", "aquapup", "embercub"):
        written.append(build_pet(kind))
    written.append(build_glen())
    missing = [p for p in written if not p.exists() or p.stat().st_size < 1024]
    if missing:
        print("MISSING", missing, file=sys.stderr)
        return 1
    print("ALL_GLB_READY")
    return 0


if __name__ == "__main__":
    sys.exit(main())
