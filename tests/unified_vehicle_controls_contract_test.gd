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

	var cabin := vehicle.get_node_or_null("Cabin") as MeshInstance3D
	var cabin_material := cabin.material_override as BaseMaterial3D if is_instance_valid(cabin) else null
	if cabin_material == null or cabin_material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA:
		push_error("Vehicle cabin is not transparent enough to show the seated avatar.")
		vehicle.queue_free()
		quit(1)
		return

	var main_source := FileAccess.get_file_as_string("res://scripts/main.gd")
	if not main_source.contains("vehicle_exit_button") or not main_source.contains("_on_contextual_interaction_down") or not main_source.contains("_sync_vehicle_occupant_pose"):
		push_error("Main scene is missing the separate exit, contextual brake, or visible driver-seat binding.")
		vehicle.queue_free()
		quit(1)
		return

	var hud := vehicle.get_node_or_null("VehicleHUDLayer/VehicleHUD") as Control
	if hud == null or not hud.has_method("_update_layout") or not hud.has_method("_press") or not hud.has_method("_clear_controls"):
		push_error("Vehicle HUD is missing its current touch-control contract.")
		vehicle.queue_free()
		quit(1)
		return

	hud.call("_update_layout")
	var drive_rect: Rect2 = hud.get("drive_rect")
	var brake_rect: Rect2 = hud.get("brake_rect")
	if drive_rect.size == Vector2.ZERO or brake_rect.size == Vector2.ZERO:
		push_error("Vehicle drive or brake touch target has no layout.")
		vehicle.queue_free()
		quit(1)
		return

	# Exercise the current press-and-hold drive control, not the retired joystick API.
	hud.call("_press", 0, drive_rect.get_center())
	if int(hud.get("drive_touch")) != 0:
		push_error("Vehicle HUD failed to capture the drive touch.")
		vehicle.queue_free()
		quit(1)
		return
	hud.call("_process", 0.016)
	if not bool(vehicle.get("drive_pressed")):
		push_error("Vehicle controller did not receive the held drive input.")
		vehicle.queue_free()
		quit(1)
		return

	# Brake is an independent touch target and must reach the vehicle controller.
	hud.call("_press", 1, brake_rect.get_center())
	if int(hud.get("brake_touch")) != 1:
		push_error("Vehicle HUD failed to capture the independent brake touch.")
		vehicle.queue_free()
		quit(1)
		return
	hud.call("_process", 0.016)
	if not bool(vehicle.get("brake_pressed")):
		push_error("Vehicle controller did not receive the brake input.")
		vehicle.queue_free()
		quit(1)
		return

	# Clearing controls must release every held command.
	hud.call("_clear_controls")
	if int(hud.get("drive_touch")) != -1 or int(hud.get("brake_touch")) != -1:
		push_error("Vehicle HUD retained a touch after controls were cleared.")
		vehicle.queue_free()
		quit(1)
		return
	if bool(vehicle.get("drive_pressed")) or bool(vehicle.get("brake_pressed")) or bool(vehicle.get("reverse_requested")):
		push_error("Vehicle controller retained a movement or brake command after controls cleared.")
		vehicle.queue_free()
		quit(1)
		return

	vehicle.queue_free()
	print("Unified vehicle control contract tests passed.")
	quit(0)
