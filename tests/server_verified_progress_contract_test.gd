extends SceneTree

const CLIENT_PATH := "res://scripts/player_sync_client.gd"
const SERVER_PATH := "res://scripts/authoritative_game_server.gd"
const MISSION_PATH := "res://scripts/mission_manager.gd"
const ACHIEVEMENT_PATH := "res://scripts/achievement_manager.gd"
const EXPLORER_MIGRATION_PATH := "res://supabase/migrations/20261121150000_record_explorer_achievement_from_verified_missions.sql"
const REWARD_MIGRATION_PATH := "res://supabase/migrations/20261121132105_server_verified_player_progress.sql"
const UNIQUENESS_MIGRATION_PATH := "res://supabase/migrations/20261121140213_prevent_duplicate_verified_activity_completions.sql"
const LOOKUP_EDGE_PATH := "res://supabase/functions/game-progress-lookup/index.ts"
const WALK_MIGRATION_PATH := "res://supabase/migrations/20261121160000_server_verified_walk_distance.sql"
const WALK_EDGE_PATH := "res://supabase/functions/game-walk-progress/index.ts"


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
	var achievement := _read(ACHIEVEMENT_PATH)
	var explorer_migration := _read(EXPLORER_MIGRATION_PATH)
	var migration := _read(REWARD_MIGRATION_PATH)
	var uniqueness_migration := _read(UNIQUENESS_MIGRATION_PATH)
	var lookup_edge := _read(LOOKUP_EDGE_PATH)
	var walk_migration := _read(WALK_MIGRATION_PATH)
	var walk_edge := _read(WALK_EDGE_PATH)
	if client.is_empty() or server.is_empty() or mission.is_empty() or achievement.is_empty() or explorer_migration.is_empty() or migration.is_empty() or uniqueness_migration.is_empty() or lookup_edge.is_empty() or walk_migration.is_empty() or walk_edge.is_empty():
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
		_require(server, 'achievement_unlocked', "dedicated server must forward the database-confirmed Explorer achievement"),
		_require(mission, 'PlayerSyncClient.fetch_verified_activity_progress()', "building mission completion must refresh the read-only verified ledger"),
		_require(mission, '["explorer"]', "the Explorer achievement proof must be accepted by the reward queue"),
		_require(achievement, 'SERVER_VERIFIED_BUILDING_MISSION_IDS', "Explorer progress must use only the three approved building missions"),
		_require(achievement, 'verified_activity_progress_received', "achievement UI must listen to the verified progress ledger"),
		_require(achievement, 'موثّق من خادم اللعبة', "achievement UI must reject progress without the server trust label"),
		_require(client, 'Verified progress is a read-only account ledger', "verified progress read must remain separate from player sync activation"),
		_require(explorer_migration, "'mission_shop', 'mission_restaurant', 'mission_employment'", "only the three approved building missions may count toward Explorer"),
		_require(explorer_migration, "'achievement', 'explorer'", "the third verified building mission must persist Explorer atomically"),
		_require(server, '/functions/v1/game-progress-lookup', "dedicated server must verify one-time mission history before starting it"),
		_require(server, '_request_server_mission_progress_lookup(peer_id, safe_mission_id)', "mission start must query persistent verified progress"),
		_require(server, 'bool(parsed.get("completed", false))', "server must reject a mission already completed on this account"),
		_require(lookup_edge, 'has_player_verified_activity', "signed lookup must query only the server verified progress ledger"),
		_require(lookup_edge, 'invalid_server_signature', "lookup endpoint must verify the dedicated server HMAC"),
		_require(server, '_issue_activity_proof(peer_id, str(session.get("user_id", "")), "mission", completed_mission_id)', "server-completed adventures and missions must enter the proof-verified progress path"),
		_require(migration, "reward_eligible_at_completion", "reward eligibility must be frozen at the moment the server completion is recorded"),
		_require(uniqueness_migration, "player_verified_activity_progress_one_time_idx", "one-time activities must be unique per player at the database level"),
		_require(uniqueness_migration, "pg_advisory_xact_lock", "concurrent completion attempts must be serialized by account and activity"),
		_require(migration, "get_player_verified_activity_progress", "only the authenticated player's verified progress may be read"),
		_require(explorer_migration, "achievement_proof_id", "Explorer reward proof must be returned only from the server recorder"),
		_require(server, "/functions/v1/game-walk-progress", "dedicated server must persist signed walking distance through the walk progress endpoint"),
		_require(server, "walk_pending_event_id", "walking retries must reuse the same idempotency event id"),
		_require(server, "RUN_SPEED * safe_delta + 0.12", "walking distance must be bounded by authoritative server movement speed"),
		_require(server, "_walk_signature_message", "walking updates and lookups must be signed by the dedicated server"),
		_require(client, '"walk_distance"', "client must accept only the dedicated verified walk-distance snapshot"),
		_require(achievement, "server_verified_walk_meters", "Online First Steps progress must use server-saved distance"),
		_require(walk_migration, "player_verified_walk_distance_events", "walking increments must persist in a dedicated append-only table"),
		_require(walk_migration, "p_distance_meters > 5.000", "database must cap each walking increment"),
		_require(walk_migration, "'first_steps'", "the one-hundred-meter milestone must create First Steps"),
		_require(walk_edge, "invalid_server_signature", "walk progress endpoint must verify dedicated-server HMAC"),
		_require(walk_edge, "distance.toFixed(3)", "walk progress HMAC must bind the exact millimeter distance"),
		_require(walk_edge, "get_server_verified_walk_distance", "server must restore cumulative distance from the durable account ledger")
	]
	for passed in checks:
		if not passed:
			quit(1)
			return

	print("Server verified progress contract tests passed.")
	quit(0)
