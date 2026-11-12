extends Node3D
## بيانات مبنى ومهمته الوظيفية.

@export var building_id: String = "building_default"
@export var building_title: String = "مبنى"
@export var mission_title: String = "مهمة"
@export_multiline var mission_description: String = "نفّذ الهدف المحدد."
@export var reward_money: int = 100
@export var reward_chips: int = 0
@export var reward_xp: int = 25
@export var required_level: int = 1
@export var requires_interior: bool = false
@export var interaction_radius: float = 4.5
@export_multiline var activity_list: String = "المهام المتاحة من هذا المكان"
@export var target_offset: Vector3 = Vector3(0, 0, -10)

func _ready() -> void:
	add_to_group("city_interactables")

func get_mission_data() -> Dictionary:
	return {
		"title": mission_title,
		"description": mission_description,
		"money": reward_money,
		"chips": reward_chips,
		"xp": reward_xp,
		"level": required_level,
		"target_offset": target_offset,
		"requires_interior": requires_interior,
		"activities": activity_list
	}
