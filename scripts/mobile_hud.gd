extends Control
## واجهة لمس متجاوبة: عصا حركة تناظرية وسحب الكاميرا.

@export var joystick_radius: float = 72.0
@export var camera_sensitivity: float = 0.006

var player: CharacterBody3D
var vehicle_control_target: CharacterBody3D
var joystick_center := Vector2.ZERO
var joystick_vector := Vector2.ZERO
var joystick_finger := -1
var camera_finger := -1
var mouse_camera_active := false
var _last_camera_pos := Vector2.ZERO
var _joystick_draw_radius := 72.0
var _camera_drag_scale := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_layout()
	queue_redraw()

func _process(_delta: float) -> void:
	if not visible:
		if is_instance_valid(player):
			player.set_mobile_move(Vector2.ZERO)
		if is_instance_valid(vehicle_control_target):
			vehicle_control_target.call("set_drive", false)
			vehicle_control_target.call("set_reverse", false)
			vehicle_control_target.call("set_steering", 0.0)
		return
	if is_instance_valid(vehicle_control_target):
		# عصا الحركة نفسها تقود السيارة: أعلى للأمام، أسفل للخلف، يمين/يسار للتوجيه.
		var forward_input := -joystick_vector.y
		var drive_active := absf(forward_input) > 0.12
		vehicle_control_target.call("set_drive", drive_active)
		vehicle_control_target.call("set_brake", not drive_active)
		vehicle_control_target.call("set_reverse", forward_input < -0.12)
		vehicle_control_target.call("set_steering", joystick_vector.x)
		return
	if is_instance_valid(player):
		player.set_mobile_move(joystick_vector)

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
	joystick_center = Vector2(maxf(margin + _joystick_draw_radius, size.x * 0.12), size.y - margin - _joystick_draw_radius)
	_camera_drag_scale = clampf(720.0 / maxf(360.0, size.y), 0.5, 1.8)

func _draw() -> void:
	_update_layout()
	draw_circle(joystick_center, _joystick_draw_radius, Color(0.04, 0.06, 0.09, 0.30))
	draw_arc(joystick_center, _joystick_draw_radius, 0.0, TAU, 48, Color(1, 1, 1, 0.58), 3.0 * minf(1.0, _joystick_draw_radius / 72.0))
	draw_circle(joystick_center + joystick_vector * _joystick_draw_radius, maxf(17.0, 26.0 * _joystick_draw_radius / 72.0), Color(0.91, 0.75, 0.38, 0.90))

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
	# إحداثي اللمس Y السالب هو أعلى العصا، وهو اتجاه الأمام في player.gd.
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
	return pos.distance_to(joystick_center) <= _joystick_draw_radius * 1.55

func _clear_touch_state() -> void:
	joystick_finger = -1
	camera_finger = -1
	joystick_vector = Vector2.ZERO
	mouse_camera_active = false
	if is_instance_valid(player):
		player.set_mobile_move(Vector2.ZERO)
	if is_instance_valid(vehicle_control_target):
		vehicle_control_target.call("set_drive", false)
		vehicle_control_target.call("set_brake", true)
		vehicle_control_target.call("set_reverse", false)
		vehicle_control_target.call("set_steering", 0.0)
	queue_redraw()
