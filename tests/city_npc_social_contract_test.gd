extends SceneTree

func _initialize() -> void:
	call_deferred("_run_city_npc_social_contract")

func _run_city_npc_social_contract() -> void:
	var population_source := FileAccess.get_file_as_string("res://scripts/city_npc_population.gd")
	var avatar_source := FileAccess.get_file_as_string("res://scripts/avatar_visual.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	for required in [
		"const SOCIAL_RANGE := 2.8",
		"const SOCIAL_DURATION := 3.0",
		"const SOCIAL_COOLDOWN := 7.0",
		"_social_actor_states[first_id]",
		"_social_actor_states[second_id]",
		"_social_pair_cooldowns[pair_key] = SOCIAL_COOLDOWN",
		"if cooldown_remaining <= 0.0:",
		"_social_pair_cooldowns.erase(pair_key)",
		"func _clear_social_actor(actor_id: String)",
		"avatar.call(\"set_motion_state\", \"talk\", 0.0)"
	]:
		if not population_source.contains(required):
			push_error("Missing ambient NPC social contract: " + required)
			quit(1)
			return
	if not avatar_source.contains("\"talk\"") or not avatar_source.contains("\"wave\""):
		push_error("Avatar talk/wave motion states are missing.")
		quit(1)
		return
	if not main_source.contains("_create_city_npc_population()") or main_source.contains("offline_city_life_manager"):
		push_error("The current city NPC population must remain the single integrated population system.")
		quit(1)
		return
	print("City NPC social interaction contract tests passed.")
	quit(0)
