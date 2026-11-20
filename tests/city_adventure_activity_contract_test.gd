extends SceneTree

func _initialize() -> void:
	call_deferred("_run_city_adventure_contract")

func _run_city_adventure_contract() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var manager_source := FileAccess.get_file_as_string("res://scripts/mission_manager.gd")
	var server_source := FileAccess.get_file_as_string("res://scripts/authoritative_game_server.gd")
	var expected_ids := [
		"city_adventure_rescue",
		"city_adventure_treasure",
		"city_adventure_message",
		"city_adventure_survival"
	]
	for adventure_id in expected_ids:
		if not manager_source.contains("\"%s\"" % adventure_id) or not server_source.contains("\"%s\"" % adventure_id):
			push_error("Adventure must be declared by both client manager and server: " + adventure_id)
			quit(1)
			return
	if not main_source.contains("func _create_adventure_hub_interaction()") or not main_source.contains("hub.position = Vector3(-75.0, 0.0, 63.9)"):
		push_error("Adventure entry interaction must remain at the existing adventure_center building.")
		quit(1)
		return
	var hub_start := main_source.find("func _create_adventure_hub_interaction()")
	var hub_end := main_source.find("func _add_functional_building(", hub_start)
	if hub_start < 0 or hub_end <= hub_start:
		push_error("Could not inspect the adventure hub interaction implementation.")
		quit(1)
		return
	var hub_source := main_source.substr(hub_start, hub_end - hub_start)
	for forbidden in ["_create_box(", "BoxMesh.new()", "StaticBody3D.new()", "CollisionShape3D.new()"]:
		if hub_source.contains(forbidden):
			push_error("Adventure hub must not create new environment geometry or collision: " + forbidden)
			quit(1)
			return
	if not manager_source.contains("func _advance_local_adventure_stage()") or not manager_source.contains("func _on_server_mission_stage_updated("):
		push_error("Both offline and server-authoritative adventure stage progression must exist.")
		quit(1)
		return
	if not server_source.contains("func receive_mission_stage_updated(") or not server_source.contains("stage_index + 1 < mission_stages.size()"):
		push_error("Server must advance ordered adventure checkpoints.")
		quit(1)
		return
	if not server_source.contains("if not completed_mission_id.begins_with(\"city_adventure_\")"):
		push_error("Adventure activities must not issue unconfigured rewards.")
		quit(1)
		return
	print("City adventure activity contract checks passed.")
	quit(0)
