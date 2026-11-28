extends SceneTree

func _initialize() -> void:
	call_deferred("_run_vehicle_control_contract")

func _run_vehicle_control_contract() -> void:
	var vehicle_scene := load("res://scenes/vehicle.tscn") as PackedScene
	var controller_script := load("res://scripts/vehicle_controller.gd") as Script
	var mobile_hud_script := load("res://scripts/mobile_hud.gd") as Script
	if vehicle_scene == null or controller_script == null or mobile_hud_script == null:
		push_error("Vehicle or shared mobile joystick resources failed to load.")
		quit(1)
		return

	var vehicle := vehicle_scene.instantiate() as CharacterBody3D
	root.add_child(vehicle)
	var hud := Control.new()
	hud.set_script(mobile_hud_script)
	root.add_child(hud)
	hud.set("player", null)
	hud.call("set_controlled_vehicle", vehicle)
	hud.set("visible", true)

	# Push the shared joystick forward and steer right.
	hud.set("joystick_vector", Vector2(0.55, -1.0))
	hud.call("_process", 0.016)
	if not bool(vehicle.get("drive_pressed")):
		push_error("Shared joystick did not drive the vehicle forward.")
		quit(1)
		return
	if bool(vehicle.get("reverse_requested")):
		push_error("Forward joystick input incorrectly selected reverse.")
		quit(1)
		return
	if absf(float(vehicle.get("steering_input")) - 0.55) > 0.01:
		push_error("Shared joystick horizontal input did not steer the vehicle.")
		quit(1)
		return

	# Pull the same joystick down to reverse.
	hud.set("joystick_vector", Vector2(-0.35, 0.8))
	hud.call("_process", 0.016)
	if not bool(vehicle.get("drive_pressed")) or not bool(vehicle.get("reverse_requested")):
		push_error("Shared joystick did not select reverse while pulled down.")
		quit(1)
		return

	# Releasing the joystick must stop and clear steering/reverse.
	hud.set("joystick_vector", Vector2.ZERO)
	hud.call("_process", 0.016)
	if bool(vehicle.get("drive_pressed")) or bool(vehicle.get("reverse_requested")):
		push_error("Vehicle kept moving after the shared joystick was released.")
		quit(1)
		return
	if absf(float(vehicle.get("steering_input"))) > 0.01:
		push_error("Vehicle steering remained active after joystick release.")
		quit(1)
		return

	# The same circular interaction button becomes a hold-to-brake control in a vehicle.
	var interaction_button := hud.get_node_or_null("PlayerInteractionButton") as Button
	if interaction_button == null or interaction_button.text != "🛑":
		push_error("The interaction button did not change into the vehicle brake.")
		quit(1)
		return
	hud.call("_on_interaction_button_down")
	hud.call("_process", 0.016)
	if not bool(vehicle.get("brake_pressed")):
		push_error("Holding the contextual interaction button did not keep the vehicle brake applied.")
		quit(1)
		return
	hud.call("_on_interaction_button_up")
	hud.call("_process", 0.016)
	if bool(vehicle.get("brake_pressed")):
		push_error("Releasing the contextual interaction button did not release the vehicle brake.")
		quit(1)
		return

	# Losing focus while the brake is held must release it and clear every vehicle command.
	hud.call("_on_interaction_button_down")
	hud.call("_clear_touch_state")
	if bool(vehicle.get("brake_pressed")) or bool(vehicle.get("drive_pressed")) or bool(vehicle.get("reverse_requested")):
		push_error("Losing mobile HUD focus left a vehicle control latched.")
		quit(1)
		return
	hud.call("set_controlled_vehicle", null)
	if interaction_button.text != "✋":
		push_error("The contextual button did not return to the hand interaction state after exiting.")
		quit(1)
		return

	hud.call("_clear_touch_state")
	if bool(vehicle.get("drive_pressed")) or bool(vehicle.get("brake_pressed")):
		push_error("Vehicle controls were not cleared with the mobile HUD.")
		quit(1)
		return

	hud.queue_free()
	vehicle.queue_free()
	print("Shared mobile joystick vehicle control contract tests passed.")
	quit(0)
