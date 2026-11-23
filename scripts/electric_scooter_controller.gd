extends CharacterBody3D
## Electric standing kick-scooter controller. No seat; rider stands on the deck.
## Input is intentionally exposed through setters so the shared interaction/HUD
## layer can own mounting and dismounting without scooter-specific action buttons.

@export var max_speed: float = 9.0
@export var acceleration: float = 7.0
@export var braking: float = 14.0
@export var steering_speed: float = 1.45
@export var gravity: float = 20.0

var throttle_pressed := false
var brake_pressed := false
var steering_input := 0.0

func _physics_process(delta: float) -> void:
	var target_speed := max_speed if throttle_pressed and not brake_pressed else 0.0
	var rate := braking if brake_pressed or not throttle_pressed else acceleration
	var forward := -global_transform.basis.z
	var desired := forward * target_speed
	velocity.x = move_toward(velocity.x, desired.x, rate * delta)
	velocity.z = move_toward(velocity.z, desired.z, rate * delta)
	if throttle_pressed and not brake_pressed:
		rotation.y -= steering_input * steering_speed * delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	move_and_slide()

func set_throttle(value: bool) -> void:
	throttle_pressed = value

func set_brake(value: bool) -> void:
	brake_pressed = value

func set_steering(value: float) -> void:
	steering_input = clampf(value, -1.0, 1.0)

func clear_controls() -> void:
	throttle_pressed = false
	brake_pressed = false
	steering_input = 0.0
