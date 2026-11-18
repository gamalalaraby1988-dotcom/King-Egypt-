extends SceneTree

func _initialize() -> void:
	call_deferred("_run_city_presence_tests")

func _run_city_presence_tests() -> void:
	await process_frame
	var manager_script: Script = load("res://scripts/social_chat_manager.gd")
	if manager_script == null:
		push_error("City Presence manager script could not be loaded.")
		quit(1)
		return
	var manager := manager_script.new() as Node
	root.add_child(manager)
	await process_frame

	manager.call("_apply_city_presence_state", {
		"session_a": {"metas": [{"phx_ref": "a1", "sector": "north_west"}]},
		"session_b": {"metas": [{"phx_ref": "b1", "sector": "south_east"}]},
		"session_c": {"metas": [{"phx_ref": "c1", "sector": "interior"}]}
	})
	var counts: Dictionary = manager.call("get_city_presence_counts")
	if int(counts.get("north_west", -1)) != 1 or int(counts.get("south_east", -1)) != 1 or int(counts.get("north_east", -1)) != 0:
		push_error("City Presence state did not count the correct coarse sectors.")
		manager.queue_free()
		quit(1)
		return

	manager.call("_apply_city_presence_diff", {
		"joins": {"session_d": {"metas": [{"phx_ref": "d1", "sector": "north_west"}]}},
		"leaves": {"session_b": {"metas": [{"phx_ref": "b1", "sector": "south_east"}]}}
	})
	counts = manager.call("get_city_presence_counts")
	if int(counts.get("north_west", -1)) != 2 or int(counts.get("south_east", -1)) != 0:
		push_error("City Presence diff did not apply joins and leaves correctly.")
		manager.queue_free()
		quit(1)
		return

	manager.call("_clear_city_presence_state")
	counts = manager.call("get_city_presence_counts")
	for sector in ["north_west", "north_east", "south_west", "south_east", "south_center"]:
		if int(counts.get(sector, -1)) != 0:
			push_error("City Presence cleanup left a stale sector count.")
			manager.queue_free()
			quit(1)
			return

	manager.queue_free()
	print("CITY_PRESENCE_TESTS: all checks passed")
	quit(0)
