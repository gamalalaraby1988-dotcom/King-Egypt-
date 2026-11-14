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
	city = get_parent() as Node3D
	player = city.get_node_or_null("Player") as CharacterBody3D
	_create_menu()
	_create_beach_portal()

func _process(_delta: float) -> void:
	if not is_instance_valid(player):
		player = city.get_node_or_null("Player") as CharacterBody3D
	if menu_panel and menu_panel.visible and (not is_instance_valid(active_gate) or player.global_position.distance_to(active_gate.global_position) > 6.0):
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
	menu_panel.custom_minimum_size = Vector2(360, 300)
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
	menu_list = VBoxContainer.new()
	menu_list.add_theme_constant_override("separation", 7)
	column.add_child(menu_list)
	var close := Button.new()
	close.text = "إغلاق"
	close.custom_minimum_size = Vector2(0, 46)
	close.pressed.connect(_close_menu)
	column.add_child(close)

func _on_dim_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		_close_menu()

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
	active_gate = gate
	var data: Dictionary = gate.get_quick_travel_data()
	var gate_id := str(data.get("gate_id", ""))
	var location_id := str(data.get("location_id", "ship_exterior"))
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
		button.text = str(option.label)
		button.custom_minimum_size = Vector2(0, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_select_destination.bind(str(option.id)))
		menu_list.add_child(button)
	var dim := menu_layer.get_node("Dim") as ColorRect
	dim.visible = true
	menu_panel.visible = true

func _location_title(location_id: String) -> String:
	if location_id == "ship_exterior":
		return "الشاطئ أمام السفينة"
	if location_id == "ship_hall":
		return "القاعة الرئيسية للسفينة"
	return str(wing_titles.get(location_id, "السفينة"))

func _close_menu() -> void:
	if is_instance_valid(menu_panel):
		menu_panel.visible = false
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
	if not is_instance_valid(player) or ship_transition_busy:
		return
	ship_transition_busy = true
	city.set("interior_transition_busy", true)
	city.set("interior_player", player)
	city.set("interior_return_transform", player.global_transform)
	player.set_physics_process(false)
	city.call("_show_interior_loading", false, "interior_loading")
	await get_tree().create_timer(0.65).timeout
	if not is_instance_valid(player) or not is_inside_tree():
		ship_transition_busy = false
		city.set("interior_transition_busy", false)
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
	if not is_instance_valid(ship_interior) or ship_transition_busy or not is_instance_valid(player):
		return
	ship_transition_busy = true
	city.set("interior_transition_busy", true)
	player.set_physics_process(false)
	city.call("_show_interior_loading", false, "interior_return_loading")
	await get_tree().create_timer(0.55).timeout
	if not is_inside_tree():
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
	if not is_instance_valid(ship_interior) or ship_transition_busy or not is_instance_valid(player):
		return
	ship_transition_busy = true
	city.set("interior_transition_busy", true)
	player.set_physics_process(false)
	city.call("_show_interior_loading", false, "interior_loading")
	await get_tree().create_timer(0.4).timeout
	ship_current_location = location_id
	var destination: Vector3 = wing_spawns.get(location_id, SHIP_WORLD_POSITION + Vector3(0, 1.1, 7.0))
	player.global_position = destination
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	city.set("interior_transition_busy", false)
	ship_transition_busy = false
	city.call("_show_interior_loading", true)
	_refresh_city_interactions()

func _refresh_city_interactions() -> void:
	var manager := city.get_node_or_null("MissionManager")
	if is_instance_valid(manager):
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
	wing_spawns[id] = SHIP_WORLD_POSITION + Vector3(x, 1.1, -8.0)
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
	var wing_light := OmniLight3D.new()
	wing_light.position = Vector3(0, 3.4, -1)
	wing_light.light_color = accent
	wing_light.light_energy = 0.85
	wing_light.omni_range = 12
	room.add_child(wing_light)

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
