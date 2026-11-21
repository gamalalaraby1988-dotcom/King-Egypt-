extends SceneTree

func _initialize() -> void:
	call_deferred("_run_city_adventure_contract")

func _run_city_adventure_contract() -> void:
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var manager_source := FileAccess.get_file_as_string("res://scripts/mission_manager.gd")
	var city_layout_source := FileAccess.get_file_as_string("res://scripts/approved_city_layout.gd")
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
	if not city_layout_source.contains('["adventure_center","مركز المغامرات",Vector3(-75,0,58)') or not city_layout_source.contains("half_d - wall_depth * 0.5"):
		push_error("Adventure hub anchor must line up with the entrance of the existing adventure center.")
		quit(1)
		return
	if not main_source.contains("for road_z in [-15.0, 15.0, 45.0]") or not main_source.contains('Vector3(0, 0.006, road_z), side_road_color'):
		push_error("Survival race must stay on the existing east-west street at z=45.")
		quit(1)
		return
	if not manager_source.contains("Vector3(-60.0, 0.15, 45.0)") or not manager_source.contains("Vector3(60.0, 0.15, 45.0)"):
		push_error("Survival race checkpoints must remain within the existing z=45 road corridor.")
		quit(1)
		return
	for existing_entrance in ['["fire_rescue","مركز الإطفاء والإنقاذ",Vector3(-75,0,15)', '["police_station","مركز الشرطة",Vector3(-75,0,-5)', '["supermarket","السوبر ماركت",Vector3(-30,0,-30)', '["cinema","السينما",Vector3(60,0,30)']:
		if not city_layout_source.contains(existing_entrance):
			push_error("Adventure checkpoint references a building that is missing from the approved city layout.")
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
	var local_fail_start := manager_source.find("func _fail_local_survival_race()")
	var local_fail_end := manager_source.find("func _advance_local_adventure_stage(", local_fail_start)
	if local_fail_start < 0 or local_fail_end <= local_fail_start:
		push_error("Could not inspect local survival failure handler.")
		quit(1)
		return
	var local_fail_source := manager_source.substr(local_fail_start, local_fail_end - local_fail_start)
	if local_fail_source.contains("mission_id") or local_fail_source.contains("message"):
		push_error("Offline survival failure handler must not reference server-only callback parameters.")
		quit(1)
		return
	if not manager_source.contains("SurvivalRaceProgress") or not manager_source.contains("SurvivalRaceProgressBar") or not manager_source.contains("func _update_survival_race_hud("):
		push_error("Survival race must show live five-checkpoint progress to the player.")
		quit(1)
		return
	if not manager_source.contains("نقاط السباق: %d / 5") or not manager_source.contains("النقطة %d من 5"):
		push_error("Survival race must report the current checkpoint count alongside the timer.")
		quit(1)
		return
	if not server_source.contains("\"time_limit_seconds\": 60.0 if mission_id == \"city_adventure_survival\" else 0.0") or not server_source.contains("receive_server_mission_failed"):
		push_error("Online survival race timeout must be enforced by the authoritative server.")
		quit(1)
		return
	var server_failure_start := manager_source.find("func _on_server_mission_failed(")
	var server_failure_end := manager_source.find("func _on_server_mission_completed(", server_failure_start)
	if server_failure_start < 0 or server_failure_end <= server_failure_start:
		push_error("Could not inspect online survival failure cleanup.")
		quit(1)
		return
	var server_failure_source := manager_source.substr(server_failure_start, server_failure_end - server_failure_start)
	if not server_failure_source.contains("survival_progress_label.visible = false") or not server_failure_source.contains("survival_progress_bar.visible = false") or not server_failure_source.contains("_hide_adventure_treasure()"):
		push_error("Online race failure must clear the race progress HUD.")
		quit(1)
		return
	if not manager_source.contains("func _show_adventure_treasure()") or not manager_source.contains("AdventureTreasureVisual") or not manager_source.contains("ChestBody") or not manager_source.contains("GoldenLid"):
		push_error("Treasure adventure must display a collectible chest visual at its final existing checkpoint.")
		quit(1)
		return
	if not manager_source.contains("chest.global_position = active_target + Vector3(0.0, 0.34, 0.0)"):
		push_error("Treasure visual must sit close to the ground at the existing final checkpoint.")
		quit(1)
		return
	var completion_start := manager_source.find("func _complete_active_mission()")
	var completion_end := manager_source.find("func _update_navigation_hud(", completion_start)
	if completion_start < 0 or completion_end <= completion_start:
		push_error("Could not inspect adventure completion side effects.")
		quit(1)
		return
	var completion_source := manager_source.substr(completion_start, completion_end - completion_start)
	var adventure_completion_start := completion_source.find("if selected_activity_kind == \"adventure\":")
	var generic_completion_start := completion_source.find("var data: Dictionary = active_mission.get_mission_data()")
	if adventure_completion_start < 0 or generic_completion_start <= adventure_completion_start:
		push_error("Adventure completion must exit before generic mission settlement.")
		quit(1)
		return
	var adventure_completion_source := completion_source.substr(adventure_completion_start, generic_completion_start - adventure_completion_start)
	if adventure_completion_source.contains("complete_activity_once(") or adventure_completion_source.contains("record_mission_completed("):
		push_error("Adventure completion must not trigger generic rewards, daily tasks, or achievements.")
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
	if not server_source.contains("func request_cancel_mission()") or not server_source.contains('if not mission_id.begins_with("city_adventure_")') or not manager_source.contains("AuthoritativeGameServer.request_cancel_mission.rpc_id(1)"):
		push_error("Online adventure cancellation must clear the active server mission instead of orphaning it.")
		quit(1)
		return
	if not manager_source.contains("جارٍ إلغاء المغامرة من الخادم...") or not manager_source.contains("_hide_adventure_treasure()"):
		push_error("Adventure cancellation must wait for server confirmation and clean local visuals.")
		quit(1)
		return
	var local_process_start := manager_source.find("func _process(")
	var local_process_end := manager_source.find("func _update_interaction_target(", local_process_start)
	if local_process_start < 0 or local_process_end <= local_process_start:
		push_error("Could not inspect local rescue progression guard.")
		quit(1)
		return
	var local_process_source := manager_source.substr(local_process_start, local_process_end - local_process_start)
	if not local_process_source.contains("var rescue_requires_interaction := selected_activity_kind == \"adventure\" and selected_adventure_id == \"city_adventure_rescue\" and adventure_stage_index == 0") or not local_process_source.contains("distance_to_target <= 2.2 and not rescue_requires_interaction"):
		push_error("Offline rescue must not skip the required citizen interaction by reaching the checkpoint.")
		quit(1)
		return
	if not npc_source.contains("func get_nearest_active_citizen(") or not npc_source.contains("func set_rescue_citizen(") or not npc_source.contains('"wave"'):
		push_error("Rescue must reuse an existing city resident and its wave animation.")
		quit(1)
		return
	if manager_source.contains('description_label.text = "%s\\\\n%s"') or manager_source.contains('description_label.text = "%s\\\\nالمرحلة'):
		push_error("Online adventure descriptions must use real line breaks instead of a literal backslash-n.")
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
	if server_source.contains('completed_missions["city_adventure_message"] = true') or server_source.contains('server_objective_reached.emit(str(session.get("user_id", "")), "mission", "city_adventure_message")'):
		push_error("Adventure completion must not be counted as a generic rewarded mission.")
		quit(1)
		return
	if not manager_source.contains("stage_number > stage_count") or not manager_source.contains("adventure_stage_index = stage_count - 1"):
		push_error("The mystery cipher must remain hidden until the server confirms arrival at the final checkpoint.")
		quit(1)
		return
	print("City adventure activity contract checks passed.")
	quit(0)
