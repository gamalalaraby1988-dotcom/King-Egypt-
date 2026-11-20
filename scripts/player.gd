extends CharacterBody3D
## حركة خفيفة: مشي وجري وجلوس، مع دعم تحكم اللمس والكاميرا.

@export var walk_speed: float = 4.0
@export var run_speed: float = 6.2
@export var acceleration: float = 18.0
@export var gravity: float = 20.0
@export var max_step_height: float = 0.38
@export var step_forward_probe: float = 0.32
@export var turn_speed: float = 10.0

var mobile_move: Vector2 = Vector2.ZERO
var mobile_sprint: bool = false
var sitting := false
var arcade_seated := false
var _sit_key_was_down := false
var animal_riding := false
var ride_visual: Node3D = null
@onready var camera_pivot: Node3D = $CameraPivot

func _ready() -> void:
	add_to_group("player")
	if not AuthoritativeGameServer.authoritative_state_received.is_connected(_apply_authoritative_state):
		AuthoritativeGameServer.authoritative_state_received.connect(_apply_authoritative_state)
	if FounderIdentityManager.is_founder:
		set_meta("founder_profile", FounderIdentityManager.get_founder_profile())
		var avatar := get_node_or_null("AvatarVisual")
		if is_instance_valid(avatar) and avatar.has_method("apply_founder_style"):
			avatar.call("apply_founder_style")

func _physics_process(delta: float) -> void:
	if arcade_seated:
		velocity = Vector3.ZERO
		mobile_move = Vector2.ZERO
		mobile_sprint = false
		sitting = true
		_update_avatar_animation("sit", 0.0)
		return
	if GameModeManager.is_online_ready():
		_process_online_input()
		return
	var sit_key_down := Input.is_key_pressed(KEY_C)
	if sit_key_down and not _sit_key_was_down:
		toggle_sit()
	_sit_key_was_down = sit_key_down
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mobile_move.length() > 0.08:
		input_vector = mobile_move
	# أي إدخال حركة ينهي الجلوس فورًا، سواء من لوحة المفاتيح أو عصا الهاتف.
	if sitting and input_vector.length() > 0.08:
		sitting = false
	if sitting:
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if not is_on_floor():
			velocity.y -= gravity * delta
		else:
			velocity.y = 0.0
		move_and_slide()
		_update_avatar_animation("sit", 0.0)
		return
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if direction.length() > 1.0:
		direction = direction.normalized()

	var basis := camera_pivot.global_transform.basis
	var forward := -basis.z
	var right := basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var world_direction := (right * direction.x + forward * -direction.z).normalized()
	var running := Input.is_action_pressed("sprint") or mobile_sprint
	var target_speed := (8.0 if running else 6.0) if animal_riding else (run_speed if running else walk_speed)
	var target_velocity := world_direction * target_speed
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if world_direction.length() > 0.1:
		var target_angle := atan2(world_direction.x, world_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
	_try_step_up(delta)
	move_and_slide()
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var motion_state := "idle"
	if planar_speed > 0.25:
		motion_state = "run" if running else "walk"
	_update_avatar_animation(motion_state, planar_speed)

func _process_online_input() -> void:
	if not AuthoritativeGameServer.is_authenticated():
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mobile_move.length() > 0.08:
		input_vector = mobile_move
	if sitting:
		input_vector = Vector2.ZERO
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var basis := camera_pivot.global_transform.basis
	var forward := -basis.z
	var right := basis.x
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()
	var world_direction := (right * direction.x + forward * -direction.z).normalized()
	var running := Input.is_action_pressed("sprint") or mobile_sprint
	AuthoritativeGameServer.send_movement_input(world_direction, running)


func _apply_authoritative_state(server_position: Vector3, server_rotation_y: float, server_velocity: Vector3) -> void:
	if not GameModeManager.is_online_ready():
		return
	global_position = server_position
	rotation.y = server_rotation_y
	velocity = server_velocity
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	_update_avatar_animation("run" if planar_speed > 4.2 else "walk" if planar_speed > 0.25 else ("sit" if sitting else "idle"), planar_speed)


func is_riding_animal() -> bool:
	return animal_riding

func start_animal_ride(animal_name: String) -> bool:
	# لا تبدأ ركوبًا ثانيًا فوق الركوب الحالي؛ يجب النزول أولًا.
	if animal_riding or animal_name.strip_edges().is_empty():
		return false
	sitting = false
	animal_riding = true
	var avatar := get_node_or_null("AvatarVisual") as Node3D
	if avatar:
		avatar.position.y = 1.05
		if avatar.has_method("set_motion_state"):
			avatar.set_motion_state("sit", 0.0)
	ride_visual = Node3D.new()
	ride_visual.name = "TemporaryRideAnimal"
	add_child(ride_visual)
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.48
	body_mesh.height = 1.9
	body.mesh = body_mesh
	body.rotation.z = PI / 2.0
	body.position = Vector3(0, 0.25, 0.18)
	var fur := StandardMaterial3D.new()
	fur.albedo_color = Color(0.54, 0.34, 0.20)
	body.material_override = fur
	ride_visual.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.34
	head_mesh.height = 0.68
	head.mesh = head_mesh
	head.position = Vector3(0, 0.58, -0.68)
	head.material_override = fur
	ride_visual.add_child(head)
	var label := Label3D.new()
	label.text = animal_name
	label.position = Vector3(0, 1.45, 0)
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	ride_visual.add_child(label)
	return true

func end_animal_ride() -> void:
	animal_riding = false
	if is_instance_valid(ride_visual):
		ride_visual.queue_free()
	ride_visual = null
	var avatar := get_node_or_null("AvatarVisual") as Node3D
	if avatar:
		avatar.position.y = 0.0
		if avatar.has_method("set_motion_state"):
			avatar.set_motion_state("idle", 0.0)

func sit_at_position(world_position: Vector3, facing_y: float = 0.0) -> bool:
	if animal_riding:
		return false
	global_position = world_position
	rotation.y = facing_y
	velocity = Vector3.ZERO
	mobile_move = Vector2.ZERO
	mobile_sprint = false
	sitting = true
	return true

func set_arcade_seated(enabled: bool) -> void:
	if animal_riding and enabled:
		return
	arcade_seated = enabled
	if enabled:
		mobile_move = Vector2.ZERO
		mobile_sprint = false
		sitting = true
		velocity = Vector3.ZERO

func end_arcade_seat(world_position: Vector3, facing_y: float = 0.0) -> void:
	arcade_seated = false
	sitting = false
	global_position = world_position
	rotation.y = facing_y
	velocity = Vector3.ZERO
	mobile_move = Vector2.ZERO
	mobile_sprint = false

func toggle_sit() -> void:
	# الجلوس غير متاح أثناء ركوب الحيوان حتى لا تتعارض حالتا الحركة.
	if animal_riding:
		return
	sitting = not sitting
	if sitting:
		mobile_move = Vector2.ZERO
		mobile_sprint = false

func _update_avatar_animation(state: String, speed: float) -> void:
	var avatar := get_node_or_null("AvatarVisual")
	if avatar != null and avatar.has_method("set_motion_state"):
		avatar.set_motion_state(state, speed)

func set_mobile_move(value: Vector2) -> void:
	mobile_move = value

func set_mobile_sprint(value: bool) -> void:
	mobile_sprint = value


func _try_step_up(delta: float) -> void:
	# Small grounded step assist for sidewalks and low curbs; never climbs tall walls.
	if not is_on_floor() or Vector2(velocity.x, velocity.z).length() < 0.15:
		return
	var horizontal_motion := Vector3(velocity.x, 0.0, velocity.z) * maxf(delta, 0.001)
	if not test_move(global_transform, horizontal_motion):
		return
	var raised := global_transform
	raised.origin.y += max_step_height
	if test_move(raised, horizontal_motion):
		return
	var landing := KinematicCollision3D.new()
	var landing_motion := horizontal_motion + Vector3.DOWN * (max_step_height + 0.12)
	if not test_move(raised, landing_motion, landing):
		return
	if landing.get_normal(0).angle_to(Vector3.UP) > deg_to_rad(50.0):
		return
	global_position.y += max_step_height
