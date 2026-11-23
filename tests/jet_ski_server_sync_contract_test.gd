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
	if server.contains('الجت سكي مشغولة حاليًا'):
		failures.append("Each authenticated rider must receive an independent jet ski slot.")
	if not server.contains("var launch_slot := JET_SKI_SERVER_LAUNCH_POSITION"):
		failures.append("The server must allocate a distinct launch slot per mounted rider.")
	if server.contains('func submit_jet_ski_input(sequence: int, position: Vector3'):
		failures.append("Client jet ski RPC must not accept a client-supplied position.")
	if not main.contains('AuthoritativeGameServer.request_jet_ski_mount()') or not main.contains('AuthoritativeGameServer.request_jet_ski_unmount()'):
		failures.append("Online mount and dismount must request server-authoritative lifecycle changes.")
	if not main.contains('jet_ski_authoritative_state_received.connect(_on_jet_ski_authoritative_state_received)'):
		failures.append("Local rider must receive authoritative jet ski corrections.")
	if not remote.contains('JET_SKI_SCENE.instantiate()') or not remote.contains('is_jet_ski_riding'):
		failures.append("Remote riders must render the authoritative jet ski snapshot.")
	if not hud.contains('AuthoritativeGameServer.send_jet_ski_input('):
		failures.append("Online HUD must send controls rather than relying on local physics.")
	if not failures.is_empty():
		for failure in failures:
			push_error(failure)
		quit(1)
		return
	print("Jet ski server synchronization contract tests passed.")
	quit(0)
