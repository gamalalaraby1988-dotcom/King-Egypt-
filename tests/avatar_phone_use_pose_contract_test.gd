extends SceneTree

const AVATAR_SCRIPT := preload("res://scripts/avatar_visual.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var avatar: Node3D = AVATAR_SCRIPT.new()
	root.add_child(avatar)
	await process_frame

	var parts: Dictionary = avatar.get("parts")
	var right_arm: MeshInstance3D = parts.get("RightArm") as MeshInstance3D
	var head: MeshInstance3D = parts.get("Head") as MeshInstance3D
	var phone: Node3D = avatar.get("phone_visual") as Node3D
	if not is_instance_valid(right_arm) or not is_instance_valid(head) or not is_instance_valid(phone):
		_fail("Avatar phone, right arm, or head was not created.")
		return
	if phone.get_parent() != right_arm:
		_fail("Phone visual is not attached to the right arm.")
		return
	var phone_world_position := phone.global_position
	if absf(phone_world_position.x) > 0.04 or absf(phone_world_position.y - 1.43) > 0.05:
		_fail("Phone was not positioned at the in front of the lower face in the rendered avatar pose.")
		return
	if phone.visible:
		_fail("Phone should be hidden before phone-use mode starts.")
		return
	if phone.get_node_or_null("RightHandThumb") == null:
		_fail("Visible thumb was not added to the front edge of the phone.")
		return
	for finger_index in range(3):
		if phone.get_node_or_null("RightHandFinger_%d" % finger_index) == null:
			_fail("A gripping finger is missing from the phone hand.")
			return

	var default_arm_rotation: Vector3 = right_arm.rotation
	var default_head_rotation: Vector3 = head.rotation
	avatar.call("set_phone_using", true)
	await process_frame
	if not phone.visible:
		_fail("Phone did not become visible when phone-use mode started.")
		return
	if not is_equal_approx(right_arm.rotation.z, -0.78):
		_fail("Right arm did not enter the configured phone-use pose.")
		return
	if absf(phone.global_position.y - 1.43) > 0.05:
		_fail("Phone dropped below the lower face when phone-use mode started.")
		return
	var head_to_phone := (phone.global_position - head.global_position).normalized()
	var head_forward := -head.global_transform.basis.z.normalized()
	if head_forward.dot(head_to_phone) < 0.95:
		_fail("Head is not facing the phone during phone-use mode.")
		return
	var phone_screen := phone.get_node_or_null("PhoneScreen") as MeshInstance3D
	if not is_instance_valid(phone_screen):
		_fail("Phone screen mesh is missing.")
		return
	var phone_to_head := (head.global_position - phone.global_position).normalized()
	var screen_forward := phone_screen.global_transform.basis.z.normalized()
	if screen_forward.dot(phone_to_head) < 0.97:
		_fail("Phone screen is not facing the avatar face.")
		return

	# Verify that phone-use pose remains active during both walking and running.
	var left_leg: MeshInstance3D = parts.get("LeftLeg") as MeshInstance3D
	if not is_instance_valid(left_leg):
		_fail("Left leg was not created for movement animation.")
		return
	avatar.call("set_motion_state", "walk", 2.0)
	await create_timer(0.25).timeout
	if not phone.visible or not is_equal_approx(right_arm.rotation.z, -0.78):
		_fail("Phone or right-arm pose was lost while walking.")
		return
	if absf(phone.global_position.y - 1.43) > 0.05:
		_fail("Phone dropped below the lower face while walking.")
		return
	if is_zero_approx(left_leg.rotation.x):
		_fail("Left leg did not animate while walking with the phone.")
		return

	avatar.call("set_motion_state", "run", 4.0)
	await create_timer(0.25).timeout
	if not phone.visible or not is_equal_approx(right_arm.rotation.z, -0.78):
		_fail("Phone or right-arm pose was lost while running.")
		return
	if absf(phone.global_position.y - 1.43) > 0.05:
		_fail("Phone dropped below the lower face while running.")
		return
	if is_zero_approx(left_leg.rotation.x):
		_fail("Left leg did not animate while running with the phone.")
		return

	avatar.call("set_motion_state", "idle", 0.0)
	await process_frame
	avatar.call("set_phone_using", false)
	await process_frame
	if phone.visible:
		_fail("Phone remained visible after phone-use mode ended.")
		return
	if not right_arm.rotation.is_equal_approx(default_arm_rotation):
		_fail("Right arm pose was not restored after phone use.")
		return
	if not head.rotation.is_equal_approx(default_head_rotation):
		_fail("Head pose was not restored after phone use.")
		return

	print("Avatar phone-use pose contract test passed.")
	quit(0)

func _fail(message: String) -> void:
	push_error("Avatar phone-use pose contract test failed: " + message)
	quit(1)
