extends Control
## واجهة لمس متجاوبة: عصا حركة يسارًا وكاميرا بالسحب دون زر جري مستقل أو زر جلوس.

@export var joystick_radius: float = 72.0
@export var camera_sensitivity: float = 0.006

var player: CharacterBody3D
var controlled_vehicle: CharacterBody3D
var interaction_button: Button
var interaction_brake_held := false
var joystick_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_finger := -1
var camera_finger := -1
var mouse_camera_active := false
var _last_camera_pos := Vector2.ZERO
var _joystick_draw_radius := 72.0
var _camera_drag_scale := 1.0
const MOBILE_SPRINT_FORWARD_THRESHOLD := 0.92

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_layout()
	_build_interaction_button()
	queue_redraw()

func _build_interaction_button() -> void:
	# زر التفاعل اليدوي الكبير — ثابت وواضح في يمين الشاشة مثل التصميم المعتمد.
	var viewport_size := get_viewport_rect().size
	var scale_factor := clampf(minf(viewport_size.x, viewport_size.y) / 720.0, 0.62, 1.0)
	var button_size := 76.0 * scale_factor
	interaction_button = Button.new()
	var button := interaction_button
	button.name = "PlayerInteractionButton"
	button.text = "✋"
	button.tooltip_text = "تفاعل"
	button.custom_minimum_size = Vector2(button_size, button_size)
	button.anchor_left = 1.0
	button.anchor_right = 1.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -button_size - 22.0 * scale_factor
	button.offset_right = -22.0 * scale_factor
	button.offset_top = -button_size - 148.0 * scale_factor
	button.offset_bottom = -148.0 * scale_factor
	button.add_theme_font_size_override("font_size", 34)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.92)
	style.border_color = Color(0.88, 0.70, 0.34, 0.98)
	style.set_border_width_all(2)
	style.set_corner_radius_all(38)
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.pressed.connect(_on_interaction_button_pressed)
	button.button_down.connect(_on_interaction_button_down)
	button.button_up.connect(_on_interaction_button_up)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(button)

	_update_interaction_button_state()

func _update_interaction_button_state() -> void:
	if not is_instance_valid(interaction_button):
		return
	if is_instance_valid(controlled_vehicle):
		interaction_button.text = "🛑"
		interaction_button.tooltip_text = "فرامل — استمر بالضغط"
	else:
		interaction_button.text = "✋"
		interaction_button.tooltip_text = "تفاعل"

func _on_interaction_button_down() -> void:
	if is_instance_valid(controlled_vehicle):
		interaction_brake_held = true
		controlled_vehicle.call("set_brake", true)

func _on_interaction_button_up() -> void:
	interaction_brake_held = false
	if is_instance_valid(controlled_vehicle):
		controlled_vehicle.call("set_brake", false)

func _on_interaction_button_pressed() -> void:
	if is_instance_valid(controlled_vehicle):
		return
	if not is_instance_valid(player):
		return
	var scene := get_tree().current_scene
	if not is_instance_valid(scene):
		return
	var manager := scene.get_node_or_null("MissionManager")
	if is_instance_valid(manager) and manager.has_method("interact"):
		manager.call("interact")

func _process(_delta: float) -> void:
	# نفس عصا الحركة تتحكم في السيارة: أعلى للأمام، أسفل للخلف، يمين/يسار للتوجيه.
	if is_instance_valid(controlled_vehicle):
		if not visible:
			_clear_vehicle_input()
			return
		var has_direction := absf(joystick_vector.y) > 0.12
		controlled_vehicle.call("set_drive", has_direction)
		controlled_vehicle.call("set_brake", interaction_brake_held)
		controlled_vehicle.call("set_reverse", has_direction and joystick_vector.y > 0.12)
		controlled_vehicle.call("set_steering", joystick_vector.x)
		if is_instance_valid(player):
			player.set_mobile_move(Vector2.ZERO)
			player.set_mobile_sprint(false)
		return
	if not is_instance_valid(player):
		return
	# Arcade seating owns camera input; discard any held joystick/camera touch
	# so it cannot leak movement when the player leaves the seat.
	if bool(player.get("arcade_seated")):
		if joystick_finger != -1 or camera_finger != -1 or not joystick_vector.is_zero_approx():
			_clear_touch_state()
		return
	if not visible:
		player.set_mobile_move(Vector2.ZERO)
		player.set_mobile_sprint(false)
		return
	player.set_mobile_move(joystick_vector)
	# دفع عصا الاتجاه للأمام حتى قرب أقصى امتدادها يشغّل الجري دون زر مستقل.
	var forward_sprint := joystick_vector.y <= -MOBILE_SPRINT_FORWARD_THRESHOLD and joystick_vector.length() >= MOBILE_SPRINT_FORWARD_THRESHOLD
	player.set_mobile_sprint(forward_sprint)

func set_controlled_vehicle(value: CharacterBody3D) -> void:
	if is_instance_valid(controlled_vehicle) and controlled_vehicle != value:
		_clear_vehicle_input()
	controlled_vehicle = value
	if is_instance_valid(controlled_vehicle):
		_clear_vehicle_input()
	_update_interaction_button_state()

	interaction_brake_held = false
	if not is_instance_valid(controlled_vehicle):
		return
	controlled_vehicle.call("set_drive", false)
	controlled_vehicle.call("set_brake", false)
	controlled_vehicle.call("set_reverse", false)
	controlled_vehicle.call("set_steering", 0.0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_touch_state()

func _update_layout() -> void:
	var size := get_viewport_rect().size
	var short_side := maxf(1.0, minf(size.x, size.y))
	var scale_factor := clampf(short_side / 720.0, 0.58, 1.0)
	var margin := 24.0 * scale_factor
	_joystick_draw_radius = joystick_radius * scale_factor
	# إبقاء العصا أقرب إلى حافة اليسار لترك فصل بصري واضح بينها وبين أزرار الوظائف اليمنى.
	joystick_center = Vector2(maxf(margin + _joystick_draw_radius, size.x * 0.08), size.y - margin - _joystick_draw_radius)
	_camera_drag_scale = clampf(720.0 / maxf(360.0, size.y), 0.5, 1.8)

func _draw() -> void:
	_update_layout()
	draw_circle(joystick_center, _joystick_draw_radius, Color(0.04, 0.06, 0.09, 0.30))
	draw_arc(joystick_center, _joystick_draw_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.58), 3.0 * minf(1.0, _joystick_draw_radius / 72.0))
	draw_circle(joystick_center + joystick_vector * _joystick_draw_radius, maxf(17.0, 26.0 * _joystick_draw_radius / 72.0), Color(0.91, 0.75, 0.38, 0.90))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	# The seated player script is the sole owner of arcade camera swipes.
	if is_instance_valid(player) and bool(player.get("arcade_seated")):
		_clear_touch_state()
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_handle_touch_press(event.index, event.position)
		else:
			_handle_touch_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == joystick_finger:
			_update_joystick(event.position)
		elif event.index == camera_finger:
			_apply_camera_drag(event.position - _last_camera_pos)
			_last_camera_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_camera_active = event.position.x > get_viewport_rect().size.x * 0.38 and not _is_over_control(event.position)
			_last_camera_pos = event.position
		else:
			mouse_camera_active = false
	elif event is InputEventMouseMotion and mouse_camera_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_apply_camera_drag(event.position - _last_camera_pos)
		_last_camera_pos = event.position

func _handle_touch_press(index: int, pos: Vector2) -> void:
	_update_layout()
	if pos.distance_to(joystick_center) <= _joystick_draw_radius * 1.55 and joystick_finger == -1:
		joystick_finger = index
		_update_joystick(pos)
	elif pos.x > get_viewport_rect().size.x * 0.38 and camera_finger == -1:
		camera_finger = index
		_last_camera_pos = pos
	queue_redraw()

func _handle_touch_release(index: int) -> void:
	if index == joystick_finger:
		joystick_finger = -1
		joystick_vector = Vector2.ZERO
	if index == camera_finger:
		camera_finger = -1
	queue_redraw()

func _update_joystick(pos: Vector2) -> void:
	var offset := pos - joystick_center
	if offset.length() > _joystick_draw_radius:
		offset = offset.normalized() * _joystick_draw_radius
	joystick_vector = offset / maxf(1.0, _joystick_draw_radius)
	queue_redraw()

func _apply_camera_drag(delta_pos: Vector2) -> void:
	var pivot: Node3D
	if is_instance_valid(controlled_vehicle):
		pivot = controlled_vehicle.get_node_or_null("VehicleCameraPivot") as Node3D
	elif is_instance_valid(player):
		pivot = player.get_node_or_null("CameraPivot") as Node3D
	else:
		return
	if pivot == null:
		return
	var sensitivity := camera_sensitivity * _camera_drag_scale
	if is_instance_valid(controlled_vehicle):
		# أثناء قيادة السيارة تتحرك زاوية الكاميرا مع اتجاه سحب الإصبع.
		pivot.rotation.y += delta_pos.x * sensitivity
	else:
		# حافظ على اتجاه كاميرا المشي الحالي دون تغيير.
		pivot.rotation.y -= delta_pos.x * sensitivity
	pivot.rotation.x = clampf(pivot.rotation.x - delta_pos.y * sensitivity, deg_to_rad(-60.0), deg_to_rad(25.0))

func _is_over_control(pos: Vector2) -> bool:
	return pos.distance_to(joystick_center) <= _joystick_draw_radius * 1.55

func _clear_touch_state() -> void:
	joystick_finger = -1
	camera_finger = -1
	joystick_vector = Vector2.ZERO
	mouse_camera_active = false
	_clear_vehicle_input()
	if is_instance_valid(player):
		player.set_mobile_move(Vector2.ZERO)
		player.set_mobile_sprint(false)
	queue_redraw()
