extends Node3D
## مجسم ماكينة سلوت ملكية مع مقعد وتفاعل جلوس على الهاتف.
## زر SPIN يبقى معطلاً حتى ربط متحكم لعبة ونتيجة خادمية موثوقة.

@export var machine_id: String = "vip_royal_classic"
@export var machine_title: String = "Royal Classic"
@export var machine_subtitle: String = "ROYAL SLOT"
@export var accent_color: Color = Color(0.82, 0.62, 0.25)
@export var body_color: Color = Color(0.055, 0.075, 0.09)

var _nearby_player: CharacterBody3D
var _seated_player: CharacterBody3D
var _seat_anchor: Marker3D
var _exit_anchor: Marker3D
var _enter_button: Button
var _spin_button: Button
var _auto_button: Button
var _exit_button: Button
var _status_label: Label
var _balance_label: Label
var _bet_label: Label
var _win_label: Label
var _decrease_bet_button: Button
var _increase_bet_button: Button
var _max_bet_button: Button
const MIN_BET_CHIPS: int = 10
var _transition_tween: Tween
var _result_tween: Tween
var _active_session_id: String = ""
var _session_request_pending := false
var _slot_spin_pending := false
var _server_active_session_id: String = ""
@export var zone_id: String = "european_vip_casino"

func _ready() -> void:
	add_to_group("city_interactables")
	_build_machine_visual()
	_build_seat()
	_build_interaction_area()
	if AuthoritativeGameServer.is_dedicated_server_requested():
		call_deferred("_register_authoritative_machine")
	else:
		_build_touch_controls()
		if not AuthoritativeGameServer.arcade_session_state_changed.is_connected(_on_arcade_session_state_changed):
			AuthoritativeGameServer.arcade_session_state_changed.connect(_on_arcade_session_state_changed)
		if not AuthoritativeGameServer.arcade_slot_spin_settled.is_connected(_on_authoritative_spin_settled):
			AuthoritativeGameServer.arcade_slot_spin_settled.connect(_on_authoritative_spin_settled)
		if not AuthoritativeGameServer.arcade_slot_spin_failed.is_connected(_on_authoritative_spin_failed):
			AuthoritativeGameServer.arcade_slot_spin_failed.connect(_on_authoritative_spin_failed)

func _process(_delta: float) -> void:
	if is_instance_valid(_seated_player):
		if not _seated_player.is_inside_tree():
			_seated_player = null
			_set_seated_controls(false)
		return
	if not is_instance_valid(_nearby_player):
		return
	if _nearby_player.global_position.distance_to(global_position) > 1.9:
		_nearby_player = null
		_set_nearby_controls(false)

func _build_machine_visual() -> void:
	var dark := _make_material(body_color, 0.48, 0.15)
	var gold := _make_material(accent_color, 0.3, 0.5)
	var screen := _make_material(Color(0.025, 0.055, 0.075), 0.22, 0.0)
	screen.emission_enabled = true
	screen.emission = accent_color.darkened(0.42)
	screen.emission_energy_multiplier = 0.65
	_add_box("MachineCabinet", Vector3(1.05, 1.45, 0.72), Vector3(0, 1.05, 0), dark, true)
	_add_box("LowerGoldTrim", Vector3(1.08, 0.09, 0.76), Vector3(0, 0.42, 0), gold)
	_add_box("UpperGoldTrim", Vector3(1.08, 0.08, 0.76), Vector3(0, 1.76, 0), gold)
	_add_box("ScreenFrame", Vector3(0.91, 0.78, 0.12), Vector3(0, 2.05, 0.405), gold)
	_add_box("ScreenGlass", Vector3(0.78, 0.64, 0.035), Vector3(0, 2.05, 0.48), screen)
	_add_box("LeftSideColumn", Vector3(0.10, 1.35, 0.12), Vector3(-0.47, 1.55, 0.39), gold)
	_add_box("RightSideColumn", Vector3(0.10, 1.35, 0.12), Vector3(0.47, 1.55, 0.39), gold)
	_add_box("TopMarquee", Vector3(0.9, 0.34, 0.18), Vector3(0, 2.66, 0.34), gold)
	_add_box("BaseFoot", Vector3(1.15, 0.16, 0.82), Vector3(0, 0.12, 0), dark, true)

	var title := Label3D.new()
	title.name = "MachineTitle"
	title.text = machine_title.to_upper()
	title.position = Vector3(0, 2.66, 0.445)
	title.rotation.y = PI
	title.font_size = 26
	title.pixel_size = 0.006
	title.modulate = Color(0.12, 0.09, 0.035)
	title.outline_size = 2
	add_child(title)

	var reels := Label3D.new()
	reels.name = "ReelSymbols"
	reels.text = "♛   ♦   ♛"
	reels.position = Vector3(0, 2.08, 0.505)
	reels.rotation.y = PI
	reels.font_size = 48
	reels.pixel_size = 0.006
	reels.modulate = Color(1.0, 0.86, 0.52)
	add_child(reels)

	var subtitle := Label3D.new()
	subtitle.name = "MachineSubtitle"
	subtitle.text = machine_subtitle
	subtitle.position = Vector3(0, 1.38, 0.405)
	subtitle.rotation.y = PI
	subtitle.font_size = 15
	subtitle.pixel_size = 0.006
	subtitle.modulate = accent_color.lightened(0.25)
	add_child(subtitle)

func _build_seat() -> void:
	var seat_root := Node3D.new()
	seat_root.name = "PlayerSeat"
	seat_root.position = Vector3(0, 0, 1.18)
	add_child(seat_root)
	_add_box_to(seat_root, "SeatBase", Vector3(0.82, 0.16, 0.78), Vector3(0, 0.48, 0), _make_material(accent_color.darkened(0.35), 0.72), false)
	_add_box_to(seat_root, "SeatCushion", Vector3(0.78, 0.20, 0.72), Vector3(0, 0.64, 0), _make_material(Color(0.12, 0.075, 0.055), 0.86), false)
	_add_box_to(seat_root, "SeatBack", Vector3(0.78, 0.92, 0.16), Vector3(0, 1.08, 0.30), _make_material(Color(0.12, 0.075, 0.055), 0.86), false)
	_add_box_to(seat_root, "SeatBackCrown", Vector3(0.62, 0.10, 0.19), Vector3(0, 1.56, 0.29), _make_material(accent_color, 0.38), false)
	_seat_anchor = Marker3D.new()
	_seat_anchor.name = "SeatAnchor"
	_seat_anchor.position = Vector3(0, 0, 0.0)
	seat_root.add_child(_seat_anchor)
	_exit_anchor = Marker3D.new()
	_exit_anchor.name = "ExitAnchor"
	_exit_anchor.position = Vector3(0.95, 0, 1.05)
	seat_root.add_child(_exit_anchor)

func _build_interaction_area() -> void:
	var area := Area3D.new()
	area.name = "InteractionArea"
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitoring = true
	var shape_node := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 1.5
	shape_node.shape = shape
	area.add_child(shape_node)
	add_child(area)
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)

func _build_touch_controls() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SlotMachineTouchLayer"
	layer.layer = 32
	add_child(layer)

	var panel := PanelContainer.new()
	panel.name = "SlotMachineControls"
	panel.anchor_left = 0.03
	panel.anchor_right = 0.97
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 0
	panel.offset_right = 0
	panel.offset_top = -306
	panel.offset_bottom = -12
	panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.018, 0.035, 0.065, 0.97)
	panel_style.border_color = accent_color
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel_style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", panel_style)
	layer.add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	panel.add_child(content)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	content.add_child(header)
	var brand := Label.new()
	brand.name = "KingOfEgyptBrand"
	brand.text = "KING OF EGYPT CITY"
	brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 19)
	brand.add_theme_color_override("font_color", Color(1.0, 0.82, 0.38))
	header.add_child(brand)
	_status_label = Label.new()
	_status_label.name = "MachineStatus"
	_status_label.text = machine_title.to_upper()
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.70, 0.82, 0.96))
	content.add_child(_status_label)

	var account_row := HBoxContainer.new()
	account_row.add_theme_constant_override("separation", 8)
	content.add_child(account_row)
	_balance_label = _make_account_card(account_row, "BALANCE", "غير متصل", "BalanceValue")
	_bet_label = _make_account_card(account_row, "BET", str(MIN_BET_CHIPS) + " رقائق", "BetValue")
	_win_label = _make_account_card(account_row, "WIN", "—", "WinValue")

	var minimum_note := Label.new()
	minimum_note.name = "MinimumBetNote"
	minimum_note.text = "الحد الأدنى للرهان: 10 رقائق"
	minimum_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	minimum_note.add_theme_font_size_override("font_size", 12)
	minimum_note.add_theme_color_override("font_color", Color(0.58, 0.78, 1.0))
	content.add_child(minimum_note)

	var camera_hint := Label.new()
	camera_hint.name = "CameraSwipeHint"
	camera_hint.text = "اسحب الشاشة يمينًا ويسارًا لتدوير الرؤية، وأعلى وأسفل لتغيير زاوية الكاميرا"
	camera_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	camera_hint.add_theme_font_size_override("font_size", 11)
	camera_hint.add_theme_color_override("font_color", Color(0.72, 0.82, 0.94))
	content.add_child(camera_hint)

	var action_row := HBoxContainer.new()
	action_row.alignment = BoxContainer.ALIGNMENT_CENTER
	action_row.add_theme_constant_override("separation", 7)
	content.add_child(action_row)

	_decrease_bet_button = _make_blue_button("−")
	_decrease_bet_button.name = "DecreaseBetButton"
	_decrease_bet_button.custom_minimum_size = Vector2(40, 42)
	_decrease_bet_button.disabled = true
	action_row.add_child(_decrease_bet_button)
	_increase_bet_button = _make_blue_button("+")
	_increase_bet_button.name = "IncreaseBetButton"
	_increase_bet_button.custom_minimum_size = Vector2(46, 44)
	_increase_bet_button.disabled = true
	action_row.add_child(_increase_bet_button)
	_max_bet_button = _make_blue_button("MAX")
	_max_bet_button.name = "MaxBetButton"
	_max_bet_button.custom_minimum_size = Vector2(52, 42)
	_max_bet_button.disabled = true
	action_row.add_child(_max_bet_button)

	_spin_button = _make_button("SPIN", _on_spin_pressed)
	_spin_button.name = "SpinButton"
	_spin_button.custom_minimum_size = Vector2(100, 46)
	_spin_button.disabled = true
	_spin_button.tooltip_text = "يتاح بعد اكتمال لعبة السلوت والتحقق الخادمي من النتيجة."
	_style_action_button(_spin_button, Color(0.025, 0.20, 0.075), Color(0.12, 0.78, 0.30))
	action_row.add_child(_spin_button)

	_auto_button = _make_button("AUTO", _on_auto_pressed)
	_auto_button.name = "AutoButton"
	_auto_button.custom_minimum_size = Vector2(68, 42)
	_auto_button.disabled = true
	_auto_button.tooltip_text = "اللعب التلقائي غير متاح قبل ربط المتحكم الخادمي."
	_style_action_button(_auto_button, Color(0.24, 0.025, 0.025), Color(0.88, 0.12, 0.12))
	action_row.add_child(_auto_button)

	var secondary_row := HBoxContainer.new()
	secondary_row.alignment = BoxContainer.ALIGNMENT_CENTER
	secondary_row.add_theme_constant_override("separation", 8)
	content.add_child(secondary_row)
	_exit_button = _make_button("🚪 مغادرة المقعد", _on_exit_pressed)
	_exit_button.name = "LeaveSeatButton"
	_exit_button.custom_minimum_size = Vector2(140, 40)
	_style_action_button(_exit_button, Color(0.025, 0.10, 0.23), Color(0.12, 0.38, 0.68))
	secondary_row.add_child(_exit_button)
	_enter_button = _make_button("✋ اجلس أمام الماكينة", _on_enter_pressed)
	_enter_button.custom_minimum_size = Vector2(160, 40)
	_style_action_button(_enter_button, Color(0.025, 0.10, 0.23), Color(0.25, 0.58, 0.92))
	secondary_row.add_child(_enter_button)
	_set_nearby_controls(false)

func _make_account_card(parent: HBoxContainer, caption: String, initial_value: String, node_name: String) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.035, 0.075, 0.12, 0.98)
	card_style.border_color = accent_color.darkened(0.12)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(9)
	card_style.set_content_margin_all(7)
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)
	var label := Label.new()
	label.name = node_name
	label.text = caption + "\n" + initial_value
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.62))
	card.add_child(label)
	return label

func _style_action_button(button: Button, background: Color, border: Color) -> void:
	button.add_theme_stylebox_override("normal", _make_spin_style(background, border))
	button.add_theme_stylebox_override("hover", _make_spin_style(background.lightened(0.12), border.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _make_spin_style(background.darkened(0.12), border))
	button.add_theme_stylebox_override("disabled", _make_spin_style(background, border.darkened(0.30)))
	button.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.48, 0.58, 0.68))

func _make_account_line(parent: VBoxContainer, caption: String, initial_value: String) -> Label:
	var line := Label.new()
	line.name = caption.capitalize() + "Value"
	line.text = caption + " : " + initial_value
	line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line.add_theme_font_size_override("font_size", 13)
	parent.add_child(line)
	return line

func _make_blue_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(76, 38)
	button.add_theme_font_size_override("font_size", 15)
	var blue := Color(0.12, 0.48, 0.88)
	var dark_blue := Color(0.025, 0.12, 0.27)
	button.add_theme_stylebox_override("normal", _make_spin_style(dark_blue, blue))
	button.add_theme_stylebox_override("hover", _make_spin_style(dark_blue.lightened(0.12), blue.lightened(0.12)))
	button.add_theme_stylebox_override("pressed", _make_spin_style(dark_blue.darkened(0.1), blue))
	button.add_theme_stylebox_override("disabled", _make_spin_style(dark_blue, blue.darkened(0.35)))
	button.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0))
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.55, 0.68))
	return button

func _make_button(label: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(190, 40)
	button.add_theme_font_size_override("font_size", 14)
	button.pressed.connect(callback)
	return button

func _make_spin_style(background: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(8)
	return style

func _apply_spin_mode_visual(auto_mode: bool) -> void:
	# حالة العرض فقط؛ لا يبدأ هذا التبديل جولات أو يخصم رقائق.
	if is_instance_valid(_spin_button):
		_style_action_button(_spin_button, Color(0.025, 0.20, 0.075), Color(0.12, 0.78, 0.30))
		_spin_button.text = "SPIN"
	if is_instance_valid(_auto_button):
		_style_action_button(_auto_button, Color(0.24, 0.025, 0.025), Color(0.88, 0.12, 0.12))
		_auto_button.text = "AUTO" if auto_mode else "AUTO"

func set_auto_play_mode_visual(auto_mode: bool) -> void:
	# Visual state only: trusted server controller must own auto-play.
	_apply_spin_mode_visual(auto_mode)
	if is_instance_valid(_status_label):
		_status_label.text = "وضع AUTO (عرض فقط)" if auto_mode else machine_title.to_upper()

func _on_auto_pressed() -> void:
	# AUTO remains disabled until a separately rate-limited server scheduler is implemented.
	if is_instance_valid(_status_label):
		_status_label.text = "اللعب التلقائي غير متاح حاليًا."

func _set_nearby_controls(visible_now: bool) -> void:
	var panel := get_node_or_null("SlotMachineTouchLayer/SlotMachineControls") as PanelContainer
	if not is_instance_valid(panel):
		return
	panel.visible = visible_now
	if is_instance_valid(_enter_button):
		_enter_button.visible = visible_now
	if is_instance_valid(_spin_button):
		_spin_button.visible = false
	if is_instance_valid(_auto_button):
		_auto_button.visible = false
	if is_instance_valid(_exit_button):
		_exit_button.visible = false

func _set_seated_controls(seated: bool) -> void:
	var panel := get_node_or_null("SlotMachineTouchLayer/SlotMachineControls") as PanelContainer
	if not is_instance_valid(panel):
		return
	panel.visible = seated
	_enter_button.visible = false
	_spin_button.visible = seated
	_spin_button.disabled = not seated or _active_session_id.is_empty() or _slot_spin_pending
	_auto_button.visible = seated
	_exit_button.visible = seated
	if is_instance_valid(_status_label):
		_status_label.text = "أنت جالس أمام " + machine_title if seated else machine_title

func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body is CharacterBody3D:
		_nearby_player = body as CharacterBody3D
		_set_nearby_controls(true)

func _on_body_exited(body: Node3D) -> void:
	if body == _nearby_player and body != _seated_player:
		_nearby_player = null
		_set_nearby_controls(false)

func _on_enter_pressed() -> void:
	if not is_instance_valid(_nearby_player) or is_instance_valid(_seated_player) or _session_request_pending:
		return
	var player := _nearby_player
	if bool(player.get("animal_riding")) or bool(player.get("arcade_seated")) or bool(player.get("sitting")):
		return
	if not AuthoritativeGameServer.is_authenticated():
		_status_label.text = "سجّل الدخول أولًا لبدء جلسة الماكينة."
		return
	_session_request_pending = true
	_status_label.text = "جارٍ التحقق من جلسة الماكينة..."
	AuthoritativeGameServer.request_start_arcade_session(machine_id, "solo")


func _seat_local_player() -> void:
	if not is_instance_valid(_nearby_player) or is_instance_valid(_seated_player):
		return
	var player := _nearby_player
	_seated_player = player
	_nearby_player = null
	if player.has_method("set_arcade_seated"):
		player.call("set_arcade_seated", true)
	var target_position := _seat_anchor.global_position
	var target_rotation := global_rotation.y
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(player, "global_position", target_position, 0.42)
	_transition_tween.parallel().tween_property(player, "rotation:y", target_rotation, 0.42)
	_transition_tween.tween_callback(func():
		if is_instance_valid(player) and player.has_method("sit_at_position"):
			player.call("sit_at_position", target_position, target_rotation)
	)
	_set_seated_controls(true)
	_spin_button.disabled = false
	_status_label.text = "الجلسة متصلة بالخادم — " + machine_title


func _on_arcade_session_state_changed(session_id: String, state: String, received_machine_id: String, message: String) -> void:
	if received_machine_id != machine_id:
		return
	if state == "running":
		_session_request_pending = false
		_active_session_id = session_id
		_seat_local_player()
	elif state in ["rejected", "unavailable", "aborted"]:
		_session_request_pending = false
		_active_session_id = ""
		_slot_spin_pending = false
		if is_instance_valid(_status_label):
			_status_label.text = message
		if is_instance_valid(_spin_button):
			_spin_button.disabled = true


func _on_spin_pressed() -> void:
	if _active_session_id.is_empty() or _slot_spin_pending or not is_instance_valid(_seated_player):
		return
	_slot_spin_pending = true
	_spin_button.disabled = true
	_status_label.text = "جارٍ اعتماد اللفة على الخادم..."
	AuthoritativeGameServer.request_arcade_slot_spin("paid", MIN_BET_CHIPS)


func _on_authoritative_spin_settled(session_id: String, result: Dictionary) -> void:
	if session_id != _active_session_id:
		return
	_slot_spin_pending = false
	var balance := int(result.get("balance_after", 0))
	var gross_return := int(result.get("gross_return_chips", 0))
	var free_spins := int(result.get("free_spins_balance", 0))
	var progress := int(result.get("challenge_progress", 0))
	var awarded := int(result.get("free_spins_awarded", 0))
	_balance_label.text = "BALANCE\n%d رقائق" % balance
	_win_label.text = "WIN\n%d رقائق" % gross_return
	_status_label.text = "تم اعتماد اللفة — اللفات المجانية: %d — التحدي: %d/15" % [free_spins, progress]
	if awarded > 0:
		_status_label.text += " — حصلت على %d لفات مجانية!" % awarded
	_spin_button.disabled = false


func _on_authoritative_spin_failed(session_id: String, message: String) -> void:
	if session_id != _active_session_id:
		return
	_slot_spin_pending = false
	_status_label.text = "تعذر تنفيذ اللفة: " + message
	_spin_button.disabled = false


func _register_authoritative_machine() -> void:
	if not AuthoritativeGameServer.is_dedicated_server_requested():
		return
	if not AuthoritativeGameServer.register_arcade_machine(machine_id, zone_id, self, self):
		push_warning("Could not register authoritative slot machine: " + machine_id)


func can_start_arcade_session(user_id: String, mode: String) -> bool:
	return AuthoritativeGameServer.is_dedicated_server_requested() and not user_id.is_empty() and mode == "solo" and _server_active_session_id.is_empty()


func can_join_arcade_session(_user_id: String, _mode: String, _participant_count: int) -> bool:
	return false


func start_arcade_session(session_id: String, mode: String, participants: Dictionary) -> bool:
	if not AuthoritativeGameServer.is_dedicated_server_requested() or mode != "solo" or session_id.is_empty() or participants.size() != 1 or not _server_active_session_id.is_empty():
		return false
	_server_active_session_id = session_id
	return true


func validate_arcade_session_result(session_id: String, mode: String, participants: Dictionary, _server_results: Dictionary, elapsed_usec: int) -> bool:
	return AuthoritativeGameServer.is_dedicated_server_requested() and session_id == _server_active_session_id and mode == "solo" and participants.size() == 1 and elapsed_usec > 0


func abort_arcade_session(session_id: String, _reason: String) -> void:
	if session_id == _server_active_session_id:
		_server_active_session_id = ""

func _on_exit_pressed() -> void:
	if not is_instance_valid(_seated_player):
		return
	if not _active_session_id.is_empty():
		AuthoritativeGameServer.request_leave_arcade_session(_active_session_id)
	_active_session_id = ""
	_slot_spin_pending = false
	_session_request_pending = false
	var player := _seated_player
	_seated_player = null
	var target_position := _exit_anchor.global_position
	var target_rotation := global_rotation.y
	if _transition_tween and _transition_tween.is_running():
		_transition_tween.kill()
	_transition_tween = create_tween()
	_transition_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(player, "global_position", target_position, 0.32)
	_transition_tween.parallel().tween_property(player, "rotation:y", target_rotation, 0.32)
	_transition_tween.tween_callback(func():
		if is_instance_valid(player) and player.has_method("end_arcade_seat"):
			player.call("end_arcade_seat", target_position, target_rotation)
		elif is_instance_valid(player):
			player.set("sitting", false)
		_nearby_player = player
		_set_nearby_controls(true)
	)
	_set_seated_controls(false)

func play_server_result(outcome: String) -> void:
	# This entry point is intentionally callable only by the trusted game controller.
	if not is_instance_valid(_seated_player) or not ["win", "loss"].has(outcome):
		return
	var avatar := _seated_player.get_node_or_null("AvatarVisual")
	if is_instance_valid(avatar) and avatar.has_method("set_motion_state"):
		avatar.call("set_motion_state", "celebrate" if outcome == "win" else "disappointed", 0.0)
	if is_instance_valid(_status_label):
		_status_label.text = "مبروك! فوز" if outcome == "win" else "لم يحالفك الحظ هذه المرة"
	if _result_tween and _result_tween.is_running():
		_result_tween.kill()
	_result_tween = create_tween()
	_result_tween.tween_interval(2.0)
	_result_tween.tween_callback(func():
		if is_instance_valid(avatar) and avatar.has_method("set_motion_state"):
			avatar.call("set_motion_state", "sit", 0.0)
	)

func _add_box(node_name: String, size: Vector3, position: Vector3, material: Material, collision: bool = false) -> void:
	_add_box_to(self, node_name, size, position, material, collision)

func _add_box_to(parent: Node3D, node_name: String, size: Vector3, position: Vector3, material: Material, collision: bool = false) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
	if collision:
		var body := StaticBody3D.new()
		body.name = node_name + "Collision"
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.position = position
		body.add_child(shape_node)
		add_child(body)

func _make_material(color: Color, roughness: float = 0.6, metallic: float = 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	return material
