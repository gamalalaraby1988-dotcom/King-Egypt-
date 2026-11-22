import bpy
import math
import os
from mathutils import Vector

# KING OF EGYPT CITY — Royal Gate, Stage 1 structural blockout.
# Generates a new, isolated model. It never reads or overwrites the legacy GLB.
OUT = "artifacts/royal-gate-build/royal_gate_stage1.glb"
os.makedirs(os.path.dirname(OUT), exist_ok=True)

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
turquoise = material("Royal turquoise enamel", (0.015, 0.42, 0.39), 0.38, 0.28)
warm_glow = material("Warm gold emissive accents", (1.0, 0.55, 0.12), 0.25, 0.25)
glow_bs = warm_glow.node_tree.nodes.get("Principled BSDF")
glow_bs.inputs["Emission Color"].default_value = (1.0, 0.34, 0.055, 1.0)
glow_bs.inputs["Emission Strength"].default_value = 1.8

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

def sphere(name, loc, scale, mat, segments=32, rings=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, location=loc)
    obj = bpy.context.object
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(obj, name, mat, 0.0)

# Side foundations only: keep the central vehicle passage completely free of steps.
# The gate's structural plinths sit beneath the pylons and wing walls, not across the road.
for side, x in (("Left", -9.0), ("Right", 9.0)):
    cube(f"{side} monumental foundation", (x, 0.0, 0.35), (10.0, 13.0, 0.7), black_stone, 0.18)
    cube(f"{side} gold foundation reveal", (x, -0.02, 0.74), (9.7, 12.6, 0.12), gold, 0.035)
    cube(f"{side} upper stone terrace", (x, 0.0, 0.98), (9.0, 12.0, 0.42), limestone, 0.12)

# Continuous, level vehicle roadway through the portal; no stairs or raised threshold.
road = cube("Continuous level vehicle roadway", (0.0, -1.5, 1.075), (8.2, 42.0, 0.22), dark, 0.025)
# Flush gold edge lines mark the lane without creating a physical obstruction.
for x in (-3.95, 3.95):
    cube("Flush gold roadway edge inlay", (x, -1.5, 1.19), (0.055, 42.0, 0.018), gold, 0.006)
# Low-contrast center guide, also flush with the road surface.
for y in range(-20, 19, 4):
    cube("Flush roadway center guide", (0.0, y, 1.19), (0.10, 1.8, 0.018), limestone, 0.006)

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
# Enlarged royal founder crest: portrait reservation above two legible identity lines.
cube("Royal crest backing", (0, -2.68, 13.42), (4.45, 0.34, 2.55), limestone, 0.14)
cube("Royal crest gold frame", (0, -2.90, 13.42), (4.02, 0.14, 2.20), gold, 0.07)
cube("Royal crest dark inset", (0, -3.00, 13.42), (3.72, 0.08, 1.94), dark, 0.045)
# Portrait frame remains empty until the founder supplies/approves a reference photo.
cube("Founder portrait reserved frame", (0, -3.065, 13.91), (1.18, 0.055, 0.98), gold, 0.035)
cube("Founder portrait reserved dark panel", (0, -3.10, 13.91), (1.02, 0.035, 0.82), blue, 0.02)
cube("Founder portrait top jewel", (0, -3.12, 14.43), (0.22, 0.035, 0.10), turquoise, 0.025)

# Founder identity lettering is real 3D text in the exported GLB.
def crest_text(name, body, size, z, mat, max_width):
    curve = bpy.data.curves.new(name, type="FONT")
    curve.body = body
    curve.align_x = "CENTER"
    curve.align_y = "CENTER"
    curve.size = size
    curve.extrude = 0.008
    curve.bevel_depth = 0.0018
    curve.bevel_resolution = 2
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    obj.location = (0.0, -3.13, z)
    obj.rotation_euler = (math.radians(90), 0.0, 0.0)
    obj.data.materials.append(mat)
    bpy.context.view_layer.update()
    if obj.dimensions.x > max_width:
        factor = max_width / obj.dimensions.x
        obj.scale.x *= factor
        obj.scale.y *= factor
        obj.scale.z *= factor
    return obj

crest_text("Founder name lettering", "GAMAL ALARABY", 0.56, 13.02, gold, 3.50)
crest_text("Founder title lettering", "FOUNDER OF KING OF EGYPT CITY", 0.235, 12.68, gold, 3.50)

# Twin slim ceremonial columns at the inside edges of the passage.
for x in (-4.55, 4.55):
    # Slim columns sit fully outside the 8.2 m vehicle lane and inside the pylon opening.
    cylinder("Portal column foot", (x, -1.95, 1.55), 0.30, 0.34, gold)
    cylinder("Portal column shaft", (x, -1.95, 5.5), 0.20, 7.6, limestone)
    cylinder("Portal column blue collar", (x, -1.95, 9.35), 0.24, 0.28, blue)
    cylinder("Portal column capital", (x, -1.95, 9.7), 0.30, 0.42, gold)
    cylinder("Portal column abacus", (x, -1.95, 10.0), 0.34, 0.18, limestone)

# Symmetric low wing walls visually anchor the gate.
for side, x in (("Left", -12.0), ("Right", 12.0)):
    cube(f"{side} wing wall", (x, 0.0, 2.45), (5.0, 3.6, 2.6), limestone, 0.12)
    cube(f"{side} wing wall dark plinth", (x, 0.0, 1.25), (5.15, 3.75, 0.28), black_stone, 0.06)
    cube(f"{side} wing wall gold coping", (x, 0.0, 3.82), (5.25, 3.85, 0.18), gold, 0.04)

# Paired monumental sphinx guardians on side plinths, fully clear of vehicle traffic.
for side, x in (("Left", -16.0), ("Right", 16.0)):
    cube(f"{side} sphinx guardian plinth", (x, -3.6, 1.35), (4.2, 6.2, 0.55), black_stone, 0.10)
    cube(f"{side} sphinx plinth gold reveal", (x, -3.6, 1.66), (4.0, 6.0, 0.10), gold, 0.025)
    sphere(f"{side} sphinx lion body", (x, -3.75, 2.18), (1.35, 2.0, 0.72), limestone)
    sphere(f"{side} sphinx chest", (x, -4.55, 2.35), (1.02, 0.88, 0.95), limestone)
    for dx in (-0.58, 0.58):
        cube(f"{side} sphinx forepaw", (x+dx, -5.35, 1.98), (0.62, 1.35, 0.42), limestone, 0.12)
        cube(f"{side} sphinx paw gold band", (x+dx, -5.95, 2.02), (0.64, 0.12, 0.18), gold, 0.035)
    sphere(f"{side} sphinx royal head", (x, -5.12, 3.18), (0.62, 0.58, 0.78), limestone)
    cube(f"{side} sphinx nemes crown", (x, -5.02, 3.70), (1.32, 0.92, 0.34), blue, 0.12)
    for dx in (-0.58, 0.58):
        cube(f"{side} sphinx nemes side flap", (x+dx, -4.92, 2.92), (0.28, 0.72, 1.12), blue, 0.10)
        cube(f"{side} sphinx headdress gold stripe", (x+dx, -5.30, 2.95), (0.08, 0.08, 0.92), gold, 0.018)
    cube(f"{side} sphinx cobra emblem", (x, -5.66, 3.38), (0.13, 0.10, 0.32), gold, 0.025)
    for dx in (-0.23, 0.23):
        sphere(f"{side} sphinx eye", (x+dx, -5.61, 3.25), (0.075, 0.045, 0.055), gold, 16, 12)
    cube(f"{side} sphinx ceremonial collar", (x, -5.34, 2.62), (0.98, 0.12, 0.16), gold, 0.035)
    # Facial sculpt details: dark eye sockets, raised brows, muzzle, nose and carved mouth.
    for dx in (-0.24, 0.24):
        sphere(f"{side} sphinx eye socket", (x+dx, -5.585, 3.27), (0.125, 0.055, 0.105), dark, 20, 12)
        sphere(f"{side} sphinx eye highlight", (x+dx, -5.645, 3.27), (0.052, 0.026, 0.052), gold, 16, 10)
        cube(f"{side} sphinx sculpted brow", (x+dx, -5.60, 3.40), (0.29, 0.10, 0.085), gold, 0.035)
    sphere(f"{side} sphinx nose bridge", (x, -5.665, 3.12), (0.16, 0.12, 0.25), limestone, 24, 16)
    sphere(f"{side} sphinx muzzle left", (x-0.13, -5.70, 3.02), (0.19, 0.12, 0.13), limestone, 20, 12)
    sphere(f"{side} sphinx muzzle right", (x+0.13, -5.70, 3.02), (0.19, 0.12, 0.13), limestone, 20, 12)
    cube(f"{side} sphinx nose tip", (x, -5.805, 3.06), (0.16, 0.07, 0.10), gold, 0.035)
    cube(f"{side} sphinx mouth line", (x, -5.80, 2.91), (0.26, 0.035, 0.035), dark, 0.012)
    sphere(f"{side} sphinx chin", (x, -5.62, 2.84), (0.25, 0.20, 0.10), limestone, 20, 12)
    # Nemes pleats and ornamental beard make the royal headdress read as carved regalia.
    for dx in (-0.43, -0.22, 0.22, 0.43):
        cube(f"{side} sphinx nemes pleat", (x+dx, -5.40, 3.16), (0.045, 0.045, 0.70), gold, 0.012)
    cube(f"{side} sphinx royal beard mount", (x, -5.48, 2.79), (0.20, 0.18, 0.18), gold, 0.025)
    cube(f"{side} sphinx royal beard", (x, -5.54, 2.58), (0.14, 0.16, 0.30), blue, 0.025)
    for dx in (-0.58, 0.58):
        for j in range(3):
            cube(f"{side} sphinx paw claw", (x+dx, -5.92+j*0.16, 1.96), (0.09, 0.10, 0.11), gold, 0.025)
    # Layered shoulder and haunch forms soften the primitive lion silhouette.
    sphere(f"{side} sphinx shoulder muscle", (x, -4.42, 2.28), (1.18, 0.90, 0.70), limestone, 32, 20)
    for dx in (-0.86, 0.86):
        torus(f"{side} sphinx flank carving", (x+dx, -3.60, 2.26), 0.34, 0.035, gold, (0, math.radians(90), 0))

# Hieroglyph-inspired relief bands and turquoise cartouche details.
for x in (-8.0, 8.0):
    for j in range(5):
        z = 5.05 + j*1.02
        cube("Turquoise vertical cartouche inlay", (x, -2.445, z), (0.18, 0.045, 0.48), turquoise, 0.035)
        cube("Gold cartouche cap", (x, -2.475, z+0.28), (0.28, 0.05, 0.07), gold, 0.02)
    for z in (4.65, 9.65):
        torus("Gold sacred ring relief", (x, -2.47, z), 0.28, 0.055, gold, (math.radians(90),0,0))
        sphere("Turquoise relief center", (x, -2.50, z), (0.12,0.045,0.12), turquoise, 20, 12)

# Integrated warm emissive accents are part of the actual model materials.
for x in (-10.7, -5.35, 5.35, 10.7):
    cube("Warm emissive vertical light strip", (x, -2.46, 7.15), (0.07, 0.045, 4.6), warm_glow, 0.018)
for x in (-1.75, 1.75):
    cube("Crest side luminous jewel", (x, -3.08, 13.42), (0.10, 0.045, 0.34), warm_glow, 0.025)

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
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x = 1600
scene.render.resolution_y = 900
scene["asset_id"] = "royal_gate_stage1_from_scratch"
scene["review_status"] = "preview_pending"
scene["design_note"] = "Enhanced royal gate with enlarged founder name/title, reserved portrait frame, paired sphinx guardians, hieroglyph-inspired reliefs, turquoise inlays and integrated warm emissive accents; vehicle passage remains level and unobstructed."

# Export only the newly generated gate mesh.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_selection=True)
print(f"EXPORTED: {OUT}")
