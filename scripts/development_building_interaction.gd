extends Node3D
## نقطة التفاعل الخارجية لمبنى التطوير؛ تستخدم زر التفاعل الموحد.

@export var building_id: String = ""
@export var building_title: String = "مبنى التطوير"
@export var interaction_radius: float = 4.5

func _ready() -> void:
	add_to_group("city_interactables")

func get_development_data() -> Dictionary:
	return {
		"title": building_title,
		"building_id": building_id,
		"description": "طوّر مستواك من خلال خمس مراحل متسلسلة في هذا المبنى."
	}
