extends Node
## نظام موحد للتفاعل والتنقل عبر بوابات سفينة الحضارات الخمس.
## يستخدم زر التفاعل الحالي وشاشة التحميل الموجودة في Main.

const SHIP_WORLD_POSITION := Vector3(1000.0, 0.0, 1000.0)
const BEACH_RETURN_POSITION := Vector3(0.0, 1.1, 234.0)
const GOLD := Color(0.82, 0.63, 0.29)
const STONE := Color(0.70, 0.61, 0.46)
const DARK := Color(0.055, 0.105, 0.12)

var city: Node3D
var player: CharacterBody3D
var menu_layer: CanvasLayer
var menu_panel: PanelContainer
var menu_title: Label
var menu_subtitle: Label
var menu_list: VBoxContainer
var menu_scroll: ScrollContainer
var active_gate: Node3D
var ship_interior: Node3D
var ship_current_location := "ship_hall"
var ship_transition_busy := false
var wing_spawns: Dictionary = {}
var wing_titles := {
	"wing_greek": "الجناح اليوناني",
	"wing_roman": "الجناح الروماني",
	"wing_japanese": "الجناح الياباني",
	"wing_chinese": "الجناح الصيني",
	"wing_french": "الجناح الفرنسي"
}
var wing_colors := {
	"wing_greek": Color(0.72, 0.82, 0.88),
	"wing_roman": Color(0.58, 0.30, 0.24),
	"wing_japanese": Color(0.50, 0.22, 0.20),
	"wing_chinese": Color(0.68, 0.20, 0.12),
	"wing_french": Color(0.35, 0.48, 0.66)
}

func _ready() -> void:
	set_process_unhandled_key_input(true)
	city = get_parent() as Node3D
	player = city.get_node_or_null("Player") as CharacterBody3D
	_create_menu()
	get_viewport().size_changed.connect(_fit_menu_to_viewport)
	_fit_menu_to_viewport()
	_create_beach_portal()

func _process(_delta: float) -> void:
	# لا تستخدم مراجع المدينة أو اللاعب بعد خروجها من المشهد أو بدء حذفها.
	if not is_instance_valid(city) or city.is_queued_for_deletion() or not city.is_inside_tree():
		_close_menu()
		return
	if not is_instance_valid(player) or player.is_queued_for_deletion() or not player.is_inside_tree():
		player = city.get_node_or_null("Player") as CharacterBody3D
	if is_instance_valid(menu_panel) and menu_panel.visible:
		var player_ready := is_instance_valid(player) and not player.is_queued_for_deletion() and player.is_inside_tree()
		var gate_ready := is_instance_valid(active_gate) and not active_gate.is_queued_for_deletion() and active_gate.is_inside_tree()
		if not player_ready or not gate_ready:
			_close_menu()
			return
		if player.global_position.distance_to(active_gate.global_position) > 6.0:
			_close_menu()

func _create_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.name = "QuickTravelLayer"
	menu_layer.layer = 35
	add_child(menu_layer)
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.015, 0.025, 0.03, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.visible = false
	dim.gui_input.connect(_on_dim_input)
	menu_layer.add_child(dim)
	menu_panel = PanelContainer.new()
	menu_panel.name = "QuickTravelPanel"
	menu_panel.set_anchors_preset(Control.PRESET_CENTER)
	menu_panel.position = Vector2(-205, -245)
	menu_panel.size = Vector2(410, 490)
	menu_panel.custom_minimum_size = Vector2.ZERO
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.075, 0.08, 0.98)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	menu_panel.add_theme_stylebox_override("panel", style)
	menu_panel.visible = false
	menu_layer.add_child(menu_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	menu_panel.add_child(column)
	menu_title = Label.new()
	menu_title.text = "التنقل السريع"
	menu_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_title.add_theme_font_size_override("font_size", 24)
	menu_title.add_theme_color_override("font_color", GOLD)
	column.add_child(menu_title)
	menu_subtitle = Label.new()
	menu_subtitle.text = "اختر الوجهة المتاحة من البوابة"
	menu_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_subtitle.add_theme_color_override("font_color", Color(0.86, 0.84, 0.76))
	column.add_child(menu_subtitle)
	var separator := HSeparator.new()
	column.add_child(separator)
	menu_scroll = ScrollContainer.new()
	menu_scroll.name = "DestinationScroll"
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(menu_scroll)
	menu_list = VBoxContainer.new()
	menu_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_list.add_theme_constant_override("separation", 7)
	menu_scroll.add_child(menu_list)
	var close := Button.new()
	close.name = "CloseButton"
	close.text = "إغلاق"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(_close_menu)
	column.add_child(close)

func _fit_menu_to_viewport() -> void:
	if not is_instance_valid(menu_panel) or not is_instance_valid(menu_title):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	# لا نفرض حدًا أدنى أكبر من الشاشة؛ هذا يمنع قص النافذة في الشاشات الصغيرة أو الوضع الأفقي.
	var panel_width := minf(410.0, maxf(1.0, viewport_size.x - 28.0))
	var panel_height := minf(490.0, maxf(1.0, viewport_size.y - 48.0))
	menu_panel.size = Vector2(panel_width, panel_height)
	menu_panel.position = -menu_panel.size * 0.5
	var compact_layout := viewport_size.y < 560.0
	menu_title.add_theme_font_size_override("font_size", 20 if compact_layout else 24)
	var close_button := menu_panel.get_node_or_null("VBoxContainer/CloseButton") as Button
	if is_instance_valid(close_button):
		close_button.custom_minimum_size.y = 42.0 if compact_layout else 46.0
	# حدّث أزرار الوجهات المفتوحة أيضًا عند تدوير الهاتف أو تغيير حجم النافذة.
	if is_instance_valid(menu_list):
		for child in menu_list.get_children():
			if child is Button:
				child.custom_minimum_size.y = 44.0 if compact_layout else 52.0
				child.add_theme_font_size_override("font_size", 16 if compact_layout else 18)

func _on_dim_input(event: InputEvent) -> void:
	# هذه الإشارة تصل عند الضغط على طبقة التعتيم خارج لوحة القائمة.
	if event is InputEventMouseButton and event.pressed:
		_close_menu()
	elif event is InputEventScreenTouch and event.pressed:
		_close_menu()

func _unhandled_key_input(event: InputEvent) -> void:
	# التقاط Escape بأمان حتى إذا أزيلت لوحة التنقل أثناء تبديل المشهد.
	if is_instance_valid(menu_panel) and menu_panel.visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_close_menu()
		get_viewport().set_input_as_handled()

func _create_beach_portal() -> void:
	var portal := Node3D.new()
	portal.name = "FiveCivilizationsShipBeachGate"
	portal.add_to_group("city_world_geometry")
	portal.position = Vector3(0, 0.1, 238)
	city.add_child(portal)
	var ring := MeshInstance3D.new()
	ring.name = "CircularShipEntryMark"
	var torus := TorusMesh.new()
	torus.inner_radius = 2.0
	torus.outer_radius = 2.35
	torus.rings = 48
	torus.ring_segments = 12
	ring.mesh = torus
	ring.position.y = 2.0
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = GOLD
	ring_mat.metallic = 0.55
	ring_mat.roughness = 0.3
	ring_mat.emission_enabled = true
	ring_mat.emission = Color(0.45, 0.27, 0.08)
	ring_mat.emission_energy_multiplier = 0.65
	ring.material_override = ring_mat
	portal.add_child(ring)
	var base := MeshInstance3D.new()
	base.name = "PortalGroundMark"
	var disk := CylinderMesh.new()
	disk.top_radius = 3.0
	disk.bottom_radius = 3.0
	disk.height = 0.16
	base.mesh = disk
	base.position.y = 0.1
	base.material_override = _make_material(DARK)
	portal.add_child(base)
	var gate := _make_gate("ship_exterior", "بوابة سفينة الحضارات الخمس", "ship_exterior", portal)
	gate.position = Vector3(0, 0, 0)

func _make_gate(id: String, title: String, location: String, parent: Node3D) -> Node3D:
	var gate := Node3D.new()
	gate.name = "Gate_" + id
	gate.set_script(load("res://scripts/quick_travel_gate.gd"))
	gate.set("gate_id", id)
	gate.set("gate_title", title)
	gate.set("location_id", location)
	gate.set("interaction_radius", 4.6)
	parent.add_child(gate)
	return gate

func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.84
	return material

func open_for_gate(gate: Node3D) -> void:
	if ship_transition_busy or not is_instance_valid(gate) or not is_instance_valid(player):
		return
	if gate.is_queued_for_deletion() or not gate.is_inside_tree() or not gate.has_method("get_quick_travel_data"):
		return
	if not player.is_inside_tree():
		return
	if not is_instance_valid(menu_layer) or not is_instance_valid(menu_panel) or not is_instance_valid(menu_list) or not is_instance_valid(menu_scroll):
		return
	var dim := menu_layer.get_node_or_null("Dim") as ColorRect
	if not is_instance_valid(dim):
		return
	var data: Dictionary = gate.get_quick_travel_data()
	var location_id := str(data.get("location_id", ""))
	if location_id != "ship_exterior" and location_id != "ship_hall" and not wing_titles.has(location_id):
		return
	active_gate = gate
	menu_title.text = "التنقل السريع"
	menu_subtitle.text = "الموقع الحالي: %s" % _location_title(location_id)
	for child in menu_list.get_children():
		child.queue_free()
	var options: Array[Dictionary] = []
	if location_id == "ship_exterior":
		options.append({"id": "ship_hall", "label": "دخول سفينة الحضارات الخمس"})
	elif location_id == "ship_hall":
		for wing_id in wing_titles.keys():
			options.append({"id": wing_id, "label": "دخول " + str(wing_titles[wing_id])})
		options.append({"id": "beach", "label": "الخروج إلى الشاطئ"})
	else:
		options.append({"id": "ship_hall", "label": "العودة إلى القاعة الرئيسية"})
		options.append({"id": "beach", "label": "الخروج إلى الشاطئ"})
	for option in options:
		var button := Button.new()
		button.text = _destination_button_text(str(option.id), str(option.label))
		var compact_layout := get_viewport().get_visible_rect().size.y < 560.0
		button.custom_minimum_size = Vector2(0, 44 if compact_layout else 52)
		button.add_theme_font_size_override("font_size", 16 if compact_layout else 18)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		button.add_theme_color_override("font_color", Color(0.94, 0.90, 0.79))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.84))
		button.add_theme_color_override("font_pressed_color", GOLD)
		var normal := StyleBoxFlat.new()
		normal.bg_color = Color(0.10, 0.14, 0.14, 0.98)
		normal.border_color = Color(0.42, 0.34, 0.21)
		normal.set_border_width_all(1)
		normal.set_corner_radius_all(9)
		normal.content_margin_left = 14
		normal.content_margin_right = 14
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(0.16, 0.19, 0.17, 1.0)
		hover.border_color = GOLD
		var pressed := normal.duplicate() as StyleBoxFlat
		pressed.bg_color = Color(0.19, 0.16, 0.10, 1.0)
		pressed.border_color = GOLD
		button.add_theme_stylebox_override("normal", normal)
		button.add_theme_stylebox_override("hover", hover)
		button.add_theme_stylebox_override("pressed", pressed)
		button.add_theme_stylebox_override("focus", hover)
		button.pressed.connect(_select_destination.bind(str(option.id)))
		menu_list.add_child(button)
	# ابدأ كل مرة من أول الوجهات حتى لا تُفتح القائمة في موضع تمرير قديم.
	menu_scroll.scroll_vertical = 0
	dim.visible = true
	menu_panel.visible = true
	# يسهّل التنقل بلوحة المفاتيح فور فتح القائمة دون الحاجة إلى تحديد زر يدويًا.
	if menu_list.get_child_count() > 0:
		var first_destination := menu_list.get_child(0) as Button
		if is_instance_valid(first_destination):
			first_destination.grab_focus()

func _destination_button_text(destination_id: String, label_text: String) -> String:
	var symbol := "◆"
	match destination_id:
		"ship_hall":
			symbol = "⚓"
		"wing_greek":
			symbol = "🏛"
		"wing_roman":
			symbol = "♜"
		"wing_japanese":
			symbol = "⛩"
		"wing_chinese":
			symbol = "☯"
		"wing_french":
			symbol = "⚜"
		"beach":
			symbol = "⇦"
	return "%s   %s" % [symbol, label_text]

func _location_title(location_id: String) -> String:
	if location_id == "ship_exterior":
		return "الشاطئ أمام السفينة"
	if location_id == "ship_hall":
		return "القاعة الرئيسية للسفينة"
	return str(wing_titles.get(location_id, "السفينة"))

func _close_menu() -> void:
	if is_instance_valid(menu_panel):
		menu_panel.visible = false
	if is_instance_valid(menu_layer):
		var dim := menu_layer.get_node_or_null("Dim") as ColorRect
		if is_instance_valid(dim):
			dim.visible = false
	active_gate = null

func _select_destination(destination_id: String) -> void:
	if ship_transition_busy or not is_instance_valid(active_gate):
		return
	_close_menu()
	if destination_id == "ship_hall":
		if not is_instance_valid(ship_interior):
			await _enter_ship()
		else:
			await _move_inside_ship("ship_hall")
	elif destination_id == "beach":
		await _exit_ship_to_beach()
	elif wing_titles.has(destination_id):
		if not is_instance_valid(ship_interior):
			return
		await _move_inside_ship(destination_id)

func _enter_ship() -> void:
	if ship_transition_busy or not is_instance_valid(city) or not city.is_inside_tree() or not is_instance_valid(player) or not player.is_inside_tree():
		return
	ship_transition_busy = true
	city.set("interior_transition_busy", true)
	city.set("interior_player", player)
	city.set("interior_return_transform", player.global_transform)
	player.set_physics_process(false)
	city.call("_show_interior_loading", false, "interior_loading")
	await get_tree().create_timer(0.65).timeout
	if not is_inside_tree() or not is_instance_valid(city) or not city.is_inside_tree() or not is_instance_valid(player) or not player.is_inside_tree():
		_abort_ship_transition()
		return
	city.call("_set_city_world_hidden", true)
	ship_interior = _build_ship_interior()
	city.set("interior_root", ship_interior)
	ship_current_location = "ship_hall"
	player.global_position = SHIP_WORLD_POSITION + Vector3(0, 1.1, 7.0)
	player.rotation.y = PI
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	city.set("interior_transition_busy", false)
	ship_transition_busy = false
	city.call("_hide_interior_loading")

func _exit_ship_to_beach() -> void:
	if ship_transition_busy or not is_instance_valid(city) or not city.is_inside_tree() or not is_instance_valid(ship_interior) or not is_instance_valid(player) or not player.is_inside_tree():
		return
	ship_transition_busy = true
	city.set("interior_transition_busy", true)
	player.set_physics_process(false)
	city.call("_show_interior_loading", false, "interior_return_loading")
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree() or not is_instance_valid(city) or not is_instance_valid(player) or not is_instance_valid(ship_interior):
		_abort_ship_transition()
		return
	ship_interior.queue_free()
	ship_interior = null
	city.set("interior_root", null)
	city.call("_set_city_world_hidden", false)
	player.global_position = BEACH_RETURN_POSITION
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	city.set("interior_player", null)
	city.set("interior_transition_busy", false)
	ship_current_location = "ship_exterior"
	ship_transition_busy = false
	city.call("_hide_interior_loading")
	_refresh_city_interactions()

func _move_inside_ship(location_id: String) -> void:
	if ship_transition_busy or not is_instance_valid(city) or not city.is_inside_tree() or not is_instance_valid(ship_interior) or not is_instance_valid(player) or not player.is_inside_tree():
		return
	ship_transition_busy = true
	city.set("interior_transition_busy", true)
	player.set_physics_process(false)
	city.call("_show_interior_loading", false, "interior_loading")
	await get_tree().create_timer(0.4).timeout
	if not is_inside_tree() or not is_instance_valid(city) or not is_instance_valid(player) or not is_instance_valid(ship_interior):
		_abort_ship_transition()
		return
	ship_current_location = location_id
	var destination: Vector3 = wing_spawns.get(location_id, SHIP_WORLD_POSITION + Vector3(0, 1.1, 7.0))
	player.global_position = destination
	if wing_titles.has(location_id):
		player.rotation.y = PI
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	city.set("interior_transition_busy", false)
	ship_transition_busy = false
	city.call("_show_interior_loading", true)
	_refresh_city_interactions()

func _abort_ship_transition() -> void:
	# استعادة حالة المدينة واللاعب إذا تعذر إكمال الانتقال بعد شاشة التحميل.
	ship_transition_busy = false
	if is_instance_valid(city):
		city.set("interior_transition_busy", false)
		city.set("interior_player", null)
		city.call("_hide_interior_loading")
	if is_instance_valid(player):
		player.set_physics_process(true)
	# إذا كانت السفينة موجودة بالفعل، لا تترك عالم المدينة مخفيًا بعد إلغاء الانتقال.
	if is_instance_valid(city) and is_instance_valid(ship_interior):
		city.call("_set_city_world_hidden", true)
	elif is_instance_valid(city):
		city.call("_set_city_world_hidden", false)
		city.set("interior_root", null)
		ship_current_location = "ship_exterior"

func _refresh_city_interactions() -> void:
	# قد تنتهي عملية الانتقال أثناء إزالة المدينة؛ لا تحدّث واجهة التفاعل إلا إذا بقيت العقد صالحة.
	if not is_instance_valid(city) or not city.is_inside_tree():
		return
	var manager := city.get_node_or_null("MissionManager")
	if is_instance_valid(manager) and not manager.is_queued_for_deletion():
		manager.call("_update_interaction_target")
		manager.call("_update_interaction_hud")

func _build_ship_interior() -> Node3D:
	var root := Node3D.new()
	root.name = "FiveCivilizationsShipInterior"
	root.position = SHIP_WORLD_POSITION
	root.set_meta("five_civilizations_ship", true)
	city.add_child(root)
	_add_ship_box(root, "MainHallFloor", Vector3(42, 0.35, 34), Vector3(0, 0, 0), STONE, true)
	_add_ship_box(root, "MainHallRearWall", Vector3(42, 5, 0.5), Vector3(0, 2.5, -17), DARK, true)
	_add_ship_box(root, "MainHallLeftWall", Vector3(0.5, 5, 34), Vector3(-21, 2.5, 0), DARK, true)
	_add_ship_box(root, "MainHallRightWall", Vector3(0.5, 5, 34), Vector3(21, 2.5, 0), DARK, true)
	_add_ship_box(root, "HallGoldBand", Vector3(40, 0.22, 0.3), Vector3(0, 3.7, -16.7), GOLD)
	_add_ship_box(root, "HallDisplayBase", Vector3(4.8, 0.55, 4.8), Vector3(0, 0.45, -3), GOLD)
	_add_ship_box(root, "HallDisplayColumn", Vector3(1.1, 2.5, 1.1), Vector3(0, 1.9, -3), Color(0.82, 0.70, 0.43))
	_add_ship_sphere(root, "FiveCivilizationsGoldenEmblem", 0.9, Vector3(0, 3.55, -3), GOLD)
	var hall_gate := _make_gate("ship_hall", "بوابة القاعة الرئيسية", "ship_hall", root)
	hall_gate.position = Vector3(0, 0, 13)
	# البوابات الحضارية الخمس مجتمعة داخل القاعة الرئيسية فقط.
	var ids := ["wing_greek", "wing_roman", "wing_japanese", "wing_chinese", "wing_french"]
	for index in range(ids.size()):
		var id: String = ids[index]
		var x := -16.0 + float(index) * 8.0
		var color: Color = wing_colors[id]
		_add_ship_box(root, "WingPortalFrame_" + id, Vector3(5.8, 4.4, 0.45), Vector3(x, 2.2, 8.0), GOLD, true)
		_add_ship_box(root, "WingPortalDark_" + id, Vector3(4.7, 3.5, 0.18), Vector3(x, 1.95, 7.72), DARK)
		_add_ship_box(root, "WingPortalAccent_" + id, Vector3(4.1, 0.12, 0.12), Vector3(x, 3.75, 7.58), color)
		var label := Label3D.new()
		label.text = str(wing_titles[id])
		label.position = Vector3(x, 4.8, 7.7)
		label.font_size = 34
		label.pixel_size = 0.01
		label.modulate = color
		root.add_child(label)
		var gate := _make_gate(id, "بوابة " + str(wing_titles[id]), id, root)
		gate.position = Vector3(x, 0, 6.0)
		_create_wing_room(root, id, x, color)
	var light := OmniLight3D.new()
	light.position = Vector3(0, 4.4, 0)
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 1.15
	light.omni_range = 36
	root.add_child(light)
	return root

func _create_wing_room(root: Node3D, id: String, x: float, accent: Color) -> void:
	var room := Node3D.new()
	room.name = "CivilizationRoom_" + id
	room.position = Vector3(x, 0, -5)
	root.add_child(room)
	_add_ship_box(room, "WingFloor", Vector3(7.2, 0.25, 12), Vector3(0, 0, -1), accent, true)
	_add_ship_box(room, "WingBackWall", Vector3(7.2, 4.2, 0.35), Vector3(0, 2.1, -7), DARK, true)
	_add_ship_box(room, "WingLeftWall", Vector3(0.35, 4.2, 12), Vector3(-3.6, 2.1, -1), DARK, true)
	_add_ship_box(room, "WingRightWall", Vector3(0.35, 4.2, 12), Vector3(3.6, 2.1, -1), DARK, true)
	# حليات أرضية منخفضة على جانبي الممر، لا تعيق حركة اللاعب.
	_add_ship_box(room, "WingFloorInlayLeft", Vector3(0.08, 0.035, 8.4), Vector3(-3.05, 0.145, -1.0), GOLD)
	_add_ship_box(room, "WingFloorInlayRight", Vector3(0.08, 0.035, 8.4), Vector3(3.05, 0.145, -1.0), GOLD)
	# زخرفة أرضية منخفضة خاصة بكل حضارة، خارج خط السير الأوسط.
	match id:
		"wing_greek":
			_add_ship_box(room, "GreekFloorMotifCrossbar", Vector3(3.8, 0.025, 0.10), Vector3(0, 0.16, -5.0), GOLD)
			_add_ship_box(room, "GreekFloorMotifSide", Vector3(0.10, 0.025, 2.2), Vector3(-1.85, 0.16, -5.0), accent)
			_add_ship_box(room, "GreekFloorMotifSide", Vector3(0.10, 0.025, 2.2), Vector3(1.85, 0.16, -5.0), accent)
		"wing_roman":
			_add_ship_box(room, "RomanFloorMosaicBar", Vector3(3.8, 0.025, 0.12), Vector3(0, 0.16, -5.0), accent)
			_add_ship_box(room, "RomanFloorMosaicBar", Vector3(3.8, 0.025, 0.12), Vector3(0, 0.16, -4.55), GOLD)
		"wing_japanese":
			_add_ship_box(room, "JapaneseFloorSteppingStone", Vector3(0.85, 0.035, 0.85), Vector3(-2.1, 0.16, -4.8), Color(0.72, 0.66, 0.48))
			_add_ship_box(room, "JapaneseFloorSteppingStone", Vector3(0.85, 0.035, 0.85), Vector3(2.1, 0.16, -4.8), Color(0.72, 0.66, 0.48))
		"wing_chinese":
			_add_ship_box(room, "ChineseFloorBorder", Vector3(3.8, 0.025, 0.12), Vector3(0, 0.16, -5.0), Color(0.72, 0.12, 0.08))
			_add_ship_box(room, "ChineseFloorGoldLine", Vector3(3.8, 0.025, 0.08), Vector3(0, 0.16, -4.55), GOLD)
		"wing_french":
			_add_ship_box(room, "FrenchFloorBlueInlay", Vector3(3.8, 0.025, 0.12), Vector3(0, 0.16, -5.0), Color(0.16, 0.25, 0.42))
			_add_ship_box(room, "FrenchFloorGoldLine", Vector3(3.8, 0.025, 0.08), Vector3(0, 0.16, -4.55), GOLD)
	_add_ship_box(room, "WingWallTrimLeft", Vector3(0.08, 2.8, 0.16), Vector3(-3.37, 2.2, -1.0), accent)
	_add_ship_box(room, "WingWallTrimRight", Vector3(0.08, 2.8, 0.16), Vector3(3.37, 2.2, -1.0), accent)
	# إضاءة جدارية هادئة وإطار علوي ذهبي موحد لكل جناح.
	_add_ship_box(room, "WingCeilingTrimFront", Vector3(6.8, 0.12, 0.18), Vector3(0, 4.02, 3.0), GOLD)
	_add_ship_box(room, "WingCeilingTrimRear", Vector3(6.8, 0.12, 0.18), Vector3(0, 4.02, -5.8), GOLD)
	for side in [-1.0, 1.0]:
		_add_ship_box(room, "WingSconceMount", Vector3(0.16, 0.58, 0.32), Vector3(side * 3.28, 2.75, -1.8), GOLD)
		_add_ship_sphere(room, "WingSconceGlow", 0.19, Vector3(side * 3.18, 2.75, -1.8), accent)
	var wing_title := Label3D.new()
	wing_title.name = "WingNamePlaque"
	wing_title.text = str(wing_titles.get(id, "جناح الحضارة"))
	wing_title.position = Vector3(0, 3.35, -6.78)
	wing_title.font_size = 30
	wing_title.pixel_size = 0.012
	wing_title.modulate = accent
	room.add_child(wing_title)
	_add_ship_box(room, "WingDisplayPlinth", Vector3(2.8, 0.55, 2.8), Vector3(0, 0.4, -2), GOLD)
	_add_ship_box(room, "WingDisplayColumn", Vector3(0.7, 1.4, 0.7), Vector3(0, 1.25, -2), accent)
	_add_ship_sphere(room, "WingCivilizationArtifact", 0.65, Vector3(0, 2.35, -2), accent)
	# لكل جناح بوابة رجوع واحدة إلى القاعة؛ أما بوابات الحضارات الخمس فتبقى في القاعة.
	_add_ship_box(room, "ReturnGateFrame", Vector3(3.4, 3.8, 0.35), Vector3(0, 1.9, 4.2), GOLD)
	_add_ship_box(room, "ReturnGateInset", Vector3(2.65, 2.9, 0.16), Vector3(0, 1.75, 4.0), DARK)
	var return_label := Label3D.new()
	return_label.text = "العودة إلى القاعة الرئيسية"
	return_label.position = Vector3(0, 4.0, 3.85)
	return_label.font_size = 20
	return_label.pixel_size = 0.012
	return_label.modulate = GOLD
	room.add_child(return_label)
	var return_gate := _make_gate("return_" + id, "بوابة العودة إلى القاعة الرئيسية", id, room)
	return_gate.position = Vector3(0, 0, 3.4)
	# نقطة الوصول قريبة بما يكفي من بوابة العودة داخل الجناح، مع مساحة حركة أمامها.
	wing_spawns[id] = SHIP_WORLD_POSITION + Vector3(x, 1.1, -3.8)
	# عناصر معمارية مميزة لكل حضارة، دون إضافة طابق أو كتلة مبنى مستقلة.
	match id:
		"wing_greek":
			for side in [-1.0, 1.0]:
				_add_ship_cylinder(room, "GreekMarbleColumn", 0.34, 3.0, Vector3(side * 2.7, 1.65, -4.5), Color(0.88, 0.84, 0.72))
			_add_ship_box(room, "GreekPediment", Vector3(6.2, 0.35, 0.45), Vector3(0, 3.35, -4.5), GOLD)
			_add_ship_box(room, "GreekFrieze", Vector3(5.8, 0.18, 0.22), Vector3(0, 2.95, -4.25), Color(0.88, 0.84, 0.72))
		"wing_roman":
			for side in [-1.0, 1.0]:
				_add_ship_cylinder(room, "RomanPillar", 0.42, 3.2, Vector3(side * 2.65, 1.75, -4.4), Color(0.73, 0.55, 0.43))
			_add_ship_box(room, "RomanArchLintel", Vector3(6.0, 0.55, 0.55), Vector3(0, 3.45, -4.4), GOLD)
			_add_ship_box(room, "RomanMosaicBand", Vector3(6.4, 0.12, 0.5), Vector3(0, 0.22, -4.4), Color(0.76, 0.55, 0.28))
		"wing_japanese":
			_add_ship_box(room, "JapaneseRoofLower", Vector3(7.0, 0.22, 2.0), Vector3(0, 3.65, -4.5), Color(0.25, 0.12, 0.10))
			_add_ship_box(room, "JapaneseRoofUpper", Vector3(5.8, 0.2, 1.45), Vector3(0, 3.95, -4.5), accent)
			_add_ship_box(room, "JapaneseGardenPath", Vector3(1.1, 0.08, 4.0), Vector3(0, 0.22, -4.5), Color(0.72, 0.66, 0.48))
			_add_ship_sphere(room, "JapaneseLantern", 0.34, Vector3(-2.4, 2.5, -4.5), GOLD)
			_add_ship_sphere(room, "JapaneseLantern", 0.34, Vector3(2.4, 2.5, -4.5), GOLD)
		"wing_chinese":
			_add_ship_box(room, "ChineseRoofLower", Vector3(7.0, 0.24, 1.8), Vector3(0, 3.65, -4.5), Color(0.45, 0.08, 0.06))
			_add_ship_box(room, "ChineseRoofUpper", Vector3(5.7, 0.2, 1.35), Vector3(0, 3.95, -4.5), GOLD)
			_add_ship_sphere(room, "ChineseLantern", 0.42, Vector3(-2.5, 2.5, -4.2), Color(0.72, 0.12, 0.08))
			_add_ship_sphere(room, "ChineseLantern", 0.42, Vector3(2.5, 2.5, -4.2), Color(0.72, 0.12, 0.08))
		"wing_french":
			for side in [-1.0, 1.0]:
				_add_ship_cylinder(room, "FrenchDecorativeColumn", 0.28, 3.1, Vector3(side * 2.75, 1.7, -4.5), Color(0.82, 0.78, 0.69))
			_add_ship_box(room, "FrenchRoyalCornice", Vector3(6.8, 0.24, 0.55), Vector3(0, 3.45, -4.5), GOLD)
			_add_ship_box(room, "FrenchBluePanel", Vector3(4.8, 1.5, 0.18), Vector3(0, 2.0, -6.7), Color(0.16, 0.25, 0.42))
	# شارة جدارية ثلاثية الأبعاد تميز هوية كل جناح من دون تغيير مساحة الحركة.
	_add_ship_box(room, "CivilizationEmblemBacking", Vector3(1.55, 1.35, 0.12), Vector3(0, 2.05, -6.58), DARK)
	match id:
		"wing_greek":
			_add_ship_sphere(room, "GreekEmblemCenter", 0.42, Vector3(0, 2.1, -6.43), Color(0.82, 0.78, 0.62))
			_add_ship_cylinder(room, "GreekEmblemStem", 0.12, 0.9, Vector3(0, 1.45, -6.42), GOLD)
		"wing_roman":
			_add_ship_sphere(room, "RomanEmblemCenter", 0.38, Vector3(0, 2.1, -6.43), Color(0.75, 0.58, 0.38))
			for side in [-1.0, 1.0]:
				_add_ship_sphere(room, "RomanLaurelDetail", 0.16, Vector3(side * 0.48, 2.1, -6.4), GOLD)
		"wing_japanese":
			_add_ship_box(room, "JapaneseEmblemToriiTop", Vector3(1.25, 0.14, 0.14), Vector3(0, 2.48, -6.42), Color(0.72, 0.16, 0.12))
			_add_ship_box(room, "JapaneseEmblemToriiLeft", Vector3(0.12, 0.78, 0.14), Vector3(-0.38, 2.05, -6.42), Color(0.72, 0.16, 0.12))
			_add_ship_box(room, "JapaneseEmblemToriiRight", Vector3(0.12, 0.78, 0.14), Vector3(0.38, 2.05, -6.42), Color(0.72, 0.16, 0.12))
		"wing_chinese":
			_add_ship_sphere(room, "ChineseEmblemCenter", 0.42, Vector3(0, 2.1, -6.43), Color(0.72, 0.12, 0.08))
			_add_ship_box(room, "ChineseEmblemTop", Vector3(0.9, 0.12, 0.18), Vector3(0, 2.58, -6.4), GOLD)
		"wing_french":
			_add_ship_sphere(room, "FrenchEmblemCenter", 0.26, Vector3(0, 2.1, -6.42), Color(0.2, 0.32, 0.55))
			_add_ship_sphere(room, "FrenchEmblemUpperLeft", 0.18, Vector3(-0.3, 2.42, -6.42), GOLD)
			_add_ship_sphere(room, "FrenchEmblemUpperRight", 0.18, Vector3(0.3, 2.42, -6.42), GOLD)
	var wing_light := OmniLight3D.new()
	wing_light.position = Vector3(0, 3.4, -1)
	wing_light.light_color = accent
	wing_light.light_energy = 0.85
	wing_light.omni_range = 12
	room.add_child(wing_light)
	for side in [-1.0, 1.0]:
		var sconce_light := OmniLight3D.new()
		sconce_light.position = Vector3(side * 2.85, 2.75, -1.8)
		sconce_light.light_color = accent
		sconce_light.light_energy = 0.28
		sconce_light.omni_range = 4.0
		room.add_child(sconce_light)

func _add_ship_sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = pos
	node.material_override = _make_material(color)
	parent.add_child(node)

func _add_ship_cylinder(parent: Node3D, node_name: String, radius: float, height: float, pos: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = node_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	node.mesh = mesh
	node.position = pos
	node.material_override = _make_material(color)
	parent.add_child(node)

func _add_ship_box(parent: Node3D, name: String, size: Vector3, pos: Vector3, color: Color, collision: bool = false) -> void:
	var mesh_node := MeshInstance3D.new()
	mesh_node.name = name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_node.mesh = mesh
	mesh_node.position = pos
	mesh_node.material_override = _make_material(color)
	parent.add_child(mesh_node)
	if collision:
		var body := StaticBody3D.new()
		body.name = name + "_Collision"
		body.position = pos
		var shape_node := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		shape_node.shape = shape
		body.add_child(shape_node)
		parent.add_child(body)
