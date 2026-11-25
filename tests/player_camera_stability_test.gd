extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var scene := load("res://scenes/player.tscn") as PackedScene
	if scene == null:
		push_error("Could not load player scene.")
		quit(1)
		return
	var player := scene.instantiate() as CharacterBody3D
	root.add_child(player)
	await process_frame
	var pivot := player.get_node("CameraPivot") as Node3D
	var initial_yaw := pivot.global_rotation.y
	player.call("_set_body_yaw_preserving_camera", 1.2)
	if not is_equal_approx(wrapf(pivot.global_rotation.y - initial_yaw, -PI, PI), 0.0):
		push_error("Camera world yaw changed when player body turned.")
		quit(1)
		return
	pivot.rotation.y -= 0.35
	var dragged_yaw := pivot.global_rotation.y
	player.call("_set_body_yaw_preserving_camera", -0.8)
	if not is_equal_approx(wrapf(pivot.global_rotation.y - dragged_yaw, -PI, PI), 0.0):
		push_error("Camera drag direction was not preserved after player turned.")
		quit(1)
		return
	print("Walking camera stability test passed.")
	quit(0)
