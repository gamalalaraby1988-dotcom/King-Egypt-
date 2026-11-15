extends Node3D
## صندوق مكافأة يومي فرعوني؛ يمنح الاستلام بعد ربط خدمة المكافآت الخادمية.

@export var interaction_radius: float = 3.5
@export var chest_title: String = "صندوق المكافأة الفرعوني"

func _ready() -> void:
	add_to_group("city_interactables")
	add_to_group("daily_reward_chests")
	_build_chest()

func get_daily_reward_chest_data() -> Dictionary:
	return {
		"title": chest_title,
		"description": "صندوق يومي صغير بزخارف فرعونية. لكل لاعب استلام مستقل مرة واحدة يوميًا.",
		"interaction": "open"
	}

func _material(color: Color, metallic: float = 0.0, roughness: float = 0.45) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = metallic
	mat.roughness = roughness
	return mat

func _add_box(part_name: String, size: Vector3, offset: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = offset
	part.material_override = material
	add_child(part)
	return part

func _add_cylinder(part_name: String, radius: float, height: float, offset: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	part.mesh = mesh
	part.position = offset
	part.material_override = material
	add_child(part)
	return part

func _build_chest() -> void:
	var gold := _material(Color(0.86, 0.62, 0.19), 0.78, 0.24)
	var bright_gold := _material(Color(1.0, 0.82, 0.39), 0.68, 0.2)
	var lapis := _material(Color(0.035, 0.19, 0.34), 0.42, 0.3)
	var turquoise := _material(Color(0.04, 0.53, 0.52), 0.36, 0.3)
	var dark := _material(Color(0.055, 0.075, 0.09), 0.35, 0.34)

	_add_box("StoneFoot", Vector3(1.62, 0.16, 1.12), Vector3(0, 0.08, 0), dark)
	_add_box("GoldBase", Vector3(1.52, 0.12, 1.02), Vector3(0, 0.19, 0), gold)
	_add_box("ChestBody", Vector3(1.38, 0.66, 0.9), Vector3(0, 0.56, 0), lapis)
	_add_box("FrontGoldBand", Vector3(1.42, 0.09, 0.94), Vector3(0, 0.38, 0), gold)
	_add_box("LeftGoldCorner", Vector3(0.1, 0.7, 0.96), Vector3(-0.66, 0.57, 0), bright_gold)
	_add_box("RightGoldCorner", Vector3(0.1, 0.7, 0.96), Vector3(0.66, 0.57, 0), bright_gold)
	_add_box("Lid", Vector3(1.48, 0.22, 1.0), Vector3(0, 1.0, 0), turquoise)
	_add_box("LidGoldTrim", Vector3(1.52, 0.07, 1.04), Vector3(0, 0.88, 0), gold)
	_add_box("LidTopGoldInlay", Vector3(0.82, 0.045, 0.48), Vector3(0, 1.135, 0), bright_gold)
	_add_cylinder("FrontAnkhMedallion", 0.19, 0.07, Vector3(0, 0.59, 0.49), gold)
	_add_box("AnkhStem", Vector3(0.055, 0.23, 0.045), Vector3(0, 0.58, 0.535), bright_gold)
	_add_box("AnkhCross", Vector3(0.2, 0.05, 0.045), Vector3(0, 0.62, 0.535), bright_gold)
	_add_box("FrontLock", Vector3(0.16, 0.18, 0.07), Vector3(0, 0.36, 0.51), gold)
	_add_cylinder("LockStud", 0.045, 0.075, Vector3(0, 0.36, 0.56), dark)
	for x in [-0.42, 0.42]:
		_add_box("LidStripe_%s" % str(x), Vector3(0.055, 0.16, 1.01), Vector3(x, 1.0, 0), gold)
