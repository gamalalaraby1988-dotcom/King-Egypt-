extends Node3D
## بوابة تفاعلية موحدة لوجهات السفينة. يتولى MissionManager إظهار زر التفاعل المعتاد.

@export var gate_id: String = "ship_main"
@export var gate_title: String = "بوابة السفينة"
@export var interaction_radius: float = 4.2
@export var location_id: String = "ship_exterior"

func _ready() -> void:
	add_to_group("ship_interactables")
	add_to_group("city_interactables")

func get_quick_travel_data() -> Dictionary:
	return {
		"title": gate_title,
		"gate_id": gate_id,
		"location_id": location_id
	}
