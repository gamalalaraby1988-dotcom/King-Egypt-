extends CharacterBody3D
## Lightweight offline resident used only for ambient city life.
## These residents are separate from the 16 playable presets and all service staff.

@export var citizen_id := ""
@export var gender := "male"
@export var city_sector := "north_west"
@export var walk_speed := 1.35
@export var roam_radius := 11.0

var _home := Vector3.ZERO
var _target := Vector3.ZERO
var _idle_remaining := 0.0
var _activity_remaining := 0.0
var _rng := RandomNumberGenerator.new()
var _avatar: Node3D
var _activity_active := false
var _gravity := 18.0

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.35
	add_to_group("offline_virtual_citizens")
	_home = global_position
	_rng.seed = abs(citizen_id.hash()) + 1
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.65
	shape.shape = capsule
	shape.position.y = 0.83
	add_child(shape)
	var packed := load("res://scenes/characters/avatar_visual.tscn") as PackedScene
	if packed != null:
		_avatar = packed.instantiate() as Node3D
		if is_instance_valid(_avatar):
			_avatar.name = "CitizenAvatar"
			_avatar.scale = Vector3.ONE * 0.92
			add_child(_avatar)
			if _avatar.has_method("apply_npc_identity"):
				_avatar.call("apply_npc_identity", citizen_id, gender)
	_pick_next_target()

func _physics_process(delta: float) -> void:
	if not is_inside_tree():
		return
	if _idle_remaining > 0.0:
		_idle_remaining = maxf(0.0, _idle_remaining - delta)
		velocity.x = move_toward(velocity.x, 0.0, 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 5.0 * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_update_avatar("idle", 0.0)
		return
	if _activity_remaining > 0.0:
		_activity_remaining = maxf(0.0, _activity_remaining - delta)
		velocity.x = move_toward(velocity.x, 0.0, 6.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 6.0 * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_update_avatar("sit", 0.0)
		if _activity_remaining <= 0.0:
			_activity_active = false
			_pick_next_target()
		return
	var offset := _target - global_position
	offset.y = 0.0
	if offset.length() <= 0.8:
		velocity.x = 0.0
		velocity.z = 0.0
		if _try_visit_activity_point():
			return
		_idle_remaining = _rng.randf_range(2.0, 6.0)
		_pick_next_target()
		return
	var direction := offset.normalized()
	velocity.x = move_toward(velocity.x, direction.x * walk_speed, 4.0 * delta)
	velocity.z = move_toward(velocity.z, direction.z * walk_speed, 4.0 * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = 0.0
	rotation.y = lerp_angle(rotation.y, atan2(-direction.x, -direction.z), 5.0 * delta)
	move_and_slide()
	if is_on_wall():
		_pick_next_target()
	_update_avatar("walk", Vector2(velocity.x, velocity.z).length())

func _try_visit_activity_point() -> bool:
	var points := get_tree().get_nodes_in_group("npc_interaction_points")
	if points.is_empty() or _rng.randf() > 0.22:
		return false
	var candidates: Array[Node3D] = []
	for item in points:
		if item is Node3D and is_instance_valid(item):
			var point := item as Node3D
			if global_position.distance_to(point.global_position) <= 24.0:
				candidates.append(point)
	if candidates.is_empty():
		return false
	var selected := candidates[_rng.randi_range(0, candidates.size() - 1)]
	_target = selected.global_position
	_activity_active = true
	_activity_remaining = _rng.randf_range(5.0, 11.0)
	return true

func _pick_next_target() -> void:
	var angle := _rng.randf_range(0.0, TAU)
	var distance := _rng.randf_range(3.0, roam_radius)
	_target = _home + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance)
	_target.x = clampf(_target.x, -82.0, 82.0)
	_target.z = clampf(_target.z, -82.0, 82.0)

func _update_avatar(state: String, speed: float) -> void:
	if is_instance_valid(_avatar) and _avatar.has_method("set_motion_state"):
		_avatar.call("set_motion_state", state, speed)
