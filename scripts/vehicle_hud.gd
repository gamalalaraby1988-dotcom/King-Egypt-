extends Control
## عصا القيادة والكاميرا بنفس أسلوب تحكم الشخصية؛ زر الفرامل مستقل في واجهة المدينة.

@export var joystick_radius: float = 72.0
@export var camera_sensitivity: float = 0.006

var vehicle: CharacterBody3D
var joystick_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_finger := -1
var camera_finger := -1
var mouse_camera_active := false
var last_camera_pos := Vector2.ZERO
var joystick_draw_radius := 72.0
var camera_drag_scale := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer := get_parent() as CanvasLayer
	if is_instance_valid(layer):
		vehicle = layer.get_parent() as CharacterBody3D
	_update_layout()
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_controls()

func _process(_delta: float) -> void:
	if not visible:
		_clear_controls()
		return
	if is_instance_valid(vehicle):
		var keyboard_input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		var active_input := joystick_vector if not joystick_vector.is_zero_approx() else keyboard_input
		vehicle.call("set_move_input", active_input)

func _update_layout() -> void:
	var size := get_viewport_rect().size
	var short_side := maxf(1.0, minf(size.x, size.y))
	var scale_factor := clampf(short_side / 720.0, 0.58, 1.0)
	var margin := 24.0 * scale_factor
	joystick_draw_radius = joystick_radius * scale_factor
	joystick_center = Vector2(maxf(margin + joystick_draw_radius, size.x * 0.12), size.y - margin - joystick_draw_radius)
	camera_drag_scale = clampf(720.0 / maxf(360.0, size.y), 0.5, 1.8)

func _draw() -> void:
	_update_layout()
	draw_circle(joystick_center, joystick_draw_radius, Color(0.04, 0.06, 0.09, 0.30))
	draw_arc(joystick_center, joystick_draw_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.58), 3.0 * minf(1.0, joystick_draw_radius / 72.0))
	draw_circle(joystick_center + joystick_vector * joystick_draw_radius, maxf(17.0, 26.0 * joystick_draw_radius / 72.0), Color(0.91, 0.75, 0.38, 0.90))

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
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
			_apply_camera_drag(event.position - last_camera_pos)
			last_camera_pos = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			mouse_camera_active = event.position.x > get_viewport_rect().size.x * 0.38 and not _is_over_joystick(event.position)
			last_camera_pos = event.position
		else:
			mouse_camera_active = false
	elif event is InputEventMouseMotion and mouse_camera_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_apply_camera_drag(event.position - last_camera_pos)
		last_camera_pos = event.position

func _handle_touch_press(index: int, pos: Vector2) -> void:
	_update_layout()
	if pos.distance_to(joystick_center) <= joystick_draw_radius * 1.55 and joystick_finger == -1:
		joystick_finger = index
		_update_joystick(pos)
	elif pos.x > get_viewport_rect().size.x * 0.38 and camera_finger == -1:
		camera_finger = index
		last_camera_pos = pos
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
	if offset.length() > joystick_draw_radius:
		offset = offset.normalized() * joystick_draw_radius
	joystick_vector = offset / maxf(1.0, joystick_draw_radius)
	queue_redraw()

func _apply_camera_drag(delta_pos: Vector2) -> void:
	var pivot := vehicle.get_node_or_null("VehicleCameraPivot") as Node3D if is_instance_valid(vehicle) else null
	if not is_instance_valid(pivot):
		return
	var sensitivity := camera_sensitivity * camera_drag_scale
	pivot.rotation.y -= delta_pos.x * sensitivity
	pivot.rotation.x = clampf(pivot.rotation.x - delta_pos.y * sensitivity, deg_to_rad(-60.0), deg_to_rad(25.0))

func _is_over_joystick(pos: Vector2) -> bool:
	return pos.distance_to(joystick_center) <= joystick_draw_radius * 1.55

func _clear_controls() -> void:
	joystick_finger = -1
	camera_finger = -1
	joystick_vector = Vector2.ZERO
	mouse_camera_active = false
	if is_instance_valid(vehicle):
		vehicle.call("set_move_input", Vector2.ZERO)
