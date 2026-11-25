extends Node3D
## Lightweight client-side representation of another authenticated player.
## Movement authority remains on the dedicated server; this node only interpolates snapshots.

const AVATAR_SCENE := preload("res://scenes/characters/avatar_visual.tscn")
const JET_SKI_SCENE := preload("res://scenes/jet_ski.tscn")
const JET_SKI_RIDER_OFFSET := Vector3(0.0, 0.88, 0.28)

var _avatar: Node3D
var _jet_ski: CharacterBody3D
var _target_position := Vector3.ZERO
var _target_rotation_y := 0.0
var _has_snapshot := false
var _motion_state := ""


func _ready() -> void:
	_avatar = AVATAR_SCENE.instantiate() as Node3D
	_avatar.name = "AvatarVisual"
	add_child(_avatar)


func apply_snapshot(server_position: Vector3, server_rotation_y: float, server_velocity: Vector3, active_emote: String = "", emote_remaining: float = 0.0, is_sitting: bool = false, is_jet_ski_riding: bool = false, jet_ski_position: Vector3 = Vector3.ZERO, jet_ski_rotation_y: float = 0.0) -> void:
	var display_position := jet_ski_position if is_jet_ski_riding else server_position
	var display_rotation := jet_ski_rotation_y if is_jet_ski_riding else server_rotation_y
	if not _has_snapshot:
		global_position = display_position
		rotation.y = display_rotation
		_has_snapshot = true
	_target_position = display_position
	_target_rotation_y = display_rotation
	if is_jet_ski_riding:
		if not is_instance_valid(_jet_ski):
			_jet_ski = JET_SKI_SCENE.instantiate() as CharacterBody3D
			if is_instance_valid(_jet_ski):
				_jet_ski.name = "RemoteRoyalJetSki"
				_jet_ski.set_physics_process(false)
				_jet_ski.set_process(false)
				add_child(_jet_ski)
		var jet_hud := _jet_ski.get_node_or_null("JetSkiHUDLayer") as CanvasLayer if is_instance_valid(_jet_ski) else null
		if is_instance_valid(jet_hud):
			jet_hud.visible = false
		var jet_camera := _jet_ski.get_node_or_null("CameraPivot/SpringArm3D/JetSkiCamera") as Camera3D if is_instance_valid(_jet_ski) else null
		if is_instance_valid(jet_camera):
			jet_camera.current = false
		if is_instance_valid(_avatar):
			_avatar.position = JET_SKI_RIDER_OFFSET
	else:
		if is_instance_valid(_jet_ski):
			_jet_ski.queue_free()
			_jet_ski = null
		if is_instance_valid(_avatar):
			_avatar.position = Vector3.ZERO
	var planar_speed := Vector2(server_velocity.x, server_velocity.z).length()
	var motion_state := "idle"
	if planar_speed > 4.2:
		motion_state = "run"
	elif planar_speed > 0.25:
		motion_state = "walk"
	var next_state := active_emote if ["clap", "dance", "cry", "wave", "heart"].has(active_emote) and emote_remaining > 0.0 else ("sit" if is_sitting else motion_state)
	if is_instance_valid(_avatar) and _avatar.has_method("set_motion_state") and next_state != _motion_state:
		_motion_state = next_state
		_avatar.call("set_motion_state", next_state, planar_speed)


func _process(delta: float) -> void:
	if not _has_snapshot:
		return
	var blend := 1.0 - exp(-14.0 * maxf(delta, 0.0))
	global_position = global_position.lerp(_target_position, blend)
	rotation.y = lerp_angle(rotation.y, _target_rotation_y, blend)
