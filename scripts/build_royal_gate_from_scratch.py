import bpy
import math
from mathutils import Vector

# KING OF EGYPT CITY — Royal Gate, Stage 1 structural blockout.
# Generates a new, isolated model. It never reads or overwrites the legacy GLB.
OUT = "artifacts/royal-gate-build/royal_gate_stage1.glb"

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
    for block in list(datablocks):
        if block.users == 0:
            datablocks.remove(block)

def material(name, color, metallic=0.0, roughness=0.45):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1.0)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1.0)
    bs.inputs["Metallic"].default_value = metallic
    bs.inputs["Roughness"].default_value = roughness
    return m

limestone = material("Warm limestone", (0.72, 0.61, 0.43), 0.0, 0.78)
black_stone = material("Obsidian black stone", (0.035, 0.045, 0.055), 0.18, 0.34)
gold = material("Royal brushed gold", (0.83, 0.53, 0.16), 0.72, 0.25)
blue = material("Egyptian lapis blue", (0.025, 0.12, 0.34), 0.32, 0.3)
dark = material("Deep recessed stone", (0.018, 0.025, 0.038), 0.05, 0.6)

def finish(obj, name, mat, bevel=0.0):
    obj.name = name
    obj.data.materials.append(mat)
    if bevel:
        mod = obj.modifiers.new("Soft cut stone edges", "BEVEL")
        mod.width = bevel
        mod.segments = 2
        obj.modifiers.new("Weighted corner normals", "WEIGHTED_NORMAL")
    return obj

def cube(name, loc, scale, mat, bevel=0.08):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, bevel)

def cylinder(name, loc, radius, depth, mat, vertices=48, bevel=0.025):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    return finish(bpy.context.object, name, mat, bevel)

def torus(name, loc, major, minor, mat, rotation=(0,0,0)):
    bpy.ops.mesh.primitive_torus_add(major_radius=major, minor_radius=minor, major_segments=64, minor_segments=12, location=loc, rotation=rotation)
    return finish(bpy.context.object, name, mat)

# Ground plinth and approach steps (front is negative Y).
cube("Monumental foundation", (0, 0.0, 0.35), (28.0, 13.0, 0.7), black_stone, 0.18)
cube("Gold foundation reveal", (0, -0.02, 0.74), (27.4, 12.6, 0.12), gold, 0.035)
cube("Upper stone terrace", (0, 0.0, 0.98), (26.8, 12.0, 0.42), limestone, 0.12)
for i in range(5):
    y = -7.0 - i * 0.72
    cube(f"Approach stair {i+1}", (0, y, 0.48 - i*0.075), (15.0 + i*1.1, 1.05, 0.22), limestone, 0.06)
    cube(f"Stair gold nosing {i+1}", (0, y-0.48, 0.60 - i*0.075), (15.0 + i*1.1, 0.055, 0.045), gold, 0.012)

# Two monumental pylons framing a clear central vehicle/pedestrian opening.
tower_x = 8.0
for side, x in (("Left", -tower_x), ("Right", tower_x)):
    cube(f"{side} pylon lower foot", (x, 0.0, 1.55), (7.0, 5.0, 0.72), gold, 0.09)
    cube(f"{side} pylon black base", (x, 0.0, 2.05), (6.65, 4.7, 0.42), black_stone, 0.08)
    cube(f"{side} pylon main mass", (x, 0.0, 7.15), (6.25, 4.35, 10.0), black_stone, 0.16)
    # Subtle battered profile: broad foot and crown, narrower central face.
    cube(f"{side} pylon lower gold band", (x, -0.02, 3.0), (6.42, 4.48, 0.22), gold, 0.035)
    cube(f"{side} pylon upper gold band", (x, -0.02, 11.65), (6.55, 4.55, 0.25), gold, 0.04)
    cube(f"{side} pylon crown", (x, 0.0, 12.15), (6.9, 4.9, 0.8), limestone, 0.12)
    cube(f"{side} pylon crown gold cap", (x, 0.0, 12.62), (7.05, 5.0, 0.16), gold, 0.035)
    # Front-facing inset panel and blue/gold framing.
    cube(f"{side} recessed facade panel", (x, -2.205, 7.15), (4.7, 0.12, 7.0), dark, 0.04)
    cube(f"{side} blue panel field", (x, -2.285, 7.15), (3.95, 0.07, 6.15), blue, 0.025)
    for dx in (-2.18, 2.18):
        cube(f"{side} panel vertical gold border", (x+dx, -2.36, 7.15), (0.16, 0.16, 6.75), gold, 0.025)
    for z in (3.82, 10.48):
        cube(f"{side} panel horizontal gold border", (x, -2.36, z), (4.5, 0.16, 0.16), gold, 0.025)
    # Repeated shallow gold relief bars; kept as structural ornament placeholders.
    for j in range(7):
        z = 4.35 + j*0.88
        cube(f"{side} facade relief {j+1}", (x, -2.39, z), (2.6, 0.08, 0.075), gold, 0.018)
    # Slim side pilasters.
    for dx in (-2.65, 2.65):
        cube(f"{side} facade pilaster", (x+dx, -2.31, 7.15), (0.22, 0.24, 7.6), limestone, 0.035)

# Central lintel bridges pylons while preserving a generous clear opening.
cube("Central lintel lower black beam", (0, 0.0, 11.55), (10.2, 4.8, 1.15), black_stone, 0.12)
cube("Central lintel gold fascia", (0, -2.47, 11.72), (9.8, 0.18, 0.42), gold, 0.04)
cube("Central lintel blue cartouche field", (0, -2.59, 12.35), (6.4, 0.16, 0.72), blue, 0.08)
cube("Central lintel top cornice", (0, 0.0, 12.95), (11.0, 5.2, 0.28), gold, 0.06)
# Royal crest base reserved for approved founder portrait and title in a later pass.
cube("Royal crest backing", (0, -2.68, 13.15), (3.8, 0.32, 1.45), limestone, 0.12)
cube("Royal crest gold frame", (0, -2.88, 13.15), (3.25, 0.12, 1.08), gold, 0.06)
cube("Royal crest dark inset", (0, -2.96, 13.15), (2.95, 0.08, 0.82), dark, 0.035)

# Twin slim ceremonial columns at the inside edges of the passage.
for x in (-4.25, 4.25):
    cylinder("Portal column foot", (x, -1.95, 1.55), 0.62, 0.34, gold)
    cylinder("Portal column shaft", (x, -1.95, 5.5), 0.34, 7.6, limestone)
    cylinder("Portal column blue collar", (x, -1.95, 9.35), 0.43, 0.28, blue)
    cylinder("Portal column capital", (x, -1.95, 9.7), 0.72, 0.42, gold)
    cylinder("Portal column abacus", (x, -1.95, 10.0), 0.82, 0.18, limestone)

# Symmetric low wing walls visually anchor the gate.
for side, x in (("Left", -12.0), ("Right", 12.0)):
    cube(f"{side} wing wall", (x, 0.0, 2.45), (5.0, 3.6, 2.6), limestone, 0.12)
    cube(f"{side} wing wall dark plinth", (x, 0.0, 1.25), (5.15, 3.75, 0.28), black_stone, 0.06)
    cube(f"{side} wing wall gold coping", (x, 0.0, 3.82), (5.25, 3.85, 0.18), gold, 0.04)

# A small sun-disc motif above the passage (structural ornament, not text).
cylinder("Royal solar disc", (0, -2.95, 10.72), 0.72, 0.16, gold, 64)
for a in range(0, 360, 30):
    rad = math.radians(a)
    x = math.sin(rad) * 1.05
    z = 10.72 + math.cos(rad) * 1.05
    bar = cube("Solar ray", (x, -2.96, z), (0.12, 0.12, 0.48), gold, 0.025)
    bar.rotation_euler[1] = -rad

# Scene metadata for downstream review.
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.render.engine = "BLENDER_EEVEE_NEXT"
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene["asset_id"] = "royal_gate_stage1_from_scratch"
scene["review_status"] = "preview_pending"
scene["design_note"] = "Stage 1 structural gate blockout; portrait, sphinx statues and fine hieroglyphic detailing intentionally reserved for later approved stages."

# Export only the newly generated gate mesh.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print(f"EXPORTED: {OUT}")
