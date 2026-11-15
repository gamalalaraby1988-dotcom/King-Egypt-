extends Control
## نافذة موحدة لدعوات المجموعة والتجمع وزيارة الشقة.
signal invitation_accepted(invitation: Dictionary)
signal invitation_declined(invitation: Dictionary)
signal invitation_expired(invitation: Dictionary)

const INVITATION_DURATION_SECONDS := 30.0
const MAX_SEEN_INVITATION_IDS := 512

var _queue: Array[Dictionary] = []
var _seen_invitation_ids: Dictionary = {}
var _seen_invitation_order: Array[String] = []
var _current: Dictionary = {}
var _remaining_seconds := 0.0
var _response_pending := false
var _panel: PanelContainer
var _title_label: Label
var _body_label: Label
var _timer_label: Label
var _progress: ProgressBar
var _accept_button: Button
var _decline_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_ui()
	resized.connect(_apply_panel_layout)
	_apply_panel_layout()

func get_panel_horizontal_margin(viewport_width: float) -> float:
	return minf(12.0, maxf(0.0, viewport_width * 0.5))

func get_panel_width_for_viewport(viewport_width: float) -> float:
	var margin := get_panel_horizontal_margin(viewport_width)
	return minf(314.0, maxf(0.0, viewport_width - margin * 2.0))

func get_panel_layout_for_viewport(viewport_width: float) -> Vector2:
	return Vector2(get_panel_horizontal_margin(viewport_width), get_panel_width_for_viewport(viewport_width))

func get_panel_vertical_layout(viewport_height: float) -> Vector2:
	var panel_height := minf(226.0, maxf(0.0, viewport_height - 24.0))
	var top_margin := minf(viewport_height * 0.12, maxf(0.0, (viewport_height - panel_height) * 0.5))
	return Vector2(top_margin, panel_height)

func _apply_panel_layout() -> void:
	if not is_instance_valid(_panel):
		return
	var viewport_size := get_viewport_rect().size
	var horizontal_layout := get_panel_layout_for_viewport(viewport_size.x)
	var vertical_layout := get_panel_vertical_layout(viewport_size.y)
	_panel.offset_left = -horizontal_layout.y - horizontal_layout.x
	_panel.offset_right = -horizontal_layout.x
	_panel.offset_top = vertical_layout.x
	_panel.offset_bottom = vertical_layout.x + vertical_layout.y
	_panel.custom_minimum_size = Vector2(horizontal_layout.y, vertical_layout.y)

func _build_ui() -> void:
	_panel = PanelContainer.new()
	_panel.name = "UnifiedInvitationPanel"
	_panel.anchor_left = 1.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 0.0
	_panel.anchor_bottom = 0.0
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

	var scroll := ScrollContainer.new()
	scroll.name = "InvitationContentScroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2.ZERO
	_panel.add_child(scroll)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 7)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)

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
	_accept_button = Button.new()
	_accept_button.name = "AcceptInvitationButton"
	_accept_button.text = "قبول"
	_accept_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_accept_button.custom_minimum_size.y = 44.0
	_accept_button.pressed.connect(_finish_current.bind(true))
	actions.add_child(_accept_button)
	_decline_button = Button.new()
	_decline_button.name = "DeclineInvitationButton"
	_decline_button.text = "رفض"
	_decline_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_decline_button.custom_minimum_size.y = 44.0
	_decline_button.pressed.connect(_finish_current.bind(false))
	actions.add_child(_decline_button)

func enqueue_invitation(invitation: Dictionary) -> void:
	var item := invitation.duplicate(true)
	var invite_id := str(item.get("invite_id", item.get("id", ""))).strip_edges()
	if invite_id.is_empty() or _contains_invitation(invite_id):
		return
	_remember_invitation_id(invite_id)
	item["invite_id"] = invite_id
	var expiry := resolve_invitation_expiry(item, float(Time.get_unix_time_from_system()))
	item["expires_at"] = expiry
	var now := float(Time.get_unix_time_from_system())
	if expiry <= now:
		invitation_expired.emit(item)
		return
	item["_remaining_seconds"] = expiry - now
	_queue.append(item)
	_show_next()

func resolve_invitation_expiry(invitation: Dictionary, now: float) -> float:
	var created_deadline := 0.0
	var created_at := str(invitation.get("created_at", "")).strip_edges()
	if created_at.length() >= 19:
		var created_timestamp := float(Time.get_unix_time_from_datetime_string(created_at.substr(0, 19)))
		# Only a valid timestamp at or before receipt can anchor expiry.
		# Malformed or future timestamps fall back to receipt time.
		if created_timestamp > 0.0 and created_timestamp <= now:
			created_deadline = created_timestamp + INVITATION_DURATION_SECONDS
	# A supplied server deadline may shorten an invitation, but must never
	# extend the approved 30-second lifetime. If no trustworthy creation time
	# is available, the local cap starts when the invitation is received.
	var maximum_deadline := created_deadline if created_deadline > 0.0 else now + INVITATION_DURATION_SECONDS
	var supplied_deadline := float(invitation.get("expires_at", 0.0))
	if supplied_deadline > 0.0:
		return minf(supplied_deadline, maximum_deadline)
	return maximum_deadline


func _contains_invitation(invite_id: String) -> bool:
	return _seen_invitation_ids.has(invite_id)


func _remember_invitation_id(invite_id: String) -> void:
	_seen_invitation_ids[invite_id] = true
	_seen_invitation_order.append(invite_id)
	while _seen_invitation_order.size() > MAX_SEEN_INVITATION_IDS:
		var oldest_id: String = _seen_invitation_order.pop_front()
		_seen_invitation_ids.erase(oldest_id)

func _show_next() -> void:
	if _response_pending or not _current.is_empty() or _queue.is_empty():
		return
	_current = _queue.pop_front()
	# Recompute from the absolute deadline whenever an invitation becomes current.
	# Cached frame-time values may be stale after the app resumes from background.
	_remaining_seconds = maxf(0.0, float(_current.get("expires_at", 0.0)) - float(Time.get_unix_time_from_system()))
	if _remaining_seconds <= 0.0:
		var expired_item := _current.duplicate(true)
		_current.clear()
		invitation_expired.emit(expired_item)
		_show_next()
		return
	_title_label.text = str(_current.get("title", "دعوة جديدة"))
	_body_label.text = str(_current.get("body", "لديك دعوة جديدة."))
	var can_respond := can_respond_to_invitation(_current)
	_accept_button.disabled = not can_respond
	_decline_button.disabled = not can_respond
	if not can_respond:
		_body_label.text += "\n\nالاستجابة لهذه الدعوة غير متاحة حاليًا؛ لم تُربط خدمتها بالخادم بعد."
	_panel.visible = true
	_update_timer_display()

func _process(delta: float) -> void:
	_tick(delta)

func _tick(_delta: float) -> void:
	# Use absolute expiry timestamps rather than frame deltas so invitations
	# still expire correctly after the app is backgrounded or the frame stalls.
	var now := float(Time.get_unix_time_from_system())
	for index in range(_queue.size() - 1, -1, -1):
		var queued_item := _queue[index]
		var queued_remaining := maxf(0.0, float(queued_item.get("expires_at", now)) - now)
		queued_item["_remaining_seconds"] = queued_remaining
		if queued_remaining <= 0.0:
			_queue.remove_at(index)
			invitation_expired.emit(queued_item)
	if _current.is_empty():
		return
	_remaining_seconds = maxf(0.0, float(_current.get("expires_at", now)) - now)
	_current["_remaining_seconds"] = _remaining_seconds
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

func can_respond_to_invitation(invitation: Dictionary) -> bool:
	# Only group invitations currently have a verified accept/decline RPC.
	return str(invitation.get("type", "")) == "group_invite"

func _finish_current(accepted: bool) -> void:
	if _current.is_empty() or not can_respond_to_invitation(_current):
		return
	var finished_item := _current.duplicate(true)
	_current.clear()
	_panel.visible = false
	# A tap can race the frame timer (or arrive immediately after resume).
	# Never emit an accept/decline for an invitation whose absolute deadline
	# has already passed; the server remains the final authority as well.
	if float(finished_item.get("expires_at", 0.0)) <= float(Time.get_unix_time_from_system()):
		invitation_expired.emit(finished_item)
	else:
		if accepted:
			invitation_accepted.emit(finished_item)
		else:
			invitation_declined.emit(finished_item)
	_show_next()

func set_response_pending(pending: bool) -> void:
	_response_pending = pending
	if not _response_pending:
		_show_next()

func clear_pending_invitations() -> void:
	# Invitations belong to the authenticated recipient; discard them silently
	# when the account changes so another player never sees stale requests.
	_queue.clear()
	_current.clear()
	_seen_invitation_ids.clear()
	_seen_invitation_order.clear()
	_response_pending = false
	_remaining_seconds = 0.0
	if is_instance_valid(_panel):
		_panel.visible = false
	_update_timer_display()


func get_current_invitation() -> Dictionary:
	return _current.duplicate(true)

func get_pending_invitation_count() -> int:
	return _queue.size() + (1 if not _current.is_empty() else 0)
