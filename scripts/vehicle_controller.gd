extends CharacterBody3D
## تحكم أولي بمركبة: ضغط مستمر للقيادة، سحب لأسفل للرجوع، وفرامل مستقلة.
## لا يعتمد نظام القيادة على مارة أو سيارات مرور؛ تحكم المركبة مستقل.

@export var forward_speed: float = 18.0
@export var reverse_speed: float = 7.0
@export var acceleration: float = 10.0
@export var braking: float = 28.0
@export var steering_speed: float = 1.8
@export var gravity: float = 20.0

var drive_pressed := false
var brake_pressed := false
var reverse_requested := false
var steering_input := 0.0

func _physics_process(delta: float) -> void:
	var target_speed := 0.0
	# الفرامل لها الأولوية دائمًا، حتى إذا ظل زر القيادة مضغوطًا.
	if brake_pressed:
		target_speed = 0.0
	elif drive_pressed:
		target_speed = -reverse_speed if reverse_requested else forward_speed

	var rate := braking if brake_pressed or not drive_pressed else acceleration
	# السرعة المحلية للأمام هي المحور -Z.
	var local_forward := -global_transform.basis.z
	var desired := local_forward * target_speed
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)

	if abs(steering_input) > 0.01 and drive_pressed and not brake_pressed:
		rotation.y -= steering_input * steering_speed * delta

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func set_drive(value: bool) -> void:
	drive_pressed = value
	if not value:
		reverse_requested = false
		steering_input = 0.0

func set_brake(value: bool) -> void:
	brake_pressed = value
	if value:
		reverse_requested = false

func set_reverse(value: bool) -> void:
	reverse_requested = value

func set_steering(value: float) -> void:
	steering_input = clampf(value, -1.0, 1.0)
