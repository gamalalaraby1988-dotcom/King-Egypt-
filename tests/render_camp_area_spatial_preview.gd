extends SceneTree
## Review-only camera capture of the real production city scene.
## No substitute camp, pyramid, or mountain geometry is created.

const OUTPUT_DIR := "res://artifacts/camp-area-spatial-preview"

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
	for _frame in range(20):
		await process_frame

	# Hide interface layers only; leave the real 3D production world untouched.
	for child in scene.get_children():
		if child is CanvasLayer:
			child.visible = false

	var camp := scene.get_node_or_null("RoyalDesertCamp") as Node3D
	var pyramids := scene.get_node_or_null("GizaPyramidsArea") as Node3D
	var layout := scene.get_node_or_null("ApprovedCityLayout") as Node3D
	if camp == null or pyramids == null or layout == null:
		push_error("Required production nodes (camp, pyramids, approved layout) are missing.")
		quit(1)
		return

	# Assert the production placement being reviewed; fail rather than silently
	# rendering a guessed or substituted location.
	if camp.global_position.distance_to(Vector3(-130.0, 0.0, 70.0)) > 0.1:
		push_error("Production camp location differs from the audited location.")
		quit(1)
		return
	if pyramids.global_position.distance_to(camp.global_position) > 0.1:
		push_error("Production pyramid area is no longer co-located with the camp area.")
		quit(1)
		return

	var overview_ok := await _capture_view(
		scene,
		"01_camp_pyramids_mountain_overview.png",
		Vector3(-18.0, 118.0, 246.0),
		Vector3(-76.0, 2.0, 80.0),
		68.0
	)
	if not overview_ok:
		quit(1)
		return

	var camp_ok := await _capture_view(
		scene,
		"02_camp_and_nearby_pyramids.png",
		Vector3(-53.0, 58.0, 172.0),
		Vector3(-103.0, 2.0, 91.0),
		58.0
	)
	if not camp_ok:
		quit(1)
		return

	var mountain_ok := await _capture_view(
		scene,
		"03_camp_to_mountain_spatial_relation.png",
		Vector3(38.0, 96.0, 198.0),
		Vector3(-55.0, 5.0, 55.0),
		72.0
	)
	if not mountain_ok:
		quit(1)
		return

	print("Camp spatial previews captured from the production main scene.")
	quit(0)

func _capture_view(scene: Node3D, file_name: String, camera_position: Vector3, target: Vector3, camera_fov: float) -> bool:
	var camera := Camera3D.new()
	camera.name = "TemporaryCampReviewCamera"
	camera.fov = camera_fov
	camera.near = 0.1
	camera.far = 1200.0
	scene.add_child(camera)
	camera.global_position = camera_position
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	for _frame in range(14):
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
