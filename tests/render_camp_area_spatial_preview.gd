extends SceneTree
## Review-only camera capture of the real production city scene.
## No substitute camp, pyramid, or mountain geometry is created.
## Review captures include the proposed development campus and relocated mountain.

const OUTPUT_DIR := "res://artifacts/royal-development-mountain-preview"

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Production main scene could not be loaded.")
		quit(1)
		return

	root.size = Vector2i(1920, 1080)
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	for _frame in range(24):
		await process_frame

	# Recursively hide all UI layers, including layers nested under gameplay systems.
	_hide_interface_layers(scene)

	var camp := scene.get_node_or_null("RoyalDesertCamp") as Node3D
	var pyramids := scene.get_node_or_null("GizaPyramidsArea") as Node3D
	var layout := scene.get_node_or_null("ApprovedCityLayout") as Node3D
	var mountain := layout.get_node_or_null("KingsMountainRoute") as Node3D if layout != null else null
	if camp == null or pyramids == null or layout == null or mountain == null:
		push_error("Required production nodes (camp, pyramids, layout, mountain) are missing.")
		quit(1)
		return

	# Assert the primary Giza area remains beside the camp, while the duplicate
	# distant pyramid set has been replaced by the development campus.
	if camp.global_position.distance_to(Vector3(-130.0, 0.0, 70.0)) > 0.1:
		push_error("Production camp location differs from the audited location.")
		quit(1)
		return
	if pyramids.global_position.distance_to(camp.global_position) > 0.1:
		push_error("Primary Giza pyramid area is no longer co-located with the camp.")
		quit(1)
		return
	for duplicate_name in ["DistantGizaPyramid_1", "DistantGizaPyramid_2", "DistantGizaPyramid_3", "DistantSphinxLandmark"]:
		if layout.get_node_or_null(duplicate_name) != null:
			push_error("Duplicate distant Giza landmark remains: " + duplicate_name)
			quit(1)
			return
	for development_id in ["city_development_center", "technology_research_center", "vehicle_development_center", "character_equipment_center"]:
		if layout.get_node_or_null("Approved_" + development_id) == null:
			push_error("Development building is missing: " + development_id)
			quit(1)
			return
	if mountain.global_position.distance_to(Vector3(0.0, 0.0, -255.0)) > 0.1:
		push_error("Mountain route is not at the proposed former-pyramid parcel.")
		quit(1)
		return

	# Verify the approved camp expansion exists in the actual production scene.
	var tent_names := ["FoundersRoyalTent", "GuestTentWest", "GuestTentEast", "GuestTentNorth"]
	for tent_name in tent_names:
		var tent := camp.get_node_or_null(tent_name) as Node3D
		if tent == null:
			push_error("Required camp tent is missing: " + tent_name)
			quit(1)
			return
		var interactive_seats := 0
		for child in tent.get_children():
			if child.name.begins_with("InteractiveSeat_"):
				interactive_seats += 1
		if interactive_seats != 4:
			push_error("Each camp tent must contain four interactive seats: " + tent_name)
			quit(1)
			return
	for required_node in ["CentralCampfire", "OpenRoyalMajlis", "PyramidViewingDeck", "CamelPen", "HorsePen", "SheepGoatPen"]:
		if camp.get_node_or_null(required_node) == null:
			push_error("Required camp feature is missing: " + required_node)
			quit(1)
			return

	var captures := [
		["01_development_and_mountain_overview.png", Vector3(104.0, 112.0, -125.0), Vector3(0.0, 8.0, -245.0), 72.0],
		["02_development_buildings.png", Vector3(0.0, 52.0, -150.0), Vector3(0.0, 6.0, -214.0), 62.0],
		["03_mountain_route_and_summit.png", Vector3(66.0, 92.0, -202.0), Vector3(0.0, 10.0, -255.0), 68.0],
		["04_full_repurposed_parcel.png", Vector3(-92.0, 126.0, -132.0), Vector3(0.0, 6.0, -246.0), 76.0]
	]
	for capture in captures:
		var ok := await _capture_view(scene, capture[0], capture[1], capture[2], capture[3])
		if not ok:
			quit(1)
			return

	print("Four actual production-scene royal development and mountain previews captured.")
	quit(0)

func _hide_interface_layers(node: Node) -> void:
	for child in node.get_children():
		if child is CanvasLayer:
			child.visible = false
		_hide_interface_layers(child)

func _capture_view(scene: Node3D, file_name: String, camera_position: Vector3, target: Vector3, camera_fov: float) -> bool:
	var camera := Camera3D.new()
	camera.name = "TemporaryCampReviewCamera"
	camera.fov = camera_fov
	camera.near = 0.1
	camera.far = 1400.0
	scene.add_child(camera)
	camera.global_position = camera_position
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	for _frame in range(16):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame

	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Rendered viewport is empty: " + file_name)
		camera.queue_free()
		return false

	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var output_path := directory.path_join(file_name)
	var error := image.save_png(output_path)
	camera.queue_free()
	await process_frame
	if error != OK:
		push_error("Could not save preview: " + output_path)
		return false
	print("Saved ", output_path, " (", image.get_width(), "x", image.get_height(), ")")
	return true
