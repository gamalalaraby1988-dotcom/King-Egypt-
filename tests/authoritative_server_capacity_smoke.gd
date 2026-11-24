extends SceneTree
## Native Godot WebSocketMultiplayerPeer admission smoke test.
## Measures transport admission only; it does not authenticate players or simulate gameplay.

const MAX_CAPACITY := 64
var _peers: Array[WebSocketMultiplayerPeer] = []
var _connect_started_usec: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var url := "wss://king-city-capacity-proxy:443"
	var capacity := 64
	var handshake_only := args.has("--handshake-only")
	for arg in args:
		if arg.begins_with("--url="):
			url = arg.trim_prefix("--url=")
		elif arg.begins_with("--capacity="):
			capacity = int(arg.trim_prefix("--capacity="))
	if capacity < 1 or capacity > MAX_CAPACITY:
		_fail("capacity must be between 1 and %d" % MAX_CAPACITY)

	if handshake_only:
		var probe := WebSocketMultiplayerPeer.new()
		var probe_tls := TLSOptions.client_unsafe() if url.begins_with("wss://") else null
		var probe_error := probe.create_client(url, probe_tls)
		if probe_error != OK:
			_fail("Native Godot probe could not start: %s" % error_string(probe_error))
		_peers.append(probe)
		if not await _wait_for_connected(1, 15.0):
			_fail("Native Godot WebSocket handshake did not complete")
		print("NATIVE_GODOT_WEBSOCKET_HANDSHAKE=PASSED")
		_close_all()
		quit(0)
		return

	var stages: Array[int] = []
	for count in [20, 30, 50, capacity]:
		if count <= capacity and not stages.has(count):
			stages.append(count)
	if stages.is_empty() or stages.back() != capacity:
		stages.append(capacity)

	var stage_results: Array[Dictionary] = []
	var previous := 0
	for target in stages:
		for index in range(previous, target):
			var peer := WebSocketMultiplayerPeer.new()
			var tls := TLSOptions.client_unsafe() if url.begins_with("wss://") else null
			var started := Time.get_ticks_usec()
			var error := peer.create_client(url, tls)
			if error != OK:
				_fail("Godot client create_client failed: %s" % error_string(error))
			_peers.append(peer)
			_connect_started_usec[peer.get_instance_id()] = started
		if not await _wait_for_connected(target, 20.0):
			_fail("Only %d of %d native Godot clients connected" % [_connected_count(), target])
		stage_results.append({
			"target": target,
			"connected": _connected_count(),
			"still_connected": _connected_count()
		})
		previous = target
		await create_timer(0.3).timeout

	var overflow := WebSocketMultiplayerPeer.new()
	var overflow_tls := TLSOptions.client_unsafe() if url.begins_with("wss://") else null
	var overflow_error := overflow.create_client(url, overflow_tls)
	if overflow_error != OK:
		_fail("overflow client could not start: %s" % error_string(overflow_error))
	var overflow_connected := false
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		overflow.poll()
		if overflow.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			overflow_connected = true
			break
		await process_frame
	overflow.close()
	if overflow_connected:
		_fail("Server accepted connection beyond configured capacity %d" % capacity)

	print(JSON.stringify({
		"result": "passed",
		"client": "Godot WebSocketMultiplayerPeer",
		"configured_capacity": capacity,
		"stages": stage_results,
		"overflow_connection_rejected": true,
		"scope": "WebSocket transport admission only; no player authentication or gameplay simulation"
	}, "  "))
	_close_all()
	quit(0)

func _wait_for_connected(target: int, timeout_seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(timeout_seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		for peer in _peers:
			if peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
				peer.poll()
		if _connected_count() >= target:
			return true
		await process_frame
	return false

func _connected_count() -> int:
	var count := 0
	for peer in _peers:
		if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
			count += 1
	return count

func _close_all() -> void:
	for peer in _peers:
		peer.close()
	_peers.clear()

func _fail(message: String) -> void:
	push_error("GODOT_CAPACITY_SMOKE_FAILED: " + message)
	_close_all()
	quit(1)
