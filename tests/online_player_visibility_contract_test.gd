extends SceneTree

func _initialize() -> void:
	var server_source := FileAccess.get_file_as_string("res://scripts/authoritative_game_server.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var visual_source := FileAccess.get_file_as_string("res://scripts/remote_player_visual.gd")
	_expect(server_source.contains("signal remote_players_received(players: Array)"), "remote player snapshot signal")
	_expect(server_source.contains('"instance_id": "city-main"'), "default logical instance assignment")
	_expect(server_source.contains('rpc_id(peer_id, "receive_remote_players", remote_players)'), "server sends peer visibility snapshots")
	_expect(server_source.contains('func receive_remote_players(players: Array)'), "client receives remote player snapshots")
	_expect(server_source.contains('int(peer_id_variant) == multiplayer.get_unique_id()'), "client filters its own peer")
	_expect(server_source.contains('MAX_PLAYERS - 1'), "remote snapshot is bounded by server capacity")
	_expect(server_source.contains("MAX_PLAYER_VISIBILITY_DISTANCE := 140.0"), "nearby-only visibility range")
	_expect(server_source.contains("distance_squared_to(remote_position)"), "server filters remote players by distance")
	_expect(main_source.contains("AuthoritativeGameServer.remote_players_received.connect(_on_remote_players_received)"), "main scene consumes remote snapshots")
	_expect(main_source.contains("RemotePlayerVisual.new()"), "main scene creates remote visual instances")
	_expect(main_source.contains("_clear_remote_player_views()"), "remote visuals clear on disconnect")
	_expect(visual_source.contains('preload("res://scenes/characters/avatar_visual.tscn")'), "remote players reuse the shared avatar visual")
	_expect(visual_source.contains("global_position.lerp(_target_position, blend)"), "remote movement is interpolated")
	if _failed:
		push_error("Online player visibility contract tests failed: %d" % _failed)
		quit(1)
		return
	print("Online player visibility contract tests passed.")
	quit(0)

var _failed := 0

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("Online player visibility contract failed: " + label)
