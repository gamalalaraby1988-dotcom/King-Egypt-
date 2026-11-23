extends SceneTree

const SERVER_SCRIPT = preload("res://scripts/authoritative_game_server.gd")

func _initialize() -> void:
	var server := SERVER_SCRIPT.new()
	var failures: Array[String] = []
	for count in [0, 1]:
		if server._jet_ski_race_can_start(count):
			failures.append("Race start incorrectly allowed with %d participant(s)." % count)
	for count in [2, 3, 4]:
		if not server._jet_ski_race_can_start(count):
			failures.append("Race start incorrectly rejected with %d participant(s)." % count)
	if server._jet_ski_race_can_start(5):
		failures.append("Race start incorrectly allowed with five participants.")
	server.free()
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Royal jet ski race minimum/maximum participant gate tests passed.")
	quit(0)
