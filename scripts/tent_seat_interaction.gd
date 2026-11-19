extends Node3D
## نقطة جلوس تفاعلية داخل خيام المخيم الملكي.

@export var seat_title: String = "جلسة الخيمة"
@export var interaction_radius: float = 2.8

func _ready() -> void:
	if not is_in_group("city_interactables"):
		add_to_group("city_interactables")

func get_interaction_data() -> Dictionary:
	return {
		"title": seat_title,
		"description": "اجلس واستمتع بإطلالة الأهرامات من داخل الخيمة."
	}

func sit_player(player: CharacterBody3D) -> bool:
	if not is_instance_valid(player) or not player.has_method("sit_at_position"):
		return false
	var sitting_position := global_position + Vector3(0, 0, 0.12)
	return bool(player.call("sit_at_position", sitting_position, global_rotation.y))
