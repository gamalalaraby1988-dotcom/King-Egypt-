extends SceneTree
## Captures real frames from the production main scene; no substitute geometry is created.

const OUTPUT_DIR := "res://artifacts"

func _initialize() -> void:
	call_deferred("_capture_previews")

func _capture_previews() -> void:
	var packed := load("res://scenes/main.tscn") as PackedScene
	if packed == null:
		push_error("Could not load the production main scene.")
		quit(1)
		return

	root.size = Vector2i(1600, 900)
	var production_scene := packed.instantiate()
	root.add_child(production_scene)
	current_scene = production_scene
	await process_frame
	for _frame in range(12):
		await process_frame

	# Hide only the startup mode-selection overlay for clean production-scene renders.
	var mode_overlay := current_scene.get_node_or_null("GameModeSelection") as CanvasLayer
	if is_instance_valid(mode_overlay):
		mode_overlay.visible = false
	await process_frame

	# Capture the actual five procedural race rings from the production city scene.
	# No preview-only or substitute gate geometry is created.
	var jet_ski_course := current_scene.get_node_or_null(
		"ApprovedCityLayout/RoyalJetSkiCourse"
	) as Node3D
	if jet_ski_course == null:
		push_error("The production royal jet ski course was not found.")
		quit(1)
		return
	for gate_name in ["Start", "Checkpoint1", "Checkpoint2", "Checkpoint3", "Finish"]:
		var ring := jet_ski_course.get_node_or_null("JetSkiGate_" + gate_name) as Node3D
		if ring == null:
			push_error("The production circular ring is missing: " + gate_name)
			quit(1)
			return
		var continuous_ring := ring.get_node_or_null("ContinuousLuminousRing") as MeshInstance3D
		var cyan_tracer := ring.get_node_or_null("CyanInnerLightTracer") as MeshInstance3D
		var gate_label := ring.get_node_or_null("GateLabel") as Label3D
		var support_count := 0
		var pontoon_count := 0
		for child in ring.get_children():
			if child.name == "EgyptianGoldSupportPylon":
				support_count += 1
			elif child.name == "FloatingGatePontoon":
				pontoon_count += 1
		if continuous_ring == null or cyan_tracer == null or gate_label == null or support_count != 2 or pontoon_count != 2:
			push_error("The production circular ring components are incomplete: %s (ring=%s, tracer=%s, label=%s, supports=%d, pontoons=%d, children=%s)" % [gate_name, str(continuous_ring != null), str(cyan_tracer != null), str(gate_label != null), support_count, pontoon_count, str(ring.get_children().map(func(child): return child.name))])
			quit(1)
			return
	var jet_ski_gate_ok := await _capture_view(
		"royal_jet_ski_circular_gate_preview.png",
		Vector3(0.0, 9.0, 72.0),
		Vector3(0.0, 8.25, 96.0),
		58.0
	)
	if not jet_ski_gate_ok:
		quit(1)
		return

	var gate_node := current_scene.get_node_or_null("ApprovedCityLayout/RoyalFounderGate") as Node3D
	if gate_node == null:
		push_error("The production royal gate node was not found.")
		quit(1)
		return

	# The approved GLB is now the single source of truth for the production gate.
	# Validate the imported asset rather than obsolete procedural node names.
	if gate_node.get_child_count() == 0:
		push_error("The approved royal gate GLB has no imported visual children.")
		quit(1)
		return
	if not ResourceLoader.exists("res://assets/models/royal_gate.glb"):
		push_error("The approved royal gate GLB asset is missing from production resources.")
		quit(1)
		return

	var gate_ok := await _capture_view(
		"royal_gate_preview.png",
		Vector3(0.0, 16.0, -24.0),
		Vector3(0.0, 7.0, -60.0),
		62.0
	)
	if not gate_ok:
		quit(1)
		return

	# Capture the reverse approach independently so both actual production faces are reviewed.
	var gate_back_ok := await _capture_view(
		"royal_gate_rear_preview.png",
		Vector3(0.0, 16.0, -72.0),
		Vector3(0.0, 7.0, -36.0),
		62.0
	)
	if not gate_back_ok:
		quit(1)
		return

	var ad := current_scene.get_node_or_null(
		"ApprovedCityLayout/Approved_royal_bank/FounderWallMural_royal_bank"
	) as Node3D
	if ad == null:
		push_error("The production royal-bank founder wall mural was not found.")
		quit(1)
		return
	var ad_target := ad.global_position + Vector3(0.0, 0.0, 0.0)
	var ad_normal := ad.global_transform.basis.z.normalized()
	var ad_ok := await _capture_view(
		"founder_wall_ad_preview.png",
		ad_target + ad_normal * 11.0 + Vector3.UP * 1.5,
		ad_target + Vector3.UP * 0.05
	)
	if not ad_ok:
		quit(1)
		return

	var mosaic := current_scene.get_node_or_null(
		"ApprovedCityLayout/Approved_royal_palace/RoyalSquareHistoricalMosaicPreview"
	) as Node3D
	if mosaic == null:
		push_error("The production royal-square historical mosaic preview was not found.")
		quit(1)
		return
	var mosaic_target := mosaic.global_position
	var mosaic_normal := mosaic.global_transform.basis.z.normalized()
	var mosaic_ok := await _capture_view(
		"royal_square_historical_mosaic_preview.png",
		mosaic_target + mosaic_normal * 10.5 + Vector3(0.0, 0.35, 0.0),
		mosaic_target + Vector3(0.0, 0.0, 0.0),
		42.0
	)
	if not mosaic_ok:
		quit(1)
		return

	print("Production-scene previews saved in ", OUTPUT_DIR)
	quit(0)

func _capture_view(file_name: String, camera_position: Vector3, target: Vector3, camera_fov: float = 55.0) -> bool:
	var camera := Camera3D.new()
	camera.name = "TemporaryPreviewCamera"
	camera.fov = camera_fov
	current_scene.add_child(camera)
	camera.global_position = camera_position
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	for _frame in range(10):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame

	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("The rendered viewport image is empty: " + file_name)
		camera.queue_free()
		return false

	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var output_path := directory.path_join(file_name)
	var error := image.save_png(output_path)
	camera.queue_free()
	await process_frame
	if error != OK:
		push_error("Could not save rendered preview: " + output_path)
		return false
	print("Saved rendered preview: ", output_path, " (", image.get_width(), "x", image.get_height(), ")")
	return true
