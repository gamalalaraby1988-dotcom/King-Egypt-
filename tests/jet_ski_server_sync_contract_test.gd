extends SceneTree

func _initialize() -> void:
	var failures: Array[String] = []
	var server_file := FileAccess.open("res://scripts/authoritative_game_server.gd", FileAccess.READ)
	var main_file := FileAccess.open("res://scripts/main.gd", FileAccess.READ)
	var remote_file := FileAccess.open("res://scripts/remote_player_visual.gd", FileAccess.READ)
	var hud_file := FileAccess.open("res://scripts/jet_ski_hud.gd", FileAccess.READ)
	if server_file == null or main_file == null or remote_file == null or hud_file == null:
		push_error("Jet ski server sync contract test could not read the required source files.")
		quit(1)
		return
	var server := server_file.get_as_text()
	var main := main_file.get_as_text()
	var remote := remote_file.get_as_text()
	var hud := hud_file.get_as_text()
	var required_server_contract := [
		'func request_jet_ski_mount_rpc()',
		'func request_jet_ski_unmount_rpc()',
		'func submit_jet_ski_input(sequence: int, throttle: Variant, brake: Variant, steering: Variant)',
		'multiplayer.get_remote_sender_id()',
		'bool(session.get("authenticated", false))',
		'bool(session.get("jet_ski_mounted", false))',
		'JetSkiNetworkContract.validate_input(',
		'JetSkiNetworkContract.step_motion(',
		'now_usec - last_jet_input_usec > 250000',
		'"is_jet_ski_riding"',
		'"jet_ski_position"',
		'func receive_jet_ski_authoritative_state('
	]
	for fragment in required_server_contract:
		if not server.contains(fragment):
			failures.append("Authoritative server is missing required jet ski contract: " + fragment)
	for fragment in [
		'var peer_id := multiplayer.get_remote_sender_id()',
		'now_usec - last_jet_input_usec > 250000',
		'session["jet_ski_mounted"] = false',
		'session["jet_ski_slot"] = -1',
		'_sessions.erase(peer_id)',
		'"is_jet_ski_riding": bool(source_session.get("jet_ski_mounted", false))',
		'func receive_jet_ski_authoritative_state('
	]:
		if not server.contains(fragment):
			failures.append("Server security, timeout, lifecycle, or snapshot rule is missing: " + fragment)
	if not server.contains('JetSkiNetworkContract.validate_input(') or not server.contains('"window_count"'):
		failures.append("Jet ski input rate limiting must be validated and persisted per authenticated peer.")
	if not server.contains('body.global_position = jet_state["position"]'):
		failures.append("The server must place the rider from its own simulated craft position.")
	if not server.contains('body.global_position = craft_position + right * 2.0 + Vector3.UP * 0.15'):
		failures.append("Server dismount must derive the player's exit position from authoritative craft state.")
	if server.contains('الجت سكي مشغولة حاليًا'):
		failures.append("Each authenticated rider must receive an independent jet ski slot.")
	if not server.contains("var launch_slot := JET_SKI_SERVER_LAUNCH_POSITION"):
		failures.append("The server must allocate a distinct launch slot per mounted rider.")
	if server.contains('func submit_jet_ski_input(sequence: int, position: Vector3'):
		failures.append("Client jet ski RPC must not accept a client-supplied position.")
	if not main.contains('AuthoritativeGameServer.request_jet_ski_mount()') or not main.contains('AuthoritativeGameServer.request_jet_ski_unmount()'):
		failures.append("Online mount and dismount must request server-authoritative lifecycle changes.")
	if not server.contains('rpc_id(peer_id, "receive_jet_ski_unmount_result", true, body.global_position)') or not server.contains('func receive_jet_ski_unmount_result(success: bool, server_position: Vector3)'):
		failures.append("Server must acknowledge dismount with its authoritative player exit position.")
	if not main.contains('jet_ski_unmount_result_received.connect(_on_jet_ski_unmount_result_received)') or not main.contains('_exit_player_jet_ski(server_position)'):
		failures.append("Online client must wait for server-confirmed dismount position before exiting the jet ski.")
	if not main.contains('vehicle_interaction_button.disabled = true') or not main.contains('_jet_ski_unmount_pending'):
		failures.append("Online dismount requests must be guarded against repeated taps while awaiting acknowledgement.")
	if not main.contains('func _request_jet_ski_unmount() -> void:') or not main.contains('func _exit_contextual_state() -> void:') or not main.contains('_request_jet_ski_unmount()'):
		failures.append("All online contextual exit paths must use the server-confirmed jet ski dismount flow.")
	if main.contains('_mount_player_jet_ski()\n\tif is_instance_valid(city_jet_ski):\n\t\tcity_jet_ski.set_physics_process(false)'):
		failures.append("Online local prediction must not be disabled immediately after mounting.")
	if not main.contains('jet_ski_authoritative_state_received.connect(_on_jet_ski_authoritative_state_received)'):
		failures.append("Local rider must receive authoritative jet ski corrections.")
	if not remote.contains('JET_SKI_SCENE.instantiate()') or not remote.contains('is_jet_ski_riding'):
		failures.append("Remote riders must render the authoritative jet ski snapshot.")
	if not hud.contains('AuthoritativeGameServer.send_jet_ski_input('):
		failures.append("Online HUD must send controls rather than relying on local physics.")
	var controller_file := FileAccess.open("res://scripts/jet_ski_controller.gd", FileAccess.READ)
	if controller_file == null:
		failures.append("Jet ski prediction controller could not be read.")
	else:
		var controller := controller_file.get_as_text()
		if not controller.contains("func reconcile_authoritative_state("):
			failures.append("Local prediction must reconcile position, rotation, and velocity with server snapshots.")
	if not main.contains('city_jet_ski.call("reconcile_authoritative_state", position, rotation_y, _velocity)'):
		failures.append("The local rider must apply server corrections through the prediction reconciler.")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Jet ski server synchronization contract tests passed.")
	quit(0)
