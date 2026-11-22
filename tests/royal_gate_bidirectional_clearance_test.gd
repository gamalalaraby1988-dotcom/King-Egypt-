extends SceneTree

var _failures := 0

func _initialize() -> void:
	call_deferred("_run_bidirectional_gate_clearance_test")


func _run_bidirectional_gate_clearance_test() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	_expect(packed_scene != null, "Production main scene can be loaded")
	if packed_scene == null:
		quit(1)
		return

	var scene := packed_scene.instantiate() as Node3D
	root.add_child(scene)
	await process_frame
	await physics_frame
	await physics_frame

	var gate := scene.get_node_or_null("City/RoyalFounderGate") as Node3D
	_expect(gate != null, "Production royal founder gate exists in the live scene")
	if gate == null:
		quit(1)
		return

	var player := scene.get_node_or_null("Player") as CollisionObject3D
	var excluded_rids: Array[RID] = []
	if player != null:
		excluded_rids.append(player.get_rid())

	var space := scene.get_world_3d().direct_space_state
	var route_z_positions: Array[float] = []
	var z := -52.0
	while z <= -44.0:
		route_z_positions.append(z)
		z += 0.5

	# A compact pedestrian envelope and a conservative passenger-car envelope.
	# Both are swept through the actual production physics world, not inferred
	# from the visible mesh or from source-code dimensions alone.
	_run_clearance_sweep(
		space,
		excluded_rids,
		"pedestrian",
		Vector3(0.85, 1.9, 0.85),
		1.15,
		route_z_positions
	)
	_run_clearance_sweep(
		space,
		excluded_rids,
		"vehicle",
		Vector3(2.4, 2.2, 4.6),
		1.45,
		route_z_positions
	)

	if _failures > 0:
		push_error("Royal gate bidirectional clearance test failed: %d blocked sweep sample(s)." % _failures)
		quit(1)
		return

	print("Royal gate bidirectional clearance passed: pedestrian and vehicle envelopes are clear in both directions.")
	quit(0)


func _run_clearance_sweep(
	space: PhysicsDirectSpaceState3D,
	excluded_rids: Array[RID],
	label: String,
	box_size: Vector3,
	center_y: float,
	positions: Array[float]
) -> void:
	var shape := BoxShape3D.new()
	shape.size = box_size

	for direction in [1, -1]:
		var ordered_positions := positions.duplicate()
		if direction < 0:
			ordered_positions.reverse()
		var direction_label := "square-to-city" if direction > 0 else "city-to-square"
		for route_z in ordered_positions:
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform = Transform3D(Basis.IDENTITY, Vector3(0.0, center_y, route_z))
			query.exclude = excluded_rids
			query.collide_with_bodies = true
			query.collide_with_areas = false
			query.margin = 0.01
			var hits := space.intersect_shape(query, 8)
			if not hits.is_empty():
				var collider: Object = hits[0].get("collider")
				var collider_name := collider.get("name") if collider != null else "unknown collider"
				_fail(
					"%s is blocked %s at z=%.2f by %s" %
					[label, direction_label, route_z, str(collider_name)]
				)


func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_fail(message)


func _fail(message: String) -> void:
	_failures += 1
	push_error(message)
