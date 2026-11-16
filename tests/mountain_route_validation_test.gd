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

	print("King mountain summit signage, road reflectors, bend warnings, and rest-stop direction tests passed.")
	route.queue_free()
	quit(0)
