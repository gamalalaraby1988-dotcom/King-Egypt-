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
	if phone.visible:
		_fail("Phone should be hidden before phone-use mode starts.")
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
	if not is_equal_approx(head.rotation.x, -0.28):
		_fail("Head did not tilt toward the phone.")
		return

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
