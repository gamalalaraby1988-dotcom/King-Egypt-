extends Control
## نافذة موحدة لدعوات المجموعة والتجمع وزيارة الشقة.
signal invitation_accepted(invitation: Dictionary)
signal invitation_declined(invitation: Dictionary)
signal invitation_expired(invitation: Dictionary)

const INVITATION_DURATION_SECONDS := 30.0

var _queue: Array[Dictionary] = []
var _current: Dictionary = {}
var _remaining_seconds := 0.0
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _timer_label: Label
var _progress: ProgressBar

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "UnifiedInvitationPanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.12
	_panel.anchor_bottom = 0.12
	_panel.offset_left = -326.0
	_panel.offset_right = -12.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = 226.0
	_panel.custom_minimum_size = Vector2(314.0, 226.0)
	_panel.visible = false
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.055, 0.075, 0.84)
	style.border_color = Color(0.78, 0.61, 0.29, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	_panel.add_child(column)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.add_theme_font_size_override("font_size", 17)
	_title_label.add_theme_color_override("font_color", Color(0.95, 0.79, 0.47))
	column.add_child(_title_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_body_label)

	_timer_label = Label.new()
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.add_theme_font_size_override("font_size", 13)
	column.add_child(_timer_label)

	_progress = ProgressBar.new()
	_progress.min_value = 0.0
	_progress.max_value = INVITATION_DURATION_SECONDS
	_progress.show_percentage = false
	_progress.custom_minimum_size.y = 7.0
	column.add_child(_progress)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 8)
	column.add_child(actions)
	var accept := Button.new()
	accept.text = "قبول"
	accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	accept.pressed.connect(_finish_current.bind(true))
	actions.add_child(accept)
	var decline := Button.new()
	decline.text = "رفض"
	decline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	decline.pressed.connect(_finish_current.bind(false))
	actions.add_child(decline)

func enqueue_invitation(invitation: Dictionary) -> void:
	var item := invitation.duplicate(true)
	var invite_id := str(item.get("invite_id", item.get("id", ""))).strip_edges()
	if invite_id.is_empty() or _contains_invitation(invite_id):
		return
	item["invite_id"] = invite_id
	var expiry := float(item.get("expires_at", 0.0))
	if expiry <= 0.0:
		var created_at := str(item.get("created_at", ""))
		if created_at.length() >= 19:
			expiry = float(Time.get_unix_time_from_datetime_string(created_at.substr(0, 19))) + INVITATION_DURATION_SECONDS
		if expiry <= 0.0:
			expiry = float(Time.get_unix_time_from_system()) + INVITATION_DURATION_SECONDS
	item["expires_at"] = expiry
	if expiry <= float(Time.get_unix_time_from_system()):
		invitation_expired.emit(item)
		return
	_queue.append(item)
	_show_next()

func _contains_invitation(invite_id: String) -> bool:
	if not _current.is_empty() and str(_current.get("invite_id", "")) == invite_id:
		return true
	for item in _queue:
		if str(item.get("invite_id", "")) == invite_id:
			return true
	return false

func _show_next() -> void:
	if not _current.is_empty() or _queue.is_empty():
		return
	_current = _queue.pop_front()
	_remaining_seconds = maxf(0.0, float(_current.get("expires_at", 0.0)) - float(Time.get_unix_time_from_system()))
	if _remaining_seconds <= 0.0:
		var expired_item := _current.duplicate(true)
		_current.clear()
		invitation_expired.emit(expired_item)
		_show_next()
		return
	_title_label.text = str(_current.get("title", "دعوة جديدة"))
	_body_label.text = str(_current.get("body", "لديك دعوة جديدة."))
	_panel.visible = true
	_update_timer_display()

func _process(delta: float) -> void:
	_tick(delta)

func _tick(delta: float) -> void:
	if _current.is_empty():
		return
	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	_update_timer_display()
	if _remaining_seconds <= 0.0:
		var expired_item := _current.duplicate(true)
		_current.clear()
		_panel.visible = false
		invitation_expired.emit(expired_item)
		_show_next()

func _update_timer_display() -> void:
	if not is_instance_valid(_timer_label) or not is_instance_valid(_progress):
		return
	_timer_label.text = "متبقي %d ثانية" % int(ceil(_remaining_seconds))
	_progress.value = clampf(_remaining_seconds, 0.0, INVITATION_DURATION_SECONDS)

func _finish_current(accepted: bool) -> void:
	if _current.is_empty():
		return
	var finished_item := _current.duplicate(true)
	_current.clear()
	_panel.visible = false
	if accepted:
		invitation_accepted.emit(finished_item)
	else:
		invitation_declined.emit(finished_item)
	_show_next()

func get_current_invitation() -> Dictionary:
	return _current.duplicate(true)

func get_pending_invitation_count() -> int:
	return _queue.size() + (1 if not _current.is_empty() else 0)
