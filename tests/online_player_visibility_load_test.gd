extends SceneTree

const SERVER_SCRIPT := preload("res://scripts/authoritative_game_server.gd")

var _failed := 0

func _initialize() -> void:
	var server := SERVER_SCRIPT.new() as Node
	root.add_child(server)
	for player_count in [5, 10, 20]:
		var sessions := _make_sessions(server, player_count, "city-main", 2.0)
		server.set("_sessions", sessions)
		var snapshots: Dictionary = server.call("_build_remote_player_snapshots")
		_expect(snapshots.size() == player_count, "%d players each receive a visibility snapshot" % player_count)
		var expected_total := player_count * (player_count - 1)
		var actual_total := 0
		for peer_id_variant in snapshots.keys():
			var remote_players: Array = snapshots[peer_id_variant]
			_expect(remote_players.size() == player_count - 1, "%d-player peer receives %d other players" % [player_count, player_count - 1])
			actual_total += remote_players.size()
		_expect(actual_total == expected_total, "%d-player total remote records equals %d" % [player_count, expected_total])
		print("Visibility simulation: %d players, %d remote records per snapshot tick." % [player_count, actual_total])
		_free_sessions(sessions)

	var isolated_sessions := _make_sessions(server, 5, "city-main", 2.0)
	isolated_sessions[99] = _make_player_session(server, 99, "city-east", Vector3(4.0, 1.0, 0.0))
	var unauthenticated := _make_player_session(server, 100, "city-main", Vector3(6.0, 1.0, 0.0))
	unauthenticated["authenticated"] = false
	isolated_sessions[100] = unauthenticated
	isolated_sessions[101] = _make_player_session(server, 101, "city-main", Vector3(250.0, 1.0, 0.0))
	server.set("_sessions", isolated_sessions)
	var filtered: Dictionary = server.call("_build_remote_player_snapshots")
	_expect(filtered.size() == 6, "only authenticated peers with valid bodies get a snapshot")
	for peer_id_variant in filtered.keys():
		var remote_players: Array = filtered[peer_id_variant]
		for remote_variant in remote_players:
			var remote: Dictionary = remote_variant
			_expect(int(remote.get("peer_id", 0)) != 99, "different logical instances are isolated")
			_expect(int(remote.get("peer_id", 0)) != 100, "unauthenticated peers are hidden")
			_expect(int(remote.get("peer_id", 0)) != 101, "players outside visibility radius are hidden")
	_free_sessions(isolated_sessions)
	server.queue_free()

	if _failed > 0:
		push_error("Online player visibility load simulation failed: %d" % _failed)
		quit(1)
		return
	print("Online player visibility load simulation passed for 5, 10, and 20 players.")
	quit(0)


func _make_sessions(server: Node, player_count: int, instance_id: String, spacing: float) -> Dictionary:
	var sessions: Dictionary = {}
	for index in range(player_count):
		sessions[index + 1] = _make_player_session(server, index + 1, instance_id, Vector3(float(index) * spacing, 1.0, 0.0))
	return sessions


func _make_player_session(server: Node, peer_id: int, instance_id: String, player_position: Vector3) -> Dictionary:
	var body := CharacterBody3D.new()
	body.name = "LoadTestPlayer_%d" % peer_id
	body.position = player_position
	server.add_child(body)
	return {
		"authenticated": true,
		"instance_id": instance_id,
		"body": body
	}


func _free_sessions(sessions: Dictionary) -> void:
	for session_variant in sessions.values():
		var session: Dictionary = session_variant
		var body := session.get("body") as Node
		if is_instance_valid(body):
			body.free()


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("Online player visibility load simulation failed: " + label)
