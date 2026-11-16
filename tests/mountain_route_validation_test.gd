extends SceneTree

func _initialize() -> void:
	call_deferred("_run_mountain_route_tests")

func _run_mountain_route_tests() -> void:
	var route_script := load("res://scripts/king_mountain_route.gd") as Script
	if route_script == null:
		push_error("King mountain route script did not load.")
		quit(1)
		return
	var route := Node3D.new()
	route.set_script(route_script)
	root.add_child(route)
	await process_frame

	var summit_board := route.get_node_or_null("MountainSummitNameBoard") as MeshInstance3D
	var summit_title := route.get_node_or_null("MountainSummitTitle") as Label3D
	var summit_subtitle := route.get_node_or_null("MountainSummitSubtitle") as Label3D
	var summit_glow := route.get_node_or_null("MountainSummitNameGlow") as OmniLight3D
	if summit_board == null or summit_title == null or summit_subtitle == null or summit_glow == null:
		push_error("The royal summit sign, title, subtitle, or illumination is missing.")
		quit(1)
		return
	if summit_title.text != "قمة الملوك" or summit_subtitle.text != "منطقة المشاهدة الملكية":
		push_error("The royal summit sign text does not match the approved destination labels.")
		quit(1)
		return
	if summit_glow.light_energy <= 0.0 or summit_glow.omni_range <= 0.0:
		push_error("The royal summit destination sign is not illuminated.")
		quit(1)
		return
	if route.get_node_or_null("MountainSummitNameBoardCollision") != null:
		push_error("The decorative summit name board must not create an unnecessary physical obstacle.")
		quit(1)
		return

	var road_reflector_count := 0
	var turn_reflector_count := 0
	var approach_stripe_count := 0
	var turn_edge_guide_count := 0
	var warning_sign_count := 0
	var rest_arrow_count := 0
	for child in route.get_children():
		var node_name := child.name
		if node_name.begins_with("MountainRoadEdgeReflector_"):
			road_reflector_count += 1
		elif node_name.begins_with("MountainTurnEdgeReflector_"):
			turn_reflector_count += 1
		elif node_name.begins_with("MountainTurnApproachStripe_"):
			approach_stripe_count += 1
		elif node_name.begins_with("MountainTurnApronEdgeGuide_"):
			turn_edge_guide_count += 1
		elif node_name.begins_with("MountainTurnWarning_"):
			warning_sign_count += 1
		elif node_name.begins_with("MountainRestContinueArrow_"):
			rest_arrow_count += 1
	if road_reflector_count == 0 or turn_reflector_count == 0:
		push_error("Mountain road edge reflectors are missing from straight segments or bends.")
		quit(1)
		return
	if approach_stripe_count == 0 or turn_edge_guide_count == 0 or warning_sign_count == 0:
		push_error("Mountain bend approach markings, apron edge guides, or warning signs are missing.")
		quit(1)
		return
	if rest_arrow_count < 2:
		push_error("Both mountain rest stops must show a clear uphill continuation arrow.")
		quit(1)
		return

	# Verify the shared road is drivable and physically continuous for walking,
	# scooters, and cars: every segment has a matching world collider and safe grade.
	var route_points: Array = route_script.get_script_constant_map().get("ROUTE_POINTS", [])
	if route_points.size() < 2:
		push_error("The mountain route must contain a connected sequence of road points.")
		quit(1)
		return
	for segment_index in range(route_points.size() - 1):
		var segment_name := "MountainRoadSegment_%02d" % segment_index
		var road_mesh := route.get_node_or_null(segment_name) as MeshInstance3D
		var road_body := route.get_node_or_null(segment_name + "Collision") as StaticBody3D
		if road_mesh == null or road_body == null:
			push_error("Mountain road segment %d is missing its physical road surface." % segment_index)
			quit(1)
			return
		var road_shape_node := road_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
		var road_shape := road_shape_node.shape as BoxShape3D if road_shape_node != null else null
		if road_shape == null or not is_equal_approx(road_shape.size.x, 8.0):
			push_error("Mountain road segment %d does not preserve the approved shared-road width." % segment_index)
			quit(1)
			return
		if road_body.collision_layer != 1 or road_body.collision_mask != 7:
			push_error("Mountain road segment %d does not use the shared world collision profile." % segment_index)
			quit(1)
			return
		var delta: Vector3 = route_points[segment_index + 1] - route_points[segment_index]
		var horizontal_length := Vector2(delta.x, delta.z).length()
		var grade_degrees := rad_to_deg(atan2(absf(delta.y), maxf(horizontal_length, 0.001)))
		if grade_degrees > 18.0:
			push_error("Mountain road segment %d is too steep for the approved shared vehicle and pedestrian route." % segment_index)
			quit(1)
			return
		for side in ["L", "R"]:
			var guard_body := route.get_node_or_null("MountainGuardWall_%02d_%sCollision" % [segment_index, side]) as StaticBody3D
			if guard_body == null:
				push_error("Mountain road segment %d is missing a solid edge guard on side %s." % [segment_index, side])
				quit(1)
				return

	# Every bend must have a collidable apron and closed guard-wall joins on both sides.
	for bend_index in range(1, route_points.size() - 1):
		var apron_body := route.get_node_or_null("MountainTurnApron_%02dCollision" % bend_index) as StaticBody3D
		if apron_body == null:
			push_error("Mountain bend %d is missing its drivable apron collision." % bend_index)
			quit(1)
			return
		for side in ["L", "R"]:
			var connector_body := route.get_node_or_null("MountainTurnGuardConnector_%02d_%sCollision" % [bend_index, side]) as StaticBody3D
			if connector_body == null:
				push_error("Mountain bend %d has an unprotected guard-wall join on side %s." % [bend_index, side])
				quit(1)
				return

	# The city approach and entrance must leave a vehicle-width opening into the climb.
	var approach_body := route.get_node_or_null("MountainCityApproachRoadCollision") as StaticBody3D
	var gate_left := route.get_node_or_null("KingsMountainEntranceGate/GateLeftPillarCollision") as StaticBody3D
	var gate_right := route.get_node_or_null("KingsMountainEntranceGate/GateRightPillarCollision") as StaticBody3D
	if approach_body == null or gate_left == null or gate_right == null:
		push_error("The mountain approach or entrance gate is missing physical collision geometry.")
		quit(1)
		return
	var gate_clear_width := absf(gate_right.global_position.x - gate_left.global_position.x) - 0.9
	if gate_clear_width < 9.0:
		push_error("The mountain gate opening is too narrow for the shared road and vehicle access.")
		quit(1)
		return

	for stop_index in range(2):
		for fixture_name in ["MountainRestBay_%d" % stop_index, "MountainRestBench_%d" % stop_index, "MountainViewDeck_%d" % stop_index]:
			var fixture_body := route.get_node_or_null(fixture_name + "Collision") as StaticBody3D
			if fixture_body == null:
				push_error("Mountain rest-stop fixture %s is missing its physical collider." % fixture_name)
				quit(1)
				return

	# Confirm the route remains visibly guided at night and the rest-stop wayfinding is present.
	for route_light_index in range(route_points.size()):
		var lamp_post := route.get_node_or_null("MountainWayfindingLampPost_%02dCollision" % route_light_index) as StaticBody3D
		var lamp_glow := route.get_node_or_null("MountainWayfindingGlow_%02d" % route_light_index) as OmniLight3D
		if lamp_post == null or lamp_glow == null or lamp_glow.omni_range < 7.0:
			push_error("Mountain route waypoint %d is missing a solid lamp post or sufficient night lighting." % route_light_index)
			quit(1)
			return
	for stop_index in range(2):
		for fixture_name in ["MountainRestLantern_%d" % stop_index, "MountainRestSignBoard_%d" % stop_index]:
			if route.get_node_or_null(fixture_name + "Collision") == null:
				push_error("Rest stop %d is missing its solid wayfinding fixture %s." % [stop_index, fixture_name])
				quit(1)
				return
		for glow_name in ["MountainRestGlow_%d" % stop_index, "MountainRestSignGlow_%d" % stop_index, "MountainRestArrowGlow_%d" % stop_index]:
			var rest_glow := route.get_node_or_null(glow_name) as OmniLight3D
			if rest_glow == null or rest_glow.light_energy <= 0.0:
				push_error("Rest stop %d is missing its night guidance light %s." % [stop_index, glow_name])
				quit(1)
				return
		var continue_arrow := route.get_node_or_null("MountainRestContinueArrow_%d" % stop_index) as Label3D
		if continue_arrow == null or continue_arrow.text != "➤":
			push_error("Rest stop %d is missing its uphill direction arrow." % stop_index)
			quit(1)
			return

	# The summit must be a usable protected terrace, with its approach left open.
	for summit_fixture in [
		"MountainSummitPlatform",
		"MountainSummitSideBarrier_-1",
		"MountainSummitSideBarrier_1",
		"MountainSummitRearBarrier",
		"MountainSummitObeliskBase",
		"MountainSummitObelisk",
		"MountainSummitBench_-1",
		"MountainSummitBench_1"
	]:
		var summit_fixture_body := route.get_node_or_null(summit_fixture + "Collision") as StaticBody3D
		if summit_fixture_body == null:
			push_error("Summit fixture %s is missing its physical collider." % summit_fixture)
			quit(1)
			return
	if route.get_node_or_null("MountainSummitFrontBarrierCollision") != null:
		push_error("The summit entrance must remain open to vehicles and pedestrians.")
		quit(1)
		return
	var summit_platform_body := route.get_node_or_null("MountainSummitPlatformCollision") as StaticBody3D
	var summit_platform_shape := summit_platform_body.get_node_or_null("CollisionShape3D") as CollisionShape3D
	var summit_platform_box := summit_platform_shape.shape as BoxShape3D if summit_platform_shape != null else null
	if summit_platform_box == null or summit_platform_box.size.x < 30.0 or summit_platform_box.size.z < 30.0:
		push_error("The summit terrace is too small for a safe arrival and gathering area.")
		quit(1)
		return

	print("King mountain route tests passed: summit signage, night guidance, shared-road grade and width, continuous collision guards, and solid rest-stop fixtures.")
	route.queue_free()
	quit(0)
