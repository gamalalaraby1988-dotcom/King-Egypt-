extends SceneTree

const MainScript = preload("res://scripts/main.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var previous_mode: int = GameModeManager.current_mode
	var previous_state: String = GameModeManager.connection_state
	var main := MainScript.new()

	GameModeManager.current_mode = GameModeManager.Mode.OFFLINE
	GameModeManager.connection_state = "offline"
	if not bool(main.call("_is_local_city_interaction_allowed")):
		push_error("Offline local city interactions should remain available.")
		main.free()
		GameModeManager.current_mode = previous_mode
		GameModeManager.connection_state = previous_state
		quit(1)
		return

	GameModeManager.current_mode = GameModeManager.Mode.ONLINE
	GameModeManager.connection_state = "connected"
	if bool(main.call("_is_local_city_interaction_allowed")):
		push_error("Online mode must block local-only interiors and vehicle transitions.")
		main.free()
		GameModeManager.current_mode = previous_mode
		GameModeManager.connection_state = previous_state
		quit(1)
		return

	# A pending or disconnected session is not an active Online world.
	GameModeManager.current_mode = GameModeManager.Mode.UNSELECTED
	GameModeManager.connection_state = "connecting"
	if not bool(main.call("_is_local_city_interaction_allowed")):
		push_error("Unselected mode should not be treated as an active Online world.")
		main.free()
		GameModeManager.current_mode = previous_mode
		GameModeManager.connection_state = previous_state
		quit(1)
		return

	main.free()
	GameModeManager.current_mode = previous_mode
	GameModeManager.connection_state = previous_state
	print("Online local-transition guard tests passed.")
	quit(0)
