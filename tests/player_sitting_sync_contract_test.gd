extends SceneTree

const PLAYER_SOURCE_PATH := "res://scripts/player.gd"


func _initialize() -> void:
	_run()


func _method_body(source: String, method_name: String) -> String:
	var marker := "func " + method_name + "("
	var start := source.find(marker)
	if start < 0:
		return ""
	var next_method := source.find("\nfunc ", start + marker.length())
	if next_method < 0:
		return source.substr(start)
	return source.substr(start, next_method - start)


func _run() -> void:
	var file := FileAccess.open(PLAYER_SOURCE_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not read player script for sitting synchronization contract.")
		quit(1)
		return
	var source := file.get_as_text()
	file.close()

	var sync_body := _method_body(source, "_sync_sitting_state")
	if sync_body.is_empty() or not sync_body.contains("GameModeManager.is_online_ready()") or not sync_body.contains("AuthoritativeGameServer.send_player_sit(sitting)"):
		push_error("Sitting synchronization helper does not safely send the current state when online.")
		quit(1)
		return

	var required_methods := [
		"sit_at_position",
		"set_arcade_seated",
		"end_arcade_seat",
		"toggle_sit",
		"_process_online_input"
	]
	for method_name in required_methods:
		var body := _method_body(source, method_name)
		if body.is_empty() or not body.contains("_sync_sitting_state()"):
			push_error("Sitting interaction does not synchronize its state: " + method_name)
			quit(1)
			return

	print("Player sitting synchronization contract tests passed.")
	quit(0)
