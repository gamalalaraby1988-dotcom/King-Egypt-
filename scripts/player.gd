extends CharacterBody3D
## حركة خفيفة: مشي وجري وجلوس، مع دعم تحكم اللمس والكاميرا.

@export var walk_speed: float = 4.0
@export var run_speed: float = 6.2
@export var acceleration: float = 18.0
@export var gravity: float = 20.0
@export var turn_speed: float = 10.0

var mobile_move: Vector2 = Vector2.ZERO
var mobile_sprint: bool = false
var sitting := false
var _sit_key_was_down := false
var animal_riding := false
var scooter_riding := false
var scooter_visual: Node3D = null
var auto_navigation_active := false
var auto_navigation_cancelled := false
var auto_navigation_direction := Vector3.ZERO
var ride_visual: Node3D = null
@onready var camera_pivot: Node3D = $CameraPivot

func _ready() -> void:
	# يساعد على متابعة سطح الطريق عند الانتقال من الأرض المستوية إلى المنحدر.
	floor_snap_length = 0.65
	floor_max_angle = deg_to_rad(48.0)
	add_to_group("player")
	# افصل دوران الكاميرا عن دوران جسم اللاعب؛ حتى لا تدور الكاميرا
	# حوله كلما استدار أثناء تحريك عصا التحكم.
	camera_pivot.top_level = true
	camera_pivot.global_position = global_position + Vector3(0.0, 1.55, 0.0)

func _process(_delta: float) -> void:
	# تظل الكاميرا متبعة لموضع اللاعب دون وراثة دورانه.
	if is_instance_valid(camera_pivot):
		camera_pivot.global_position = global_position + Vector3(0.0, 1.55, 0.0)

func _physics_process(delta: float) -> void:
	var sit_key_down := Input.is_key_pressed(KEY_C)
	if sit_key_down and not _sit_key_was_down:
		toggle_sit()
	_sit_key_was_down = sit_key_down
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if mobile_move.length() > 0.08:
		input_vector = mobile_move
	if auto_navigation_active and input_vector.length() > 0.08:
		auto_navigation_active = false
		auto_navigation_cancelled = true
		auto_navigation_direction = Vector3.ZERO
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
	var world_direction := Vector3.ZERO
	var movement_strength := 0.0
	if scooter_riding:
		# الاسكوتر لا يرجع للخلف: أعلى العصا للتقدم، واليمين/اليسار لتدوير المقود.
		rotation.y -= input_vector.x * turn_speed * delta
		world_direction = -global_transform.basis.z
		world_direction.y = 0.0
		world_direction = world_direction.normalized()
		movement_strength = clampf(-input_vector.y, 0.0, 1.0)
	else:
		world_direction = (right * direction.x + forward * -direction.z)
		movement_strength = clampf(input_vector.length(), 0.0, 1.0)
		if world_direction.length() > 0.001:
			world_direction = world_direction.normalized()
		if auto_navigation_active and not auto_navigation_cancelled:
			world_direction = auto_navigation_direction.normalized()
			movement_strength = 1.0
	var keyboard_running := Input.is_action_pressed("sprint")
	# لا يوجد زر جري مستقل على الهاتف: تزداد السرعة تدريجيًا مع ميل العصا.
	var target_speed := (8.0 if keyboard_running else 6.0) if animal_riding else (7.5 if scooter_riding else (run_speed if keyboard_running else lerpf(walk_speed, run_speed, movement_strength)))
	var target_velocity := world_direction * target_speed * movement_strength
	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0
	if not scooter_riding and world_direction.length() > 0.1:
		var target_angle := atan2(-world_direction.x, -world_direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, turn_speed * delta)
	move_and_slide()
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var motion_state := "idle"
	if planar_speed > 0.25:
		motion_state = "run" if keyboard_running or (mobile_move.length() > 0.08 and movement_strength > 0.78) else "walk"
	_update_avatar_animation("sit" if scooter_riding else motion_state, planar_speed)

func begin_auto_navigation() -> bool:
	if animal_riding or scooter_riding:
		return false
	sitting = false
	mobile_move = Vector2.ZERO
	mobile_sprint = false
	auto_navigation_cancelled = false
	auto_navigation_active = true
	auto_navigation_direction = Vector3.ZERO
	return true


func set_auto_navigation_direction(direction: Vector3) -> void:
	if auto_navigation_active and not auto_navigation_cancelled:
		auto_navigation_direction = Vector3(direction.x, 0.0, direction.z).normalized()


func is_auto_navigation_cancelled() -> bool:
	return auto_navigation_cancelled


func end_auto_navigation() -> void:
	auto_navigation_active = false
	auto_navigation_cancelled = false
	auto_navigation_direction = Vector3.ZERO
	mobile_move = Vector2.ZERO
	velocity.x = 0.0
	velocity.z = 0.0


func is_riding_animal() -> bool:
	return animal_riding

func is_riding_scooter() -> bool:
	return scooter_riding


func start_scooter_ride() -> bool:
	if scooter_riding or animal_riding or sitting or auto_navigation_active:
		return false
	sitting = false
	mobile_move = Vector2.ZERO
	scooter_riding = true
	var avatar := get_node_or_null("AvatarVisual") as Node3D
	if is_instance_valid(avatar):
		avatar.position.y = 0.38
		if avatar.has_method("set_motion_state"):
			avatar.set_motion_state("sit", 0.0)
	_create_scooter_visual()
	return true


func end_scooter_ride() -> void:
	if not scooter_riding:
		return
	scooter_riding = false
	mobile_move = Vector2.ZERO
	velocity.x = 0.0
	velocity.z = 0.0
	if is_instance_valid(scooter_visual):
		scooter_visual.queue_free()
	scooter_visual = null
	var avatar := get_node_or_null("AvatarVisual") as Node3D
	if is_instance_valid(avatar):
		avatar.position.y = 0.0
		if avatar.has_method("set_motion_state"):
			avatar.set_motion_state("idle", 0.0)


func _create_scooter_visual() -> void:
	if is_instance_valid(scooter_visual):
		scooter_visual.queue_free()
	scooter_visual = Node3D.new()
	scooter_visual.name = "PlayerScooterVisual"
	add_child(scooter_visual)
	var dark_material := StandardMaterial3D.new()
	dark_material.albedo_color = Color(0.10, 0.13, 0.17)
	dark_material.metallic = 0.45
	var gold_material := StandardMaterial3D.new()
	gold_material.albedo_color = Color(0.82, 0.62, 0.25)
	gold_material.metallic = 0.55
	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(0.30, 0.10, 0.92)
	deck.mesh = deck_mesh
	deck.position = Vector3(0.0, 0.18, 0.12)
	deck.material_override = gold_material
	scooter_visual.add_child(deck)
	for wheel_z in [-0.34, 0.57]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.19
		wheel_mesh.bottom_radius = 0.19
		wheel_mesh.height = 0.10
		wheel.mesh = wheel_mesh
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(0.0, 0.19, wheel_z)
		wheel.material_override = dark_material
		scooter_visual.add_child(wheel)
	var stem := MeshInstance3D.new()
	var stem_mesh := CylinderMesh.new()
	stem_mesh.top_radius = 0.035
	stem_mesh.bottom_radius = 0.045
	stem_mesh.height = 0.92
	stem.mesh = stem_mesh
	stem.position = Vector3(0.0, 0.66, -0.35)
	stem.material_override = gold_material
	scooter_visual.add_child(stem)
	var handle := MeshInstance3D.new()
	var handle_mesh := BoxMesh.new()
	handle_mesh.size = Vector3(0.72, 0.07, 0.08)
	handle.mesh = handle_mesh
	handle.position = Vector3(0.0, 1.12, -0.35)
	handle.material_override = dark_material
	scooter_visual.add_child(handle)


func toggle_scooter_ride() -> bool:
	if scooter_riding:
		end_scooter_ride()
		return false
	return start_scooter_ride()


func start_animal_ride(animal_name: String) -> bool:
	# لا تبدأ ركوبًا ثانيًا فوق الركوب الحالي؛ يجب النزول أولًا.
	if animal_riding or scooter_riding or animal_name.strip_edges().is_empty():
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
	if animal_riding or scooter_riding:
		return false
	global_position = world_position
	rotation.y = facing_y
	velocity = Vector3.ZERO
	mobile_move = Vector2.ZERO
	mobile_sprint = false
	sitting = true
	return true

func toggle_sit() -> void:
	# الجلوس غير متاح أثناء ركوب الحيوان حتى لا تتعارض حالتا الحركة.
	if animal_riding or scooter_riding:
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
