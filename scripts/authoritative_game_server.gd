extends Node
## Dedicated WSS game authority. Clients submit bounded movement input, never positions.
## Server-side collision uses the loaded city physics world. Objective zones remain disabled
## until their canonical server coordinates and evidence rules are configured.

signal authentication_completed(success: bool, message: String)
signal authoritative_state_received(position: Vector3, rotation_y: float, velocity: Vector3)

const DEFAULT_PORT := 2456
const MAX_PLAYERS := 64
const MAX_INPUT_RATE := 35.0
const WALK_SPEED := 4.0
const RUN_SPEED := 6.2
const ACCELERATION := 18.0
const GRAVITY := 20.0
const SNAPSHOT_INTERVAL := 0.05
const SPAWN_POSITION := Vector3(0.0, 1.0, -42.0)

var _server_peer: WebSocketMultiplayerPeer
var _sessions: Dictionary = {}
var _auth_requests: Dictionary = {}
var _is_dedicated_server := false
var _input_sequence := 0
var _snapshot_elapsed := 0.0


func _ready() -> void:
	_is_dedicated_server = OS.get_cmdline_user_args().has("--dedicated-server")
	if _is_dedicated_server:
		call_deferred("start_dedicated_server")


func is_dedicated_server_requested() -> bool:
	return _is_dedicated_server


func is_authenticated() -> bool:
	if _is_dedicated_server:
		return true
	return bool(_sessions.get(multiplayer.get_unique_id(), {}).get("authenticated", false))


func start_dedicated_server() -> void:
	if not _is_dedicated_server or multiplayer.multiplayer_peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
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
	print("KING OF EGYPT CITY authoritative WSS server listening on UDP/TCP-independent WebSocket TCP port %d." % port)


func _on_peer_connected(peer_id: int) -> void:
	if _sessions.size() + _auth_requests.size() >= MAX_PLAYERS:
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)
		return
	_sessions[peer_id] = {
		"authenticated": false,
		"user_id": "",
		"body": null,
		"direction": Vector3.ZERO,
		"sprint": false,
		"velocity": Vector3.ZERO,
		"last_sequence": -1,
		"last_input_usec": 0,
		"input_window_usec": Time.get_ticks_usec(),
		"input_count": 0
	}


func _on_peer_disconnected(peer_id: int) -> void:
	var session: Dictionary = _sessions.get(peer_id, {})
	var body := session.get("body") as CharacterBody3D
	if is_instance_valid(body):
		body.queue_free()
	_sessions.erase(peer_id)
	if _auth_requests.has(peer_id):
		var request := _auth_requests[peer_id] as HTTPRequest
		if is_instance_valid(request):
			request.queue_free()
		_auth_requests.erase(peer_id)


@rpc("any_peer", "call_remote", "reliable")
func authenticate_player(access_token: String) -> void:
	if not multiplayer.is_server():
		return
	var peer_id := multiplayer.get_remote_sender_id()
	if not _sessions.has(peer_id) or bool(_sessions[peer_id].get("authenticated", false)) or _auth_requests.has(peer_id):
		return
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
	var body_node := CharacterBody3D.new()
	body_node.name = "AuthoritativePlayer_%d" % peer_id
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
	_sessions[peer_id]["body"] = body_node
	rpc_id(peer_id, "receive_authentication_result", true, "تم التحقق من حساب اللاعب.")
	print("Authenticated game peer %d." % peer_id)


func _reject_peer(peer_id: int, reason: String) -> void:
	if multiplayer.is_server() and multiplayer.get_peers().has(peer_id):
		rpc_id(peer_id, "receive_authentication_result", false, reason)
		multiplayer.multiplayer_peer.disconnect_peer(peer_id)


@rpc("authority", "call_remote", "reliable")
func receive_authentication_result(success: bool, message: String) -> void:
	if multiplayer.is_server():
		return
	if success:
		authentication_completed.emit(true, message)
	else:
		authentication_completed.emit(false, message)


func send_movement_input(world_direction: Vector3, sprint: bool) -> void:
	if _is_dedicated_server or not is_authenticated():
		return
	var direction := world_direction
	direction.y = 0.0
	if direction.length() > 1.0:
		direction = direction.normalized()
	_input_sequence += 1
	submit_movement_input.rpc_id(1, _input_sequence, direction, sprint)


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


func _physics_process(delta: float) -> void:
	if not multiplayer.is_server():
		return
	var safe_delta := clampf(delta, 0.0, 0.05)
	for peer_id_variant in _sessions.keys():
		var peer_id := int(peer_id_variant)
		var session: Dictionary = _sessions[peer_id]
		if not bool(session.get("authenticated", false)):
			continue
		var body := session.get("body") as CharacterBody3D
		if not is_instance_valid(body):
			continue
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
		body.move_and_slide()
		session["velocity"] = body.velocity
		_sessions[peer_id] = session
	_snapshot_elapsed += safe_delta
	if _snapshot_elapsed >= SNAPSHOT_INTERVAL:
		_snapshot_elapsed = 0.0
		for peer_id_variant in _sessions.keys():
			var peer_id := int(peer_id_variant)
			var session: Dictionary = _sessions[peer_id]
			if not bool(session.get("authenticated", false)):
				continue
			var body := session.get("body") as CharacterBody3D
			if is_instance_valid(body):
				rpc_id(peer_id, "receive_authoritative_state", body.global_position, body.rotation.y, body.velocity)


@rpc("authority", "call_remote", "unreliable_ordered")
func receive_authoritative_state(position: Vector3, rotation_y: float, velocity: Vector3) -> void:
	if multiplayer.is_server() or not is_authenticated():
		return
	authoritative_state_received.emit(position, rotation_y, velocity)
