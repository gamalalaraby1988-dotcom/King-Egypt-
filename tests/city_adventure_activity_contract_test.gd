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
	if not manager_source.contains("const SURVIVAL_PREPARATION_SECONDS := 10.0") or not manager_source.contains("const SURVIVAL_DURATION_SECONDS := 60.0"):
		push_error("Survival race must use the approved 10-second preparation and 60-second duration.")
		quit(1)
		return
	if not manager_source.contains("func _update_survival_timers(") or not manager_source.contains("func _fail_local_survival_race("):
		push_error("Offline survival race must display and enforce its countdown.")
		quit(1)
		return
	if not server_source.contains("\"time_limit_seconds\": 60.0 if safe_mission_id == \"city_adventure_survival\" else 0.0") or not server_source.contains("receive_server_mission_failed"):
		push_error("Online survival race timeout must be enforced by the authoritative server.")
		quit(1)
		return
	if not manager_source.contains("func _show_adventure_treasure()") or not manager_source.contains("AdventureTreasureVisual") or not manager_source.contains("ChestBody") or not manager_source.contains("GoldenLid"):
		push_error("Treasure adventure must display a collectible chest visual at its final existing checkpoint.")
		quit(1)
		return
	if not manager_source.contains("if mission_id == \"city_adventure_treasure\" and stage_number == stage_count") or not manager_source.contains("_hide_adventure_treasure()"):
		push_error("Treasure visual must appear at the final checkpoint and be cleared on completion.")
		quit(1)
		return
	var npc_source := FileAccess.get_file_as_string("res://scripts/city_npc_population.gd")
	if not manager_source.contains("RescueCitizenInteractionButton") or not manager_source.contains("func _interact_with_rescue_citizen(") or not manager_source.contains("request_rescue_citizen_interaction.rpc_id(1)"):
		push_error("Rescue adventure must provide a direct player interaction with the citizen.")
		quit(1)
		return
	if not server_source.contains("func request_rescue_citizen_interaction()") or not server_source.contains("rescue_requires_interaction"):
		push_error("Online rescue progression must require server-validated citizen interaction.")
		quit(1)
		return
	if not npc_source.contains("func get_nearest_active_citizen(") or not npc_source.contains("func set_rescue_citizen(") or not npc_source.contains('"wave"'):
		push_error("Rescue must reuse an existing city resident and its wave animation.")
		quit(1)
		return
	if not manager_source.contains("func _submit_message_puzzle_answer()") or not manager_source.contains("MysteryMessageAnswer") or not manager_source.contains("SubmitMysteryMessageAnswer"):
		push_error("Mystery message must expose an answer input and explicit submit interaction.")
		quit(1)
		return
	if not manager_source.contains("الدليل الأول:") or not manager_source.contains("الدليل الثاني:") or not manager_source.contains("الدليل الثالث:") or not manager_source.contains('normalized_answer == "النيل"'):
		push_error("Mystery message must reveal three clues and validate the decoded answer.")
		quit(1)
		return
	if not server_source.contains("func request_submit_message_puzzle_answer(answer: String)") or not server_source.contains('normalized_answer != "النيل"') or not server_source.contains('"puzzle_ready"') or not server_source.contains("mission_stages.size() + 1"):
		push_error("Online mystery answer must be unlocked and validated by the server only after the final checkpoint.")
		quit(1)
		return
	if not manager_source.contains("stage_number > stage_count") or not manager_source.contains("adventure_stage_index = stage_count - 1"):
		push_error("The mystery cipher must remain hidden until the server confirms arrival at the final checkpoint.")
		quit(1)
		return
	print("City adventure activity contract checks passed.")
	quit(0)
