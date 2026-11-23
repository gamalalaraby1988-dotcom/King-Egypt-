extends CharacterBody3D
## Independent personal-watercraft controller. It deliberately does not reuse car ground physics.

@export var max_forward_speed: float = 15.5
@export var acceleration: float = 5.2
@export var braking_deceleration: float = 8.5
@export var water_resistance: float = 1.15
@export var lateral_water_resistance: float = 4.8
@export var max_yaw_rate: float = 1.25
@export var minimum_steering_authority: float = 0.12
@export var waterline_height: float = 0.34
@export var bob_amplitude: float = 0.045
@export var bob_frequency: float = 1.7
@export var visual_roll_degrees: float = 9.0

var drive_pressed := false
var brake_pressed := false
var steering_input := 0.0
var camera_drag_input := 0.0
var _planar_velocity := Vector3.ZERO
var _water_time := 0.0

@onready var visual_root: Node3D = $VisualRoot
@onready var camera_pivot: Node3D = $CameraPivot


static func steering_authority(speed: float, max_speed: float, minimum: float = 0.12) -> float:
	if max_speed <= 0.0:
		return 0.0
	return lerpf(clampf(minimum, 0.0, 1.0), 1.0, clampf(absf(speed) / max_speed, 0.0, 1.0))


static func apply_water_resistance(speed: float, resistance: float, delta: float) -> float:
	return move_toward(speed, 0.0, maxf(0.0, resistance) * maxf(0.0, delta))


func _physics_process(delta: float) -> void:
	var safe_delta := clampf(delta, 0.0, 0.05)
	if safe_delta <= 0.0:
		return
	_water_time += safe_delta

	var forward := -global_transform.basis.z
	var right := global_transform.basis.x
	var forward_speed := _planar_velocity.dot(forward)

	if brake_pressed:
		_planar_velocity = _planar_velocity.move_toward(Vector3.ZERO, braking_deceleration * safe_delta)
	elif drive_pressed:
		_planar_velocity += forward * acceleration * safe_delta

	# Hydrodynamic resistance slows the craft naturally after releasing throttle.
	var speed_before_drag := _planar_velocity.length()
	if speed_before_drag > 0.0:
		_planar_velocity = _planar_velocity.move_toward(Vector3.ZERO, water_resistance * safe_delta)

	# Water strongly damps sideways slip without using car tire friction.
	var lateral_speed := _planar_velocity.dot(right)
	_planar_velocity -= right * lateral_speed * minf(1.0, lateral_water_resistance * safe_delta)

	forward_speed = _planar_velocity.dot(forward)
	if absf(forward_speed) > max_forward_speed:
		_planar_velocity -= forward * (forward_speed - signf(forward_speed) * max_forward_speed)

	if absf(forward_speed) > 0.35 and absf(steering_input) > 0.01:
		var authority := steering_authority(forward_speed, max_forward_speed, minimum_steering_authority)
		var reverse_sign := -1.0 if forward_speed < 0.0 else 1.0
		rotation.y -= steering_input * max_yaw_rate * authority * reverse_sign * safe_delta

	global_position += _planar_velocity * safe_delta
	var bob := sin(_water_time * TAU * bob_frequency) * bob_amplitude
	global_position.y = lerpf(global_position.y, waterline_height + bob, minf(1.0, safe_delta * 5.0))
	velocity = Vector3(_planar_velocity.x, 0.0, _planar_velocity.z)

	if is_instance_valid(visual_root):
		var speed_ratio := clampf(_planar_velocity.length() / max_forward_speed, 0.0, 1.0)
		visual_root.rotation.z = lerpf(visual_root.rotation.z, -deg_to_rad(visual_roll_degrees) * steering_input * speed_ratio, minf(1.0, safe_delta * 4.0))

	if is_instance_valid(camera_pivot) and absf(camera_drag_input) > 0.0:
		camera_pivot.rotation.y -= camera_drag_input
		camera_drag_input = 0.0


func reconcile_authoritative_state(server_position: Vector3, server_rotation_y: float, server_velocity: Vector3) -> void:
	if not is_finite(server_position.x) or not is_finite(server_position.y) or not is_finite(server_position.z):
		return
	if not is_finite(server_rotation_y) or not is_finite(server_velocity.x) or not is_finite(server_velocity.y) or not is_finite(server_velocity.z):
		return
	# Keep local input prediction responsive, but continuously pull drift toward the server.
	global_position = global_position.lerp(server_position, 0.35)
	rotation.y = lerp_angle(rotation.y, server_rotation_y, 0.4)
	_planar_velocity = _planar_velocity.lerp(Vector3(server_velocity.x, 0.0, server_velocity.z), 0.3)
	velocity = _planar_velocity


func set_drive(value: bool) -> void:
	drive_pressed = value


func set_brake(value: bool) -> void:
	brake_pressed = value


func set_steering(value: float) -> void:
	steering_input = clampf(value, -1.0, 1.0)


func set_camera_drag(value: float) -> void:
	camera_drag_input = clampf(value, -0.35, 0.35)


func clear_controls() -> void:
	drive_pressed = false
	brake_pressed = false
	steering_input = 0.0
	camera_drag_input = 0.0


func get_planar_speed() -> float:
	return _planar_velocity.length()
