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
var auto_navigation_speed := -1.0
var auto_navigation_interrupted := false

func _ready() -> void:
	# يحافظ على تماس المركبة مع سطح الطريق عند صعود المنحدرات والهبوط منها.
	floor_snap_length = 0.8
	floor_max_angle = deg_to_rad(38.0)
	floor_constant_speed = true

func _physics_process(delta: float) -> void:
	var target_speed := 0.0
	# الفرامل لها الأولوية دائمًا، حتى إذا ظل زر القيادة مضغوطًا.
	if brake_pressed:
		target_speed = 0.0
	elif drive_pressed:
		target_speed = -reverse_speed if reverse_requested else forward_speed
	if auto_navigation_speed >= 0.0:
		target_speed = auto_navigation_speed

	var rate := braking if brake_pressed or not drive_pressed or (auto_navigation_speed >= 0.0 and auto_navigation_speed <= 0.05) else acceleration
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

func set_auto_navigation_controls(speed: float, steering: float) -> void:
	auto_navigation_interrupted = false
	auto_navigation_speed = clampf(speed, 0.0, 6.0)
	drive_pressed = auto_navigation_speed > 0.05
	brake_pressed = auto_navigation_speed <= 0.05
	reverse_requested = false
	steering_input = clampf(steering, -1.0, 1.0)


func clear_auto_navigation_controls() -> void:
	auto_navigation_speed = -1.0
	drive_pressed = false
	brake_pressed = true
	reverse_requested = false
	steering_input = 0.0
	auto_navigation_interrupted = false


func set_drive(value: bool) -> void:
	if auto_navigation_speed >= 0.0:
		auto_navigation_interrupted = true
		auto_navigation_speed = -1.0
	drive_pressed = value
	if not value:
		reverse_requested = false
		steering_input = 0.0

func set_brake(value: bool) -> void:
	if auto_navigation_speed >= 0.0:
		auto_navigation_interrupted = true
		auto_navigation_speed = -1.0
	brake_pressed = value
	if value:
		reverse_requested = false

func set_reverse(value: bool) -> void:
	if auto_navigation_speed >= 0.0:
		auto_navigation_interrupted = true
		auto_navigation_speed = -1.0
	reverse_requested = value

func set_steering(value: float) -> void:
	if auto_navigation_speed >= 0.0:
		auto_navigation_interrupted = true
		auto_navigation_speed = -1.0
	steering_input = clampf(value, -1.0, 1.0)
