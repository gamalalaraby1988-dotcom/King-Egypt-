extends SceneTree

const MODEL_PATH := "res://assets/review/main_royal_tent.glb"
const OUTPUT_PATH := "res://artifacts/main-royal-tent-build/royal_tent_city_placement_preview.png"
const TENT_POSITION := Vector3(-35.0, 0.0, -78.0)
const TENT_YAW := PI * 0.5

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var packed_main := load("res://scenes/main.tscn") as PackedScene
	var packed_tent := load(MODEL_PATH) as PackedScene
	if packed_main == null or packed_tent == null:
		push_error("Could not load production city scene or exact tent GLB.")
		quit(1)
		return

	root.size = Vector2i(1600, 900)
	var city := packed_main.instantiate() as Node3D
	if city == null:
		push_error("Production main scene root must be Node3D.")
		quit(1)
		return
	root.add_child(city)
	current_scene = city

	# The review-only instance is attached to the live layout in memory.
	# No production scene, script, registry, or collision data is changed.
	await process_frame
	var layout := city.get_node_or_null("ApprovedCityLayout") as Node3D
	if layout == null:
		push_error("ApprovedCityLayout was not created by the production scene.")
		quit(1)
		return
	var tent := packed_tent.instantiate() as Node3D
	if tent == null:
		push_error("Exact tent GLB root must be Node3D.")
		quit(1)
		return
	tent.name = "ReviewOnly_MainRoyalTent"
	tent.position = TENT_POSITION
	tent.rotation.y = TENT_YAW
	layout.add_child(tent)

	# Frame the royal palace, gate, square, and proposed tent location together.
	var camera := Camera3D.new()
	camera.name = "ReviewPlacementCamera"
	camera.fov = 54.0
	camera.position = Vector3(-83.0, 66.0, -13.0)
	city.add_child(camera)
	camera.look_at(Vector3(-12.0, 1.0, -62.0), Vector3.UP)
	camera.make_current()

	for _frame in range(40):
		await process_frame
	RenderingServer.force_draw(false)
	await process_frame
	var image := root.get_texture().get_image()
	if image.is_empty():
		push_error("Royal tent placement render is empty.")
		quit(1)
		return
	var output := ProjectSettings.globalize_path(OUTPUT_PATH)
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	if image.save_png(output) != OK:
		push_error("Could not save royal tent city placement preview.")
		quit(1)
		return
	print("Rendered production city + exact tent GLB at ", TENT_POSITION, " yaw ", TENT_YAW)
	print("Saved placement preview: ", OUTPUT_PATH)
	quit(0)
