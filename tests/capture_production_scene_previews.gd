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
		Vector3(0.0, 66.0, 24.0),
		Vector3(0.0, 0.0, 114.0),
		58.0
	)
	if not waterfront_ok:
		quit(1)
		return

	# Capture the real jet-ski start, checkpoint buoys, and finish gates in the same production scene.
	var course_ok := await _capture_view(
		"royal_jet_ski_course_preview.png",
		Vector3(30.0, 34.0, 78.0),
		Vector3(0.0, 2.0, 122.0),
		58.0
	)
	if not course_ok:
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
	jet_ski_preview.position = Vector3(0.0, 0.34, 108.0)
	jet_ski_preview.rotation.y = deg_to_rad(18.0)
	current_scene.add_child(jet_ski_preview)
	for _frame in range(8):
		await process_frame

	var jet_ski_three_quarter_ok := await _capture_view(
		"royal_jet_ski_craft_three_quarter_preview.png",
		Vector3(4.8, 3.1, 102.8),
		Vector3(0.0, 0.72, 108.0),
		48.0
	)
	if not jet_ski_three_quarter_ok:
		quit(1)
		return

	var jet_ski_side_ok := await _capture_view(
		"royal_jet_ski_craft_side_preview.png",
		Vector3(5.8, 2.1, 108.8),
		Vector3(0.0, 0.58, 108.0),
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
