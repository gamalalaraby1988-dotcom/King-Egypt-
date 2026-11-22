extends SceneTree

const MODEL_PATH := "res://assets/review/royal_gate_repaired.glb"
const OUTPUT_PATH := "res://artifacts/royal-gate-review/royal_gate_repaired_preview.png"

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var packed := load(MODEL_PATH) as PackedScene
	if packed == null:
		push_error("Could not load the repaired GLB as a Godot PackedScene: " + MODEL_PATH)
		quit(1)
		return

	root.size = Vector2i(1600, 900)
	var stage := Node3D.new()
	stage.name = "RoyalGateGLBReviewStage"
	root.add_child(stage)
	current_scene = stage

	var model := packed.instantiate()
	model.name = "ExactRepairedRoyalGateGLB"
	stage.add_child(model)

	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.055, 0.075, 0.11)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.72, 0.78, 0.9)
	env.ambient_light_energy = 0.8
	environment.environment = env
	stage.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -28.0, 0.0)
	key_light.light_energy = 1.8
	stage.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
	fill_light.light_energy = 0.65
	stage.add_child(fill_light)

	var camera := Camera3D.new()
	camera.fov = 42.0
	camera.position = Vector3(23.0, 15.0, 29.0)
	stage.add_child(camera)
	camera.look_at(Vector3(0.0, 4.7, 0.0), Vector3.UP)
	camera.make_current()

	for _frame in range(20):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame

	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("The repaired GLB preview viewport is empty.")
		quit(1)
		return
	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save the repaired GLB preview: " + output)
		quit(1)
		return

	print("Rendered preview directly from ", MODEL_PATH)
	print("Saved exact GLB render: ", OUTPUT_PATH)
	quit(0)
