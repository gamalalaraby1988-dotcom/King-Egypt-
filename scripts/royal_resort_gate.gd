extends Node3D

@export var gate_id: String = ""
@export var gate_title: String = "بوابة المنتجع"
@export var required_level: int = 1
@export var destination_offset: Vector3 = Vector3.ZERO
@export var gate_kind: String = "zone"
var interaction_radius: float = 4.5

func _ready() -> void:
	add_to_group("city_interactables")

func get_royal_resort_gate_data() -> Dictionary:
	return {
		"gate_id": gate_id,
		"title": gate_title,
		"required_level": required_level,
		"destination_offset": destination_offset,
		"gate_kind": gate_kind
	}
