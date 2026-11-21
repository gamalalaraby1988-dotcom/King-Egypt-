extends SceneTree

const CLIENT_PATH := "res://scripts/player_sync_client.gd"
const SERVER_PATH := "res://scripts/authoritative_game_server.gd"
const MISSION_PATH := "res://scripts/mission_manager.gd"
const REWARD_MIGRATION_PATH := "res://supabase/migrations/20261121132105_server_verified_player_progress.sql"
const LOOKUP_EDGE_PATH := "res://supabase/functions/game-progress-lookup/index.ts"


func _read(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	return file.get_as_text()


func _require(source: String, needle: String, message: String) -> bool:
	if source.contains(needle):
		return true
	push_error("Server verified progress contract test failed: " + message)
	return false


func _initialize() -> void:
	var client := _read(CLIENT_PATH)
	var server := _read(SERVER_PATH)
	var mission := _read(MISSION_PATH)
	var migration := _read(REWARD_MIGRATION_PATH)
	var lookup_edge := _read(LOOKUP_EDGE_PATH)
	if client.is_empty() or server.is_empty() or mission.is_empty() or migration.is_empty() or lookup_edge.is_empty():
		push_error("Server verified progress contract test failed: a required source file is missing.")
		quit(1)
		return

	var checks := [
		_require(client, "/rest/v1/rpc/get_player_verified_activity_progress", "client must fetch the dedicated server verified progress RPC"),
		_require(client, 'str(parsed.get("trust", "")) != "server_verified"', "client must reject an unverified trust label"),
		_require(client, '_verified_activity_progress = clean_activities', "verified progress must remain in a separate in-memory collection"),
		_require(client, "is_server_activity_verified", "online mission start must check server-verified completion history"),
		_require(server, '/functions/v1/game-proof-issuer', "dedicated server must send its HMAC evidence to the trusted proof issuer"),
		_require(server, 'bool(parsed.get("progress_recorded", false))', "dedicated server must require a positive persisted-progress response"),
		_require(server, 'receive_server_activity_progress_recorded', "dedicated server must report progress persistence independently from reward proof"),
		_require(server, '/functions/v1/game-progress-lookup', "dedicated server must verify one-time mission history before starting it"),
		_require(server, '_request_server_mission_progress_lookup(peer_id, safe_mission_id)', "mission start must query persistent verified progress"),
		_require(server, 'bool(parsed.get("completed", false))', "server must reject a mission already completed on this account"),
		_require(lookup_edge, 'has_player_verified_activity', "signed lookup must query only the server verified progress ledger"),
		_require(lookup_edge, 'invalid_server_signature', "lookup endpoint must verify the dedicated server HMAC"),
		_require(server, '_issue_activity_proof(peer_id, str(session.get("user_id", "")), "mission", completed_mission_id)', "server-completed adventures and missions must enter the proof-verified progress path"),
		_require(migration, "reward_eligible_at_completion", "reward eligibility must be frozen at the moment the server completion is recorded"),
		_require(migration, "player_verified_activity_progress_one_time_idx", "one-time activities must be unique per player at the database level"),
		_require(migration, "pg_advisory_xact_lock", "concurrent completion attempts must be serialized by account and activity"),
		_require(migration, "get_player_verified_activity_progress", "only the authenticated player's verified progress may be read")
	]
	for passed in checks:
		if not passed:
			quit(1)
			return

	print("Server verified progress contract tests passed.")
	quit(0)
