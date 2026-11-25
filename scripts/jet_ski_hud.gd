extends Control
## Touch controls for the royal jet ski: drive/brake/steer plus right-side camera drag.

var jet_ski: CharacterBody3D
var drive_touch := -1
var brake_touch := -1
var steering_touch := -1
var camera_touch := -1
var steering_value := 0.0
var drive_rect := Rect2()
var brake_rect := Rect2()
var steering_rect := Rect2()
var camera_last_position := Vector2.ZERO
var _ui_scale := 1.0
var _network_send_elapsed := 0.0
var _race_state := "waiting"
var _race_participant_count := 0
var _race_message := ""
var _race_next_gate_index := 0
var _race_status := "waiting"
var _race_place := 0
var _race_results: Array = []

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var layer := get_parent() as CanvasLayer
	if is_instance_valid(layer):
		jet_ski = layer.get_parent() as CharacterBody3D
	_update_layout()
	if not AuthoritativeGameServer.jet_ski_race_state_changed.is_connected(_on_race_state_changed):
		AuthoritativeGameServer.jet_ski_race_state_changed.connect(_on_race_state_changed)
	if not AuthoritativeGameServer.jet_ski_race_progress_changed.is_connected(_on_race_progress_changed):
		AuthoritativeGameServer.jet_ski_race_progress_changed.connect(_on_race_progress_changed)
	if not AuthoritativeGameServer.jet_ski_race_results_received.is_connected(_on_race_results_received):
		AuthoritativeGameServer.jet_ski_race_results_received.connect(_on_race_results_received)
	queue_redraw()


func _on_race_state_changed(state: String, participant_count: int, message: String) -> void:
	_race_state = state
	_race_participant_count = participant_count
	_race_message = message
	if state == "countdown":
		_race_next_gate_index = 0
		_race_status = "racing"
		_race_place = 0
		_race_results.clear()
	queue_redraw()


func _on_race_progress_changed(next_gate_index: int, status: String, place: int) -> void:
	_race_next_gate_index = next_gate_index
	_race_status = status
	_race_place = place
	queue_redraw()


func _on_race_results_received(results: Array) -> void:
	_race_results = results.duplicate(true)
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_update_layout()
		queue_redraw()
	elif what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_controls()


func _process(delta: float) -> void:
	if not visible:
		_clear_controls()
		return
	if is_instance_valid(jet_ski):
		jet_ski.call("set_drive", drive_touch != -1)
		jet_ski.call("set_brake", brake_touch != -1)
		jet_ski.call("set_steering", steering_value)
		if GameModeManager.is_online_ready():
			_network_send_elapsed += maxf(delta, 0.0)
			if _network_send_elapsed >= 0.05:
				_network_send_elapsed = 0.0
				AuthoritativeGameServer.send_jet_ski_input(1.0 if drive_touch != -1 else 0.0, 1.0 if brake_touch != -1 else 0.0, steering_value)
		else:
			_network_send_elapsed = 0.0


func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var short_side := maxf(1.0, minf(viewport_size.x, viewport_size.y))
	_ui_scale = clampf(short_side / 720.0, 0.58, 1.0)
	var margin := 18.0 * _ui_scale
	var drive_size := 94.0 * _ui_scale
	var brake_size := 76.0 * _ui_scale
	var steer_width := 142.0 * _ui_scale
	var steer_height := 108.0 * _ui_scale
	drive_rect = Rect2(Vector2(viewport_size.x - margin - drive_size - brake_size * 0.25, viewport_size.y - margin - drive_size), Vector2(drive_size, drive_size))
	brake_rect = Rect2(Vector2(viewport_size.x - margin - brake_size, viewport_size.y - margin - brake_size), Vector2(brake_size, brake_size))
	steering_rect = Rect2(Vector2(margin, viewport_size.y - margin - steer_height), Vector2(steer_width, steer_height))


func _draw() -> void:
	_update_layout()
	_draw_button(drive_rect, "GO", Color(0.12, 0.42, 0.2, 0.82))
	_draw_button(brake_rect, "BRAKE", Color(0.65, 0.12, 0.1, 0.84))
	_draw_button(steering_rect, "STEER", Color(0.08, 0.12, 0.2, 0.66))
	_draw_race_panel()


func _draw_race_panel() -> void:
	if _race_state == "waiting" and _race_message.is_empty() and _race_results.is_empty():
		return
	var viewport_size := get_viewport_rect().size
	var width := minf(390.0, viewport_size.x - 28.0)
	var panel_height := 112.0 if _race_results.is_empty() else 210.0
	var panel := Rect2(Vector2((viewport_size.x - width) * 0.5, 18.0), Vector2(width, panel_height))
	draw_rect(panel, Color(0.025, 0.045, 0.075, 0.9), true)
	draw_rect(panel, Color(0.88, 0.69, 0.32, 0.95), false, 2.0)
	var font := ThemeDB.fallback_font
	var title := "بطولة الجت سكي الملكية"
	draw_string(font, Vector2(panel.position.x + 14.0, panel.position.y + 24.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1.0, 0.84, 0.48))
	var status_text := "المتسابقون: %d / 4" % _race_participant_count
	if _race_state == "countdown":
		status_text = "استعد للانطلاق"
	elif _race_state == "racing":
		status_text = "السباق جارٍ"
	elif _race_state == "finished":
		status_text = "انتهت الجولة"
	draw_string(font, Vector2(panel.position.x + 14.0, panel.position.y + 48.0), status_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	if _race_state == "racing" or _race_status == "finished":
		var gate_text := "التقدم: %d / 5 بوابات" % _race_next_gate_index
		if _race_status == "finished":
			gate_text = "وصلت إلى خط النهاية" + (" — المركز %d" % _race_place if _race_place > 0 else "")
		draw_string(font, Vector2(panel.position.x + 14.0, panel.position.y + 70.0), gate_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.9, 0.9, 0.9))
	if not _race_results.is_empty():
		var y := panel.position.y + 112.0
		draw_line(Vector2(panel.position.x + 12.0, y), Vector2(panel.end.x - 12.0, y), Color(0.7, 0.55, 0.25, 0.8), 1.0)
		y += 19.0
		draw_string(font, Vector2(panel.position.x + 14.0, y), "النتائج", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1.0, 0.84, 0.48))
		for row in _race_results:
			y += 19.0
			var slot := int(row.get("slot", 0))
			var result_status := str(row.get("status", "dnf"))
			var result_text := "المتسابق %d: %s" % [slot, "أنهى السباق" if result_status == "finished" else "لم يكمل"]
			if result_status == "finished":
				result_text += " — المركز %d" % int(row.get("place", 0))
			draw_string(font, Vector2(panel.position.x + 14.0, y), result_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)


func _draw_button(rect: Rect2, label: String, color: Color) -> void:
	draw_rect(rect, color, true)
	draw_rect(rect, Color(0.9, 0.72, 0.36, 0.8), false, 2.0)
	var font_size := maxi(12, roundi(17.0 * _ui_scale))
	var label_width := ThemeDB.fallback_font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(ThemeDB.fallback_font, rect.position + Vector2((rect.size.x - label_width) * 0.5, rect.size.y * 0.56), label, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		if event.index == steering_touch:
			var center := steering_rect.position.x + steering_rect.size.x * 0.5
			steering_value = clampf((event.position.x - center) / (steering_rect.size.x * 0.46), -1.0, 1.0)
		elif event.index == camera_touch and is_instance_valid(jet_ski):
			var drag_delta: float = event.position.x - camera_last_position.x
			jet_ski.call("set_camera_drag", drag_delta * 0.006)
			camera_last_position = event.position
		queue_redraw()


func _press(index: int, position: Vector2) -> void:
	_update_layout()
	if drive_rect.has_point(position) and drive_touch == -1:
		drive_touch = index
	elif brake_rect.has_point(position) and brake_touch == -1:
		brake_touch = index
	elif steering_rect.has_point(position) and steering_touch == -1:
		steering_touch = index
		var center := steering_rect.position.x + steering_rect.size.x * 0.5
		steering_value = clampf((position.x - center) / (steering_rect.size.x * 0.46), -1.0, 1.0)
	elif position.x >= get_viewport_rect().size.x * 0.52 and camera_touch == -1:
		camera_touch = index
		camera_last_position = position
	queue_redraw()


func _release(index: int) -> void:
	if drive_touch == index:
		drive_touch = -1
	if brake_touch == index:
		brake_touch = -1
	if steering_touch == index:
		steering_touch = -1
		steering_value = 0.0
	if camera_touch == index:
		camera_touch = -1
	queue_redraw()


func _clear_controls() -> void:
	drive_touch = -1
	brake_touch = -1
	steering_touch = -1
	camera_touch = -1
	steering_value = 0.0
	if is_instance_valid(jet_ski):
		jet_ski.call("clear_controls")
	queue_redraw()
