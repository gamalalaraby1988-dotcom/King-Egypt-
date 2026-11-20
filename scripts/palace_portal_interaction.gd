extends Node3D
## Palace doorway target handled by the shared MissionManager interaction button.

@export var interaction_radius: float = 3.6

func _ready() -> void:
	add_to_group("city_interactables")
