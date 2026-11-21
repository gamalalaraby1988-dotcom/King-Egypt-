extends Node3D
## Lightweight client-side representation of another authenticated player.
## Movement authority remains on the dedicated server; this node only interpolates snapshots.

const AVATAR_SCENE := preload("res://scenes/characters/avatar_visual.tscn")

var _avatar: Node3D
var _target_position := Vector3.ZERO
var _target_rotation_y := 0.0
var _has_snapshot := false


func _ready() -> void:
	_avatar = AVATAR_SCENE.instantiate() as Node3D
	_avatar.name = "AvatarVisual"
	add_child(_avatar)


func apply_snapshot(server_position: Vector3, server_rotation_y: float, server_velocity: Vector3) -> void:
	if not _has_snapshot:
		global_position = server_position
		rotation.y = server_rotation_y
		_has_snapshot = true
	_target_position = server_position
	_target_rotation_y = server_rotation_y
	var planar_speed := Vector2(server_velocity.x, server_velocity.z).length()
	var motion_state := "idle"
	if planar_speed > 4.2:
		motion_state = "run"
	elif planar_speed > 0.25:
		motion_state = "walk"
	if is_instance_valid(_avatar) and _avatar.has_method("set_motion_state"):
		_avatar.call("set_motion_state", motion_state, planar_speed)


func _process(delta: float) -> void:
	if not _has_snapshot:
		return
	var blend := 1.0 - exp(-14.0 * maxf(delta, 0.0))
	global_position = global_position.lerp(_target_position, blend)
	rotation.y = lerp_angle(rotation.y, _target_rotation_y, blend)
