extends SceneTree

const MODEL_PATH := "res://assets/review/main_royal_tent.glb"
const OUTPUT_PATH := "res://artifacts/main-royal-tent-build/main_royal_tent_preview.png"

func _initialize() -> void:
    call_deferred("_render")

func _render() -> void:
    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("Could not load main royal tent GLB: " + MODEL_PATH)
        quit(1)
        return

    root.size = Vector2i(1600, 900)
    var stage := Node3D.new()
    stage.name = "ExactMainRoyalTentGLBReview"
    root.add_child(stage)
    current_scene = stage
    var model := packed.instantiate()
    model.name = "ExactMainRoyalTentGLB"
    stage.add_child(model)

    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.035, 0.045, 0.075)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.82, 0.82, 0.88)
    env.ambient_light_energy = 1.0
    environment.environment = env
    stage.add_child(environment)

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
    key.light_energy = 2.2
    stage.add_child(key)
    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
    fill.light_energy = 0.85
    stage.add_child(fill)

    var camera := Camera3D.new()
    camera.fov = 42.0
    camera.position = Vector3(21.0, 15.0, 27.0)
    stage.add_child(camera)
    camera.look_at(Vector3(0.0, 5.0, 0.0), Vector3.UP)
    camera.make_current()

    for _frame in range(28):
        await process_frame
    RenderingServer.force_draw(false)
    await process_frame
    var image := root.get_texture().get_image()
    if image.is_empty():
        push_error("Main royal tent preview is empty.")
        quit(1)
        return
    var output := ProjectSettings.globalize_path(OUTPUT_PATH)
    DirAccess.make_dir_recursive_absolute(output.get_base_dir())
    var error := image.save_png(output)
    if error != OK:
        push_error("Could not save main royal tent preview.")
        quit(1)
        return
    print("Rendered exact model: ", MODEL_PATH)
    print("Saved preview: ", OUTPUT_PATH)
    quit(0)
