extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var mode_manager := root.get_node_or_null("GameModeManager")
	if not is_instance_valid(mode_manager):
		push_error("GameModeManager autoload was not available to the regression test.")
		quit(1)
		return
	var previous_mode: int = int(mode_manager.get("current_mode"))
	var previous_state: String = str(mode_manager.get("connection_state"))
	var main := MainScript.new()

	mode_manager.set("current_mode", 1)
	mode_manager.set("connection_state", "offline")
	if not bool(main.call("_is_local_city_interaction_allowed")):
		push_error("Offline local city interactions should remain available.")
		main.free()
		mode_manager.set("current_mode", previous_mode)
		mode_manager.set("connection_state", previous_state)
		quit(1)
		return

	mode_manager.set("current_mode", 2)
	mode_manager.set("connection_state", "connected")
	if bool(main.call("_is_local_city_interaction_allowed")):
		push_error("Online mode must block local-only interiors and vehicle transitions.")
		main.free()
		mode_manager.set("current_mode", previous_mode)
		mode_manager.set("connection_state", previous_state)
		quit(1)
		return

	# A pending or disconnected session is not an active Online world.
	mode_manager.set("current_mode", 0)
	mode_manager.set("connection_state", "connecting")
	if not bool(main.call("_is_local_city_interaction_allowed")):
		push_error("Unselected mode should not be treated as an active Online world.")
		main.free()
		mode_manager.set("current_mode", previous_mode)
		mode_manager.set("connection_state", previous_state)
		quit(1)
		return

	main.free()
	mode_manager.set("current_mode", previous_mode)
	mode_manager.set("connection_state", previous_state)
	print("Online local-transition guard tests passed.")
	quit(0)
