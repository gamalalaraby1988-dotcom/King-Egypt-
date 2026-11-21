extends SceneTree

func _initialize() -> void:
	var server_source := FileAccess.get_file_as_string("res://scripts/authoritative_game_server.gd")
	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	var docs_source := FileAccess.get_file_as_string("res://docs/CITY_SESSION_DIRECTORY_AR.md")
	var project_source := FileAccess.get_file_as_string("res://project.godot")
	_expect(server_source.contains("KING_CITY_SESSION_DIRECTORY_HMAC_SECRET_B64"), "server HMAC key comes from a server environment variable")
	_expect(server_source.contains("HMACContext.new()"), "server signs directory requests with HMAC")
	_expect(server_source.contains('"action": "server_register"'), "dedicated server registers itself")
	_expect(server_source.contains('"action": "server_heartbeat"'), "dedicated server sends heartbeat")
	_expect(server_source.contains('"action": "server_player_connected"'), "server confirms the reservation after account verification")
	_expect(server_source.contains('"action": "server_player_disconnected"'), "server releases a connected reservation on disconnect")
	_expect(server_source.contains('if _city_directory_enabled and not _city_directory_registered:'), "directory-enabled server rejects players before registration")
	_expect(server_source.contains('func authenticate_player(access_token: String, reservation_id: String = "")'), "server authentication accepts the reservation id")
	_expect(main_source.contains('ProjectSettings.get_setting("network/online/session_directory_enabled", false)'), "matchmaking is disabled by default")
	_expect(main_source.contains('"action": "matchmake"'), "client requests an authenticated city reservation")
	_expect(main_source.contains('"Authorization: Bearer " + access_token'), "matchmaking request uses the player's access token")
	_expect(main_source.contains('GameModeManager.connect_online(endpoint, 2456)'), "client connects to the assigned WSS endpoint")
	_expect(main_source.contains('authenticate_player.rpc_id(1, access_token, _pending_city_reservation_id)'), "client forwards the reservation id to the game server")
	_expect(main_source.contains('authenticate_player.rpc_id(1, access_token, _pending_city_reservation_id)'), "token refresh preserves the active reservation id")
	_expect(project_source.contains("online/session_directory_enabled=false"), "matchmaking is explicitly disabled in the default project settings")
	_expect(docs_source.contains("لا يوجد نشر على Supabase الإنتاجي"), "documentation states that production was not deployed")
	_expect(not server_source.contains("SUPABASE_SERVICE_ROLE_KEY"), "server does not embed a Supabase service role key")
	if _failed:
		push_error("Trusted city session directory integration tests failed: %d" % _failed)
		quit(1)
		return
	print("Trusted city session directory integration tests passed.")
	quit(0)

var _failed := 0

func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("Trusted city session directory integration test failed: " + label)
