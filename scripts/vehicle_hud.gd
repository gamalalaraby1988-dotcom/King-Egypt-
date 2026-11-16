extends Control
## واجهة قيادة لمس: قيادة بالضغط، فرامل مستقلة، رجوع للخلف بالسحب لأسفل.
## الأزرار مؤقتة مرسومة برمجيًا ويمكن استبدالها بأيقونات لاحقًا.

var vehicle: CharacterBody3D
var drive_touch := -1
var brake_touch := -1
var steering_touch := -1
var steering_value := 0.0
var drive_rect := Rect2()
var brake_rect := Rect2()
var steering_rect := Rect2()
var reverse_start := Vector2.ZERO
var reverse_active := false
var _ui_scale := 1.0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
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
		# لا تسمح ببقاء أي أمر قيادة عالق إذا أُخفيت الواجهة أثناء لمس أحد الأزرار.
		if drive_touch != -1 or brake_touch != -1 or steering_touch != -1 or reverse_active or absf(steering_value) > 0.001:
			_clear_controls()
		return
	if is_instance_valid(vehicle):
		vehicle.call("set_drive", drive_touch != -1)
		vehicle.call("set_brake", brake_touch != -1)
		vehicle.call("set_reverse", reverse_active)
		vehicle.call("set_steering", steering_value)

func _update_layout() -> void:
	var s := get_viewport_rect().size
	var short_side := maxf(1.0, minf(s.x, s.y))
	_ui_scale = clampf(short_side / 720.0, 0.58, 1.0)
	var margin := 18.0 * _ui_scale
	var drive_size := 100.0 * _ui_scale
	var brake_size := 78.0 * _ui_scale
	var steer_width := 142.0 * _ui_scale
	var steer_height := 112.0 * _ui_scale
	drive_rect = Rect2(Vector2(s.x - margin - drive_size - brake_size * 0.25, s.y - margin - drive_size), Vector2(drive_size, drive_size))
	brake_rect = Rect2(Vector2(s.x - margin - brake_size, s.y - margin - brake_size), Vector2(brake_size, brake_size))
	steering_rect = Rect2(Vector2(margin, s.y - margin - steer_height), Vector2(steer_width, steer_height))

func _layout() -> void:
	_update_layout()

func _draw() -> void:
	_layout()
	_draw_button(drive_rect, "DRIVE", Color(0.12, 0.42, 0.2, 0.78))
	_draw_button(brake_rect, "BRAKE", Color(0.65, 0.12, 0.1, 0.82))
	_draw_button(steering_rect, "STEER", Color(0.08, 0.12, 0.2, 0.65))
	if reverse_active:
		draw_string(ThemeDB.fallback_font, drive_rect.position + Vector2(8, -10), "REVERSE", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _draw_button(rect: Rect2, label: String, color: Color) -> void:
	draw_rounded_rect(rect, color, 22.0 * _ui_scale)
	var font_size := maxi(12, roundi(18.0 * _ui_scale))
	var width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(ThemeDB.fallback_font, rect.position + Vector2((rect.size.x - width) * 0.5, rect.size.y * 0.56), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)

func draw_rounded_rect(rect: Rect2, color: Color, radius: float) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, Color(1, 1, 1, 0.55), false, 2.0)

func _input(event: InputEvent) -> void:
	# لا تستقبل واجهة القيادة أي لمسات أثناء إخفائها أو خارج حالة القيادة.
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == drive_touch:
			var delta: Vector2 = event.position - reverse_start
			reverse_active = delta.y > 65.0
		elif event.index == steering_touch:
			var center := steering_rect.position.x + steering_rect.size.x / 2.0
			steering_value = clampf((event.position.x - center) / 65.0, -1.0, 1.0)
		queue_redraw()

func _press(index: int, pos: Vector2) -> void:
	_layout()
	if drive_rect.has_point(pos) and drive_touch == -1:
		drive_touch = index
		reverse_start = pos
	elif brake_rect.has_point(pos) and brake_touch == -1:
		brake_touch = index
	elif steering_rect.has_point(pos) and steering_touch == -1:
		steering_touch = index
		var center := steering_rect.position.x + steering_rect.size.x / 2.0
		steering_value = clampf((pos.x - center) / 65.0, -1.0, 1.0)
	queue_redraw()

func _clear_controls() -> void:
	drive_touch = -1
	brake_touch = -1
	steering_touch = -1
	reverse_active = false
	steering_value = 0.0
	if is_instance_valid(vehicle):
		vehicle.call("set_drive", false)
		vehicle.call("set_brake", false)
		vehicle.call("set_reverse", false)
		vehicle.call("set_steering", 0.0)
	queue_redraw()

func _release(index: int) -> void:
	if index == drive_touch:
		drive_touch = -1
		reverse_active = false
	if index == brake_touch:
		brake_touch = -1
	if index == steering_touch:
		steering_touch = -1
		steering_value = 0.0
	queue_redraw()
