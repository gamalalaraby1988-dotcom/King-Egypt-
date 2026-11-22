import bpy
import math
import os
from mathutils import Vector

# KING OF EGYPT CITY — Main Royal Tent, isolated review asset.
# This workflow exports an independent GLB and never edits production scenes.
OUT = "artifacts/main-royal-tent-build/main_royal_tent.glb"
os.makedirs(os.path.dirname(OUT), exist_ok=True)

bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials):
    for block in list(datablocks):
        if block.users == 0:
            datablocks.remove(block)

def mat(name, color, metallic=0.0, rough=0.45, emission=None):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    bs = m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Metallic"].default_value = metallic
    bs.inputs["Roughness"].default_value = rough
    if emission:
        bs.inputs["Emission Color"].default_value = (*emission, 1)
        bs.inputs["Emission Strength"].default_value = 0.65
    return m

gold = mat("Royal brushed gold", (0.82, 0.53, 0.18), 0.78, 0.24)
midnight = mat("Midnight royal blue fabric", (0.018, 0.045, 0.12), 0.08, 0.72)
lapis = mat("Lapis blue canopy panels", (0.025, 0.12, 0.34), 0.12, 0.66)
ivory = mat("Warm ivory fabric", (0.78, 0.70, 0.53), 0.0, 0.84)
black = mat("Obsidian base", (0.025, 0.03, 0.04), 0.25, 0.34)
turquoise = mat("Turquoise enamel", (0.015, 0.42, 0.39), 0.45, 0.25)
glow = mat("Warm lantern glass", (0.95, 0.48, 0.12), 0.25, 0.25, (1.0, 0.24, 0.035))

def finish(obj, name, material, bevel=0.0):
    obj.name = name
    obj.data.materials.append(material)
    if bevel and obj.type == "MESH":
        mod = obj.modifiers.new("Soft tailored edges", "BEVEL")
        mod.width = bevel
        mod.segments = 3
        obj.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return obj

def cube(name, loc, scale, material, bevel=0.05):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.dimensions = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, material, bevel)

def cyl(name, loc, radius, depth, material, vertices=32):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    return finish(bpy.context.object, name, material, 0.025)

def sphere(name, loc, scale, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24, ring_count=16, location=loc)
    o = bpy.context.object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, name, material)

def mesh_obj(name, verts, faces, material):
    mesh = bpy.data.meshes.new(name + "Mesh")
    mesh.from_pydata(verts, [], faces)
    mesh.materials.append(material)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    return obj

# Broad, low, walkable royal dais. The entrance edge stays level and open.
cube("Octagonal obsidian dais", (0, 0, 0.35), (18.0, 14.0, 0.7), black, 0.22)
cube("Gold perimeter reveal", (0, 0, 0.72), (17.65, 13.65, 0.12), gold, 0.035)
cube("Ivory upper floor", (0, 0, 0.82), (17.25, 13.25, 0.14), ivory, 0.045)
# Decorative inset floor border, not raised.
for x in (-8.0, 8.0):
    cube("Flush gold floor border", (x, 0, 0.90), (0.055, 12.0, 0.018), gold, 0.005)
for y in (-6.0, 6.0):
    cube("Flush gold floor border", (0, y, 0.90), (16.0, 0.055, 0.018), gold, 0.005)

# Four gold structural masts and corner capitals.
for x in (-7.0, 7.0):
    for y in (-5.0, 5.0):
        cyl("Gold tent mast foot", (x, y, 1.55), 0.48, 1.15, gold)
        cyl("Turquoise mast collar", (x, y, 2.18), 0.34, 0.18, turquoise)
        cyl("Tall gold tent mast", (x, y, 5.15), 0.17, 6.0, gold)
        for z in (3.0, 7.2):
            cyl("Mast ring moulding", (x, y, z), 0.24, 0.12, turquoise)
        sphere("Mast finial", (x, y, 8.28), (0.34, 0.34, 0.48), gold)

# Central mast and royal finial.
cyl("Central royal mast base", (0, 0, 1.55), 0.78, 1.2, gold, 48)
cyl("Central royal mast", (0, 0, 6.1), 0.24, 9.0, gold, 48)
for z in (2.4, 9.7, 10.35):
    cyl("Central mast turquoise collar", (0, 0, z), 0.42, 0.18, turquoise, 48)
sphere("Central lotus finial", (0, 0, 10.9), (0.62, 0.62, 0.88), gold)
sphere("Finial turquoise jewel", (0, 0, 11.55), (0.24, 0.24, 0.32), turquoise)

# Tailored canopy: four sloping fabric planes rise to a high central peak.
corners = [(-8.0,-6.0,8.0),(8.0,-6.0,8.0),(8.0,6.0,8.0),(-8.0,6.0,8.0)]
peak = (0.0,0.0,10.7)
for i in range(4):
    j = (i + 1) % 4
    mesh_obj("Royal canopy fabric panel %02d" % (i+1), [corners[i], corners[j], peak],
             [(0,1,2)], lapis if i % 2 == 0 else midnight)
# Gold seam lines along each canopy rib.
for corner in corners:
    a = Vector(corner); b = Vector(peak)
    mid = (a+b)*0.5
    vec = b-a
    bpy.ops.mesh.primitive_cylinder_add(vertices=16, radius=0.055, depth=vec.length, location=mid)
    rib = bpy.context.object
    rib.name = "Raised gold canopy seam"
    rib.rotation_mode = "QUATERNION"
    rib.rotation_quaternion = Vector((0,0,1)).rotation_difference(vec.normalized())
    finish(rib, rib.name, gold)

# Deep decorative valance around the eaves, leaving a wide open front entrance.
for x in (-4.0, 4.0):
    cube("Side hanging blue valance", (x, 5.85, 6.55), (8.0, 0.18, 2.5), midnight, 0.06)
    cube("Side valance gold hem", (x, 5.72, 5.30), (8.0, 0.12, 0.14), gold, 0.025)
# Rear curtain wall and split side curtains; front remains welcoming and open.
cube("Rear royal curtain", (0, 5.88, 4.05), (15.8, 0.20, 5.2), midnight, 0.04)
for x in (-7.82, 7.82):
    cube("Side curtain panel", (x, 0.0, 4.05), (0.20, 11.6, 5.2), lapis, 0.04)
# Front entrance curtains are pulled to the sides, framing a broad central opening.
for x in (-6.65, 6.65):
    cube("Entrance gathered curtain", (x, -5.82, 4.15), (2.2, 0.20, 5.0), midnight, 0.08)
    for z in (2.0, 3.0, 4.0, 5.0, 6.0):
        sphere("Gold curtain tie ornament", (x + (0.9 if x < 0 else -0.9), -5.98, z), (0.12,0.08,0.12), gold)
cube("Front valance header", (0, -5.86, 6.62), (15.8, 0.24, 0.52), gold, 0.07)
cube("Front header blue inset", (0, -6.02, 6.62), (12.8, 0.08, 0.27), lapis, 0.025)

# Repeating gold and turquoise pharaonic medallions along the valance.
for x in range(-6, 7, 2):
    sphere("Valance turquoise jewel", (float(x), -6.10, 6.62), (0.16,0.07,0.16), turquoise)
    cube("Valance gold vertical stitch", (float(x), -6.12, 6.25), (0.045,0.045,0.42), gold, 0.01)

# Royal emblem above the entrance: winged solar disc abstraction.
sphere("Royal solar disc", (0, -6.16, 7.55), (0.72,0.14,0.72), gold)
for side in (-1,1):
    wing = cube("Solar emblem wing", (side*1.25,-6.12,7.55), (1.45,0.12,0.28), turquoise, 0.08)
    wing.rotation_euler[1] = side * math.radians(-12)
# Name plaque, actual 3D text in the exported asset.
def text_obj(name, body, size, loc, material):
    c = bpy.data.curves.new(name, type="FONT")
    c.body = body
    c.align_x = "CENTER"
    c.align_y = "CENTER"
    c.size = size
    c.extrude = 0.008
    o = bpy.data.objects.new(name, c)
    bpy.context.collection.objects.link(o)
    o.location = loc
    o.rotation_euler = (math.radians(90),0,0)
    o.data.materials.append(material)
    return o

text_obj("Main royal tent title", "THE ROYAL TENT", 0.48, (0,-6.22,6.62), gold)

# Four low lanterns at the corners; warm emissive inserts.
for x in (-7.2,7.2):
    for y in (-5.3,5.3):
        cube("Royal lantern pedestal", (x,y,1.45), (0.72,0.72,0.55), black, 0.08)
        cube("Lantern gold frame", (x,y,2.12), (0.48,0.48,0.88), gold, 0.04)
        sphere("Lantern warm light", (x,y,2.12), (0.20,0.20,0.32), glow)
        cube("Lantern cap", (x,y,2.62), (0.62,0.62,0.12), turquoise, 0.04)

# Low ornamental boundary rails on rear and sides; front path stays clear.
for x in (-8.5,8.5):
    cube("Side dais gold boundary", (x,0,1.16), (0.10,10.8,0.42), gold, 0.035)
for x in (-8.5,8.5):
    for y in (-5.2,5.2):
        sphere("Boundary lotus post cap", (x,y,1.55), (0.22,0.22,0.26), turquoise)

# Export the exact isolated scene as GLB.
bpy.ops.object.select_all(action="SELECT")
bpy.ops.export_scene.gltf(
    filepath=OUT, export_format="GLB", use_selection=True,
    export_apply=True, export_materials="EXPORT",
    export_cameras=False, export_lights=False
)
print("EXPORTED_MAIN_ROYAL_TENT:", OUT)
