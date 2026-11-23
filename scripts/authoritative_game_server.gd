extends Node

const JetSkiNetworkContract = preload("res://scripts/jet_ski_network_contract.gd")
const JET_SKI_SERVER_LAUNCH_POSITION := Vector3(0.0, 0.34, 82.0)
const JET_SKI_SERVER_BOARDING_RADIUS := 8.0
const JET_SKI_RIDER_OFFSET := Vector3(0.0, 0.88, 0.28)
## Dedicated WSS game authority. Clients submit bounded movement input, never positions.
## Server-side collision uses the loaded city physics world. Objective zones remain disabled
## until their canonical server coordinates and evidence rules are configured.

signal authentication_completed(success: bool, message: String)
signal authoritative_state_received(position: Vector3, rotation_y: float, velocity: Vector3)
signal safe_return_completed(success: bool, message: String)
signal remote_players_received(players: Array)
signal server_objective_reached(user_id: String, activity_kind: String, activity_id: String)
signal job_start_result(success: bool, job_id: String, target: Vector3, message: String)
signal job_completed(job_id: String)
signal mission_start_result(success: bool, mission_id: String, target: Vector3, message: String)
signal mission_stage_updated(mission_id: String, target: Vector3, stage_number: int, stage_count: int, message: String)
signal mission_failed(mission_id: String, message: String)
signal mission_completed(mission_id: String)
signal activity_progress_recorded(activity_kind: String, activity_id: String, reward_eligible: bool)
signal activity_proof_received(activity_kind: String, activity_id: String, proof_id: String)
signal activity_proof_failed(activity_kind: String, activity_id: String, message: String)
signal arcade_session_state_changed(session_id: String, state: String, machine_id: String, message: String)
signal arcade_session_verified(session_id: String, server_event_id: String, machine_id: String, zone_id: String, mode: String, participants: Dictionary, results: Dictionary)
signal arcade_slot_spin_settled(session_id: String, result: Dictionary)
signal arcade_slot_spin_failed(session_id: String, message: String)
signal jet_ski_race_state_changed(state: String, participant_count: int, message: String)
signal jet_ski_mount_result_received(success: bool, message: String)
signal jet_ski_authoritative_state_received(position: Vector3, rotation_y: float, velocity: Vector3)

const DEFAULT_PORT := 2456
const MAX_PLAYERS := 64
const MAX_INPUT_RATE := 35.0
const WALK_SPEED := 4.0
const RUN_SPEED := 6.2
const ACCELERATION := 18.0
const GRAVITY := 20.0
const SNAPSHOT_INTERVAL := 0.05
const MAX_PLAYER_VISIBILITY_DISTANCE := 140.0
const JET_SKI_RACE_MIN_PARTICIPANTS := 2
const JET_SKI_RACE_MAX_PARTICIPANTS := 4
const JET_SKI_RACE_COUNTDOWN_SECONDS := 5
const JET_SKI_RACE_DURATION_SECONDS := 300
const JET_SKI_RACE_OFF_COURSE_LIMIT_SECONDS := 300
const JET_SKI_RACE_DAILY_REWARD_WINNING_RANKS := 3
const JET_SKI_RACE_WEEKLY_DAYS := [1, 4, 6] # Godot weekday: Monday=1, Thursday=4, Saturday=6.
const JET_SKI_RACE_START_HOUR_EGYPT := 20
const JET_SKI_RACE_START_MINUTE_EGYPT := 0
const JET_SKI_RACE_ANNOUNCEMENT_MINUTES := 15
const SPAWN_POSITION := Vector3(0.0, 1.0, -42.0)

var _server_peer: WebSocketMultiplayerPeer
var _sessions: Dictionary = {}
var _auth_requests: Dictionary = {}
var _walk_progress_requests: Dictionary = {}
var _pending_mission_progress_lookups: Dictionary = {}
var _is_dedicated_server := false
var _input_sequence := 0
var _jet_ski_input_sequence := 0
var _snapshot_elapsed := 0.0
var _client_authenticated := false
var _objective_zones: Dictionary = {}
var _proof_hmac_secret := PackedByteArray()
var _proof_secret_warning_shown := false
var _jet_ski_race_participants: Array[int] = []
var _jet_ski_race_locked_participants: Array[int] = []
var _jet_ski_race_spectators: Array[int] = []
var _jet_ski_race_state := "waiting"
var _jet_ski_race_countdown_until_usec := 0
var _jet_ski_race_ends_at_usec := 0
var _arcade_machines: Dictionary = {}
var _arcade_sessions: Dictionary = {}
var _peer_arcade_sessions: Dictionary = {}
var _pending_slot_spins: Dictionary = {}
var _closed_arcade_sessions: Dictionary = {}
var _city_directory_url := ""
var _city_directory_server_id := ""
var _city_directory_region := ""
var _city_directory_endpoint := ""
var _city_directory_hmac_key := PackedByteArray()
var _city_directory_enabled := false
var _city_directory_registered := false
var _city_directory_next_heartbeat_usec := 0
var _city_directory_requests: Array[HTTPRequest] = []
const ARCADE_ZONE_IDS := [
	"european_vip_casino",
	"civilization_ship",
	"greek_wing",
	"roman_wing",
	"japanese_wing",
	"chinese_wing",
	"french_wing"
]
const ARCADE_SESSION_MODES := ["solo", "multiplayer", "tournament"]
const ARCADE_MACHINE_INTERACTION_RADIUS := 3.5
var _daily_job_completions: Dictionary = {}
const DAILY_JOB_SAVE_PATH := "user://king_city_daily_jobs.cfg"
const EGYPT_UTC_OFFSET_SECONDS := 7200
const WEEKLY_JOB_SCHEDULE := {}


func _egypt_datetime() -> Dictionary:
	return Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + EGYPT_UTC_OFFSET_SECONDS)

func _jet_ski_race_is_scheduled_day(date_time: Dictionary) -> bool:
	return JET_SKI_RACE_WEEKLY_DAYS.has(int(date_time.get("weekday", -1)))


func _jet_ski_race_is_announcement_time(date_time: Dictionary) -> bool:
	if not _jet_ski_race_is_scheduled_day(date_time):
		return false
	var minutes_since_midnight := int(date_time.get("hour", -1)) * 60 + int(date_time.get("minute", -1))
	var announcement_start := JET_SKI_RACE_START_HOUR_EGYPT * 60 + JET_SKI_RACE_START_MINUTE_EGYPT - JET_SKI_RACE_ANNOUNCEMENT_MINUTES
	var race_start := JET_SKI_RACE_START_HOUR_EGYPT * 60 + JET_SKI_RACE_START_MINUTE_EGYPT
	return minutes_since_midnight >= announcement_start and minutes_since_midnight < race_start


func _egypt_day_key() -> String:
	var date := _egypt_datetime()
	return "%04d-%02d-%02d" % [int(date.year), int(date.month), int(date.day)]

func _daily_job_key(job_id: String) -> String:
	return "%s:%s" % [_egypt_day_key(), job_id]

func _job_available_today(job_id: String) -> bool:
	var date := _egypt_datetime()
	var jobs: Array = WEEKLY_JOB_SCHEDULE.get(int(date.weekday), [])
	return jobs.has(job_id)

func _load_daily_job_completions() -> void:
	var config := ConfigFile.new()
	if config.load(DAILY_JOB_SAVE_PATH) == OK:
		var stored: Variant = config.get_value("jobs", "completed", {})
		if stored is Dictionary:
			_daily_job_completions = stored.duplicate(true)

func _save_daily_job_completions() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(DAILY_JOB_SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(DAILY_JOB_SAVE_PATH):
		push_warning("تعذر قراءة سجل الوظائف اليومية على الخادم؛ لم يتم استبداله.")
		return
	config.set_value("jobs", "completed", _daily_job_completions)
	var save_error := config.save(DAILY_JOB_SAVE_PATH)
	if save_error != OK:
		push_warning("تعذر حفظ سجل الوظائف اليومية على الخادم: %s" % save_error)

func _ready() -> void:
	_load_daily_job_completions()
	_is_dedicated_server = OS.get_cmdline_user_args().has("--dedicated-server")
	if _is_dedicated_server:
		var secret_b64 := OS.get_environment("KING_CITY_PROOF_HMAC_SECRET_B64").strip_edges()
		if not secret_b64.is_empty():
			_proof_hmac_secret = Marshalls.base64_to_raw(secret_b64)
		_configure_city_session_directory()
		call_deferred("start_dedicated_server")


func is_dedicated_server_requested() -> bool:
	return _is_dedicated_server


func is_authenticated() -> bool:
	if _is_dedicated_server:
		return true
	return _client_authenticated


func start_dedicated_server() -> void:
	if not _is_dedicated_server or _server_peer != null:
		return
	var key_path := OS.get_environment("KING_CITY_TLS_KEY_PATH").strip_edges()
	var cert_path := OS.get_environment("KING_CITY_TLS_CERT_PATH").strip_edges()
	if key_path.is_empty() or cert_path.is_empty():
		push_error("Dedicated server requires KING_CITY_TLS_KEY_PATH and KING_CITY_TLS_CERT_PATH.")
		return
	var private_key := CryptoKey.new()
	var key_error := private_key.load(key_path)
	var certificate := X509Certificate.new()
	var cert_error := certificate.load(cert_path)
	if key_error != OK or cert_error != OK:
		push_error("Dedicated server TLS key/certificate could not be loaded.")
		return
	var tls_options := TLSOptions.server(private_key, certificate)
	_server_peer = WebSocketMultiplayerPeer.new()
	var port := int(OS.get_environment("KING_CITY_GAME_PORT")) if not OS.get_environment("KING_CITY_GAME_PORT").is_empty() else DEFAULT_PORT
	var error := _server_peer.create_server(port, "0.0.0.0", tls_options)
	if error != OK:
		push_error("Could not start secure WebSocket game server: %s" % error_string(error))
		_server_peer = null
		return
	multiplayer.multiplayer_peer = _server_peer
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	print("KING OF EGYPT CITY authoritative WSS server listening on TCP port %d." % port)


func _configure_city_session_directory() -> void:
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	_city_directory_url = OS.get_environment("KING_CITY_SESSION_DIRECTORY_URL").strip_edges()
	if _city_directory_url.is_empty() and base_url.begins_with("https://"):
		_city_directory_url = base_url + "/functions/v1/city-session-directory"
	_city_directory_server_id = OS.get_environment("KING_CITY_SESSION_SERVER_ID").strip_edges()
	_city_directory_region = OS.get_environment("KING_CITY_SESSION_REGION").strip_edges().to_lower()
	_city_directory_endpoint = OS.get_environment("KING_CITY_SESSION_ENDPOINT").strip_edges()
	_city_directory_hmac_key = Marshalls.base64_to_raw(OS.get_environment("KING_CITY_SESSION_DIRECTORY_HMAC_SECRET_B64").strip_edges())
	var id_regex := RegEx.new()
	id_regex.compile("^[A-Za-z0-9][A-Za-z0-9_-]{2,63}$")
	var region_regex := RegEx.new()
	region_regex.compile("^[a-z0-9][a-z0-9-]{1,31}$")
	var valid := _city_directory_url.begins_with("https://") and id_regex.search(_city_directory_server_id) != null
	valid = valid and region_regex.search(_city_directory_region) != null
	valid = valid and _city_directory_endpoint.begins_with("wss://") and _city_directory_hmac_key.size() >= 32
	_city_directory_enabled = valid
	if not valid:
		push_warning("City session directory is not configured; legacy direct WSS mode remains available.")
		return
	print("Trusted city session directory configuration loaded for server %s." % _city_directory_server_id)


func _city_directory_uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (int(bytes[6]) & 15) | 64
	bytes[8] = (int(bytes[8]) & 63) | 128
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


func _send_city_directory_server_action(payload: Dictionary, callback: Callable = Callable()) -> void:
	if not _city_directory_enabled:
		return
	var raw_body := JSON.stringify(payload)
	var timestamp := str(int(Time.get_unix_time_from_system()))
	var nonce := _city_directory_uuid()
	if nonce.is_empty():
		push_warning("Could not generate a city directory request nonce.")
		return
	var signer := HMACContext.new()
	if signer.start(HashingContext.HASH_SHA256, _city_directory_hmac_key) != OK:
		push_warning("Could not initialize city directory HMAC signing.")
		return
	if signer.update((timestamp + "\n" + nonce + "\n" + raw_body).to_utf8_buffer()) != OK:
		push_warning("Could not prepare city directory HMAC signing.")
		return
	var signature := signer.finish().hex_encode()
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	_city_directory_requests.append(request)
	request.request_completed.connect(_on_city_directory_request_completed.bind(request, callback))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"apikey: " + str(ProjectSettings.get_setting("founder/auth/publishable_key", "")),
		"x-king-city-timestamp: " + timestamp,
		"x-king-city-nonce: " + nonce,
		"x-king-city-signature: " + signature
	])
	var error := request.request(_city_directory_url, headers, HTTPClient.METHOD_POST, raw_body)
	if error != OK:
		_city_directory_requests.erase(request)
		request.queue_free()
		if callback.is_valid():
			callback.call(-1, 0, PackedByteArray())


func _on_city_directory_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, callback: Callable) -> void:
	_city_directory_requests.erase(request)
	if is_instance_valid(request):
		request.queue_free()
	if callback.is_valid():
		callback.call(result, response_code, body)


func _register_city_session_server() -> void:
	if not _city_directory_enabled or _city_directory_registered:
		return
	var capacity := clampi(int(OS.get_environment("KING_CITY_SESSION_CAPACITY")) if not OS.get_environment("KING_CITY_SESSION_CAPACITY").is_empty() else MAX_PLAYERS, 1, MAX_PLAYERS)
	_city_directory_next_heartbeat_usec = Time.get_ticks_usec() + 20000000
	var payload := {
		"action": "server_register",
		"server_id": _city_directory_server_id,
		"region": _city_directory_region,
		"endpoint": _city_directory_endpoint,
		"capacity": capacity,
		"connected_players": 0
	}
	_send_city_directory_server_action(payload, _on_city_session_server_registered)


func _on_city_session_server_registered(result: int, response_code: int, body: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result == HTTPRequest.RESULT_SUCCESS and response_code == 200 and parsed is Dictionary and str(parsed.get("status", "")) == "registered":
		_city_directory_registered = true
		_city_directory_next_heartbeat_usec = Time.get_ticks_usec() + 20000000
		print("Trusted city session directory registered server %s." % _city_directory_server_id)
		return
	_city_directory_next_heartbeat_usec = Time.get_ticks_usec() + 20000000
	push_warning("City session server registration failed; retry scheduled.")


func _city_session_connected_player_count() -> int:
	var count := 0
	for session_variant in _sessions.values():
		if bool((session_variant as Dictionary).get("authenticated", false)):
			count += 1
	return count


func _send_city_session_heartbeat() -> void:
	if not _city_directory_enabled:
		return
	_city_directory_next_heartbeat_usec = Time.get_ticks_usec() + 20000000
	var payload := {
		"action": "server_heartbeat",
		"server_id": _city_directory_server_id,
		"connected_players": _city_session_connected_player_count()
	}
	_send_city_directory_server_action(payload, _on_city_session_heartbeat_completed)


func _on_city_session_heartbeat_completed(result: int, response_code: int, body: PackedByteArray) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not (parsed is Dictionary) or str(parsed.get("status", "")) != "heartbeat_accepted":
		push_warning("City session heartbeat was not accepted; the directory lease will expire unless a retry succeeds.")
	_city_directory_next_heartbeat_usec = Time.get_ticks_usec() + 20000000


func _on_city_reservation_confirmed(result: int, response_code: int, body: PackedByteArray, peer_id: int, user_id: String, reservation_id: String) -> void:
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not _sessions.has(peer_id):
		_release_city_reservation_from_server(user_id, reservation_id)
		return
	var session: Dictionary = _sessions[peer_id]
	if bool(session.get("authenticated", false)) or str(session.get("reservation_id", "")) != reservation_id:
		_release_city_reservation_from_server(user_id, reservation_id)
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200 or not (parsed is Dictionary) or str(parsed.get("status", "")) != "connected":
		_reject_peer(peer_id, "تعذر تأكيد حجز جلسة المدينة؛ حاول الدخول مرة أخرى.")
		return
	_complete_player_authentication(peer_id, user_id, reservation_id)


func _release_city_reservation_from_server(user_id: String, reservation_id: String) -> void:
	if not _city_directory_enabled or user_id.is_empty() or reservation_id.is_empty():
		return
	_send_city_directory_server_action({
		"action": "server_player_disconnected",
		"server_id": _city_directory_server_id,
		"user_id": user_id,
		"reservation_id": reservation_id
	})


func _complete_player_authentication(peer_id: int, user_id: String, reservation_id: String) -> void:
	if not _sessions.has(peer_id) or bool(_sessions[peer_id].get("authenticated", false)):
		return
	var body_node := CharacterBody3D.new()
	body_node.name = "AuthoritativePlayer_%d" % peer_id
	body_node.collision_layer = 2
	body_node.collision_mask = 1
	body_node.position = SPAWN_POSITION
	body_node.floor_snap_length = 0.25
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.8
	collision.shape = capsule
	body_node.add_child(collision)
	var world_root := get_tree().current_scene
	if not is_instance_valid(world_root):
		_reject_peer(peer_id, "عالم المدينة غير جاهز على الخادم.")
		return
	world_root.add_child(body_node)
	_sessions[peer_id]["authenticated"] = true
	_sessions[peer_id]["user_id"] = user_id
	_sessions[peer_id]["reservation_id"] = reservation_id
	_sessions[peer_id]["body"] = body_node
	_sessions[peer_id]["last_auth_usec"] = Time.get_ticks_usec()
	_request_walk_progress(peer_id, "lookup")
	rpc_id(peer_id, "receive_authentication_result", true, "تم التحقق من الحساب وتأكيد حجز جلسة المدينة.")
	if _city_directory_enabled:
		_send_city_session_heartbeat()
	print("Authenticated game peer %d." % peer_id)


func clear_client_session() -> void:
	_client_authenticated = false


func _process(_delta: float) -> void:
	if not multiplayer.is_server():
		return
	var now_usec := Time.get_ticks_usec()
	if _jet_ski_race_state == "countdown" and now_usec >= _jet_ski_race_countdown_until_usec:
		_jet_ski_race_state = "racing"
		_jet_ski_race_countdown_until_usec = 0
		_jet_ski_race_ends_at_usec = now_usec + JET_SKI_RACE_DURATION_SECONDS * 1000000
		_notify_jet_ski_race_participants("انطلق السباق! مدة المسابقة خمس دقائق.")
	elif _jet_ski_race_state == "racing" and _jet_ski_race_duration_expired(now_usec, _jet_ski_race_ends_at_usec):
		_jet_ski_race_state = "finished"
		_jet_ski_race_ends_at_usec = 0
		_notify_jet_ski_race_participants("انتهت مدة المسابقة (خمس دقائق). انتهت الجولة.")
	if _city_directory_enabled and _server_peer != null and now_usec >= _city_directory_next_heartbeat_usec:
		if _city_directory_registered:
			_send_city_session_heartbeat()
		else:
			_register_city_session_server()
	for peer_id_variant in _sessions.keys():
		var peer_id := int(peer_id_variant)
		var session: Dictionary = _sessions[peer_id]
		if not bool(session.get("authenticated", false)) and now_usec - int(session.get("connected_at_usec", now_usec)) > 10000000:
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		elif bool(session.get("authenticated", false)) and now_usec - int(session.get("last_auth_usec", now_usec)) > 3300000000:
			multiplayer.multiplayer_peer.disconnect_peer(peer_id)


func _on_peer_connected(peer_id: int) -> void:
	if _city_directory_enabled and not _city_directory_registered:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	if _sessions.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_sessions[peer_id] = {
		"authenticated": false,
		"user_id": "",
		"reservation_id": "",
		"instance_id": "city-main",
		"body": null,
		"direction": Vector3.ZERO,
		"sprint": false,
		"velocity": Vector3.ZERO,
		"last_sequence": -1,
		"jet_ski_mounted": false,
		"jet_ski_position": Vector3.ZERO,
		"jet_ski_rotation_y": 0.0,
		"jet_ski_velocity": Vector3.ZERO,
		"jet_ski_throttle": 0.0,
		"jet_ski_brake": 0.0,
		"jet_ski_steering": 0.0,
		"jet_ski_last_sequence": 0,
		"jet_ski_last_input_usec": 0,
		"jet_ski_input_window_usec": Time.get_ticks_usec(),
		"jet_ski_input_count": 0,
		"last_input_usec": 0,
		"last_emote_usec": 0,
		"active_emote": "",
		"emote_until_usec": 0,
		"is_sitting": false,
		"last_sit_usec": 0,
		"last_safe_position": SPAWN_POSITION,
		"last_safe_return_usec": 0,
		"input_window_usec": Time.get_ticks_usec(),
		"input_count": 0,
		"reached_objectives": {},
		"connected_at_usec": Time.get_ticks_usec(),
		"last_auth_usec": 0,
		"active_job": {},
		"completed_jobs": {},
		"active_mission": {},
		"completed_missions": {},
		"walk_distance_meters": 0.0,
		"walk_pending_meters": 0.0,
		"walk_progress_ready": false,
		"walk_request_active": false,
		"walk_retry_after_usec": 0,
		"walk_pending_event_id": "",
		"walk_pending_event_meters": 0.0,
		"walk_pending_event_issued_at": 0,
		"walk_pending_event_expires_at": 0
	}


func _on_peer_disconnected(peer_id: int) -> void:
	var walk_request := _walk_progress_requests.get(peer_id) as HTTPRequest
	if is_instance_valid(walk_request):
		walk_request.queue_free()
	_walk_progress_requests.erase(peer_id)
	var pending_lookup := _pending_mission_progress_lookups.get(peer_id, {}) as Dictionary
	var pending_request := pending_lookup.get("request") as HTTPRequest
	if is_instance_valid(pending_request):
		pending_request.queue_free()
	_pending_mission_progress_lookups.erase(peer_id)
	_abort_peer_arcade_session(peer_id, "انقطع اتصال أحد المشاركين؛ أُغلقت الجلسة دون نتيجة أو مكافأة.")
	var session: Dictionary = _sessions.get(peer_id, {})
	if _city_directory_enabled and bool(session.get("authenticated", false)):
		var reservation_id := str(session.get("reservation_id", ""))
		var user_id := str(session.get("user_id", ""))
		if not reservation_id.is_empty() and not user_id.is_empty():
			_send_city_directory_server_action({
				"action": "server_player_disconnected",
				"server_id": _city_directory_server_id,
				"user_id": user_id,
				"reservation_id": reservation_id
			})
	var body := session.get("body") as CharacterBody3D
	if is_instance_valid(body):
		body.queue_free()
	_sessions.erase(peer_id)
	var was_jet_ski_race_participant := _jet_ski_race_participants.has(peer_id)
	_jet_ski_race_participants.erase(peer_id)
	_jet_ski_race_spectators.erase(peer_id)
	_jet_ski_race_locked_participants.erase(peer_id)
	if _jet_ski_race_should_reopen_after_disconnect(was_jet_ski_race_participant, _jet_ski_race_state):
		_jet_ski_race_state = "waiting"
		_jet_ski_race_countdown_until_usec = 0
		_jet_ski_race_locked_participants.clear()
		_notify_jet_ski_race_participants("غادر متسابق قبل بدء الجولة؛ أُعيد فتح التسجيل.")
	elif was_jet_ski_race_participant:
		_notify_jet_ski_race_participants("غادر متسابق؛ تم تحديث عدد المشاركين.")
	if _auth_requests.has(peer_id):
		var request := _auth_requests[peer_id] as HTTPRequest
		if is_instance_valid(request):
			request.queue_free()
		_auth_requests.erase(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func authenticate_player(access_token: String, reservation_id: String = "") -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or _auth_requests.has(peer_id):
		return
	if _city_directory_enabled:
		var reservation_regex := RegEx.new()
		reservation_regex.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
		if reservation_regex.search(reservation_id) == null:
			_reject_peer(peer_id, "حجز جلسة المدينة غير صالح أو منتهي.")
			return
		if bool(_sessions[peer_id].get("authenticated", false)):
			if str(_sessions[peer_id].get("reservation_id", "")) != reservation_id:
				_reject_peer(peer_id, "لا يمكن تغيير حجز الجلسة أثناء الاتصال.")
				return
		else:
			_sessions[peer_id]["reservation_id"] = reservation_id
	if access_token.length() < 40 or access_token.length() > 8192:
		_reject_peer(peer_id, "رمز جلسة الحساب غير صالح.")
		return
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		_reject_peer(peer_id, "إعدادات التحقق من حساب اللاعب غير مكتملة على الخادم.")
		return
	var request := HTTPRequest.new()
	request.timeout = 8.0
	add_child(request)
	request.request_completed.connect(_on_auth_request_completed.bind(peer_id))
	_auth_requests[peer_id] = request
	var headers := PackedStringArray([
		"Accept: application/json",
		"apikey: " + publishable_key,
		"Authorization: Bearer " + access_token
	])
	var error := request.request(base_url + "/auth/v1/user", headers, HTTPClient.METHOD_GET)
	if error != OK:
		_auth_requests.erase(peer_id)
		request.queue_free()
		_reject_peer(peer_id, "تعذر بدء التحقق من حساب اللاعب.")


func _on_auth_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, peer_id: int) -> void:
	var request := _auth_requests.get(peer_id) as HTTPRequest
	_auth_requests.erase(peer_id)
	if is_instance_valid(request):
		request.queue_free()
	if not _sessions.has(peer_id):
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_reject_peer(peer_id, "انتهت جلسة الحساب أو تعذر التحقق منها.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_reject_peer(peer_id, "استجابة التحقق من الحساب غير صالحة.")
		return
	var user_id := str(parsed.get("id", ""))
	var uuid_pattern := RegEx.new()
	uuid_pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	if uuid_pattern.search(user_id) == null:
		_reject_peer(peer_id, "لم يتم تأكيد هوية حساب اللاعب.")
		return
	if bool(_sessions[peer_id].get("authenticated", false)):
		if str(_sessions[peer_id].get("user_id", "")) != user_id:
			_reject_peer(peer_id, "تغيرت هوية الحساب أثناء جلسة اللعب.")
			return
		_sessions[peer_id]["last_auth_usec"] = Time.get_ticks_usec()
		rpc_id(peer_id, "receive_authentication_result", true, "تم تجديد التحقق من حساب اللاعب.")
		return
	var reservation_id := str(_sessions[peer_id].get("reservation_id", ""))
	if _city_directory_enabled:
		_send_city_directory_server_action({
			"action": "server_player_connected",
			"server_id": _city_directory_server_id,
			"user_id": user_id,
			"reservation_id": reservation_id
		}, _on_city_reservation_confirmed.bind(peer_id, user_id, reservation_id))
		return
	_complete_player_authentication(peer_id, user_id, reservation_id)


func _reject_peer(peer_id: int, reason: String) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "receive_authentication_result", false, reason)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func receive_authentication_result(success: bool, message: String) -> void:
	if multiplayer.is_server():
		return
	if success:
		_client_authenticated = true
		authentication_completed.emit(true, message)
	else:
		_client_authenticated = false
		authentication_completed.emit(false, message)


func request_start_arcade_session(machine_id: String, mode: String) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	request_start_arcade_session_rpc.rpc_id(1, machine_id, mode)


func request_join_arcade_session(session_id: String) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	request_join_arcade_session_rpc.rpc_id(1, session_id)


func request_launch_arcade_session(session_id: String) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	request_launch_arcade_session_rpc.rpc_id(1, session_id)


func request_arcade_slot_spin(spin_type: String, wager_chips: int = 10) -> void:
	if _is_dedicated_server or not is_authenticated() or spin_type != "auto":
		return
	request_arcade_slot_spin_rpc.rpc_id(1, spin_type, wager_chips)


func request_leave_arcade_session(session_id: String) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	request_leave_arcade_session_rpc.rpc_id(1, session_id)


func request_jet_ski_mount() -> void:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return
	request_jet_ski_mount_rpc.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func request_jet_ski_mount_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id):
		return
	var session: Dictionary = _sessions[peer_id]
	if not bool(session.get("authenticated", false)) or bool(session.get("jet_ski_mounted", false)) or bool(session.get("is_sitting", false)):
		return
	var body := session.get("body") as CharacterBody3D
	if not is_instance_valid(body) or body.global_position.distance_to(JET_SKI_SERVER_LAUNCH_POSITION) > JET_SKI_SERVER_BOARDING_RADIUS:
		rpc_id(peer_id, "receive_jet_ski_mount_result", false, "اقترب من بوابة الجت سكي الملكية أولًا.")
		return
	for other_variant in _sessions.keys():
		var other_peer := int(other_variant)
		if other_peer != peer_id and bool((_sessions[other_peer] as Dictionary).get("jet_ski_mounted", false)):
			rpc_id(peer_id, "receive_jet_ski_mount_result", false, "الجت سكي مشغولة حاليًا.")
			return
	var now_usec := Time.get_ticks_usec()
	session["jet_ski_last_sequence"] = 0
	session["jet_ski_input_window_usec"] = now_usec
	session["jet_ski_input_count"] = 0
	session["jet_ski_mounted"] = true
	session["jet_ski_position"] = JET_SKI_SERVER_LAUNCH_POSITION
	session["jet_ski_rotation_y"] = body.rotation.y
	session["jet_ski_velocity"] = Vector3.ZERO
	session["jet_ski_throttle"] = 0.0
	session["jet_ski_brake"] = 0.0
	session["jet_ski_steering"] = 0.0
	session["jet_ski_last_input_usec"] = now_usec
	session["is_sitting"] = true
	session["direction"] = Vector3.ZERO
	session["sprint"] = false
	body.global_position = JET_SKI_SERVER_LAUNCH_POSITION + JET_SKI_RIDER_OFFSET
	body.velocity = Vector3.ZERO
	session["velocity"] = Vector3.ZERO
	_sessions[peer_id] = session
	rpc_id(peer_id, "receive_jet_ski_mount_result", true, "تم تأكيد ركوب الجت سكي على الخادم.")


func request_jet_ski_unmount() -> void:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return
	request_jet_ski_unmount_rpc.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func request_jet_ski_unmount_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id):
		return
	var session: Dictionary = _sessions[peer_id]
	if not bool(session.get("authenticated", false)) or not bool(session.get("jet_ski_mounted", false)):
		return
	var body := session.get("body") as CharacterBody3D
	if not is_instance_valid(body):
		return
	var craft_position: Vector3 = session.get("jet_ski_position", JET_SKI_SERVER_LAUNCH_POSITION)
	var craft_rotation := float(session.get("jet_ski_rotation_y", 0.0))
	var right := Vector3(cos(craft_rotation), 0.0, -sin(craft_rotation))
	body.global_position = craft_position + right * 2.0 + Vector3.UP * 0.15
	body.velocity = Vector3.ZERO
	session["jet_ski_mounted"] = false
	session["jet_ski_throttle"] = 0.0
	session["jet_ski_brake"] = 0.0
	session["jet_ski_steering"] = 0.0
	session["jet_ski_velocity"] = Vector3.ZERO
	session["is_sitting"] = false
	session["velocity"] = Vector3.ZERO
	session["last_input_usec"] = Time.get_ticks_usec()
	_sessions[peer_id] = session


func send_jet_ski_input(throttle: float, brake: float, steering: float) -> void:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return
	_jet_ski_input_sequence += 1
	submit_jet_ski_input.rpc_id(1, _jet_ski_input_sequence, throttle, brake, steering)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_jet_ski_input(sequence: int, throttle: Variant, brake: Variant, steering: Variant) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id):
		return
	var session: Dictionary = _sessions[peer_id]
	if not bool(session.get("authenticated", false)) or not bool(session.get("jet_ski_mounted", false)):
		return
	var now_usec := Time.get_ticks_usec()
	var validation := JetSkiNetworkContract.validate_input(
		throttle, brake, steering, sequence,
		int(session.get("jet_ski_last_sequence", 0)), now_usec,
		int(session.get("jet_ski_input_window_usec", now_usec)),
		int(session.get("jet_ski_input_count", 0))
	)
	if not bool(validation.get("accepted", false)):
		return
	session["jet_ski_last_sequence"] = sequence
	session["jet_ski_last_input_usec"] = now_usec
	session["jet_ski_input_window_usec"] = int(validation["window_start_usec"])
	session["jet_ski_input_count"] = int(validation["window_count"])
	session["jet_ski_throttle"] = float(validation["throttle"])
	session["jet_ski_brake"] = float(validation["brake"])
	session["jet_ski_steering"] = float(validation["steering"])
	_sessions[peer_id] = session


@rpc("authority", "call_remote", "reliable")
func receive_jet_ski_mount_result(success: bool, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	jet_ski_mount_result_received.emit(success, message)


func send_movement_input(world_direction: Vector3, sprint: bool) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	var direction := world_direction
	direction.y = 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()
	_input_sequence += 1
	submit_movement_input.rpc_id(1, _input_sequence, direction, sprint)


func request_safe_return() -> bool:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return false
	request_safe_return_rpc.rpc_id(1)
	return true


@rpc("any_peer", "call_remote", "reliable")
func request_safe_return_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id):
		return
	var session: Dictionary = _sessions[peer_id]
	if not bool(session.get("authenticated", false)):
		return
	if bool(session.get("jet_ski_mounted", false)):
		rpc_id(peer_id, "receive_safe_return_result", false, "انزل من الجت سكي قبل طلب العودة الآمنة.")
		return
	var now_usec := Time.get_ticks_usec()
	if now_usec - int(session.get("last_safe_return_usec", 0)) < 5000000:
		rpc_id(peer_id, "receive_safe_return_result", false, "انتظر قليلًا قبل طلب عودة آمنة أخرى.")
		return
	var body := session.get("body") as CharacterBody3D
	if not is_instance_valid(body):
		rpc_id(peer_id, "receive_safe_return_result", false, "تعذر العثور على شخصية اللاعب على الخادم.")
		return
	# Server-owned relocation: reset movement only; keep account, inventory,
	# friends, wallet, mission and all persisted progression untouched.
	body.global_position = SPAWN_POSITION
	body.velocity = Vector3.ZERO
	body.reset_physics_interpolation()
	session["velocity"] = Vector3.ZERO
	session["direction"] = Vector3.ZERO
	session["sprint"] = false
	session["is_sitting"] = false
	session["last_input_usec"] = now_usec
	session["last_safe_position"] = SPAWN_POSITION
	session["last_safe_return_usec"] = now_usec
	_sessions[peer_id] = session
	rpc_id(peer_id, "receive_safe_return_result", true, "تمت إعادتك إلى نقطة بداية المدينة. حسابك وممتلكاتك وتقدمك محفوظة.")


@rpc("authority", "call_remote", "reliable")
func receive_safe_return_result(success: bool, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	safe_return_completed.emit(success, message)


func send_player_sit(is_sitting: bool) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	submit_player_sit.rpc_id(1, is_sitting)


@rpc("any_peer", "call_remote", "reliable")
func submit_player_sit(is_sitting: bool) -> void:
	if not multiplayer.is_server() or not _sessions.has(multiplayer.get_remote_sender_id()):
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var session: Dictionary = _sessions[peer_id]
	if not bool(session.get("authenticated", false)) or typeof(is_sitting) != TYPE_BOOL:
		return
	var now_usec := Time.get_ticks_usec()
	if now_usec - int(session.get("last_sit_usec", 0)) < 200000:
		return
	session["last_sit_usec"] = now_usec
	session["is_sitting"] = is_sitting
	_sessions[peer_id] = session


func send_player_emote(emote_id: String) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	if not ["clap", "dance", "cry", "wave", "heart"].has(emote_id):
		return
	submit_player_emote.rpc_id(1, emote_id)


@rpc("any_peer", "call_remote", "reliable")
func submit_player_emote(emote_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var durations := {"clap": 2.4, "dance": 4.0, "cry": 3.0, "wave": 2.2, "heart": 2.6}
	if not durations.has(emote_id):
		return
	var session: Dictionary = _sessions[peer_id]
	var now_usec := Time.get_ticks_usec()
	if now_usec - int(session.get("last_emote_usec", 0)) < 500000:
		return
	session["last_emote_usec"] = now_usec
	session["active_emote"] = emote_id
	session["emote_until_usec"] = now_usec + int(float(durations[emote_id]) * 1000000.0)
	_sessions[peer_id] = session


@rpc("any_peer", "call_remote", "unreliable_ordered")
func submit_movement_input(sequence: int, direction: Vector3, sprint: bool) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var session: Dictionary = _sessions[peer_id]
	if sequence <= int(session.get("last_sequence", -1)):
		return
	var now_usec := Time.get_ticks_usec()
	var window_usec := int(session.get("input_window_usec", now_usec))
	var count := int(session.get("input_count", 0))
	if now_usec - window_usec >= 1000000:
		window_usec = now_usec
		count = 0
	count += 1
	if count > int(MAX_INPUT_RATE):
		session["input_window_usec"] = window_usec
		session["input_count"] = count
		_sessions[peer_id] = session
		return
	if not is_finite(direction.x) or not is_finite(direction.y) or not is_finite(direction.z) or absf(direction.y) > 0.001 or direction.length() > 1.05:
		return
	session["last_sequence"] = sequence
	session["last_input_usec"] = now_usec
	session["input_window_usec"] = window_usec
	session["input_count"] = count
	session["direction"] = direction.limit_length(1.0)
	session["sprint"] = sprint
	_sessions[peer_id] = session


func _get_server_job_definition(_job_id: String) -> Dictionary:
	# Legacy one-stop job definitions are intentionally retired. The approved
	# multi-stop delivery workflow remains offline-only until vehicle state and
	# hand-delivery interactions are authoritative on the server.
	return {}


@rpc("any_peer", "call_remote", "reliable")
func request_start_job(job_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var session: Dictionary = _sessions[peer_id]
	var active_mission: Dictionary = session.get("active_mission", {})
	if not active_mission.is_empty():
		rpc_id(peer_id, "receive_job_start_result", false, job_id, Vector3.ZERO, "أنهِ المهمة الحالية أولًا.")
		return
	var safe_job_id := job_id.strip_edges().to_lower()
	var definition := _get_server_job_definition(safe_job_id)
	if definition.is_empty():
		rpc_id(peer_id, "receive_job_start_result", false, safe_job_id, Vector3.ZERO, "هذه الوظيفة غير معتمدة على الخادم.")
		return
	if not _job_available_today(safe_job_id):
		rpc_id(peer_id, "receive_job_start_result", false, safe_job_id, Vector3.ZERO, "هذه الوظيفة غير متاحة اليوم وفق جدول الأسبوع.")
		return
	var daily_completion_key := "%s:%s" % [str(session.get("user_id", "")), _daily_job_key(safe_job_id)]
	if _daily_job_completions.has(daily_completion_key):
		rpc_id(peer_id, "receive_job_start_result", false, safe_job_id, Vector3.ZERO, "أنجزت هذه الوظيفة اليوم. اختر وظيفة أخرى أو عد غدًا.")
		return
	var current_job: Dictionary = session.get("active_job", {})
	if not current_job.is_empty():
		rpc_id(peer_id, "receive_job_start_result", false, safe_job_id, Vector3.ZERO, "لديك وظيفة أخرى قيد التنفيذ.")
		return
	var completed_jobs: Dictionary = session.get("completed_jobs", {})
	if completed_jobs.has(_daily_job_key(safe_job_id)):
		rpc_id(peer_id, "receive_job_start_result", false, safe_job_id, Vector3.ZERO, "أنجزت هذه الوظيفة بالفعل اليوم.")
		return
	var body := session.get("body") as CharacterBody3D
	if not is_instance_valid(body) or body.global_position.distance_to(definition["board"]) > 5.0:
		rpc_id(peer_id, "receive_job_start_result", false, safe_job_id, Vector3.ZERO, "اقترب من لوحة الوظائف أولًا.")
		return
	session["active_job"] = {
		"job_id": safe_job_id,
		"target": definition["target"],
		"radius": 2.2
	}
	_sessions[peer_id] = session
	rpc_id(peer_id, "receive_job_start_result", true, safe_job_id, definition["target"], "بدأت الوظيفة على الخادم. اتبع علامة الهدف.")


@rpc("authority", "call_remote", "reliable")
func receive_job_start_result(success: bool, job_id: String, target: Vector3, message: String) -> void:
	if multiplayer.is_server():
		return
	job_start_result.emit(success, job_id, target, message)


@rpc("authority", "call_remote", "reliable")
func receive_server_job_completed(job_id: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	job_completed.emit(job_id)


func _get_server_mission_definition(mission_id: String) -> Dictionary:
	match mission_id:
		"city_adventure_rescue":
			return {"board": Vector3(-75.0, 0.0, 63.9), "stages": [Vector3(-75.0, 0.15, 20.9), Vector3(-75.0, 0.15, 0.9)]}
		"city_adventure_treasure":
			return {"board": Vector3(-75.0, 0.0, 63.9), "stages": [Vector3(-30.0, 0.15, -23.6), Vector3(0.0, 0.15, 6.4), Vector3(60.0, 0.15, 36.4)]}
		"city_adventure_message":
			return {"board": Vector3(-75.0, 0.0, 63.9), "stages": [Vector3(75.0, 0.15, 0.9), Vector3(75.0, 0.15, 20.9), Vector3(60.0, 0.15, -23.6)]}
		"city_adventure_survival":
			return {"board": Vector3(-75.0, 0.0, 63.9), "stages": [Vector3(-60.0, 0.15, 45.0), Vector3(-30.0, 0.15, 45.0), Vector3(0.0, 0.15, 45.0), Vector3(30.0, 0.15, 45.0), Vector3(60.0, 0.15, 45.0)]}
		"mission_shop":
			return {"board": Vector3(16.0, 0.0, 16.0), "target": Vector3(16.0, 0.15, 6.0)}
		"mission_restaurant":
			return {"board": Vector3(-16.0, 0.0, 16.0), "target": Vector3(-16.0, 0.15, 6.0)}
		"mission_employment":
			return {"board": Vector3(16.0, 0.0, -16.0), "target": Vector3(16.0, 0.15, -26.0)}
	return {}


@rpc("any_peer", "call_remote", "reliable")
func request_start_mission(mission_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var session: Dictionary = _sessions[peer_id]
	var safe_mission_id := mission_id.strip_edges().to_lower()
	var definition := _get_server_mission_definition(safe_mission_id)
	if definition.is_empty():
		rpc_id(peer_id, "receive_mission_start_result", false, safe_mission_id, Vector3.ZERO, "هذه المهمة غير معتمدة على الخادم.")
		return
	if not session.get("active_mission", {}).is_empty() or not session.get("active_job", {}).is_empty():
		rpc_id(peer_id, "receive_mission_start_result", false, safe_mission_id, Vector3.ZERO, "أنهِ النشاط الحالي أولًا.")
		return
	if (session.get("completed_missions", {}) as Dictionary).has(safe_mission_id):
		rpc_id(peer_id, "receive_mission_start_result", false, safe_mission_id, Vector3.ZERO, "أنجزت هذه المهمة بالفعل في جلسة اللعب.")
		return
	var body := session.get("body") as CharacterBody3D
	if not is_instance_valid(body) or body.global_position.distance_to(definition["board"]) > 5.0:
		rpc_id(peer_id, "receive_mission_start_result", false, safe_mission_id, Vector3.ZERO, "اقترب من المبنى أولًا.")
		return
	if safe_mission_id.begins_with("city_adventure_"):
		_start_server_mission_for_peer(peer_id, safe_mission_id)
		return
	_request_server_mission_progress_lookup(peer_id, safe_mission_id)


func _start_server_mission_for_peer(peer_id: int, mission_id: String) -> void:
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var session: Dictionary = _sessions[peer_id]
	if not session.get("active_mission", {}).is_empty() or not session.get("active_job", {}).is_empty():
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "أنهِ النشاط الحالي أولًا.")
		return
	if (session.get("completed_missions", {}) as Dictionary).has(mission_id):
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "أنجزت هذه المهمة بالفعل في جلسة اللعب.")
		return
	var definition := _get_server_mission_definition(mission_id)
	var body := session.get("body") as CharacterBody3D
	if definition.is_empty() or not is_instance_valid(body) or body.global_position.distance_to(definition.get("board", Vector3.ZERO)) > 5.0:
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "تعذر تأكيد موقع بدء المهمة.")
		return
	var mission_stages: Array = definition.get("stages", [definition.get("target", Vector3.ZERO)])
	if mission_stages.is_empty():
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "مسار المهمة غير مكتمل على الخادم.")
		return
	var first_target: Vector3 = mission_stages[0]
	session["active_mission"] = {
		"mission_id": mission_id,
		"target": first_target,
		"stages": mission_stages.duplicate(true),
		"stage_index": 0,
		"radius": 2.2,
		"started_at_usec": Time.get_ticks_usec(),
		"time_limit_seconds": 60.0 if mission_id == "city_adventure_survival" else 0.0
	}
	_sessions[peer_id] = session
	rpc_id(peer_id, "receive_mission_start_result", true, mission_id, first_target, "بدأت المهمة على الخادم. اتبع علامة الهدف.")


func _request_server_mission_progress_lookup(peer_id: int, mission_id: String) -> void:
	if _pending_mission_progress_lookups.has(peer_id):
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "جارٍ التحقق من سجل المهمة؛ انتظر لحظة.")
		return
	var session: Dictionary = _sessions.get(peer_id, {})
	var user_id := str(session.get("user_id", ""))
	if user_id.is_empty() or _proof_hmac_secret.size() < 32:
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "خدمة التحقق من سجل الإنجازات غير مهيأة؛ لم تبدأ المهمة.")
		return
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "إعدادات سجل الإنجازات الخادمي غير مكتملة.")
		return
	var issued_at := int(Time.get_unix_time_from_system())
	var canonical := "v1|lookup|%s|mission|%s|%d" % [user_id, mission_id, issued_at]
	var hmac_context := HMACContext.new()
	if hmac_context.start(HashingContext.HASH_SHA256, _proof_hmac_secret) != OK or hmac_context.update(canonical.to_utf8_buffer()) != OK:
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "تعذر توقيع طلب التحقق من سجل المهمة.")
		return
	var payload := {
		"user_id": user_id,
		"activity_kind": "mission",
		"activity_id": mission_id,
		"issued_at": issued_at,
		"signature_hex": hmac_context.finish().hex_encode()
	}
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(_on_server_mission_progress_lookup_completed.bind(request, peer_id, user_id, mission_id))
	_pending_mission_progress_lookups[peer_id] = {"request": request, "user_id": user_id, "mission_id": mission_id}
	var error := request.request(
		base_url + "/functions/v1/game-progress-lookup",
		PackedStringArray(["Content-Type: application/json", "apikey: " + publishable_key]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_pending_mission_progress_lookups.erase(peer_id)
		request.queue_free()
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "تعذر بدء التحقق من سجل المهمة؛ لم تبدأ المهمة.")


func _on_server_mission_progress_lookup_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, peer_id: int, user_id: String, mission_id: String) -> void:
	if is_instance_valid(request):
		request.queue_free()
	var pending: Dictionary = _pending_mission_progress_lookups.get(peer_id, {})
	if pending.is_empty() or pending.get("request") != request:
		return
	_pending_mission_progress_lookups.erase(peer_id)
	if not _sessions.has(peer_id) or str(_sessions[peer_id].get("user_id", "")) != user_id:
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "تعذر التحقق من سجل إنجازاتك؛ لم تبدأ المهمة حفاظًا على تقدمك.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not bool(parsed.get("verified", false)) or typeof(parsed.get("completed")) != TYPE_BOOL:
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "استجابة سجل الإنجازات غير موثوقة؛ لم تبدأ المهمة.")
		return
	if bool(parsed.get("completed", false)):
		rpc_id(peer_id, "receive_mission_start_result", false, mission_id, Vector3.ZERO, "أنجزت هذه المهمة سابقًا على حسابك؛ لن نكررها.")
		return
	_start_server_mission_for_peer(peer_id, mission_id)


@rpc("any_peer", "call_remote", "reliable")
func request_submit_message_puzzle_answer(answer: String) -> void:
	if not multiplayer.is_server() or answer.length() > 64:
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var session: Dictionary = _sessions[peer_id]
	var active_mission: Dictionary = session.get("active_mission", {})
	if str(active_mission.get("mission_id", "")) != "city_adventure_message" or not bool(active_mission.get("puzzle_ready", false)):
		return
	var body := session.get("body") as CharacterBody3D
	var stages: Array = active_mission.get("stages", [])
	var final_target: Vector3 = active_mission.get("target", Vector3.ZERO)
	if not is_instance_valid(body) or stages.is_empty() or int(active_mission.get("stage_index", -1)) != stages.size() - 1:
		return
	var distance := Vector2(body.global_position.x - final_target.x, body.global_position.z - final_target.z).length()
	if distance > float(active_mission.get("radius", 2.2)) + 0.6:
		rpc_id(peer_id, "receive_mission_stage_updated", "city_adventure_message", final_target, stages.size(), stages.size(), "ابقَ عند نقطة فك الشفرة لإرسال الإجابة.")
		return
	var normalized_answer := answer.strip_edges().replace(" ", "").replace("ـ", "")
	if normalized_answer != "النيل":
		rpc_id(peer_id, "receive_mission_stage_updated", "city_adventure_message", final_target, stages.size(), stages.size(), "الإجابة غير صحيحة. راجع الأدلة وحاول مرة أخرى.")
		return
	session["active_mission"] = {}
	_sessions[peer_id] = session
	rpc_id(peer_id, "receive_server_mission_completed", "city_adventure_message")
	_issue_activity_proof(peer_id, str(session.get("user_id", "")), "mission", "city_adventure_message")


@rpc("any_peer", "call_remote", "reliable")
func request_cancel_mission() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var session: Dictionary = _sessions[peer_id]
	var active_mission: Dictionary = session.get("active_mission", {})
	var mission_id := str(active_mission.get("mission_id", ""))
	if not mission_id.begins_with("city_adventure_"):
		return
	session["active_mission"] = {}
	_sessions[peer_id] = session
	rpc_id(peer_id, "receive_server_mission_failed", mission_id, "تم إلغاء المغامرة بناءً على طلبك.")


@rpc("any_peer", "call_remote", "reliable")
func request_rescue_citizen_interaction() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	var session: Dictionary = _sessions[peer_id]
	var active_mission: Dictionary = session.get("active_mission", {})
	if str(active_mission.get("mission_id", "")) != "city_adventure_rescue" or int(active_mission.get("stage_index", -1)) != 0:
		return
	var body := session.get("body") as CharacterBody3D
	var mission_target: Vector3 = active_mission.get("target", Vector3.ZERO)
	if not is_instance_valid(body):
		return
	var distance := Vector2(body.global_position.x - mission_target.x, body.global_position.z - mission_target.z).length()
	if distance > float(active_mission.get("radius", 2.2)) + 0.6:
		rpc_id(peer_id, "receive_mission_stage_updated", "city_adventure_rescue", mission_target, 1, 2, "اقترب من المواطن أولًا ثم تفاعل معه.")
		return
	var mission_stages: Array = active_mission.get("stages", [])
	if mission_stages.size() < 2:
		return
	var next_target: Vector3 = mission_stages[1]
	active_mission["stage_index"] = 1
	active_mission["target"] = next_target
	session["active_mission"] = active_mission
	_sessions[peer_id] = session
	rpc_id(peer_id, "receive_mission_stage_updated", "city_adventure_rescue", next_target, 2, mission_stages.size(), "ساعدت المواطن! اتجه إلى مركز الشرطة لإكمال الإنقاذ.")


@rpc("authority", "call_remote", "reliable")
func receive_mission_start_result(success: bool, mission_id: String, target: Vector3, message: String) -> void:
	if multiplayer.is_server():
		return
	mission_start_result.emit(success, mission_id, target, message)


@rpc("authority", "call_remote", "reliable")
func receive_mission_stage_updated(mission_id: String, target: Vector3, stage_number: int, stage_count: int, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	mission_stage_updated.emit(mission_id, target, stage_number, stage_count, message)


@rpc("authority", "call_remote", "reliable")
func receive_server_mission_failed(mission_id: String, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	mission_failed.emit(mission_id, message)


@rpc("authority", "call_remote", "reliable")
func receive_server_mission_completed(mission_id: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	mission_completed.emit(mission_id)


@rpc("authority", "call_remote", "reliable")
func receive_server_activity_progress_recorded(activity_kind: String, activity_id: String, reward_eligible: bool) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	activity_progress_recorded.emit(activity_kind, activity_id, reward_eligible)


@rpc("authority", "call_remote", "reliable")
func receive_server_activity_proof(activity_kind: String, activity_id: String, proof_id: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	activity_proof_received.emit(activity_kind, activity_id, proof_id)


@rpc("authority", "call_remote", "reliable")
func receive_server_activity_proof_failed(activity_kind: String, activity_id: String, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	activity_proof_failed.emit(activity_kind, activity_id, message)




# Arcade session authority foundation.
# Machine controllers must be registered by trusted server scene code. Clients can
# request lifecycle transitions, but can never submit or choose a result.
func register_arcade_machine(machine_id: String, zone_id: String, anchor: Node3D, controller: Node) -> bool:
	if not multiplayer.is_server() or not _is_valid_arcade_machine_id(machine_id):
		return false
	if not ARCADE_ZONE_IDS.has(zone_id) or not is_instance_valid(anchor) or not is_instance_valid(controller):
		return false
	if not anchor.is_inside_tree() or not controller.is_inside_tree() or _arcade_machines.has(machine_id):
		return false
	for method_name in ["can_start_arcade_session", "can_join_arcade_session", "start_arcade_session", "validate_arcade_session_result", "abort_arcade_session"]:
		if not controller.has_method(method_name):
			push_warning("Arcade machine %s is missing required server controller method %s." % [machine_id, method_name])
			return false
	_arcade_machines[machine_id] = {"zone_id": zone_id, "anchor": anchor, "controller": controller}
	return true


func unregister_arcade_machine(machine_id: String) -> void:
	if not multiplayer.is_server():
		return
	for session_id_variant in _arcade_sessions.keys():
		var session_id := str(session_id_variant)
		if str(_arcade_sessions[session_id].get("machine_id", "")) == machine_id:
			_abort_arcade_session(session_id, "تم إيقاف الماكينة على الخادم.")
	_arcade_machines.erase(machine_id)


func _user_has_active_arcade_session(user_id: String) -> bool:
	if user_id.is_empty():
		return true
	for peer_id_variant in _peer_arcade_sessions.keys():
		var peer_id := int(peer_id_variant)
		if _sessions.has(peer_id) and str(_sessions[peer_id].get("user_id", "")) == user_id:
			return true
	return false


func _is_valid_arcade_machine_id(machine_id: String) -> bool:
	if machine_id.is_empty() or machine_id.length() > 80:
		return false
	var pattern := RegEx.new()
	pattern.compile("^[a-z0-9][a-z0-9_.-]{0,79}$")
	return pattern.search(machine_id) != null


@rpc("any_peer", "call_remote", "reliable")
func request_start_arcade_session_rpc(machine_id: String, mode: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if not _is_valid_arcade_machine_id(machine_id) or not ARCADE_SESSION_MODES.has(mode):
		_reply_arcade_session(peer_id, "", "rejected", machine_id, "طلب جلسة اللعب غير صالح.")
		return
	if _peer_arcade_sessions.has(peer_id) or _user_has_active_arcade_session(str(_sessions[peer_id].get("user_id", ""))):
		_reply_arcade_session(peer_id, "", "rejected", machine_id, "لديك جلسة ماكينة أخرى قيد التنفيذ على هذا الحساب.")
		return
	var machine: Dictionary = _arcade_machines.get(machine_id, {})
	var anchor := machine.get("anchor") as Node3D
	var controller := machine.get("controller") as Node
	if machine.is_empty() or not is_instance_valid(anchor) or not is_instance_valid(controller):
		_reply_arcade_session(peer_id, "", "unavailable", machine_id, "هذه الماكينة غير مفعلة للعب الفعلي بعد.")
		return
	var body := _sessions[peer_id].get("body") as CharacterBody3D
	if not is_instance_valid(body) or body.global_position.distance_to(anchor.global_position) > ARCADE_MACHINE_INTERACTION_RADIUS:
		_reply_arcade_session(peer_id, "", "rejected", machine_id, "اقترب من الماكينة أولًا.")
		return
	var user_id := str(_sessions[peer_id].get("user_id", ""))
	if not bool(controller.call("can_start_arcade_session", user_id, mode)):
		_reply_arcade_session(peer_id, "", "rejected", machine_id, "لا يمكن بدء جلسة بهذه الإعدادات حاليًا.")
		return
	var session_id := _new_server_event_uuid()
	if session_id.is_empty() or _closed_arcade_sessions.has(session_id) or _arcade_sessions.has(session_id):
		_reply_arcade_session(peer_id, "", "rejected", machine_id, "تعذر إنشاء معرّف جلسة آمن.")
		return
	var participants := {peer_id: {"user_id": user_id, "team_id": ""}}
	var session := {
		"session_id": session_id,
		"machine_id": machine_id,
		"zone_id": str(machine.get("zone_id", "")),
		"mode": mode,
		"state": "waiting",
		"host_peer_id": peer_id,
		"participants": participants,
		"created_at_usec": Time.get_ticks_usec(),
		"started_at_usec": 0,
		"controller": controller
	}
	_arcade_sessions[session_id] = session
	_peer_arcade_sessions[peer_id] = session_id
	if mode == "solo":
		_launch_arcade_session(session_id, peer_id)
	else:
		_reply_arcade_session(peer_id, session_id, "waiting", machine_id, "تم إنشاء الجلسة؛ في انتظار المشاركين.")


@rpc("any_peer", "call_remote", "reliable")
func request_join_arcade_session_rpc(session_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if _peer_arcade_sessions.has(peer_id) or _user_has_active_arcade_session(str(_sessions[peer_id].get("user_id", ""))):
		_reply_arcade_session(peer_id, session_id, "rejected", "", "لديك جلسة ماكينة أخرى قيد التنفيذ على هذا الحساب.")
		return
	var session: Dictionary = _arcade_sessions.get(session_id, {})
	if session.is_empty() or str(session.get("state", "")) != "waiting":
		_reply_arcade_session(peer_id, session_id, "rejected", "", "هذه الجلسة لم تعد متاحة للانضمام.")
		return
	var machine: Dictionary = _arcade_machines.get(str(session.get("machine_id", "")), {})
	var anchor := machine.get("anchor") as Node3D
	var controller := session.get("controller") as Node
	var body := _sessions[peer_id].get("body") as CharacterBody3D
	if not is_instance_valid(anchor) or not is_instance_valid(controller) or not is_instance_valid(body):
		_abort_arcade_session(session_id, "تعذر التحقق من الماكينة أو اللاعب.")
		return
	if body.global_position.distance_to(anchor.global_position) > ARCADE_MACHINE_INTERACTION_RADIUS:
		_reply_arcade_session(peer_id, session_id, "rejected", str(session.get("machine_id", "")), "اقترب من الماكينة أولًا.")
		return
	var user_id := str(_sessions[peer_id].get("user_id", ""))
	var participants: Dictionary = session.get("participants", {})
	if str(session.get("mode", "")) == "solo":
		_reply_arcade_session(peer_id, session_id, "rejected", str(session.get("machine_id", "")), "الجلسة الفردية لا تقبل مشاركين إضافيين.")
		return
	for participant in participants.values():
		if str(participant.get("user_id", "")) == user_id:
			_reply_arcade_session(peer_id, session_id, "rejected", str(session.get("machine_id", "")), "هذا الحساب مشارك بالفعل في الجلسة.")
			return
	if participants.size() >= MAX_PLAYERS or not bool(controller.call("can_join_arcade_session", user_id, str(session.get("mode", "")), participants.size())):
		_reply_arcade_session(peer_id, session_id, "rejected", str(session.get("machine_id", "")), "لا يمكن الانضمام إلى هذه الجلسة.")
		return
	participants[peer_id] = {"user_id": user_id, "team_id": ""}
	session["participants"] = participants
	_arcade_sessions[session_id] = session
	_peer_arcade_sessions[peer_id] = session_id
	for participant_peer_variant in participants.keys():
		_reply_arcade_session(int(participant_peer_variant), session_id, "waiting", str(session.get("machine_id", "")), "انضم مشارك جديد إلى الجلسة.")


@rpc("any_peer", "call_remote", "reliable")
func request_launch_arcade_session_rpc(session_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	var session: Dictionary = _arcade_sessions.get(session_id, {})
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if session.is_empty() or int(session.get("host_peer_id", -1)) != peer_id:
		_reply_arcade_session(peer_id, session_id, "rejected", "", "بدء الجلسة متاح لمنشئها فقط.")
		return
	_launch_arcade_session(session_id, peer_id)


func _launch_arcade_session(session_id: String, peer_id: int) -> void:
	var session: Dictionary = _arcade_sessions.get(session_id, {})
	if session.is_empty() or str(session.get("state", "")) != "waiting":
		return
	if int(session.get("host_peer_id", -1)) != peer_id:
		return
	var controller := session.get("controller") as Node
	var participants: Dictionary = session.get("participants", {})
	if not is_instance_valid(controller):
		_abort_arcade_session(session_id, "متحكم اللعبة غير متاح؛ لم تبدأ الجولة.")
		return
	session["state"] = "running"
	session["started_at_usec"] = Time.get_ticks_usec()
	_arcade_sessions[session_id] = session
	if not bool(controller.call("start_arcade_session", session_id, str(session.get("mode", "")), participants.duplicate(true))):
		_abort_arcade_session(session_id, "رفض نظام اللعبة بدء الجلسة؛ لم تبدأ الجولة.")
		return
	if not _arcade_sessions.has(session_id):
		return
	for participant_peer_variant in participants.keys():
		_reply_arcade_session(int(participant_peer_variant), session_id, "running", str(session.get("machine_id", "")), "بدأت جلسة اللعب على الخادم.")


@rpc("any_peer", "call_remote", "reliable")
func request_arcade_slot_spin_rpc(spin_type: String, wager_chips: int) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if spin_type != "auto":
		return
	var session_id := str(_peer_arcade_sessions.get(peer_id, ""))
	var session: Dictionary = _arcade_sessions.get(session_id, {})
	if session.is_empty() or str(session.get("state", "")) != "running" or str(session.get("mode", "")) != "solo":
		_notify_slot_spin_failed(peer_id, session_id, "لا توجد جلسة ماكينة فردية نشطة.")
		return
	var participants: Dictionary = session.get("participants", {})
	if not participants.has(peer_id):
		return
	var machine_id := str(session.get("machine_id", ""))
	var machine: Dictionary = _arcade_machines.get(machine_id, {})
	var anchor := machine.get("anchor") as Node3D
	var body := _sessions[peer_id].get("body") as CharacterBody3D
	if machine.is_empty() or not is_instance_valid(anchor) or not is_instance_valid(body):
		_notify_slot_spin_failed(peer_id, session_id, "الماكينة أو اللاعب غير متاح.")
		return
	if body.global_position.distance_to(anchor.global_position) > ARCADE_MACHINE_INTERACTION_RADIUS:
		_notify_slot_spin_failed(peer_id, session_id, "يجب البقاء بجوار الماكينة أثناء اللعب.")
		return
	if wager_chips < 10 or wager_chips > 2000000000:
		_notify_slot_spin_failed(peer_id, session_id, "قيمة الرهان غير صالحة.")
		return
	if _pending_slot_spins.has(session_id):
		_notify_slot_spin_failed(peer_id, session_id, "هناك لفة قيد المعالجة بالفعل.")
		return
	if _proof_hmac_secret.size() < 32:
		_notify_slot_spin_failed(peer_id, session_id, "إعداد توقيع خادم اللعبة غير مكتمل.")
		return
	# Slot settlement is explicitly environment-configured for TEST first.
	# Never fall back to the production project settings used by account authentication.
	var base_url := OS.get_environment("KING_CITY_SLOT_API_BASE_URL").strip_edges().trim_suffix("/")
	var publishable_key := OS.get_environment("KING_CITY_SLOT_PUBLISHABLE_KEY").strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		_notify_slot_spin_failed(peer_id, session_id, "خدمة تسوية الماكينات غير مهيأة على بيئة الاختبار.")
		return
	var user_id := str(_sessions[peer_id].get("user_id", ""))
	var event_id := _new_server_event_uuid()
	if event_id.is_empty():
		_notify_slot_spin_failed(peer_id, session_id, "تعذر إنشاء معرف لفة آمن.")
		return
	var issued_at := int(Time.get_unix_time_from_system())
	var canonical := "v2|%s|%s|%s|%s|%s|%d|%d" % [user_id, session_id, machine_id, event_id, spin_type, wager_chips, issued_at]
	var hmac_context := HMACContext.new()
	if hmac_context.start(HashingContext.HASH_SHA256, _proof_hmac_secret) != OK or hmac_context.update(canonical.to_utf8_buffer()) != OK:
		_notify_slot_spin_failed(peer_id, session_id, "تعذر توقيع طلب اللفة.")
		return
	var payload := {
		"user_id": user_id,
		"session_id": session_id,
		"server_event_id": event_id,
		"machine_id": machine_id,
		"spin_type": spin_type,
		"issued_at": issued_at,
		"signature_hex": hmac_context.finish().hex_encode()
	}
	payload["wager_chips"] = wager_chips
	_pending_slot_spins[session_id] = event_id
	_send_slot_spin_request(peer_id, session_id, payload, 0, base_url, publishable_key)


func _send_slot_spin_request(peer_id: int, session_id: String, payload: Dictionary, attempt: int, base_url: String, publishable_key: String) -> void:
	var request := HTTPRequest.new()
	request.timeout = 15.0
	add_child(request)
	request.request_completed.connect(_on_slot_spin_request_completed.bind(request, peer_id, session_id, payload, attempt, base_url, publishable_key))
	var error := request.request(
		base_url + "/functions/v1/slot-machine-spin",
		PackedStringArray(["Content-Type: application/json", "apikey: " + publishable_key]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		request.queue_free()
		_schedule_slot_spin_retry(peer_id, session_id, payload, attempt, base_url, publishable_key)


func _schedule_slot_spin_retry(peer_id: int, session_id: String, payload: Dictionary, attempt: int, base_url: String, publishable_key: String) -> void:
	if attempt >= 2:
		_pending_slot_spins.erase(session_id)
		_notify_slot_spin_failed(peer_id, session_id, "تعذر إكمال اللفة بعد إعادة المحاولة؛ راجع الرصيد قبل بدء لفة جديدة.")
		return
	await get_tree().create_timer([2.0, 5.0][attempt]).timeout
	_send_slot_spin_request(peer_id, session_id, payload, attempt + 1, base_url, publishable_key)


func _on_slot_spin_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, peer_id: int, session_id: String, payload: Dictionary, attempt: int, base_url: String, publishable_key: String) -> void:
	if is_instance_valid(request):
		request.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 429 or response_code >= 500:
		_schedule_slot_spin_retry(peer_id, session_id, payload, attempt, base_url, publishable_key)
		return
	_pending_slot_spins.erase(session_id)
	if response_code != 200:
		var error_data: Variant = JSON.parse_string(body.get_string_from_utf8())
		var error_code := str(error_data.get("error", "slot_spin_rejected")) if error_data is Dictionary else "slot_spin_rejected"
		_notify_slot_spin_failed(peer_id, session_id, error_code)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not parsed is Dictionary or not bool(parsed.get("settled", false)) or not parsed.has("balance_after"):
		_notify_slot_spin_failed(peer_id, session_id, "استجابة تسوية اللفة غير صالحة.")
		return
	if not _sessions.has(peer_id) or not multiplayer.get_peers().has(peer_id):
		return
	if str(_peer_arcade_sessions.get(peer_id, "")) != session_id:
		return
	rpc_id(peer_id, "receive_authoritative_slot_spin_result", session_id, parsed)


func _notify_slot_spin_failed(peer_id: int, session_id: String, message: String) -> void:
	if _sessions.has(peer_id) and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "receive_authoritative_slot_spin_failed", session_id, message)


@rpc("authority", "call_remote", "reliable")
func receive_authoritative_slot_spin_result(session_id: String, result: Dictionary) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	arcade_slot_spin_settled.emit(session_id, result)


@rpc("authority", "call_remote", "reliable")
func receive_authoritative_slot_spin_failed(session_id: String, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	arcade_slot_spin_failed.emit(session_id, message)


@rpc("any_peer", "call_remote", "reliable")
func request_leave_arcade_session_rpc(session_id: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if str(_peer_arcade_sessions.get(peer_id, "")) != session_id:
		return
	_abort_arcade_session(session_id, "غادر أحد المشاركين؛ أُغلقت الجلسة دون نتيجة أو مكافأة.")


func complete_arcade_session(session_id: String, server_results: Dictionary) -> bool:
	if not multiplayer.is_server():
		return false
	var session: Dictionary = _arcade_sessions.get(session_id, {})
	if session.is_empty() or str(session.get("state", "")) != "running":
		return false
	var controller := session.get("controller") as Node
	if not is_instance_valid(controller):
		_abort_arcade_session(session_id, "تعذر التحقق من نتيجة اللعبة.")
		return false
	var elapsed_usec := Time.get_ticks_usec() - int(session.get("started_at_usec", 0))
	var participants: Dictionary = session.get("participants", {})
	if elapsed_usec <= 0 or not bool(controller.call("validate_arcade_session_result", session_id, str(session.get("mode", "")), participants.duplicate(true), server_results.duplicate(true), elapsed_usec)):
		_abort_arcade_session(session_id, "لم يجتز سجل الجولة تحقق الخادم؛ لم تُسجل نتيجة.")
		return false
	var event_id := _new_server_event_uuid()
	if event_id.is_empty() or _closed_arcade_sessions.has(session_id):
		_abort_arcade_session(session_id, "تعذر إنشاء معرّف حدث آمن.")
		return false
	_remember_closed_arcade_session(session_id, event_id)
	session["state"] = "completed"
	for participant_peer_variant in participants.keys():
		_peer_arcade_sessions.erase(int(participant_peer_variant))
	_arcade_sessions.erase(session_id)
	arcade_session_verified.emit(session_id, event_id, str(session.get("machine_id", "")), str(session.get("zone_id", "")), str(session.get("mode", "")), participants.duplicate(true), server_results.duplicate(true))
	for participant_peer_variant in participants.keys():
		_reply_arcade_session(int(participant_peer_variant), session_id, "completed", str(session.get("machine_id", "")), "اكتملت الجولة واعتمد الخادم نتيجتها.")
	return true


func _abort_peer_arcade_session(peer_id: int, reason: String) -> void:
	var session_id := str(_peer_arcade_sessions.get(peer_id, ""))
	if not session_id.is_empty():
		_abort_arcade_session(session_id, reason)


func _abort_arcade_session(session_id: String, reason: String) -> void:
	var session: Dictionary = _arcade_sessions.get(session_id, {})
	if session.is_empty():
		return
	var controller := session.get("controller") as Node
	if is_instance_valid(controller):
		controller.call("abort_arcade_session", session_id, reason)
	var participants: Dictionary = session.get("participants", {})
	for participant_peer_variant in participants.keys():
		var participant_peer := int(participant_peer_variant)
		_peer_arcade_sessions.erase(participant_peer)
		_reply_arcade_session(participant_peer, session_id, "aborted", str(session.get("machine_id", "")), reason)
	_remember_closed_arcade_session(session_id, "aborted")
	_arcade_sessions.erase(session_id)


func _remember_closed_arcade_session(session_id: String, outcome: String) -> void:
	_closed_arcade_sessions[session_id] = outcome
	while _closed_arcade_sessions.size() > 1024:
		_closed_arcade_sessions.erase(_closed_arcade_sessions.keys()[0])


func _reply_arcade_session(peer_id: int, session_id: String, state: String, machine_id: String, message: String) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "receive_arcade_session_state", session_id, state, machine_id, message)


@rpc("authority", "call_remote", "reliable")
func receive_arcade_session_state(session_id: String, state: String, machine_id: String, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	arcade_session_state_changed.emit(session_id, state, machine_id, message)



# Royal jet ski race lobby gate. The server owns the roster and start eligibility.
func request_join_jet_ski_race() -> bool:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return false
	request_join_jet_ski_race_rpc.rpc_id(1)
	return true


func request_leave_jet_ski_race() -> bool:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return false
	request_leave_jet_ski_race_rpc.rpc_id(1)
	return true


func request_start_jet_ski_race() -> bool:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return false
	request_start_jet_ski_race_rpc.rpc_id(1)
	return true


func request_watch_jet_ski_race() -> bool:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return false
	request_watch_jet_ski_race_rpc.rpc_id(1)
	return true


func request_stop_watching_jet_ski_race() -> bool:
	if _is_dedicated_server or not is_authenticated() or not multiplayer.has_multiplayer_peer():
		return false
	request_stop_watching_jet_ski_race_rpc.rpc_id(1)
	return true


func _jet_ski_race_can_start(participant_count: int) -> bool:
	return participant_count >= JET_SKI_RACE_MIN_PARTICIPANTS and participant_count <= JET_SKI_RACE_MAX_PARTICIPANTS


func _jet_ski_race_duration_expired(now_usec: int, ends_at_usec: int) -> bool:
	return ends_at_usec > 0 and now_usec >= ends_at_usec


func _jet_ski_race_reward_rank_eligible(rank: int) -> bool:
	return rank >= 1 and rank <= JET_SKI_RACE_DAILY_REWARD_WINNING_RANKS


func _jet_ski_race_daily_reward_claim_key(user_id: String, utc_day_key: String) -> String:
	var normalized_user_id := user_id.strip_edges()
	var normalized_day_key := utc_day_key.strip_edges()
	if normalized_user_id.is_empty() or normalized_day_key.is_empty():
		return ""
	return "%s:%s" % [normalized_user_id, normalized_day_key]


func _jet_ski_race_should_reopen_after_disconnect(was_participant: bool, race_state: String) -> bool:
	return was_participant and race_state in ["ready", "countdown"]


func _jet_ski_race_can_watch(peer_id: int, participant_ids: Array[int]) -> bool:
	return peer_id > 0 and not participant_ids.has(peer_id)


func _notify_jet_ski_race_participants(message: String) -> void:
	var audience: Array[int] = _jet_ski_race_participants.duplicate()
	for spectator_peer_id in _jet_ski_race_spectators:
		if not audience.has(spectator_peer_id):
			audience.append(spectator_peer_id)
	for peer_id in audience:
		if _sessions.has(peer_id) and bool(_sessions[peer_id].get("authenticated", false)):
			rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), message)


@rpc("any_peer", "call_remote", "reliable")
func request_join_jet_ski_race_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if _jet_ski_race_state != "waiting":
		rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), "قائمة المتسابقين أُغلقت لهذه الجولة.")
		return
	if _jet_ski_race_participants.has(peer_id):
		rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), "أنت مسجل بالفعل في المسابقة.")
		return
	if _jet_ski_race_participants.size() >= JET_SKI_RACE_MAX_PARTICIPANTS:
		rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), "اكتملت خانات المتسابقين الأربعة.")
		return
	_jet_ski_race_spectators.erase(peer_id)
	_jet_ski_race_participants.append(peer_id)
	_notify_jet_ski_race_participants("تم تسجيلك في بطولة الجت سكي الملكية.")


@rpc("any_peer", "call_remote", "reliable")
func request_watch_jet_ski_race_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if not _jet_ski_race_can_watch(peer_id, _jet_ski_race_participants):
		rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), "أنت متسابق في هذه الجولة ولا يمكنك دخول وضع المشاهدة.")
		return
	if not _jet_ski_race_spectators.has(peer_id):
		_jet_ski_race_spectators.append(peer_id)
	rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), "تم تفعيل وضع المشاهدة. لن تتمكن من قيادة الجت سكي أو التأثير في نتيجة السباق.")


@rpc("any_peer", "call_remote", "reliable")
func request_stop_watching_jet_ski_race_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	_jet_ski_race_spectators.erase(peer_id)
	rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), "تم إيقاف وضع مشاهدة السباق.")


@rpc("any_peer", "call_remote", "reliable")
func request_leave_jet_ski_race_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if _jet_ski_race_state != "waiting" or not _jet_ski_race_participants.has(peer_id):
		return
	_jet_ski_race_participants.erase(peer_id)
	_notify_jet_ski_race_participants("تم تحديث قائمة المتسابقين بعد مغادرة لاعب.")


@rpc("any_peer", "call_remote", "reliable")
func request_start_jet_ski_race_rpc() -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or not bool(_sessions[peer_id].get("authenticated", false)):
		return
	if not _jet_ski_race_participants.has(peer_id):
		rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, _jet_ski_race_participants.size(), "سجل نفسك في المسابقة أولًا.")
		return
	var participant_count := _jet_ski_race_participants.size()
	if not _jet_ski_race_can_start(participant_count):
		rpc_id(peer_id, "receive_jet_ski_race_state", "waiting", participant_count, "تحتاج المسابقة إلى متسابقين على الأقل لبدء الجولة.")
		return
	if _jet_ski_race_state != "waiting":
		rpc_id(peer_id, "receive_jet_ski_race_state", _jet_ski_race_state, participant_count, "تم تقديم طلب بدء الجولة بالفعل.")
		return
	_jet_ski_race_locked_participants = _jet_ski_race_participants.duplicate()
	_jet_ski_race_state = "countdown"
	_jet_ski_race_countdown_until_usec = Time.get_ticks_usec() + JET_SKI_RACE_COUNTDOWN_SECONDS * 1000000
	_jet_ski_race_ends_at_usec = 0
	_notify_jet_ski_race_participants("تم قفل المتسابقين الأربعة أو أقل. يبدأ السباق بعد 5 ثوانٍ، ومدة المسابقة خمس دقائق.")


@rpc("authority", "call_remote", "reliable")
func receive_jet_ski_race_state(state: String, participant_count: int, message: String) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	jet_ski_race_state_changed.emit(state, participant_count, message)



func _walk_signature_message(action: String, user_id: String, issued_at: int, event_id: String = "", distance_meters: float = 0.0, expires_at: int = 0) -> String:
	if action == "lookup":
		return "v1|walk|lookup|%s|%d" % [user_id, issued_at]
	return "v1|walk|record|%s|%s|%.3f|%d|%d" % [user_id, event_id, distance_meters, issued_at, expires_at]


func _request_walk_progress(peer_id: int, action: String) -> void:
	if not multiplayer.is_server() or not _sessions.has(peer_id) or _walk_progress_requests.has(peer_id):
		return
	var session: Dictionary = _sessions[peer_id]
	var user_id := str(session.get("user_id", ""))
	if user_id.is_empty():
		return
	if _proof_hmac_secret.size() < 32:
		session["walk_retry_after_usec"] = Time.get_ticks_usec() + 60000000
		return
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		session["walk_retry_after_usec"] = Time.get_ticks_usec() + 30000000
		return

	var issued_at := int(Time.get_unix_time_from_system())
	var event_id := ""
	var distance_meters := 0.0
	var expires_at := 0
	if action == "record":
		event_id = str(session.get("walk_pending_event_id", ""))
		if event_id.is_empty():
			distance_meters = floorf(minf(float(session.get("walk_pending_meters", 0.0)), 5.0) * 1000.0) / 1000.0
			if distance_meters <= 0.0:
				return
			event_id = _new_server_event_uuid()
			if event_id.is_empty():
				return
			expires_at = issued_at + 300
			session["walk_pending_event_id"] = event_id
			session["walk_pending_event_meters"] = distance_meters
			session["walk_pending_event_issued_at"] = issued_at
			session["walk_pending_event_expires_at"] = expires_at
		else:
			distance_meters = float(session.get("walk_pending_event_meters", 0.0))
			issued_at = int(session.get("walk_pending_event_issued_at", 0))
			expires_at = int(session.get("walk_pending_event_expires_at", 0))
			if expires_at < int(Time.get_unix_time_from_system()):
				# Expired unconfirmed batch is discarded rather than replayed with a new event id.
				session["walk_pending_meters"] = maxf(0.0, float(session.get("walk_pending_meters", 0.0)) - distance_meters)
				session["walk_pending_event_id"] = ""
				session["walk_pending_event_meters"] = 0.0
				session["walk_pending_event_issued_at"] = 0
				session["walk_pending_event_expires_at"] = 0
				session["walk_retry_after_usec"] = Time.get_ticks_usec() + 5000000
				return

	var canonical := _walk_signature_message(action, user_id, issued_at, event_id, distance_meters, expires_at)
	var hmac_context := HMACContext.new()
	if hmac_context.start(HashingContext.HASH_SHA256, _proof_hmac_secret) != OK or hmac_context.update(canonical.to_utf8_buffer()) != OK:
		session["walk_retry_after_usec"] = Time.get_ticks_usec() + 5000000
		return
	var payload: Dictionary = {
		"action": action,
		"user_id": user_id,
		"issued_at": issued_at,
		"signature_hex": hmac_context.finish().hex_encode()
	}
	if action == "record":
		payload["server_event_id"] = event_id
		payload["distance_meters"] = distance_meters
		payload["expires_at"] = expires_at

	var request := HTTPRequest.new()
	request.name = "WalkProgressHTTPRequest_%d" % peer_id
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(_on_walk_progress_completed.bind(peer_id, user_id, action, event_id, distance_meters))
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + publishable_key
	])
	var error := request.request(base_url + "/functions/v1/game-walk-progress", headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request.queue_free()
		session["walk_retry_after_usec"] = Time.get_ticks_usec() + 5000000
		return
	session["walk_request_active"] = true
	_walk_progress_requests[peer_id] = request


func _on_walk_progress_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, peer_id: int, user_id: String, action: String, event_id: String, distance_meters: float) -> void:
	var request := _walk_progress_requests.get(peer_id) as HTTPRequest
	_walk_progress_requests.erase(peer_id)
	if is_instance_valid(request):
		request.queue_free()
	if not _sessions.has(peer_id):
		return
	var session: Dictionary = _sessions[peer_id]
	if str(session.get("user_id", "")) != user_id:
		return
	session["walk_request_active"] = false
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		session["walk_retry_after_usec"] = Time.get_ticks_usec() + 5000000
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not bool(parsed.get("verified", false)):
		session["walk_retry_after_usec"] = Time.get_ticks_usec() + 5000000
		return
	var total_meters := float(parsed.get("total_meters", -1.0))
	if not is_finite(total_meters) or total_meters < 0.0 or total_meters > 100000000.0:
		session["walk_retry_after_usec"] = Time.get_ticks_usec() + 5000000
		return
	session["walk_distance_meters"] = maxf(float(session.get("walk_distance_meters", 0.0)), total_meters)
	if action == "lookup":
		session["walk_progress_ready"] = true
		session["first_steps_recorded"] = total_meters >= 100.0
	else:
		if bool(parsed.get("recorded", false)) and str(session.get("walk_pending_event_id", "")) == event_id:
			session["walk_pending_meters"] = maxf(0.0, float(session.get("walk_pending_meters", 0.0)) - distance_meters)
			session["walk_pending_event_id"] = ""
			session["walk_pending_event_meters"] = 0.0
			session["walk_pending_event_issued_at"] = 0
			session["walk_pending_event_expires_at"] = 0
		if bool(parsed.get("achievement_unlocked", false)):
			session["first_steps_recorded"] = true
			session["walk_pending_meters"] = 0.0
			if multiplayer.get_peers().has(peer_id):
				rpc_id(peer_id, "receive_server_activity_progress_recorded", "achievement", "first_steps", false)
	session["walk_retry_after_usec"] = 0


func _notify_proof_issue_failed(peer_id: int, activity_kind: String, activity_id: String, message: String) -> void:
	if _sessions.has(peer_id) and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "receive_server_activity_proof_failed", activity_kind, activity_id, message)


func _new_server_event_uuid() -> String:
	var crypto := Crypto.new()
	var bytes := crypto.generate_random_bytes(16)
	if bytes.size() != 16:
		return ""
	bytes[6] = (bytes[6] & 0x0f) | 0x40
	bytes[8] = (bytes[8] & 0x3f) | 0x80
	var hex := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [hex.substr(0, 8), hex.substr(8, 4), hex.substr(12, 4), hex.substr(16, 4), hex.substr(20, 12)]


func _proof_signature_message(user_id: String, activity_kind: String, activity_id: String, event_id: String, issued_at: int, expires_at: int) -> String:
	return "v1|%s|%s|%s|%s|%d|%d" % [user_id, activity_kind, activity_id, event_id, issued_at, expires_at]


func _issue_activity_proof(peer_id: int, user_id: String, activity_kind: String, activity_id: String) -> void:
	if _proof_hmac_secret.size() < 32:
		if not _proof_secret_warning_shown:
			push_warning("Online reward proofs are disabled: KING_CITY_PROOF_HMAC_SECRET_B64 is not configured on the dedicated server.")
			_proof_secret_warning_shown = true
		_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "إعداد إثبات المكافأة غير مكتمل على الخادم.")
		return
	var base_url := str(ProjectSettings.get_setting("founder/auth/api_base_url", "")).strip_edges().trim_suffix("/")
	var publishable_key := str(ProjectSettings.get_setting("founder/auth/publishable_key", "")).strip_edges()
	if not base_url.begins_with("https://") or publishable_key.is_empty():
		push_warning("Cannot issue activity proof: Supabase project settings are missing on the dedicated server.")
		_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "خدمة اعتماد المكافآت غير مهيأة على الخادم.")
		return
	var event_id := _new_server_event_uuid()
	if event_id.is_empty():
		push_warning("Cannot issue activity proof: secure random event id generation failed.")
		_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "تعذر إنشاء رقم إثبات آمن.")
		return
	var issued_at := int(Time.get_unix_time_from_system())
	var expires_at := issued_at + 300
	var canonical := _proof_signature_message(user_id, activity_kind, activity_id, event_id, issued_at, expires_at)
	var digest_context := HashingContext.new()
	if digest_context.start(HashingContext.HASH_SHA256) != OK or digest_context.update(canonical.to_utf8_buffer()) != OK:
		_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "تعذر تجهيز بصمة إثبات المكافأة.")
		return
	var evidence_digest := digest_context.finish()
	var hmac_context := HMACContext.new()
	if hmac_context.start(HashingContext.HASH_SHA256, _proof_hmac_secret) != OK or hmac_context.update(canonical.to_utf8_buffer()) != OK:
		_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "تعذر توقيع إثبات المكافأة.")
		return
	var payload := {
		"user_id": user_id,
		"activity_kind": activity_kind,
		"activity_id": activity_id,
		"server_event_id": event_id,
		"issued_at": issued_at,
		"expires_at": expires_at,
		"evidence_digest_hex": evidence_digest.hex_encode(),
		"signature_hex": hmac_context.finish().hex_encode()
	}
	_send_activity_proof_request(peer_id, payload, 0, base_url, publishable_key)


func _send_activity_proof_request(peer_id: int, payload: Dictionary, attempt: int, base_url: String, publishable_key: String) -> void:
	if not _sessions.has(peer_id) or not multiplayer.get_peers().has(peer_id):
		return
	var request := HTTPRequest.new()
	request.timeout = 10.0
	add_child(request)
	request.request_completed.connect(_on_proof_issue_completed.bind(request, peer_id, payload, attempt, base_url, publishable_key))
	var error := request.request(
		base_url + "/functions/v1/game-proof-issuer",
		PackedStringArray(["Content-Type: application/json", "apikey: " + publishable_key]),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		request.queue_free()
		_schedule_activity_proof_retry(peer_id, payload, attempt, base_url, publishable_key)


func _schedule_activity_proof_retry(peer_id: int, payload: Dictionary, attempt: int, base_url: String, publishable_key: String) -> void:
	if attempt >= 3:
		_notify_proof_issue_failed(peer_id, str(payload.get("activity_kind", "")), str(payload.get("activity_id", "")), "تعذر إصدار إثبات المكافأة بعد عدة محاولات؛ لم تُمنح مكافأة.")
		return
	var delays := [2.0, 5.0, 15.0]
	_retry_activity_proof_after(peer_id, payload, attempt + 1, delays[attempt], base_url, publishable_key)


func _retry_activity_proof_after(peer_id: int, payload: Dictionary, attempt: int, delay_seconds: float, base_url: String, publishable_key: String) -> void:
	await get_tree().create_timer(delay_seconds).timeout
	_send_activity_proof_request(peer_id, payload, attempt, base_url, publishable_key)


func _on_proof_issue_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray, request: HTTPRequest, peer_id: int, payload: Dictionary, attempt: int, base_url: String, publishable_key: String) -> void:
	if is_instance_valid(request):
		request.queue_free()
	var activity_kind := str(payload.get("activity_kind", ""))
	var activity_id := str(payload.get("activity_id", ""))
	if result != HTTPRequest.RESULT_SUCCESS or response_code == 429 or response_code >= 500:
		_schedule_activity_proof_retry(peer_id, payload, attempt, base_url, publishable_key)
		return
	if response_code != 200:
		push_warning("Trusted proof issuer rejected activity %s/%s with HTTP %d." % [activity_kind, activity_id, response_code])
		_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "لم تصدر خدمة المكافآت إثباتًا صالحًا؛ لم تُمنح مكافأة.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary) or not bool(parsed.get("progress_recorded", false)):
		push_warning("Trusted game server progress recorder returned an invalid response.")
		_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "لم يؤكد الخادم حفظ الإنجاز.")
		return
	var reward_eligible := bool(parsed.get("reward_eligible", false))
	var proof_id := str(parsed.get("proof_id", ""))
	var user_id := str(payload.get("user_id", ""))
	if not _sessions.has(peer_id) or str(_sessions[peer_id].get("user_id", "")) != user_id:
		return
	rpc_id(peer_id, "receive_server_activity_progress_recorded", activity_kind, activity_id, reward_eligible)
	var uuid_pattern := RegEx.new()
	uuid_pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$")
	if proof_id.is_empty() == false:
		if uuid_pattern.search(proof_id) == null:
			push_warning("Trusted progress recorder returned an invalid reward proof id.")
			_notify_proof_issue_failed(peer_id, activity_kind, activity_id, "استجابة إثبات المكافأة غير صالحة.")
			return
		rpc_id(peer_id, "receive_server_activity_proof", activity_kind, activity_id, proof_id)
	if bool(parsed.get("achievement_unlocked", false)):
		rpc_id(
			peer_id,
			"receive_server_activity_progress_recorded",
			"achievement",
			"explorer",
			bool(parsed.get("achievement_reward_eligible", false))
		)
		var achievement_proof_id := str(parsed.get("achievement_proof_id", "")).strip_edges()
		if not achievement_proof_id.is_empty():
			if uuid_pattern.search(achievement_proof_id) == null:
				push_warning("Trusted progress recorder returned an invalid Explorer achievement proof id.")
			else:
				rpc_id(peer_id, "receive_server_activity_proof", "achievement", "explorer", achievement_proof_id)


func register_server_objective_zone(activity_kind: String, activity_id: String, center: Vector3, radius: float) -> bool:
	if not multiplayer.is_server() or not ["mission", "job", "achievement", "daily_claim"].has(activity_kind):
		return false
	var safe_id := activity_id.strip_edges().to_lower()
	var id_pattern := RegEx.new()
	id_pattern.compile("^[a-z0-9][a-z0-9_.-]{0,79}$")
	if id_pattern.search(safe_id) == null or not is_finite(center.x) or not is_finite(center.y) or not is_finite(center.z):
		return false
	if not is_finite(radius) or radius < 0.75 or radius > 20.0:
		return false
	var zone_key := activity_kind + ":" + safe_id
	_objective_zones[zone_key] = {
		"activity_kind": activity_kind,
		"activity_id": safe_id,
		"center": center,
		"radius": radius
	}
	return true


func _evaluate_server_objective_zones(peer_id: int, session: Dictionary, body: CharacterBody3D) -> Dictionary:
	var reached: Dictionary = session.get("reached_objectives", {})
	for zone_key in _objective_zones.keys():
		if reached.has(zone_key):
			continue
		var zone: Dictionary = _objective_zones[zone_key]
		var center: Vector3 = zone["center"]
		var radius := float(zone["radius"])
		if body.global_position.distance_to(center) <= radius:
			reached[zone_key] = true
			server_objective_reached.emit(
				str(session.get("user_id", "")),
				str(zone["activity_kind"]),
				str(zone["activity_id"])
			)
	session["reached_objectives"] = reached
	return session


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var safe_delta := clampf(delta, 0.0, 0.05)
	var now_usec := Time.get_ticks_usec()
	for peer_id_variant in _sessions.keys():
		var peer_id := int(peer_id_variant)
		var session: Dictionary = _sessions[peer_id]
		if not bool(session.get("authenticated", false)):
			continue
		var body := session.get("body") as CharacterBody3D
		if not is_instance_valid(body):
			continue
		if bool(session.get("jet_ski_mounted", false)):
			var last_jet_input_usec := int(session.get("jet_ski_last_input_usec", 0))
			if now_usec - last_jet_input_usec > 250000:
				session["jet_ski_throttle"] = 0.0
				session["jet_ski_brake"] = 0.0
				session["jet_ski_steering"] = 0.0
			var jet_state := JetSkiNetworkContract.step_motion(
				session.get("jet_ski_position", JET_SKI_SERVER_LAUNCH_POSITION),
				float(session.get("jet_ski_rotation_y", 0.0)),
				session.get("jet_ski_velocity", Vector3.ZERO),
				float(session.get("jet_ski_throttle", 0.0)),
				float(session.get("jet_ski_brake", 0.0)),
				float(session.get("jet_ski_steering", 0.0)),
				safe_delta
			)
			session["jet_ski_position"] = jet_state["position"]
			session["jet_ski_rotation_y"] = jet_state["rotation_y"]
			session["jet_ski_velocity"] = jet_state["velocity"]
			body.global_position = jet_state["position"] + JET_SKI_RIDER_OFFSET.rotated(Vector3.UP, float(jet_state["rotation_y"]))
			body.rotation.y = float(jet_state["rotation_y"])
			body.velocity = Vector3.ZERO
			session["velocity"] = Vector3.ZERO
			session["direction"] = Vector3.ZERO
			session["sprint"] = false
			_sessions[peer_id] = session
			continue
		var current_position := body.global_position
		var movement_start_position := current_position
		var was_grounded := body.is_on_floor()
		if not bool(session.get("walk_progress_ready", false)) and not bool(session.get("walk_request_active", false)) and now_usec >= int(session.get("walk_retry_after_usec", 0)):
			_request_walk_progress(peer_id, "lookup")
		var outside_city := absf(current_position.x) > 155.0 or current_position.z < -340.0 or current_position.z > 180.0
		if current_position.y < -3.0 or outside_city:
			var safe_position: Vector3 = session.get("last_safe_position", SPAWN_POSITION)
			if safe_position.y < -3.0 or absf(safe_position.x) > 155.0 or safe_position.z < -340.0 or safe_position.z > 180.0:
				safe_position = SPAWN_POSITION
			body.global_position = safe_position + Vector3.UP * 0.15
			body.velocity = Vector3.ZERO
			session["velocity"] = Vector3.ZERO
			session["direction"] = Vector3.ZERO
			session["sprint"] = false
		elif body.is_on_floor() and current_position.y > -0.25:
			session["last_safe_position"] = current_position
		if now_usec >= int(session.get("emote_until_usec", 0)):
			session["active_emote"] = ""
		var direction: Vector3 = session.get("direction", Vector3.ZERO)
		var last_input_usec := int(session.get("last_input_usec", 0))
		if Time.get_ticks_usec() - last_input_usec > 250000:
			direction = Vector3.ZERO
			session["direction"] = direction
			session["sprint"] = false
		var speed := RUN_SPEED if bool(session.get("sprint", false)) else WALK_SPEED
		var target := direction * speed
		var velocity: Vector3 = session.get("velocity", Vector3.ZERO)
		velocity.x = move_toward(velocity.x, target.x, ACCELERATION * safe_delta)
		velocity.z = move_toward(velocity.z, target.z, ACCELERATION * safe_delta)
		if not body.is_on_floor():
			velocity.y -= GRAVITY * safe_delta
		else:
			velocity.y = 0.0
		body.velocity = velocity
		_try_player_step_up(body, safe_delta)
		body.move_and_slide()
		if direction.length() > 0.1:
			body.rotation.y = atan2(direction.x, direction.z)
		if bool(session.get("walk_progress_ready", false)) and not bool(session.get("first_steps_recorded", false)) and was_grounded and body.is_on_floor() and direction.length() > 0.1 and not outside_city:
			var verified_step := Vector2(body.global_position.x - movement_start_position.x, body.global_position.z - movement_start_position.z).length()
			var maximum_step := RUN_SPEED * safe_delta + 0.12
			if is_finite(verified_step) and verified_step > 0.0 and verified_step <= maximum_step:
				var remaining_distance := maxf(0.0, 100.0 - float(session.get("walk_distance_meters", 0.0)) - float(session.get("walk_pending_meters", 0.0)))
				session["walk_pending_meters"] = float(session.get("walk_pending_meters", 0.0)) + minf(verified_step, remaining_distance)
		if float(session.get("walk_pending_meters", 0.0)) >= 1.0 and not bool(session.get("walk_request_active", false)) and now_usec >= int(session.get("walk_retry_after_usec", 0)):
			_request_walk_progress(peer_id, "record")
		session["velocity"] = body.velocity
		session = _evaluate_server_objective_zones(peer_id, session, body)
		var active_job: Dictionary = session.get("active_job", {})
		if not active_job.is_empty():
			var job_target: Vector3 = active_job.get("target", Vector3.ZERO)
			var planar_distance := Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(job_target.x, job_target.z))
			if planar_distance <= float(active_job.get("radius", 2.2)):
				var completed_job_id := str(active_job.get("job_id", ""))
				var completed: Dictionary = session.get("completed_jobs", {})
				completed[_daily_job_key(completed_job_id)] = true
				session["completed_jobs"] = completed
				var user_id := str(session.get("user_id", ""))
				if not user_id.is_empty():
					_daily_job_completions["%s:%s" % [user_id, _daily_job_key(completed_job_id)]] = Time.get_datetime_string_from_unix_time(int(Time.get_unix_time_from_system()) + EGYPT_UTC_OFFSET_SECONDS)
					_save_daily_job_completions()
				session["active_job"] = {}
				server_objective_reached.emit(str(session.get("user_id", "")), "job", completed_job_id)
				rpc_id(peer_id, "receive_server_job_completed", completed_job_id)
				_issue_activity_proof(peer_id, str(session.get("user_id", "")), "job", completed_job_id)
		var active_mission: Dictionary = session.get("active_mission", {})
		if not active_mission.is_empty():
			var completed_mission_id := str(active_mission.get("mission_id", ""))
			var time_limit := float(active_mission.get("time_limit_seconds", 0.0))
			var started_at_usec := int(active_mission.get("started_at_usec", now_usec))
			if time_limit > 0.0 and now_usec - started_at_usec >= int(time_limit * 1000000.0):
				session["active_mission"] = {}
				rpc_id(peer_id, "receive_server_mission_failed", completed_mission_id, "انتهى الوقت! لم تصل إلى نقطة النجاة.")
			else:
				var mission_target: Vector3 = active_mission.get("target", Vector3.ZERO)
				var mission_distance := Vector2(body.global_position.x, body.global_position.z).distance_to(Vector2(mission_target.x, mission_target.z))
				var rescue_requires_interaction := completed_mission_id == "city_adventure_rescue" and int(active_mission.get("stage_index", 0)) == 0
				if mission_distance <= float(active_mission.get("radius", 2.2)) and not rescue_requires_interaction:
					var mission_stages: Array = active_mission.get("stages", [mission_target])
					var stage_index := int(active_mission.get("stage_index", 0))
					if stage_index + 1 < mission_stages.size():
						stage_index += 1
						var next_target: Vector3 = mission_stages[stage_index]
						active_mission["stage_index"] = stage_index
						active_mission["target"] = next_target
						session["active_mission"] = active_mission
						rpc_id(peer_id, "receive_mission_stage_updated", completed_mission_id, next_target, stage_index + 1, mission_stages.size(), "تم اجتياز المرحلة. اتجه إلى النقطة التالية.")
					elif completed_mission_id == "city_adventure_message":
						if not bool(active_mission.get("puzzle_ready", false)):
							active_mission["puzzle_ready"] = true
							session["active_mission"] = active_mission
							rpc_id(peer_id, "receive_mission_stage_updated", completed_mission_id, mission_target, mission_stages.size() + 1, mission_stages.size(), "جمعت الأدلة الثلاثة. فك الشفرة وأرسل الإجابة.")
					else:
						session["active_mission"] = {}
						rpc_id(peer_id, "receive_server_mission_completed", completed_mission_id)
						if not completed_mission_id.begins_with("city_adventure_"):
							var completed_missions: Dictionary = session.get("completed_missions", {})
							completed_missions[completed_mission_id] = true
							session["completed_missions"] = completed_missions
						server_objective_reached.emit(str(session.get("user_id", "")), "mission", completed_mission_id)
						_issue_activity_proof(peer_id, str(session.get("user_id", "")), "mission", completed_mission_id)
		_sessions[peer_id] = session
	_snapshot_elapsed += safe_delta
	if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
		_snapshot_elapsed = 0.0
		var remote_snapshots_by_peer := _build_remote_player_snapshots()
		for peer_id_variant in _sessions.keys():
			var peer_id := int(peer_id_variant)
			var session: Dictionary = _sessions[peer_id]
			if not bool(session.get("authenticated", false)):
				continue
			var body := session.get("body") as CharacterBody3D
			if not is_instance_valid(body):
				continue
			rpc_id(peer_id, "receive_authoritative_state", body.global_position, body.rotation.y, body.velocity)
			if bool(session.get("jet_ski_mounted", false)):
				rpc_id(peer_id, "receive_jet_ski_authoritative_state", session.get("jet_ski_position", JET_SKI_SERVER_LAUNCH_POSITION), float(session.get("jet_ski_rotation_y", 0.0)), session.get("jet_ski_velocity", Vector3.ZERO))
			var remote_players: Array = remote_snapshots_by_peer.get(peer_id, [])
			rpc_id(peer_id, "receive_remote_players", remote_players)


func _build_remote_player_snapshots() -> Dictionary:
	var snapshots_by_instance: Dictionary = {}
	var bodies_by_peer: Dictionary = {}
	for source_peer_variant in _sessions.keys():
		var source_peer := int(source_peer_variant)
		var source_session: Dictionary = _sessions[source_peer]
		if not bool(source_session.get("authenticated", false)):
			continue
		var source_body := source_session.get("body") as CharacterBody3D
		if not is_instance_valid(source_body):
			continue
		var instance_id := str(source_session.get("instance_id", "city-main"))
		if not snapshots_by_instance.has(instance_id):
			snapshots_by_instance[instance_id] = []
		(snapshots_by_instance[instance_id] as Array).append({
			"peer_id": source_peer,
			"position": source_body.global_position,
			"rotation_y": source_body.rotation.y,
			"velocity": source_body.velocity,
			"is_jet_ski_riding": bool(source_session.get("jet_ski_mounted", false)),
			"jet_ski_position": source_session.get("jet_ski_position", Vector3.ZERO),
			"jet_ski_rotation_y": float(source_session.get("jet_ski_rotation_y", 0.0)),
			"jet_ski_velocity": source_session.get("jet_ski_velocity", Vector3.ZERO),
			"active_emote": str(source_session.get("active_emote", "")),
			"emote_remaining": maxf(0.0, float(int(source_session.get("emote_until_usec", 0)) - Time.get_ticks_usec()) / 1000000.0),
			"is_sitting": bool(source_session.get("is_sitting", false))
		})
		bodies_by_peer[source_peer] = source_body

	var snapshots_by_peer: Dictionary = {}
	for peer_id_variant in bodies_by_peer.keys():
		var peer_id := int(peer_id_variant)
		var session: Dictionary = _sessions[peer_id]
		var body := bodies_by_peer[peer_id] as CharacterBody3D
		var instance_id := str(session.get("instance_id", "city-main"))
		var same_instance_players: Array = snapshots_by_instance.get(instance_id, [])
		var remote_players: Array = []
		for player_snapshot_variant in same_instance_players:
			var player_snapshot: Dictionary = player_snapshot_variant
			if int(player_snapshot.get("peer_id", 0)) == peer_id:
				continue
			var remote_position: Vector3 = player_snapshot.get("position", Vector3.ZERO)
			if body.global_position.distance_squared_to(remote_position) <= pow(MAX_PLAYER_VISIBILITY_DISTANCE, 2.0):
				remote_players.append(player_snapshot)
		snapshots_by_peer[peer_id] = remote_players
	return snapshots_by_peer






@rpc("authority", "call_remote", "unreliable_ordered")
func receive_jet_ski_authoritative_state(position: Vector3, rotation_y: float, velocity: Vector3) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	if not is_finite(position.x) or not is_finite(position.y) or not is_finite(position.z):
		return
	if not is_finite(velocity.x) or not is_finite(velocity.y) or not is_finite(velocity.z) or not is_finite(rotation_y):
		return
	jet_ski_authoritative_state_received.emit(position, rotation_y, velocity)


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_authoritative_state(position: Vector3, rotation_y: float, velocity: Vector3) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	authoritative_state_received.emit(position, rotation_y, velocity)


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_remote_players(players: Array) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	var safe_players: Array = []
	var seen_peer_ids: Dictionary = {}
	for player_variant in players:
		if not (player_variant is Dictionary):
			continue
		var player: Dictionary = player_variant
		var peer_id_variant: Variant = player.get("peer_id", 0)
		var position_variant: Variant = player.get("position", null)
		var rotation_variant: Variant = player.get("rotation_y", 0.0)
		var velocity_variant: Variant = player.get("velocity", null)
		var emote_variant: Variant = player.get("active_emote", "")
		var emote_remaining_variant: Variant = player.get("emote_remaining", 0.0)
		var sitting_variant: Variant = player.get("is_sitting", false)
		if not (peer_id_variant is int) or int(peer_id_variant) <= 0 or int(peer_id_variant) == multiplayer.get_unique_id():
			continue
		if seen_peer_ids.has(int(peer_id_variant)) or not (position_variant is Vector3) or not (velocity_variant is Vector3):
			continue
		if not (rotation_variant is float or rotation_variant is int):
			continue
		var remote_position: Vector3 = position_variant
		var remote_velocity: Vector3 = velocity_variant
		var remote_rotation := float(rotation_variant)
		if not is_finite(remote_position.x) or not is_finite(remote_position.y) or not is_finite(remote_position.z):
			continue
		if not is_finite(remote_velocity.x) or not is_finite(remote_velocity.y) or not is_finite(remote_velocity.z) or not is_finite(remote_rotation):
			continue
		var safe_emote := str(emote_variant) if emote_variant is String and ["clap", "dance", "cry", "wave", "heart"].has(str(emote_variant)) else ""
		var safe_emote_remaining := clampf(float(emote_remaining_variant), 0.0, 4.0) if emote_remaining_variant is float or emote_remaining_variant is int else 0.0
		if safe_emote_remaining <= 0.0:
			safe_emote = ""
		var safe_sitting: bool = bool(sitting_variant) if sitting_variant is bool else false
		var riding_variant: Variant = player.get("is_jet_ski_riding", false)
		var jet_position_variant: Variant = player.get("jet_ski_position", Vector3.ZERO)
		var jet_velocity_variant: Variant = player.get("jet_ski_velocity", Vector3.ZERO)
		var jet_rotation_variant: Variant = player.get("jet_ski_rotation_y", 0.0)
		var safe_jet_position: Vector3 = jet_position_variant if jet_position_variant is Vector3 else Vector3.ZERO
		var safe_jet_velocity: Vector3 = jet_velocity_variant if jet_velocity_variant is Vector3 else Vector3.ZERO
		var safe_jet_rotation := float(jet_rotation_variant) if jet_rotation_variant is float or jet_rotation_variant is int else 0.0
		var safe_jet_vectors_finite := jet_position_variant is Vector3 and jet_velocity_variant is Vector3 and is_finite(safe_jet_position.x) and is_finite(safe_jet_position.y) and is_finite(safe_jet_position.z) and is_finite(safe_jet_velocity.x) and is_finite(safe_jet_velocity.y) and is_finite(safe_jet_velocity.z)
		var safe_jet_riding := riding_variant is bool and bool(riding_variant) and safe_jet_vectors_finite and is_finite(safe_jet_rotation)
		seen_peer_ids[int(peer_id_variant)] = true
		safe_players.append({
			"peer_id": int(peer_id_variant),
			"position": remote_position,
			"rotation_y": remote_rotation,
			"velocity": remote_velocity,
			"active_emote": safe_emote,
			"emote_remaining": safe_emote_remaining,
			"is_sitting": safe_sitting,
			"is_jet_ski_riding": safe_jet_riding,
			"jet_ski_position": safe_jet_position,
			"jet_ski_rotation_y": safe_jet_rotation,
			"jet_ski_velocity": safe_jet_velocity
		})
		if safe_players.size() >= MAX_PLAYERS - 1:
			break
	remote_players_received.emit(safe_players)


func _try_player_step_up(body: CharacterBody3D, delta: float) -> void:
	# Server-authoritative low-curb assist, shared by all online players.
	if not body.is_on_floor() or Vector2(body.velocity.x, body.velocity.z).length() < 0.15:
		return
	var horizontal_motion := Vector3(body.velocity.x, 0.0, body.velocity.z) * maxf(delta, 0.001)
	if not body.test_move(body.global_transform, horizontal_motion):
		return
	var raised := body.global_transform
	raised.origin.y += 0.38
	if body.test_move(raised, horizontal_motion):
		return
	var landing := KinematicCollision3D.new()
	if not body.test_move(raised, horizontal_motion + Vector3.DOWN * 0.5, landing):
		return
	if landing.get_normal(0).angle_to(Vector3.UP) > deg_to_rad(50.0):
		return
	body.global_position.y += 0.38
