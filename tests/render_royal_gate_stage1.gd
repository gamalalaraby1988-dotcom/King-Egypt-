extends SceneTree

const MODEL_PATH := "res://assets/review/royal_gate_stage1.glb"
const OUTPUT_PATH := "res://artifacts/royal-gate-build/royal_gate_stage1_preview.png"

func _initialize() -> void:
    call_deferred("_render")

func _render() -> void:
    var packed := load(MODEL_PATH) as PackedScene
    if packed == null:
        push_error("Could not load the stage 1 GLB: " + MODEL_PATH)
        quit(1)
        return

    root.size = Vector2i(1600, 900)
    var stage := Node3D.new()
    stage.name = "ExactRoyalGateStage1Review"
    root.add_child(stage)
    current_scene = stage

    var model := packed.instantiate()
    model.name = "ExactStage1GLB"
    stage.add_child(model)

    var environment := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.045, 0.06, 0.09)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.78, 0.78, 0.82)
    env.ambient_light_energy = 0.9
    environment.environment = env
    stage.add_child(environment)

    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-38.0, -28.0, 0.0)
    key.light_energy = 2.0
    stage.add_child(key)

    var fill := DirectionalLight3D.new()
    fill.rotation_degrees = Vector3(-18.0, 145.0, 0.0)
    fill.light_energy = 0.75
    stage.add_child(fill)

    var camera := Camera3D.new()
    camera.fov = 38.0
    camera.position = Vector3(21.0, 15.0, 31.0)
    stage.add_child(camera)
    camera.look_at(Vector3(0.0, 7.0, 0.0), Vector3.UP)
    camera.make_current()

    for _frame in range(24):
        await process_frame
    RenderingServer.force_draw(false)
    await process_frame

    var image := root.get_texture().get_image()
    if image.is_empty():
        push_error("The stage 1 GLB preview is empty.")
        quit(1)
        return
    var output := ProjectSettings.globalize_path(OUTPUT_PATH)
    DirAccess.make_dir_recursive_absolute(output.get_base_dir())
    var error := image.save_png(output)
    if error != OK:
        push_error("Could not save stage 1 GLB preview.")
        quit(1)
        return
    print("Rendered exact model: ", MODEL_PATH)
    print("Saved preview: ", OUTPUT_PATH)
    quit(0)
