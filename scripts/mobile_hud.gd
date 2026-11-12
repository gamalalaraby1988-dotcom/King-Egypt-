extends Control
## المرحلة 28: واجهة لمس متجاوبة، مع فصل مناطق الحركة والجري والجلوس والكاميرا.

@export var joystick_radius: float = 72.0
@export var sprint_radius: float = 43.0
@export var sit_radius: float = 39.0
@export var camera_sensitivity: float = 0.006

var player: CharacterBody3D
var joystick_center := Vector2.ZERO
var sprint_center := Vector2.ZERO
var sit_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_finger := -1
var sprint_finger := -1
var sit_finger := -1
var camera_finger := -1
var mouse_camera_active := false
var sprint_active := false
var _last_camera_pos := Vector2.ZERO
var _joystick_draw_radius := 72.0
var _sprint_draw_radius := 43.0
var _sit_draw_radius := 39.0
var _camera_drag_scale := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_layout()
	queue_redraw()

func _process(_delta: float) -> void:
	if is_instance_valid(player):
		player.set_mobile_move(joystick_vector)
		player.set_mobile_sprint(sprint_active)

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
	_sprint_draw_radius = sprint_radius * scale_factor
	_sit_draw_radius = sit_radius * scale_factor
	joystick_center = Vector2(maxf(margin + _joystick_draw_radius, size.x * 0.12), size.y - margin - _joystick_draw_radius)
	# وضع زري الجري والجلوس رأسيًا لمنع تداخل مناطق اللمس على الشاشات الصغيرة.
	var right_x := size.x - margin - maxf(_sprint_draw_radius, _sit_draw_radius)
	sprint_center = Vector2(right_x, size.y - margin - _sprint_draw_radius)
	sit_center = Vector2(right_x, maxf(margin + _sit_draw_radius, sprint_center.y - _sprint_draw_radius - _sit_draw_radius - 24.0 * scale_factor))
	_camera_drag_scale = clampf(720.0 / maxf(360.0, size.y), 0.5, 1.8)

func _draw() -> void:
	_update_layout()
	draw_circle(joystick_center, _joystick_draw_radius, Color(0.04, 0.06, 0.09, 0.30))
	draw_arc(joystick_center, _joystick_draw_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.58), 3.0 * minf(1.0, _joystick_draw_radius / 72.0))
	draw_circle(joystick_center + joystick_vector * _joystick_draw_radius, maxf(17.0, 26.0 * _joystick_draw_radius / 72.0), Color(0.91, 0.75, 0.38, 0.90))
	_draw_button(sprint_center, _sprint_draw_radius, "RUN", sprint_active)
	var sitting_now: bool = is_instance_valid(player) and bool(player.get("sitting"))
	_draw_button(sit_center, _sit_draw_radius, "SIT", sitting_now)

func _draw_button(center: Vector2, radius: float, caption: String, active: bool) -> void:
	var fill := Color(0.67, 0.48, 0.19, 0.82) if active else Color(0.04, 0.06, 0.09, 0.48)
	draw_circle(center, radius, fill)
	draw_arc(center, radius, 0.0, TAU, 40, Color(1, 1, 1, 0.78), 2.0)
	var font := ThemeDB.fallback_font
	var text_size := maxi(11, roundi(17.0 * radius / 43.0))
	var text_width := font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_string(font, center + Vector2(-text_width / 2.0, text_size * 0.34), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, Color.WHITE)

func _unhandled_input(event: InputEvent) -> void:
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
	elif pos.distance_to(sprint_center) <= _sprint_draw_radius * 1.55 and sprint_finger == -1:
		sprint_finger = index
		sprint_active = true
	elif pos.distance_to(sit_center) <= _sit_draw_radius * 1.55 and sit_finger == -1:
		sit_finger = index
		if is_instance_valid(player) and player.has_method("toggle_sit"):
			player.toggle_sit()
	elif pos.x > get_viewport_rect().size.x * 0.38 and camera_finger == -1:
		camera_finger = index
		_last_camera_pos = pos
	queue_redraw()

func _handle_touch_release(index: int) -> void:
	if index == joystick_finger:
		joystick_finger = -1
		joystick_vector = Vector2.ZERO
	if index == sprint_finger:
		sprint_finger = -1
		sprint_active = false
	if index == sit_finger:
		sit_finger = -1
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
	if not is_instance_valid(player):
		return
	var pivot := player.get_node_or_null("CameraPivot") as Node3D
	if pivot == null:
		return
	var sensitivity := camera_sensitivity * _camera_drag_scale
	pivot.rotation.y -= delta_pos.x * sensitivity
	pivot.rotation.x = clampf(pivot.rotation.x - delta_pos.y * sensitivity, deg_to_rad(-60.0), deg_to_rad(25.0))

func _is_over_control(pos: Vector2) -> bool:
	return pos.distance_to(joystick_center) <= _joystick_draw_radius * 1.55 or pos.distance_to(sprint_center) <= _sprint_draw_radius * 1.55 or pos.distance_to(sit_center) <= _sit_draw_radius * 1.55

func _clear_touch_state() -> void:
	joystick_finger = -1
	sprint_finger = -1
	sit_finger = -1
	camera_finger = -1
	joystick_vector = Vector2.ZERO
	sprint_active = false
	mouse_camera_active = false
	if is_instance_valid(player):
		player.set_mobile_move(Vector2.ZERO)
		player.set_mobile_sprint(false)
	queue_redraw()
