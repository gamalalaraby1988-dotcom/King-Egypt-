extends SceneTree
## Renders the actual avatar_visual.gd character with phone-use mode enabled.

const AVATAR_SCRIPT := preload("res://scripts/avatar_visual.gd")
const OUTPUT_PATH := "res://artifacts/avatar_phone_use_pose_preview.png"

func _initialize() -> void:
	call_deferred("_render_pose")

func _render_pose() -> void:
	root.size = Vector2i(1000, 1000)
	var world := Node3D.new()
	world.name = "AvatarPhonePosePreviewWorld"
	root.add_child(world)

	var environment := WorldEnvironment.new()
	var environment_resource := Environment.new()
	environment_resource.background_mode = Environment.BG_COLOR
	environment_resource.background_color = Color("#202733")
	environment.environment = environment_resource
	world.add_child(environment)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-24.0, -28.0, 0.0)
	key_light.light_energy = 1.5
	world.add_child(key_light)

	var fill_light := DirectionalLight3D.new()
	fill_light.rotation_degrees = Vector3(-12.0, 145.0, 0.0)
	fill_light.light_energy = 0.55
	world.add_child(fill_light)

	var avatar: Node3D = AVATAR_SCRIPT.new()
	avatar.name = "ActualAvatarVisual"
	world.add_child(avatar)
	avatar.call("set_phone_using", true)

	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 1.25, -4.3)
	camera.fov = 38.0
	camera.look_at(Vector3(0.0, 1.05, 0.0), Vector3.UP)
	world.add_child(camera)
	camera.make_current()

	for _frame in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Avatar phone-use pose render returned an empty image.")
		quit(1)
		return
	var directory := ProjectSettings.globalize_path("res://artifacts")
	DirAccess.make_dir_recursive_absolute(directory)
	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save avatar phone-use pose preview: " + output)
		quit(1)
		return
	print("Saved actual avatar phone-use pose preview: ", output)
	quit(0)
