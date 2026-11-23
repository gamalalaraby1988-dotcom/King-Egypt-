extends SceneTree
## Renders the actual avatar_visual.gd character holding the phone while idle, walking, and running.

const AVATAR_SCRIPT := preload("res://scripts/avatar_visual.gd")
const OUTPUT_DIRECTORY := "res://artifacts"

func _initialize() -> void:
	call_deferred("_render_poses")

func _render_poses() -> void:
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
	world.add_child(camera)
	camera.look_at(Vector3(0.0, 1.05, 0.0), Vector3.UP)
	camera.make_current()

	await _save_preview("avatar_phone_use_pose_idle.png")
	avatar.call("set_motion_state", "walk", 2.0)
	await _wait_motion_frames()
	await _save_preview("avatar_phone_use_pose_walk.png")
	avatar.call("set_motion_state", "run", 4.0)
	await _wait_motion_frames()
	await _save_preview("avatar_phone_use_pose_run.png")
	print("Saved actual avatar phone-use pose previews for idle, walk, and run.")
	quit(0)

func _wait_motion_frames() -> void:
	for _frame in range(12):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame

func _save_preview(file_name: String) -> void:
	for _frame in range(8):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Avatar phone-use pose render returned an empty image: " + file_name)
		quit(1)
		return
	var directory := ProjectSettings.globalize_path(OUTPUT_DIRECTORY)
	DirAccess.make_dir_recursive_absolute(directory)
	var output := ProjectSettings.globalize_path(OUTPUT_DIRECTORY.path_join(file_name))
	var error := image.save_png(output)
	if error != OK:
		push_error("Could not save avatar phone-use pose preview: " + output)
		quit(1)
		return
	print("Saved actual avatar phone-use pose preview: ", output)
