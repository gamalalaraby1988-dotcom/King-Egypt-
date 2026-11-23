extends CharacterBody3D
## قيادة السيارة بنفس عصا حركة الشخصية: للأمام/الخلف والتوجيه، مع كاميرا بالسحب.
## الفرامل سياقية ويُتحكم بها من زر التفاعل أثناء الركوب.

@export var forward_speed: float = 18.0
@export var reverse_speed: float = 6.0
@export var acceleration: float = 10.0
@export var braking: float = 28.0
@export var steering_speed: float = 1.65
@export var gravity: float = 20.0
@export var max_step_height: float = 0.42

var move_input := Vector2.ZERO
var brake_pressed := false
var drive_pressed := false
var reverse_requested := false
var steering_input := 0.0

func _physics_process(delta: float) -> void:
	var longitudinal := clampf(-move_input.y, -1.0, 1.0)
	if drive_pressed and absf(longitudinal) < 0.05:
		longitudinal = -1.0 if reverse_requested else 1.0
	var target_speed := 0.0
	if not brake_pressed:
		target_speed = forward_speed * maxf(longitudinal, 0.0) - reverse_speed * maxf(-longitudinal, 0.0)
	var moving := Vector2(velocity.x, velocity.z).length()
	var rate := braking if brake_pressed or absf(longitudinal) < 0.05 else acceleration
	var forward := -global_transform.basis.z
	var desired := forward * target_speed
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	var steering := move_input.x if absf(move_input.x) > 0.04 else steering_input
	if absf(steering) > 0.04 and moving > 0.15 and not brake_pressed:
		var direction_sign := -1.0 if longitudinal < -0.05 else 1.0
		rotation.y -= steering * steering_speed * delta * direction_sign
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	_try_step_up(delta)
	move_and_slide()

func set_move_input(value: Vector2) -> void:
	move_input = value.limit_length(1.0)

func set_drive(value: bool) -> void:
	drive_pressed = value

func set_brake(value: bool) -> void:
	brake_pressed = value

func set_reverse(value: bool) -> void:
	reverse_requested = value

func set_steering(value: float) -> void:
	steering_input = clampf(value, -1.0, 1.0)

func clear_controls() -> void:
	move_input = Vector2.ZERO
	drive_pressed = false
	brake_pressed = false
	reverse_requested = false
	steering_input = 0.0

func _try_step_up(delta: float) -> void:
	if not is_on_floor() or Vector2(velocity.x, velocity.z).length() < 0.25:
		return
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * maxf(delta, 0.001)
	if not test_move(global_transform, horizontal_motion):
		return
	var raised := global_transform
	raised.origin.y += max_step_height
	if test_move(raised, horizontal_motion):
		return
	var landing := KinematicCollision3D.new()
	if not test_move(raised, horizontal_motion + Vector3.DOWN * (max_step_height + 0.16), landing):
		return
	if landing.get_normal(0).angle_to(Vector3.UP) > deg_to_rad(50.0):
		return
	global_position.y += max_step_height
