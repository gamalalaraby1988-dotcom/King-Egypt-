extends SceneTree
## Renders the repository's exact royal_gate.glb asset in isolation.
## No replacement geometry or production-scene gate is created here.

const MODEL_PATH := "res://assets/models/royal_gate.glb"
const OUTPUT_DIR := "res://artifacts"
const VIEW_SIZE := Vector2i(1600, 900)

func _initialize() -> void:
	call_deferred("_capture_glb_previews")


func _capture_glb_previews() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Could not import royal_gate.glb as a PackedScene.")
		quit(1)
		return

	var viewport := SubViewport.new()
	viewport.name = "RoyalGateGlbPreviewViewport"
	viewport.size = VIEW_SIZE
	viewport.use_own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.transparent_bg = false
	root.add_child(viewport)

	var stage := Node3D.new()
	stage.name = "RoyalGateGlbPreviewStage"
	viewport.add_child(stage)

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.055, 0.067, 0.085, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.82, 0.9, 1.0)
	environment.ambient_light_energy = 0.8
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	stage.add_child(world_environment)

	var key_light := DirectionalLight3D.new()
	key_light.name = "PreviewKeyLight"
	key_light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key_light.light_energy = 1.7
	stage.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.name = "PreviewFillLight"
	fill_light.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill_light.light_energy = 0.55
	stage.add_child(fill_light)

	var model := packed.instantiate() as Node3D
	if model == null:
		push_error("The imported royal_gate.glb root is not a Node3D.")
		quit(1)
		return
	model.name = "ExactRoyalGateGlb"
	stage.add_child(model)

	await process_frame
	var bounds := _get_model_bounds(model)
	if bounds.size.length() <= 0.001:
		push_error("The imported royal_gate.glb has no measurable mesh bounds.")
		quit(1)
		return

	var center := bounds.position + bounds.size * 0.5
	var largest_dimension: float = maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	var distance: float = largest_dimension * 2.35
	var camera := Camera3D.new()
	camera.name = "RoyalGateGlbPreviewCamera"
	camera.fov = 42.0
	camera.current = true
	stage.add_child(camera)

	var front_ok := await _capture_viewport(
		viewport,
		camera,
		center + Vector3(distance * 0.72, distance * 0.42, distance * 1.25),
		center,
		"royal_gate_glb_front.png"
	)
	if not front_ok:
		quit(1)
		return

	var rear_ok := await _capture_viewport(
		viewport,
		camera,
		center + Vector3(distance * 0.72, distance * 0.42, -distance * 1.25),
		center,
		"royal_gate_glb_rear.png"
	)
	if not rear_ok:
		quit(1)
		return

	print("Exact royal_gate.glb front and rear previews saved in ", OUTPUT_DIR)
	quit(0)


func _get_model_bounds(model: Node3D) -> AABB:
	var result := AABB()
	var has_bounds := false
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var mesh_node := node as MeshInstance3D
		if mesh_node == null or mesh_node.mesh == null:
			continue
		var transformed_bounds: AABB = mesh_node.global_transform * mesh_node.get_aabb()
		if not has_bounds:
			result = transformed_bounds
			has_bounds = true
		else:
			result = result.merge(transformed_bounds)
	return result


func _capture_viewport(
	viewport: SubViewport,
	camera: Camera3D,
	camera_position: Vector3,
	target: Vector3,
	file_name: String
) -> bool:
	camera.global_position = camera_position
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	for _frame in range(18):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame

	var image := viewport.get_texture().get_image()
	if image.is_empty():
		push_error("The GLB preview viewport image is empty: " + file_name)
		return false

	var directory := ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(directory)
	var output_path := directory.path_join(file_name)
	var error := image.save_png(output_path)
	if error != OK:
		push_error("Could not save the exact GLB preview: " + output_path)
		return false
	print("Saved exact GLB preview: ", output_path, " (", image.get_width(), "x", image.get_height(), ")")
	return true
