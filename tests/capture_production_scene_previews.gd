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
	# Hide all HUD CanvasLayers so the city geometry can be inspected without UI covering it.
	for canvas_layer in current_scene.find_children("*", "CanvasLayer", true, false):
		(canvas_layer as CanvasLayer).visible = false
	await process_frame

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

	# Capture the expanded open sea and royal beach from the actual production scene.
	var waterfront_ok := await _capture_view(
		"royal_open_sea_waterfront_preview.png",
		Vector3(0.0, 66.0, -560.0),
		Vector3(0.0, 0.0, -670.0),
		58.0
	)
	if not waterfront_ok:
		quit(1)
		return

	# Capture the real jet-ski start, checkpoint buoys, and finish gates in the same production scene.
	var course_ok := await _capture_view(
		"royal_jet_ski_course_preview.png",
		Vector3(30.0, 34.0, -535.0),
		Vector3(0.0, 2.0, -570.0),
		58.0
	)
	if not course_ok:
		quit(1)
		return

	# Capture the actual Five Civilizations Ship and its dedicated independent boarding bridge.
	var ship_bridge_ok := await _capture_view(
		"royal_civilizations_ship_bridge_preview.png",
		Vector3(-5.0, 105.0, -585.0),
		Vector3(-45.0, 2.0, -640.0),
		68.0
	)
	if not ship_bridge_ok:
		quit(1)
		return

	# Full-city aerial now includes the southern desert, pyramids and Kings Summit districts.
	# Render the full north-to-south production map through a dedicated portrait SubViewport.
	# Changing Window.size is ignored by some headless runners, so capture the SubViewport texture directly.
	var aerial_environment := current_scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	var aerial_fog_was_enabled := false
	if aerial_environment != null and aerial_environment.environment != null:
		aerial_fog_was_enabled = aerial_environment.environment.fog_enabled
		aerial_environment.environment.fog_enabled = false
	_prepare_full_detail_aerial_capture()
	var master_plan_ok := await _capture_portrait_master_plan(
		"expanded_city_aerial_master_plan_preview.png",
		Vector3(0.0, 1420.0, -110.0),
		Vector3(0.0, 0.0, -110.0)
	)
	if aerial_environment != null and aerial_environment.environment != null:
		aerial_environment.environment.fog_enabled = aerial_fog_was_enabled
	if not master_plan_ok:
		quit(1)
		return

	var southern_district_ok := await _capture_view(
		"southern_desert_district_aerial_preview.png",
		Vector3(0.0, 170.0, 610.0),
		Vector3(0.0, 0.0, 430.0),
		64.0
	)
	if not southern_district_ok:
		quit(1)
		return

	# Instantiate the exact production RoyalJetSki scene so the preview uses the in-game craft,
	# not a replacement mesh or illustration. Keep it in the production waterfront scene.
	var jet_ski_packed := load("res://scenes/jet_ski.tscn") as PackedScene
	if jet_ski_packed == null:
		push_error("The production RoyalJetSki scene could not be loaded.")
		quit(1)
		return
	var jet_ski_preview := jet_ski_packed.instantiate() as Node3D
	if jet_ski_preview == null:
		push_error("The production RoyalJetSki scene did not instantiate as a Node3D.")
		quit(1)
		return
	jet_ski_preview.name = "RoyalJetSkiProductionPreviewInstance"
	jet_ski_preview.position = Vector3(0.0, 0.34, -550.0)
	jet_ski_preview.rotation.y = deg_to_rad(18.0)
	current_scene.add_child(jet_ski_preview)
	for _frame in range(8):
		await process_frame

	var jet_ski_three_quarter_ok := await _capture_view(
		"royal_jet_ski_craft_three_quarter_preview.png",
		Vector3(4.8, 3.1, -554.8),
		Vector3(0.0, 0.72, -550.0),
		48.0
	)
	if not jet_ski_three_quarter_ok:
		quit(1)
		return

	var jet_ski_side_ok := await _capture_view(
		"royal_jet_ski_craft_side_preview.png",
		Vector3(5.8, 2.1, -548.8),
		Vector3(0.0, 0.58, -550.0),
		48.0
	)
	if not jet_ski_side_ok:
		quit(1)
		return
	jet_ski_preview.queue_free()
	await process_frame

	# Capture both relocated northern building rows from the production scene.
	var north_district_ok := await _capture_view(
		"northern_six_buildings_preview.png",
		Vector3(0.0, 44.0, -204.0),
		Vector3(0.0, 3.0, -135.0),
		56.0
	)
	if not north_district_ok:
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

func _prepare_full_detail_aerial_capture() -> void:
	# The aerial camera is above the normal 480 m LOD range. Disable only the
	# building proxy groups for this test capture and reveal their real production
	# geometry; this does not alter the shipped scene or runtime LOD settings.
	var buildings := current_scene.find_children("*", "Node3D", true, false)
	for building in buildings:
		if not building.is_in_group("approved_city_buildings"):
			continue
		var proxy := building.get_node_or_null("BuildingLODProxy")
		if is_instance_valid(proxy):
			proxy.visible = false
		for visual in building.find_children("*", "GeometryInstance3D", true, false):
			var geometry := visual as GeometryInstance3D
			geometry.visibility_range_begin = 0.0
			geometry.visibility_range_end = 0.0

func _capture_portrait_master_plan(file_name: String, camera_position: Vector3, target: Vector3) -> bool:
	var portrait := SubViewport.new()
	portrait.name = "PortraitMasterPlanViewport"
	portrait.size = Vector2i(900, 1600)
	portrait.own_world_3d = false
	portrait.world_3d = current_scene.get_world_3d()
	portrait.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(portrait)

	var camera := Camera3D.new()
	camera.name = "PortraitMasterPlanCamera"
	camera.fov = 60.0
	portrait.add_child(camera)
	camera.global_position = camera_position
	camera.look_at(target, Vector3(0.0, 0.0, -1.0))
	camera.far = 4000.0
	camera.make_current()
	for _frame in range(18):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame

	var image := portrait.get_texture().get_image()
	portrait.queue_free()
	await process_frame
	if image.is_empty():
		push_error("The portrait master-plan viewport image is empty: " + file_name)
		return false
	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var output_path := directory.path_join(file_name)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save portrait master-plan preview: " + output_path)
		return false
	print("Saved portrait master-plan preview: ", output_path, " (", image.get_width(), "x", image.get_height(), ")")
	return true

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
