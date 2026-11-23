extends SceneTree

func _initialize() -> void:
	call_deferred("_run_vehicle_control_contract")

func _run_vehicle_control_contract() -> void:
	var vehicle_scene := load("res://scenes/vehicle.tscn") as PackedScene
	var controller_script := load("res://scripts/vehicle_controller.gd") as Script
	var hud_script := load("res://scripts/vehicle_hud.gd") as Script
	if vehicle_scene == null or controller_script == null or hud_script == null:
		push_error("Unified vehicle control resources failed to load.")
		quit(1)
		return

	var vehicle := vehicle_scene.instantiate() as CharacterBody3D
	root.add_child(vehicle)
	await process_frame
	var hud := vehicle.get_node_or_null("VehicleHUDLayer/VehicleHUD") as Control
	if hud == null or not hud.has_method("_update_layout"):
		push_error("Vehicle HUD does not expose the shared joystick layout.")
		quit(1)
		return
	hud.call("_update_layout")
	var joystick_center: Vector2 = hud.get("joystick_center")
	var radius := float(hud.get("joystick_draw_radius"))
	hud.call("_handle_touch_press", 0, joystick_center + Vector2(0.0, -radius))
	if int(hud.get("joystick_finger")) != 0:
		push_error("Vehicle HUD failed to capture the same left-side movement joystick.")
		quit(1)
		return
	var input_value: Vector2 = hud.get("joystick_vector")
	if input_value.y > -0.95:
		push_error("Forward joystick input was not preserved for vehicle movement.")
		quit(1)
		return
	vehicle.call("set_move_input", input_value)
	if (vehicle.get("move_input") as Vector2).y > -0.95:
		push_error("Vehicle controller did not receive the shared movement vector.")
		quit(1)
		return

	vehicle.call("set_brake", true)
	if not bool(vehicle.get("brake_pressed")):
		push_error("Contextual brake state did not activate.")
		quit(1)
		return
	vehicle.call("set_brake", false)
	if bool(vehicle.get("brake_pressed")):
		push_error("Contextual brake state did not release.")
		quit(1)
		return

	hud.call("_clear_controls")
	if not (vehicle.get("move_input") as Vector2).is_zero_approx():
		push_error("Vehicle movement input remained stuck after controls cleared.")
		quit(1)
		return

	vehicle.queue_free()
	print("Unified vehicle control contract tests passed.")
	quit(0)
