extends CharacterBody3D
## حركة خفيفة: مشي وجري وجلوس، مع دعم تحكم اللمس والكاميرا.

@export var walk_speed: float = 4.0
@export var run_speed: float = 6.2
@export var acceleration: float = 18.0
@export var gravity: float = 20.0
@export var max_step_height: float = 0.38
@export var step_forward_probe: float = 0.32
@export var turn_speed: float = 14.0

var mobile_move: Vector2 = Vector2.ZERO
var mobile_sprint: bool = false
var mounted_scooter: CharacterBody3D = null
var sitting := false
var _active_emote := ""
var _emote_remaining := 0.0
var arcade_seated := false
var _sit_key_was_down := false
var _arcade_touch_index: int = -1
var _arcade_mouse_dragging := false
var _arcade_camera_default_rotation: Vector3 = Vector3.ZERO
const ARCADE_CAMERA_DRAG_SENSITIVITY: float = 0.006
const ARCADE_CAMERA_PITCH_MIN: float = -0.72
const ARCADE_CAMERA_PITCH_MAX: float = 0.24
const ARCADE_CAMERA_YAW_LIMIT: float = 1.15
var animal_riding := false
var phone_using := false
var ride_visual: Node3D = null
@onready var camera_pivot: Node3D = $CameraPivot

func _ready() -> void:
	_arcade_camera_default_rotation = camera_pivot.rotation
	add_to_group("player")
	if not AuthoritativeGameServer.authoritative_state_received.is_connected(_apply_authoritative_state):
		AuthoritativeGameServer.authoritative_state_received.connect(_apply_authoritative_state)
	if FounderIdentityManager.is_founder:
		set_meta("founder_profile", FounderIdentityManager.get_founder_profile())
		var avatar := get_node_or_null("AvatarVisual")
		if is_instance_valid(avatar) and avatar.has_method("apply_founder_style"):
			avatar.call("apply_founder_style")

func _process(delta: float) -> void:
	if _emote_remaining <= 0.0:
		return
	_emote_remaining = maxf(0.0, _emote_remaining - delta)
	if _emote_remaining == 0.0:
		_active_emote = ""


func play_emote(emote_id: String) -> bool:
	# يرسل التعبير إلى الخادم عند اللعب عبر الإنترنت.
	if sitting or arcade_seated or animal_riding:
		return false
	var durations := {
		"clap": 2.4,
		"dance": 4.0,
		"cry": 3.0,
		"wave": 2.2,
		"heart": 2.6
	}
	if not durations.has(emote_id):
		return false
	_active_emote = emote_id
	_emote_remaining = float(durations[emote_id])
	_update_avatar_animation(_active_emote, 0.0)
	if GameModeManager.is_online_ready():
		AuthoritativeGameServer.send_player_emote(emote_id)
	return true


func _unhandled_input(event: InputEvent) -> void:
	if not arcade_seated or not is_instance_valid(camera_pivot):
		_arcade_touch_index = -1
		_arcade_mouse_dragging = false
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var right_side_start := touch.position.x > get_viewport().get_visible_rect().size.x * 0.38
			if _arcade_touch_index == -1 and right_side_start:
				_arcade_touch_index = touch.index
		else:
			if touch.index == _arcade_touch_index:
				_arcade_touch_index = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _arcade_touch_index:
			_apply_arcade_camera_drag(drag.relative)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_arcade_mouse_dragging = event.pressed and event.position.x > get_viewport().get_visible_rect().size.x * 0.38
	elif event is InputEventMouseMotion and _arcade_mouse_dragging:
		_apply_arcade_camera_drag((event as InputEventMouseMotion).relative)

func _apply_arcade_camera_drag(relative: Vector2) -> void:
	# أثناء الجلوس فقط: السحب الأفقي يلف الرؤية، والرأسي يرفع/يخفض زاوية الكاميرا.
	camera_pivot.rotation.y = clampf(
		camera_pivot.rotation.y - relative.x * ARCADE_CAMERA_DRAG_SENSITIVITY,
		-ARCADE_CAMERA_YAW_LIMIT,
		ARCADE_CAMERA_YAW_LIMIT
	)
	camera_pivot.rotation.x = clampf(
		camera_pivot.rotation.x - relative.y * ARCADE_CAMERA_DRAG_SENSITIVITY,
		ARCADE_CAMERA_PITCH_MIN,
		ARCADE_CAMERA_PITCH_MAX
	)

func _physics_process(delta: float) -> void:
	if is_instance_valid(mounted_scooter):
		velocity = Vector3.ZERO
		var scooter_speed := Vector2(mounted_scooter.velocity.x, mounted_scooter.velocity.z).length()
		_update_avatar_animation("run" if scooter_speed > 0.25 else "idle", scooter_speed)
		return
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
	forward.y = 0.0
	forward = forward.normalized()
	# اشتق محور اليمين من الأمام الأفقي لضمان تعامد اتجاهي الحركة.
	var right := forward.cross(Vector3.UP).normalized()
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
	_try_step_up(delta)
	move_and_slide()
	# وجّه الشخصية حسب اتجاه انتقالها الفعلي بعد التسارع والاصطدام،
	# حتى لا تواجه الاتجاه الجديد بينما جسمها ما زال يتحرك في الاتجاه السابق.
	var planar_velocity := Vector3(velocity.x, 0.0, velocity.z)
	if planar_velocity.length() > 0.18:
		var target_angle := _get_facing_yaw_for_direction(planar_velocity)
		_set_body_yaw_preserving_camera(rotate_toward(rotation.y, target_angle, turn_speed * delta))
	var planar_speed := planar_velocity.length()
	var motion_state := "idle"
	if planar_speed > 0.25:
		motion_state = "run" if running else "walk"
	_update_avatar_animation(_active_emote if not _active_emote.is_empty() else motion_state, planar_speed)

func _process_online_input() -> void:
	if not AuthoritativeGameServer.is_authenticated():
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mobile_move.length() > 0.08:
		input_vector = mobile_move
	if sitting and input_vector.length() > 0.08:
		sitting = false
		_sync_sitting_state()
	if sitting:
		input_vector = Vector2.ZERO
	var direction := Vector3(input_vector.x, 0.0, input_vector.y)
	if direction.length() > 1.0:
		direction = direction.normalized()
	var basis := camera_pivot.global_transform.basis
	var forward := -basis.z
	forward.y = 0.0
	forward = forward.normalized()
	# اشتق محور اليمين من الأمام الأفقي لضمان تعامد اتجاهي الحركة.
	var right := forward.cross(Vector3.UP).normalized()
	var world_direction := (right * direction.x + forward * -direction.z).normalized()
	var running := Input.is_action_pressed("sprint") or mobile_sprint
	AuthoritativeGameServer.send_movement_input(world_direction, running)


func _get_facing_yaw_for_direction(direction: Vector3) -> float:
	# وجه الشخصية الأمامي هو -Z؛ عكس إشارة X يمنع التفافها بظهرها عند الحركة الجانبية.
	return atan2(-direction.x, -direction.z)


func _set_body_yaw_preserving_camera(target_yaw: float) -> void:
	# دوران جسم اللاعب لا ينبغي أن يغيّر اتجاه الكاميرا أثناء المشي.
	# نحفظ اتجاه الكاميرا العالمي ثم نعيده بعد تدوير جسم اللاعب.
	var camera_world_rotation := camera_pivot.global_rotation
	rotation.y = target_yaw
	camera_pivot.global_rotation = camera_world_rotation


func _apply_authoritative_state(server_position: Vector3, server_rotation_y: float, server_velocity: Vector3) -> void:
	if not GameModeManager.is_online_ready():
		return
	global_position = server_position
	_set_body_yaw_preserving_camera(server_rotation_y)
	velocity = server_velocity
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	_update_avatar_animation(_active_emote if not _active_emote.is_empty() else ("run" if planar_speed > 4.2 else "walk" if planar_speed > 0.25 else ("sit" if sitting else "idle")), planar_speed)


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
	_sync_sitting_state()
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
		_sync_sitting_state()

func end_arcade_seat(world_position: Vector3, facing_y: float = 0.0) -> void:
	arcade_seated = false
	sitting = false
	_sync_sitting_state()
	global_position = world_position
	rotation.y = facing_y
	velocity = Vector3.ZERO
	mobile_move = Vector2.ZERO
	mobile_sprint = false
	_arcade_touch_index = -1
	_arcade_mouse_dragging = false
	if is_instance_valid(camera_pivot):
		var camera_reset := create_tween()
		camera_reset.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		camera_reset.tween_property(camera_pivot, "rotation", _arcade_camera_default_rotation, 0.24)

func toggle_sit() -> void:
	# الجلوس غير متاح أثناء ركوب الحيوان حتى لا تتعارض حالتا الحركة.
	if animal_riding:
		return
	sitting = not sitting
	if sitting:
		mobile_move = Vector2.ZERO
		mobile_sprint = false
	_sync_sitting_state()

func _sync_sitting_state() -> void:
	if GameModeManager.is_online_ready():
		AuthoritativeGameServer.send_player_sit(sitting)

func set_phone_using(enabled: bool) -> void:
	phone_using = enabled
	var avatar := get_node_or_null("AvatarVisual")
	if is_instance_valid(avatar) and avatar.has_method("set_phone_using"):
		avatar.call("set_phone_using", enabled)


func _update_avatar_animation(state: String, speed: float) -> void:
	var avatar := get_node_or_null("AvatarVisual")
	if avatar != null and avatar.has_method("set_motion_state"):
		avatar.set_motion_state(state, speed)

func set_mobile_move(value: Vector2) -> void:
	mobile_move = value
	if is_instance_valid(mounted_scooter):
		mounted_scooter.call("set_throttle", value.y < -0.16)
		mounted_scooter.call("set_brake", value.y > 0.16)
		mounted_scooter.call("set_steering", value.x)

func set_mobile_sprint(value: bool) -> void:
	mobile_sprint = false if is_instance_valid(mounted_scooter) else value

func set_mounted_scooter(scooter: CharacterBody3D) -> void:
	mounted_scooter = scooter
	if is_instance_valid(mounted_scooter):
		mounted_scooter.call("clear_controls")
	else:
		mobile_move = Vector2.ZERO
		mobile_sprint = false


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
