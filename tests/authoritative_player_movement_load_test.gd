extends SceneTree
## Exercises the real authoritative movement tick and visibility snapshot builder
## with 64 isolated synthetic sessions. This is not a network/authentication test.

const SERVER_SCRIPT := preload("res://scripts/authoritative_game_server.gd")
const PLAYER_COUNT := 64

var _failed := 0

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.name = "MovementLoadTestFloor"
	floor_body.collision_layer = 1
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(500.0, 1.0, 500.0)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	root.add_child(floor_body)

	var server := SERVER_SCRIPT.new() as Node
	server.name = "AuthoritativeMovementLoadTestServer"
	root.add_child(server)

	var now_usec := Time.get_ticks_usec()
	var sessions: Dictionary = {}
	var start_positions: Dictionary = {}
	var bodies: Array[CharacterBody3D] = []
	for index in range(PLAYER_COUNT):
		var peer_id := index + 2
		var body := CharacterBody3D.new()
		body.name = "MovementLoadTestPlayer_%02d" % peer_id
		body.collision_layer = 2
		body.collision_mask = 1
		body.position = Vector3(float(index % 8) * 3.0 - 10.5, 0.9, float(index / 8) * 3.0 - 10.5)
		body.floor_snap_length = 0.25
		var collision := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.42
		capsule.height = 1.8
		collision.shape = capsule
		body.add_child(collision)
		root.add_child(body)
		bodies.append(body)
		start_positions[peer_id] = body.global_position
		sessions[peer_id] = {
			"authenticated": true,
			"user_id": "synthetic-movement-test-%02d" % peer_id,
			"instance_id": "city-main",
			"body": body,
			"direction": Vector3.RIGHT,
			"sprint": false,
			"velocity": Vector3.ZERO,
			"last_sequence": -1,
			"last_input_usec": now_usec,
			"last_auth_usec": now_usec,
			"connected_at_usec": now_usec,
			"input_window_usec": now_usec,
			"input_count": 0,
			"walk_progress_ready": true,
			"first_steps_recorded": true,
			"last_safe_position": body.global_position,
			"last_safe_return_usec": 0,
			"reached_objectives": {},
			"active_job": {},
			"active_mission": {},
			"jet_ski_mounted": false,
			"emote_until_usec": 0,
			"is_sitting": false
		}

	server.set("_sessions", sessions)
	# Keep the periodic RPC broadcast out of this deterministic, in-process
	# simulation. Snapshot construction is asserted directly below.
	server.set("_snapshot_elapsed", -100.0)

	await create_timer(1.2).timeout

	var moved_count := 0
	for index in range(PLAYER_COUNT):
		var peer_id := index + 2
		var start_position: Vector3 = start_positions[peer_id]
		var final_position: Vector3 = bodies[index].global_position
		var displacement := Vector2(final_position.x - start_position.x, final_position.z - start_position.z).length()
		if displacement > 0.5:
			moved_count += 1
		else:
			_expect(false, "synthetic player %d moved through authoritative physics" % peer_id)

	var snapshots: Dictionary = server.call("_build_remote_player_snapshots")
	_expect(snapshots.size() == PLAYER_COUNT, "64 authenticated synthetic sessions receive visibility snapshots")
	var total_remote_records := 0
	for peer_id_variant in snapshots.keys():
		var remote_players: Array = snapshots[peer_id_variant]
		_expect(remote_players.size() == PLAYER_COUNT - 1, "each player sees the other 63 players")
		total_remote_records += remote_players.size()

	print(JSON.stringify({
			"result": "passed" if _failed == 0 else "failed",
			"scope": "in-process authoritative physics and visibility simulation; no WebSocket RPC, authentication, or live gameplay session",
		"synthetic_players": PLAYER_COUNT,
		"players_moved": moved_count,
		"players_with_visibility_snapshots": snapshots.size(),
		"total_remote_player_records": total_remote_records
	}, "  "))

	for body in bodies:
		if is_instance_valid(body):
			body.queue_free()
	server.queue_free()
	floor_body.queue_free()

	if _failed > 0:
		push_error("Authoritative 64-player movement simulation failed: %d" % _failed)
		quit(1)
		return
	quit(0)


func _expect(condition: bool, label: String) -> void:
	if not condition:
		_failed += 1
		push_error("Authoritative 64-player movement simulation failed: " + label)
