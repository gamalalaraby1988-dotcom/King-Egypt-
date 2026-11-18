extends Node3D
## المرحلة 11: ملامح وجه وشعر أولية، مع نقاط تركيب لأصول الملابس والشعر النهائية.
## جميع الأشكال الحالية Placeholder هندسية وليست نماذج فنية أو Rig نهائيًا.

const SKIN := Color("#c98f68")
const HAIR := Color("#241b18")
const EYE_WHITE := Color("#f4eee4")
const EYE_DARK := Color("#29211e")
const OUTFIT_SCENES := {
	"men_formal": "res://assets/outfits/men_formal.tscn",
	"women_formal": "res://assets/outfits/women_formal.tscn",
	"urban_casual": "res://assets/outfits/urban_casual.tscn",
	"sport": "res://assets/outfits/sport.tscn"
}
const HAIR_SCENES := {
	"short": "res://assets/hairstyles/short.tscn",
	"long": "res://assets/hairstyles/long.tscn",
	"curly": "res://assets/hairstyles/curly.tscn"
}

var parts: Dictionary = {}
var current_outfit := "default"
var current_hairstyle := "short"
var outfit_mount: Node3D
var hair_mount: Node3D
var motion_state := "idle"
var motion_speed := 0.0
var motion_time := 0.0
var animated_defaults: Dictionary = {}

func _ready() -> void:
	_build_base_character()
	_build_face()
	_build_hair_placeholders()
	apply_outfit(current_outfit)
	apply_hairstyle(current_hairstyle)
	_cache_animation_defaults()


func apply_character_identity(character_id: String) -> void:
	# Fixed in-game presets for the roster; this is not a wardrobe/customization system.
	var is_female := character_id.contains("_f_")
	var palette_index := absi(character_id.hash()) % 4
	var skin_tones: Array[Color] = [
		Color("#c98f68"), Color("#a96f50"), Color("#e0ad83"), Color("#86583f")
	]
	var hair_tones: Array[Color] = [
		Color("#241b18"), Color("#493025"), Color("#17191e"), Color("#76503a")
	]
	var outfit_tones: Array[Color] = [
		Color("#315b78"), Color("#466b5b"), Color("#75445d"), Color("#66543c")
	]
	var skin := skin_tones[palette_index]
	var hair := hair_tones[palette_index]
	var outfit := outfit_tones[palette_index]
	for part_name in ["Head", "Neck", "LeftArm", "RightArm", "LeftEar", "RightEar"]:
		_set_part_color(part_name, skin)
	for part_name in ["ShortHairCap", "LongHairBack", "CurlyHairCap", "Curl_0", "Curl_1", "Curl_2", "Curl_3", "Curl_4"]:
		_set_part_color(part_name, hair)
	if is_female:
		apply_outfit("women_formal")
		apply_hairstyle("long")
		_set_part_color("SkirtLayer", outfit)
		_set_part_color("WomenFormalTopLayer", outfit.lightened(0.12))
	else:
		apply_outfit("men_formal")
		apply_hairstyle("short")
		_set_part_color("JacketLayer", outfit)
		_set_part_color("ShirtLayer", Color("#e8e6df"))
		_set_part_color("TieLayer", outfit.darkened(0.25))

func set_motion_state(state: String, speed: float = 0.0) -> void:
	motion_state = state if ["idle", "walk", "run", "sit", "talk", "wave"].has(state) else "idle"
	motion_speed = maxf(speed, 0.0)

func _process(delta: float) -> void:
	motion_time += delta
	var intensity := 1.0 if motion_state == "walk" else (1.35 if motion_state == "run" else 0.0)
	var cycle_speed := 7.0 if motion_state == "walk" else 11.0
	var swing := sin(motion_time * cycle_speed) * 0.48 * intensity
	var bob := absf(sin(motion_time * cycle_speed * 2.0)) * 0.045 * intensity
	_restore_animation_defaults()
	if motion_state == "wave" or motion_state == "talk":
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation.z = -0.18
		if parts.has("RightArm"):
			var gesture := sin(motion_time * (5.5 if motion_state == "wave" else 3.2))
			(parts["RightArm"] as MeshInstance3D).rotation.z = -1.05 + gesture * (0.28 if motion_state == "wave" else 0.08)
			(parts["RightArm"] as MeshInstance3D).rotation.x = -0.22 if motion_state == "wave" else gesture * 0.12
		if parts.has("TorsoBase") and motion_state == "talk":
			(parts["TorsoBase"] as MeshInstance3D).rotation.y = sin(motion_time * 3.2) * 0.035
		return
	if motion_state == "sit":
		if parts.has("TorsoBase"):
			(parts["TorsoBase"] as MeshInstance3D).position.y = 0.91
		if parts.has("LeftLeg"):
			(parts["LeftLeg"] as MeshInstance3D).rotation.x = -1.05
			(parts["LeftLeg"] as MeshInstance3D).position.y = 0.30
		if parts.has("RightLeg"):
			(parts["RightLeg"] as MeshInstance3D).rotation.x = -1.05
			(parts["RightLeg"] as MeshInstance3D).position.y = 0.30
		if parts.has("LeftArm"):
			(parts["LeftArm"] as MeshInstance3D).rotation.z = -0.75
		if parts.has("RightArm"):
			(parts["RightArm"] as MeshInstance3D).rotation.z = 0.75
		return
	if parts.has("TorsoBase"):
		(parts["TorsoBase"] as MeshInstance3D).position.y += bob
	for limb_name in ["LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		if parts.has(limb_name):
			var limb := parts[limb_name] as MeshInstance3D
			var sign := -1.0 if limb_name in ["LeftArm", "RightLeg"] else 1.0
			if limb_name.ends_with("Arm"):
				limb.rotation.x = swing * sign
			else:
				limb.rotation.x = -swing * sign

func _cache_animation_defaults() -> void:
	for limb_name in ["TorsoBase", "LeftArm", "RightArm", "LeftLeg", "RightLeg"]:
		if parts.has(limb_name):
			var limb := parts[limb_name] as MeshInstance3D
			animated_defaults[limb_name] = {"position": limb.position, "rotation": limb.rotation}

func _restore_animation_defaults() -> void:
	for limb_name in animated_defaults:
		if parts.has(limb_name):
			var limb := parts[limb_name] as MeshInstance3D
			var defaults: Dictionary = animated_defaults[limb_name]
			limb.position = defaults["position"]
			limb.rotation = defaults["rotation"]

func _build_base_character() -> void:
	var skin_mat := _material(SKIN)
	var body_mat := _material(Color("#41658b"))
	var shoe_mat := _material(Color("#29231f"))
	_add_capsule("Head", 0.22, 0.46, Vector3(0, 1.68, 0), skin_mat)
	_add_capsule("Neck", 0.09, 0.20, Vector3(0, 1.42, 0), skin_mat)
	_add_capsule("TorsoBase", 0.27, 0.72, Vector3(0, 1.08, 0), body_mat)
	_add_capsule("LeftArm", 0.105, 0.62, Vector3(-0.36, 1.08, 0), skin_mat)
	_add_capsule("RightArm", 0.105, 0.62, Vector3(0.36, 1.08, 0), skin_mat)
	_add_capsule("LeftLeg", 0.13, 0.78, Vector3(-0.15, 0.43, 0), body_mat)
	_add_capsule("RightLeg", 0.13, 0.78, Vector3(0.15, 0.43, 0), body_mat)
	_add_box("LeftShoe", Vector3(0.22, 0.12, 0.34), Vector3(-0.15, 0.08, -0.055), _material(shoe_mat.albedo_color))
	_add_box("RightShoe", Vector3(0.22, 0.12, 0.34), Vector3(0.15, 0.08, -0.055), _material(shoe_mat.albedo_color))

	# طبقات بديلة مؤقتة؛ يمكن استبدالها بمشاهد مستقلة من مجلد assets/outfits.
	_add_capsule("JacketLayer", 0.292, 0.76, Vector3(0, 1.08, -0.012), _material(Color("#202735")))
	_add_capsule("ShirtLayer", 0.205, 0.59, Vector3(0, 1.10, -0.045), _material(Color("#e8e6df")))
	_add_box("TieLayer", Vector3(0.055, 0.34, 0.035), Vector3(0, 1.13, -0.16), _material(Color("#9d3030")))
	_add_cylinder("SkirtLayer", 0.30, 0.52, Vector3(0, 0.72, 0), _material(Color("#8b3152")))
	_add_capsule("WomenFormalTopLayer", 0.285, 0.72, Vector3(0, 1.08, -0.012), _material(Color("#8b3152")))
	_add_capsule("CasualTopLayer", 0.29, 0.74, Vector3(0, 1.08, -0.012), _material(Color("#426f64")))
	_add_capsule("SportTopLayer", 0.29, 0.74, Vector3(0, 1.08, -0.012), _material(Color("#d56a28")))

	outfit_mount = Node3D.new()
	outfit_mount.name = "OutfitMount"
	add_child(outfit_mount)
	hair_mount = Node3D.new()
	hair_mount.name = "HairMount"
	add_child(hair_mount)

func _build_face() -> void:
	var white := _material(EYE_WHITE)
	var dark := _material(EYE_DARK)
	var skin := _material(Color("#b97c59"))
	var mouth := _material(Color("#713e39"))
	# الوجه يتجه إلى -Z؛ تفاصيل صغيرة لتظل خفيفة على الهاتف.
	_add_sphere("LeftEyeWhite", Vector3(0.075, 0.055, 0.035), Vector3(-0.085, 1.72, -0.197), white)
	_add_sphere("RightEyeWhite", Vector3(0.075, 0.055, 0.035), Vector3(0.085, 1.72, -0.197), white)
	_add_sphere("LeftPupil", Vector3(0.027, 0.034, 0.018), Vector3(-0.085, 1.72, -0.229), dark)
	_add_sphere("RightPupil", Vector3(0.027, 0.034, 0.018), Vector3(0.085, 1.72, -0.229), dark)
	_add_box("LeftEyebrow", Vector3(0.13, 0.025, 0.025), Vector3(-0.085, 1.805, -0.202), dark)
	_add_box("RightEyebrow", Vector3(0.13, 0.025, 0.025), Vector3(0.085, 1.805, -0.202), dark)
	_add_sphere("Nose", Vector3(0.045, 0.065, 0.055), Vector3(0, 1.635, -0.218), skin)
	_add_box("Mouth", Vector3(0.09, 0.018, 0.018), Vector3(0, 1.565, -0.211), mouth)
	_add_sphere("LeftEar", Vector3(0.045, 0.09, 0.07), Vector3(-0.218, 1.66, 0), _material(SKIN))
	_add_sphere("RightEar", Vector3(0.045, 0.09, 0.07), Vector3(0.218, 1.66, 0), _material(SKIN))

func _build_hair_placeholders() -> void:
	_add_sphere("ShortHairCap", Vector3(0.235, 0.13, 0.235), Vector3(0, 1.88, 0.005), _material(HAIR))
	_add_sphere("LongHairBack", Vector3(0.22, 0.30, 0.12), Vector3(0, 1.69, 0.13), _material(HAIR))
	_add_sphere("CurlyHairCap", Vector3(0.25, 0.17, 0.25), Vector3(0, 1.87, 0.005), _material(Color("#35251f")))
	for i in range(5):
		var x := -0.16 + float(i) * 0.08
		_add_sphere("Curl_%d" % i, Vector3(0.07, 0.07, 0.07), Vector3(x, 1.91, -0.09), _material(Color("#35251f")))


func _set_part_color(part_name: String, color: Color) -> void:
	if not parts.has(part_name):
		return
	var mesh_instance := parts[part_name] as MeshInstance3D
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh_instance.material_override = material

func apply_outfit(outfit_id: String) -> void:
	current_outfit = outfit_id
	var ids := ["JacketLayer", "ShirtLayer", "TieLayer", "SkirtLayer", "WomenFormalTopLayer", "CasualTopLayer", "SportTopLayer"]
	for part_id in ids:
		_set_visible(part_id, false)
	_set_visible("TorsoBase", outfit_id == "default")
	_set_visible("LeftLeg", outfit_id != "women_formal")
	_set_visible("RightLeg", outfit_id != "women_formal")
	_set_visible("LeftArm", true)
	_set_visible("RightArm", true)
	if outfit_id == "men_formal":
		_set_visible("JacketLayer", true)
		_set_visible("ShirtLayer", true)
		_set_visible("TieLayer", true)
	elif outfit_id == "women_formal":
		_set_visible("SkirtLayer", true)
		_set_visible("WomenFormalTopLayer", true)
	elif outfit_id == "urban_casual":
		_set_visible("CasualTopLayer", true)
	elif outfit_id == "sport":
		_set_visible("SportTopLayer", true)
	var external_outfit := _apply_external_scene(outfit_mount, OUTFIT_SCENES.get(outfit_id, ""))
	if external_outfit:
		for part_id in ids:
			_set_visible(part_id, false)

func apply_hairstyle(hairstyle_id: String) -> void:
	current_hairstyle = hairstyle_id if HAIR_SCENES.has(hairstyle_id) else "short"
	_set_visible("ShortHairCap", current_hairstyle == "short")
	_set_visible("LongHairBack", current_hairstyle == "long")
	_set_visible("CurlyHairCap", current_hairstyle == "curly")
	for i in range(5):
		_set_visible("Curl_%d" % i, current_hairstyle == "curly")
	var external_hair := _apply_external_scene(hair_mount, HAIR_SCENES.get(current_hairstyle, ""))
	if external_hair:
		_set_visible("ShortHairCap", false)
		_set_visible("LongHairBack", false)
		_set_visible("CurlyHairCap", false)
		for i in range(5):
			_set_visible("Curl_%d" % i, false)

func _apply_external_scene(mount: Node3D, scene_path: String) -> bool:
	for child in mount.get_children():
		mount.remove_child(child)
		child.queue_free()
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return false
	var packed := load(scene_path) as PackedScene
	if packed != null:
		mount.add_child(packed.instantiate())
		return true
	return false

func _set_visible(part_name: String, is_visible: bool) -> void:
	if parts.has(part_name):
		(parts[part_name] as MeshInstance3D).visible = is_visible

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.82
	return mat

func _add_capsule(part_name: String, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	_add_mesh(part_name, mesh, pos, mat)

func _add_cylinder(part_name: String, radius: float, height: float, pos: Vector3, mat: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius * 0.72
	mesh.bottom_radius = radius
	mesh.height = height
	_add_mesh(part_name, mesh, pos, mat)

func _add_box(part_name: String, dimensions: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	_add_mesh(part_name, mesh, pos, mat)

func _add_sphere(part_name: String, dimensions: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.scale = dimensions
	instance.position = pos
	instance.material_override = mat
	add_child(instance)
	parts[part_name] = instance

func _add_mesh(part_name: String, mesh: Mesh, pos: Vector3, mat: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = part_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = mat
	add_child(instance)
	parts[part_name] = instance


func apply_npc_identity(character_id: String, npc_gender: String) -> void:
	# NPC-only appearance variation; the approved 16-character roster is unchanged.
	var skin_tones: Array[Color] = [Color("#c98f68"), Color("#a96f50"), Color("#e0ad83"), Color("#86583f")]
	var hair_tones: Array[Color] = [Color("#241b18"), Color("#493025"), Color("#17191e"), Color("#76503a")]
	var outfit_tones: Array[Color] = [Color("#315b78"), Color("#466b5b"), Color("#75445d"), Color("#66543c")]
	var skin_index := absi(character_id.hash()) % skin_tones.size()
	var hair_index := absi(int(character_id.hash() / 7)) % hair_tones.size()
	var outfit_index := absi(int(character_id.hash() / 13)) % outfit_tones.size()
	var skin := skin_tones[skin_index]
	var hair := hair_tones[hair_index]
	var outfit := outfit_tones[outfit_index]
	for part_name in ["Head", "Neck", "LeftArm", "RightArm", "LeftEar", "RightEar"]:
		_set_part_color(part_name, skin)
	for part_name in ["ShortHairCap", "LongHairBack", "CurlyHairCap", "Curl_0", "Curl_1", "Curl_2", "Curl_3", "Curl_4"]:
		_set_part_color(part_name, hair)
	if npc_gender == "female":
		apply_outfit("women_formal")
		apply_hairstyle("long" if outfit_index % 2 == 0 else "curly")
		_set_part_color("SkirtLayer", outfit)
		_set_part_color("WomenFormalTopLayer", outfit.lightened(0.12))
	else:
		apply_outfit("men_formal")
		apply_hairstyle("short" if outfit_index % 2 == 0 else "curly")
		_set_part_color("JacketLayer", outfit)
		_set_part_color("ShirtLayer", Color("#e8e6df"))
		_set_part_color("TieLayer", outfit.darkened(0.25))
