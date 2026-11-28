extends SceneTree

func _initialize() -> void:
	call_deferred("_run_camera_input_tests")

func _run_camera_input_tests() -> void:
	var player_scene := load("res://scenes/player.tscn") as PackedScene
	var mobile_script := load("res://scripts/mobile_hud.gd") as Script
	if player_scene == null or mobile_script == null:
		push_error("Player scene or mobile HUD script could not be loaded.")
		quit(1)
		return

	var player := player_scene.instantiate() as CharacterBody3D
	root.add_child(player)
	var mobile_hud := Control.new()
	mobile_hud.set_script(mobile_script)
	mobile_hud.set("player", player)
	root.add_child(mobile_hud)
	await process_frame

	mobile_hud.call("_update_layout")
	var joystick_center: Vector2 = mobile_hud.get("joystick_center")
	var viewport_width := mobile_hud.get_viewport_rect().size.x

	# A touch that was holding the joystick must be cleared when seating begins.
	mobile_hud.call("_handle_touch_press", 0, joystick_center + Vector2(18.0, 0.0))
	if int(mobile_hud.get("joystick_finger")) != 0:
		push_error("Mobile joystick did not capture its left-side touch before seating.")
		quit(1)
		return
	player.call("set_arcade_seated", true)
	mobile_hud.call("_process", 0.0)
	if int(mobile_hud.get("joystick_finger")) != -1 or not (mobile_hud.get("joystick_vector") as Vector2).is_zero_approx():
		push_error("Held joystick input was not cleared when arcade seating began.")
		quit(1)
		return

	# Left-side touches remain reserved for the joystick and must not rotate the seated camera.
	var left_touch := InputEventScreenTouch.new()
	left_touch.index = 1
	left_touch.pressed = true
	left_touch.position = joystick_center
	player.call("_unhandled_input", left_touch)
	mobile_hud.call("_unhandled_input", left_touch)
	if int(player.get("_arcade_touch_index")) != -1:
		push_error("Arcade camera incorrectly captured a left-side joystick touch.")
		quit(1)
		return

	# A right-side touch is captured by the seated player only, never by both camera handlers.
	var right_touch := InputEventScreenTouch.new()
	right_touch.index = 2
	right_touch.pressed = true
	right_touch.position = Vector2(viewport_width * 0.8, 240.0)
	player.call("_unhandled_input", right_touch)
	mobile_hud.call("_unhandled_input", right_touch)
	if int(player.get("_arcade_touch_index")) != 2 or int(mobile_hud.get("camera_finger")) != -1:
		push_error("Arcade camera touch ownership was not exclusive to the seated player.")
		quit(1)
		return

	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = right_touch.position + Vector2(100.0, 0.0)
	drag.relative = Vector2(100.0, 0.0)
	player.call("_unhandled_input", drag)
	mobile_hud.call("_unhandled_input", drag)
	var pivot := player.get_node("CameraPivot") as Node3D
	if not is_equal_approx(pivot.rotation.y, -0.6):
		push_error("Arcade camera drag was applied more than once or used the wrong sensitivity: %s" % pivot.rotation.y)
		quit(1)
		return

	var release := InputEventScreenTouch.new()
	release.index = 2
	release.pressed = false
	release.position = right_touch.position
	player.call("_unhandled_input", release)
	mobile_hud.call("_unhandled_input", release)

	# Vehicle orbit camera follows the horizontal direction of the finger drag.
	var vehicle_scene := load("res://scenes/vehicle.tscn") as PackedScene
	if vehicle_scene == null:
		push_error("Vehicle scene could not be loaded for camera drag test.")
		quit(1)
		return
	var vehicle := vehicle_scene.instantiate() as CharacterBody3D
	root.add_child(vehicle)
	mobile_hud.call("set_controlled_vehicle", vehicle)
	var vehicle_pivot := vehicle.get_node("VehicleCameraPivot") as Node3D
	vehicle_pivot.rotation.y = 0.0
	mobile_hud.call("_apply_camera_drag", Vector2(100.0, 0.0))
	if vehicle_pivot.rotation.y >= 0.0:
		push_error("Vehicle camera drag must match the player's right-drag rotation direction.")
		quit(1)
		return
	vehicle_pivot.rotation.y = 0.0
	mobile_hud.call("_apply_camera_drag", Vector2(-100.0, 0.0))
	if vehicle_pivot.rotation.y <= 0.0:
		push_error("Vehicle camera left-drag must match the player's left-drag rotation direction.")
		quit(1)
		return
	vehicle_pivot.rotation.x = 0.0
	mobile_hud.call("_apply_camera_drag", Vector2(0.0, 100.0))
	if vehicle_pivot.rotation.x >= 0.0:
		push_error("Vehicle camera vertical drag must match the player's vertical camera response.")
		quit(1)
		return

	mobile_hud.call("set_controlled_vehicle", null)
	vehicle.queue_free()
	mobile_hud.queue_free()
	player.queue_free()
	print("Arcade mobile camera ownership tests passed.")
	quit(0)
