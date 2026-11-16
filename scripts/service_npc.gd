extends Node3D

const CollisionProfile = preload("res://scripts/city_collision_profile.gd")
## مالك متجر أو موظف خدمة ثابت وخفيف على الأداء.

@export var character_name: String = "موظف"
@export_multiline var interaction_text: String = "أهلًا بك! كيف يمكنني مساعدتك؟"
@export var interaction_radius: float = 4.0
@export var role_title: String = "موظف خدمة"
@export var name_key: String = ""
@export var role_key: String = ""
@export var interaction_key: String = ""

func _ready() -> void:
	add_to_group("city_interactables")
	add_to_group("city_service_staff")
	_build_visual()
	CollisionProfile.add_staff_collider(self, 0.34, 1.8)

func _build_visual() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.16, 0.30, 0.48) if role_title != "صاحب محل" else Color(0.48, 0.28, 0.12)
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.30
	mesh.height = 1.55
	body.mesh = mesh
	body.position.y = 0.78
	body.material_override = material
	add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.22
	head_mesh.height = 0.44
	head.mesh = head_mesh
	head.position.y = 1.72
	head.material_override = StandardMaterial3D.new()
	head.material_override.albedo_color = Color(0.72, 0.52, 0.38)
	add_child(head)

func get_interaction_data() -> Dictionary:
	var shown_name := CityLanguage.translate(name_key) if not name_key.is_empty() else character_name
	var shown_role := CityLanguage.translate(role_key) if not role_key.is_empty() else role_title
	var shown_text := CityLanguage.translate(interaction_key) if not interaction_key.is_empty() else interaction_text
	return {
		"kind": "service_staff",
		"title": shown_name + " — " + shown_role,
		"description": shown_text,
		"activities": shown_role
	}

func is_shop_owner() -> bool:
	return character_name == "صاحب المتجر"
