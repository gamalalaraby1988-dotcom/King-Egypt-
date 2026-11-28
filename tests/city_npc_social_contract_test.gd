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

	var layout_source := FileAccess.get_file_as_string("res://scripts/approved_city_layout.gd")
	var population_call_count := main_source.count("_create_city_npc_population()")
	if population_call_count != 2 or layout_source.contains("_build_npc_population()"):
		push_error("Ambient NPC population must be created only once by the client startup flow.")
		quit(1)
		return
	# Every base resident and copy must have clear visual spacing at spawn.
	var spawn_regex := RegEx.new()
	if spawn_regex.compile("Vector3\\((-?[0-9]+(?:\\.[0-9]+)?), 0, (-?[0-9]+(?:\\.[0-9]+)?)\\)") != OK:
		push_error("Could not compile NPC spawn spacing pattern.")
		quit(1)
		return
	var spawn_matches := spawn_regex.search_all(population_source)
	if spawn_matches.size() != 70:
		push_error("Expected 50 base NPCs plus 20 copies; found %d spawn points." % spawn_matches.size())
		quit(1)
		return
	for i in range(spawn_matches.size()):
		var first := Vector2(float(spawn_matches[i].get_string(1)), float(spawn_matches[i].get_string(2)))
		for j in range(i + 1, spawn_matches.size()):
			var second := Vector2(float(spawn_matches[j].get_string(1)), float(spawn_matches[j].get_string(2)))
			if first.distance_to(second) < 7.5:
				push_error("NPC spawn points are too close: %d and %d." % [i + 1, j + 1])
				quit(1)
				return
			var first_wander := 0.0 if i < 50 and i % 3 == 0 else (1.35 if i < 50 else (0.0 if (i - 50) % 4 == 0 else 1.1))
			var second_wander := 0.0 if j < 50 and j % 3 == 0 else (1.35 if j < 50 else (0.0 if (j - 50) % 4 == 0 else 1.1))
			if first.distance_to(second) - first_wander - second_wander < 6.5:
				push_error("NPC movement paths can approach too closely: %d and %d." % [i + 1, j + 1])
				quit(1)
				return
	if not population_source.contains("_disable_npc_collisions(actor)") or not population_source.contains("collision_object.collision_layer = 0") or not population_source.contains("collision_object.collision_mask = 0"):
		push_error("NPC visuals must remain non-blocking for players and world actors.")
		quit(1)
		return
	var service_source := FileAccess.get_file_as_string("res://scripts/service_npc.gd")
	if main_source.count("_create_service_staff(") != 4 or main_source.count("_create_interior_staff(interior_root, building_title)") != 1:
		push_error("Approved outdoor and interior service staff creation points changed unexpectedly.")
		quit(1)
		return
	if main_source.contains("camp_animal_staff.gd") or main_source.contains("camp_system.gd"):
		push_error("Legacy camp staff/animal system must not be loaded alongside the approved desert camp.")
		quit(1)
		return
	if service_source.contains("CollisionObject3D") or service_source.contains("CollisionShape3D"):
		push_error("Service staff visuals must not introduce duplicate blocking collision bodies.")
		quit(1)
		return
	print("City NPC social interaction and spawn spacing contract tests passed.")
	quit(0)
