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
var _exit_button: Button
var _status_label: Label
var _transition_tween: Tween
var _result_tween: Tween

func _ready() -> void:
	add_to_group("city_interactables")
	_build_machine_visual()
	_build_seat()
	_build_interaction_area()
	if not AuthoritativeGameServer.is_dedicated_server_requested():
		_build_touch_controls()

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
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = -224
	panel.offset_right = -10
	panel.offset_top = -176
	panel.offset_bottom = -10
	panel.visible = false
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.96)
	style.border_color = accent_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)
	_status_label = Label.new()
	_status_label.text = machine_title
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(_status_label)
	_enter_button = _make_button("✋ اجلس أمام الماكينة", _on_enter_pressed)
	_enter_button.modulate = Color(0.55, 0.78, 1.0)
	content.add_child(_enter_button)
	_spin_button = _make_button("SPIN — قريبًا", _on_spin_pressed)
	_spin_button.name = "SpinButton"
	_spin_button.disabled = true
	_spin_button.tooltip_text = "يتاح بعد اكتمال لعبة السلوت والتحقق الخادمي من النتيجة."
	content.add_child(_spin_button)
	_apply_spin_mode_visual(false)
	_exit_button = _make_button("🚪 خروج من المقعد", _on_exit_pressed)
	content.add_child(_exit_button)
	panel.set_meta("controls_content", content)
	_set_nearby_controls(false)

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
	if not is_instance_valid(_spin_button):
		return
	var active_color := Color(0.12, 0.78, 0.30) if not auto_mode else Color(0.88, 0.12, 0.12)
	var dark_color := Color(0.025, 0.20, 0.075) if not auto_mode else Color(0.24, 0.025, 0.025)
	_spin_button.text = "AUTO" if auto_mode else "SPIN"
	_spin_button.add_theme_stylebox_override("normal", _make_spin_style(dark_color, active_color))
	_spin_button.add_theme_stylebox_override("hover", _make_spin_style(dark_color.lightened(0.12), active_color.lightened(0.12)))
	_spin_button.add_theme_stylebox_override("pressed", _make_spin_style(dark_color.darkened(0.12), active_color))
	_spin_button.add_theme_stylebox_override("disabled", _make_spin_style(dark_color, active_color))
	_spin_button.add_theme_color_override("font_color", active_color.lightened(0.35))
	_spin_button.add_theme_color_override("font_hover_color", Color.WHITE)
	_spin_button.add_theme_color_override("font_pressed_color", Color.WHITE)
	_spin_button.add_theme_color_override("font_disabled_color", active_color.lightened(0.35))

func set_auto_play_mode_visual(auto_mode: bool) -> void:
	# Visual state only: this does not start or stop rounds; the trusted server controller must own auto-play.
	_apply_spin_mode_visual(auto_mode)

func _set_nearby_controls(visible_now: bool) -> void:
	var panel := get_node_or_null("SlotMachineTouchLayer/SlotMachineControls") as PanelContainer
	if not is_instance_valid(panel):
		return
	panel.visible = visible_now
	if is_instance_valid(_enter_button):
		_enter_button.visible = visible_now
	if is_instance_valid(_spin_button):
		_spin_button.visible = false
	if is_instance_valid(_exit_button):
		_exit_button.visible = false

func _set_seated_controls(seated: bool) -> void:
	var panel := get_node_or_null("SlotMachineTouchLayer/SlotMachineControls") as PanelContainer
	if not is_instance_valid(panel):
		return
	panel.visible = seated
	_enter_button.visible = false
	_spin_button.visible = seated
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
	if not is_instance_valid(_nearby_player) or is_instance_valid(_seated_player):
		return
	var player := _nearby_player
	if bool(player.get("animal_riding")) or bool(player.get("arcade_seated")):
		return
	if bool(player.get("sitting")):
		return
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

func _on_spin_pressed() -> void:
	# No client-side spin or result is permitted before a trusted server game controller exists.
	if is_instance_valid(_status_label):
		_status_label.text = "اللعبة قيد التجهيز والتحقق الخادمي."

func _on_exit_pressed() -> void:
	if not is_instance_valid(_seated_player):
		return
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
