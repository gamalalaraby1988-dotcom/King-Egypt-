extends SceneTree

func _initialize() -> void:
	call_deferred("_run_startup_loading_contract")

func _run_startup_loading_contract() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if source.is_empty():
		push_error("Could not read main.gd.")
		quit(1)
		return

	var ready_start := source.find("func _ready() -> void:")
	var ready_end := source.find("func _create_startup_loading_ui()")
	if ready_start < 0 or ready_end <= ready_start:
		push_error("Could not locate the client startup initialization block.")
		quit(1)
		return
	var ready_block := source.substr(ready_start, ready_end - ready_start)
	if not ready_block.contains("_create_mode_selection_ui()"):
		push_error("The entry screen must be created during initial startup.")
		quit(1)
	for forbidden in ["_create_ground()", "_create_city()", "_create_approved_city_layout()", "_create_mobile_hud()"]:
		if ready_block.contains(forbidden):
			push_error("World generation must not run before mode selection: " + forbidden)
			quit(1)
			return

	var world_start := source.find("func _initialize_game_world()")
	var world_end := source.find("func _create_city_npc_population()")
	if world_start < 0 or world_end <= world_start:
		push_error("Deferred world initialization function is missing.")
		quit(1)
		return
	var world_block := source.substr(world_start, world_end - world_start)
	for required in [
		"_create_ground()",
		"_create_city()",
		"_create_approved_city_layout()",
		"_create_mobile_hud()",
		"_create_interactive_buildings()",
		"_create_city_npc_population()",
		"_create_interior_transition_ui()",
		"_create_player_vehicle()",
		"_set_startup_loading_progress(100.0"
	]:
		if not world_block.contains(required):
			push_error("Startup loading stage is missing: " + required)
			quit(1)
			return
	if not source.contains("await get_tree().process_frame"):
		push_error("Startup progress must yield frames so the loading UI can render.")
		quit(1)
		return
	if not source.contains("func _set_startup_loading_progress(value: float, message: String)"):
		push_error("Startup loading progress updater is missing.")
		quit(1)
		return

	print("City startup and staged loading contract tests passed.")
	quit(0)
