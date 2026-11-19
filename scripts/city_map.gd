extends Control
## خريطة مصغرة خفيفة تتمركز حول اللاعب وتعرض المعالم القريبة واتجاه الحركة.

var player: Node3D
var mission_manager: Node
var landmark_buttons: Array[Button] = []
var selected_landmark_key := ""
var map_size := Vector2(220, 220)
var world_radius := 90.0
var map_visible := true
var toggle_button: Button
var destinations_button: Button
var destinations_panel: PanelContainer
var destinations_list: VBoxContainer
var destination_choice_buttons: Array[Button] = []
var marker_radius := 4.0
var region_notice_panel: PanelContainer
var region_notice_label: Label
var active_region_key := ""
var region_notice_remaining := 0.0

# حدود تقريبية لمناطق النموذج الحالي، وليست خريطة مساحية نهائية.
const REGION_BOUNDS := {
	"region_city_center": {"center": Vector2(0.0, 0.0), "half_size": Vector2(84.0, 84.0)},
	"region_pyramids_camp": {"center": Vector2(50.5, 56.0), "half_size": Vector2(33.5, 28.0)}
}

# معالم مثبتة في main.gd؛ لا تُضاف البوابة أو الميناء قبل وجود مواقع فعلية لهما.
const CITY_LANDMARKS := [
	{"key": "shop", "position": Vector3(16.0, 0.0, 19.56)},
	{"key": "restaurant", "position": Vector3(-16.0, 0.0, 19.56)},
	{"key": "employment", "position": Vector3(16.0, 0.0, -12.44)},
	{"key": "delivery", "position": Vector3(24.0, 0.0, 4.5)},
	{"key": "city_guide", "position": Vector3(-24.0, 0.0, 4.5)},
	{"key": "maintenance", "position": Vector3(4.5, 0.0, 24.0)},
	{"key": "pyramids_camp", "position": Vector3(60.0, 0.0, 60.0)}
]

func _ready() -> void:
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	mouse_filter = Control.MOUSE_FILTER_PASS
	clip_contents = true
	_create_landmark_buttons()
	_create_destinations_menu()
	toggle_button = Button.new()
	toggle_button.text = CityLanguage.translate("hide_map")
	toggle_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	toggle_button.pressed.connect(_toggle_map)
	get_parent().add_child(toggle_button)
	_create_region_notice()
	active_region_key = _get_region_key(_player_position())
	get_viewport().size_changed.connect(_update_layout)
	CityLanguage.language_changed.connect(_refresh_language)
	_refresh_language()
	_update_layout()

func _exit_tree() -> void:
	for landmark_button in landmark_buttons:
		if is_instance_valid(landmark_button):
			landmark_button.queue_free()
	if get_viewport().size_changed.is_connected(_update_layout):
		get_viewport().size_changed.disconnect(_update_layout)
	if CityLanguage.language_changed.is_connected(_refresh_language):
		CityLanguage.language_changed.disconnect(_refresh_language)
	if is_instance_valid(toggle_button):
		toggle_button.queue_free()
	if is_instance_valid(destinations_button):
		destinations_button.queue_free()
	if is_instance_valid(destinations_panel):
		destinations_panel.queue_free()
	if is_instance_valid(region_notice_panel):
		region_notice_panel.queue_free()

func _create_region_notice() -> void:
	region_notice_panel = PanelContainer.new()
	region_notice_panel.name = "RegionEntryNotice"
	region_notice_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	region_notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_notice_panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.075, 0.09, 0.94)
	panel_style.border_color = Color(0.82, 0.69, 0.39, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 12.0
	panel_style.content_margin_right = 12.0
	panel_style.content_margin_top = 7.0
	panel_style.content_margin_bottom = 7.0
	region_notice_panel.add_theme_stylebox_override("panel", panel_style)
	region_notice_label = Label.new()
	region_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	region_notice_label.add_theme_font_size_override("font_size", 18)
	region_notice_label.add_theme_color_override("font_color", Color(1.0, 0.91, 0.68))
	region_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	region_notice_panel.add_child(region_notice_label)
	get_parent().add_child(region_notice_panel)

func _refresh_language() -> void:
	if is_instance_valid(toggle_button):
		toggle_button.text = CityLanguage.translate("hide_map") if map_visible else CityLanguage.translate("show_map")
	if is_instance_valid(destinations_button):
		destinations_button.text = CityLanguage.translate("map_destinations")
		destinations_button.visible = map_visible
	for index in range(mini(destination_choice_buttons.size(), CITY_LANDMARKS.size())):
		destination_choice_buttons[index].text = CityLanguage.translate(str(CITY_LANDMARKS[index]["key"]))
	if is_instance_valid(region_notice_label) and region_notice_remaining > 0.0:
		_update_region_notice_text()
	queue_redraw()

func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	var side := clampf(minf(viewport_size.x, viewport_size.y) * 0.30, 140.0, 220.0)
	map_size = Vector2(side, side)
	size = map_size
	position = Vector2(-side - 16.0, 16.0)
	if is_instance_valid(toggle_button):
		toggle_button.position = Vector2(-side - 16.0, side + 64.0)
		toggle_button.size = Vector2(side, 38.0)	
	if is_instance_valid(destinations_button):
		destinations_button.position = Vector2(-side - 16.0, side + 22.0)
		destinations_button.size = Vector2(side, 38.0)
		destinations_button.visible = map_visible
	if is_instance_valid(destinations_panel):
		destinations_panel.position = position + Vector2(0.0, 0.0)
		destinations_panel.size = Vector2(side, minf(270.0, maxf(190.0, viewport_size.y - 90.0)))
		destinations_panel.visible = map_visible and destinations_panel.visible
	if is_instance_valid(region_notice_panel):
		var notice_width := minf(maxf(viewport_size.x - 24.0, 180.0), 360.0)
		region_notice_panel.position = Vector2(-notice_width * 0.5, 72.0)
		region_notice_panel.size = Vector2(notice_width, 50.0)

func _process(delta: float) -> void:
	_update_landmark_buttons()
	var detected_region := _get_region_key(_player_position())
	if active_region_key.is_empty():
		active_region_key = detected_region
	elif detected_region != active_region_key:
		active_region_key = detected_region
		_show_region_notice()
	if region_notice_remaining > 0.0:
		region_notice_remaining = maxf(region_notice_remaining - delta, 0.0)
		if region_notice_remaining <= 0.0 and is_instance_valid(region_notice_panel):
			region_notice_panel.visible = false
	if map_visible:
		queue_redraw()

func _show_region_notice() -> void:
	if not is_instance_valid(region_notice_panel):
		return
	region_notice_remaining = 3.0
	_update_region_notice_text()
	region_notice_panel.visible = true

func _update_region_notice_text() -> void:
	if not is_instance_valid(region_notice_label):
		return
	var prefix := CityLanguage.translate("region_entered")
	var region_name := CityLanguage.translate(active_region_key)
	region_notice_label.text = "%s %s" % [prefix, region_name]

func _toggle_map() -> void:
	map_visible = not map_visible
	visible = map_visible
	if not map_visible and is_instance_valid(destinations_panel):
		destinations_panel.visible = false
	if is_instance_valid(toggle_button):
		toggle_button.text = CityLanguage.translate("hide_map") if map_visible else CityLanguage.translate("show_map")
	if is_instance_valid(destinations_button):
		destinations_button.text = CityLanguage.translate("map_destinations")
		destinations_button.visible = map_visible
	for index in range(mini(destination_choice_buttons.size(), CITY_LANDMARKS.size())):
		destination_choice_buttons[index].text = CityLanguage.translate(str(CITY_LANDMARKS[index]["key"]))
	_update_landmark_buttons()

func _player_position() -> Vector3:
	if is_instance_valid(player):
		return player.global_position
	return Vector3.ZERO

func _get_region_key(position_3d: Vector3) -> String:
	# تُفحص المنطقة الفرعية أولًا؛ فهي داخل حدود وسط المدينة وتضم الأهرامات والمخيم وأبو الهول.
	if _is_inside_region("region_pyramids_camp", position_3d):
		return "region_pyramids_camp"
	if _is_inside_region("region_city_center", position_3d):
		return "region_city_center"
	return "region_outskirts"

func _is_inside_region(region_key: String, position_3d: Vector3) -> bool:
	var definition: Dictionary = REGION_BOUNDS.get(region_key, {})
	if definition.is_empty():
		return false
	var region_center: Vector2 = definition["center"]
	var half_size: Vector2 = definition["half_size"]
	return absf(position_3d.x - region_center.x) <= half_size.x and absf(position_3d.z - region_center.y) <= half_size.y

func _draw_region_boundaries() -> void:
	for region_key in ["region_city_center", "region_pyramids_camp"]:
		var definition: Dictionary = REGION_BOUNDS[region_key]
		var region_center: Vector2 = definition["center"]
		var half_size: Vector2 = definition["half_size"]
		var corners := [
			Vector3(region_center.x - half_size.x, 0.0, region_center.y - half_size.y),
			Vector3(region_center.x + half_size.x, 0.0, region_center.y - half_size.y),
			Vector3(region_center.x + half_size.x, 0.0, region_center.y + half_size.y),
			Vector3(region_center.x - half_size.x, 0.0, region_center.y + half_size.y)
		]
		var outline := PackedVector2Array()
		for corner in corners:
			outline.append(_world_to_map(corner))
		outline.append(outline[0])
		var line_color := Color(0.55, 0.68, 0.66, 0.78)
		var line_width := 1.5
		if region_key == active_region_key:
			line_color = Color(1.0, 0.82, 0.38, 0.98)
			line_width = 2.8
		draw_polyline(outline, line_color, line_width, true)

func _world_to_map(world_pos: Vector3) -> Vector2:
	var center := map_size * 0.5
	var origin := _player_position()
	var delta := world_pos - origin
	var heading := player.global_rotation.y if is_instance_valid(player) else 0.0
	var local := Vector2(delta.x, delta.z).rotated(heading)
	return center + local * (map_size.x * 0.42 / world_radius)

func _create_landmark_buttons() -> void:
	for index in range(CITY_LANDMARKS.size()):
		var landmark: Dictionary = CITY_LANDMARKS[index]
		var landmark_button := Button.new()
		landmark_button.name = "LandmarkSelect_%s" % str(landmark["key"])
		landmark_button.text = "◎"
		landmark_button.tooltip_text = CityLanguage.translate(str(landmark["key"]))
		landmark_button.flat = true
		landmark_button.focus_mode = Control.FOCUS_NONE
		landmark_button.mouse_filter = Control.MOUSE_FILTER_STOP
		landmark_button.add_theme_font_size_override("font_size", 18)
		landmark_button.add_theme_color_override("font_color", Color(1.0, 0.88, 0.48))
		landmark_button.pressed.connect(_on_landmark_button_pressed.bind(index))
		add_child(landmark_button)
		landmark_buttons.append(landmark_button)
	_update_landmark_buttons()


func _create_destinations_menu() -> void:
	destinations_button = Button.new()
	destinations_button.name = "MapDestinationsButton"
	destinations_button.text = CityLanguage.translate("map_destinations")
	destinations_button.focus_mode = Control.FOCUS_NONE
	destinations_button.mouse_filter = Control.MOUSE_FILTER_STOP
	destinations_button.pressed.connect(_toggle_destinations_menu)
	get_parent().add_child(destinations_button)
	destinations_button.z_index = 19
	destinations_panel = PanelContainer.new()
	destinations_panel.name = "MapDestinationsPanel"
	destinations_panel.visible = false
	destinations_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.065, 0.97)
	panel_style.border_color = Color(0.82, 0.69, 0.39, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(7)
	panel_style.content_margin_left = 7.0
	panel_style.content_margin_right = 7.0
	panel_style.content_margin_top = 7.0
	panel_style.content_margin_bottom = 7.0
	destinations_panel.add_theme_stylebox_override("panel", panel_style)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	destinations_panel.add_child(scroll)
	destinations_list = VBoxContainer.new()
	destinations_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	destinations_list.add_theme_constant_override("separation", 4)
	scroll.add_child(destinations_list)
	for index in range(CITY_LANDMARKS.size()):
		var landmark: Dictionary = CITY_LANDMARKS[index]
		var choice := Button.new()
		choice.name = "DestinationChoice_%s" % str(landmark["key"])
		choice.text = CityLanguage.translate(str(landmark["key"]))
		choice.custom_minimum_size = Vector2(0.0, 34.0)
		choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choice.focus_mode = Control.FOCUS_NONE
		choice.pressed.connect(_on_destination_choice_pressed.bind(index))
		destinations_list.add_child(choice)
		destination_choice_buttons.append(choice)
	var close_button := Button.new()
	close_button.name = "CloseDestinationsMenu"
	close_button.text = "×"
	close_button.custom_minimum_size = Vector2(0.0, 30.0)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.pressed.connect(_close_destinations_menu)
	destinations_list.add_child(close_button)	
	get_parent().add_child(destinations_panel)
	destinations_panel.z_index = 20

func _close_destinations_menu() -> void:
	if is_instance_valid(destinations_panel):
		destinations_panel.visible = false

func _toggle_destinations_menu() -> void:
	if not map_visible or not is_instance_valid(destinations_panel):
		return
	destinations_panel.visible = not destinations_panel.visible
	if destinations_panel.visible:
		destinations_panel.position = position
		destinations_panel.size = Vector2(map_size.x, minf(270.0, maxf(190.0, get_viewport_rect().size.y - 90.0)))

func _on_destination_choice_pressed(index: int) -> void:
	if not map_visible or index < 0 or index >= CITY_LANDMARKS.size():
		return
	_on_landmark_button_pressed(index)
	if is_instance_valid(destinations_panel):
		destinations_panel.visible = false

func _update_landmark_buttons() -> void:
	if landmark_buttons.is_empty():
		return
	var map_rect := Rect2(Vector2.ZERO, map_size)
	for index in range(mini(landmark_buttons.size(), CITY_LANDMARKS.size())):
		var landmark_button := landmark_buttons[index]
		if not is_instance_valid(landmark_button):
			continue
		var landmark: Dictionary = CITY_LANDMARKS[index]
		var point := _world_to_map(landmark["position"])
		landmark_button.position = point - Vector2(13.0, 13.0)
		landmark_button.size = Vector2(26.0, 26.0)
		landmark_button.visible = map_visible and map_rect.has_point(point)
		landmark_button.tooltip_text = CityLanguage.translate(str(landmark["key"]))
		landmark_button.add_theme_color_override("font_color", Color(1.0, 0.98, 0.82) if str(landmark["key"]) == selected_landmark_key else Color(1.0, 0.88, 0.48))

func _on_landmark_button_pressed(index: int) -> void:
	if index < 0 or index >= CITY_LANDMARKS.size() or not is_instance_valid(mission_manager):
		return
	var landmark: Dictionary = CITY_LANDMARKS[index]
	var key := str(landmark["key"])
	var world_position: Vector3 = landmark["position"]
	if mission_manager.has_method("navigate_to_landmark") and mission_manager.navigate_to_landmark(key, world_position):
		selected_landmark_key = key
		_update_landmark_buttons()
		queue_redraw()

func _draw() -> void:
	if not map_visible:
		return
	var rect := Rect2(Vector2.ZERO, map_size)
	draw_rect(rect, Color(0.035, 0.075, 0.09, 0.92), true)
	draw_rect(rect, Color(0.82, 0.69, 0.39, 0.95), false, 3.0)
	var center := map_size * 0.5
	var origin := _player_position()
	var scale_factor := map_size.x * 0.42 / world_radius
	var heading := player.global_rotation.y if is_instance_valid(player) else 0.0
	var road_color := Color(0.24, 0.31, 0.30, 0.92)
	# رسم الشوارع الفعلية فقط: المحوران الرئيسيان والشوارع الفرعية الأربعة.
	for road_x in [-72.0, -24.0, 0.0, 24.0, 72.0]:
		var top := _world_to_map(Vector3(road_x, 0.0, -90.0))
		var bottom := _world_to_map(Vector3(road_x, 0.0, 90.0))
		draw_line(top, bottom, road_color, 2.0 if road_x == 0.0 else 1.5)
	for road_z in [-72.0, -24.0, 0.0, 24.0, 72.0]:
		var left := _world_to_map(Vector3(-90.0, 0.0, road_z))
		var right := _world_to_map(Vector3(90.0, 0.0, road_z))
		draw_line(left, right, road_color, 2.0 if road_z == 0.0 else 1.5)
	# وصلة المخيم الخاصة كما هي منشأة في مشهد المدينة.
	draw_line(_world_to_map(Vector3(16.0, 0.0, 0.0)), _world_to_map(Vector3(30.0, 0.0, 0.0)), road_color, 1.8)
	draw_line(_world_to_map(Vector3(30.0, 0.0, 0.0)), _world_to_map(Vector3(30.0, 0.0, 75.0)), road_color, 1.8)
	draw_line(_world_to_map(Vector3(30.0, 0.0, 75.0)), _world_to_map(Vector3(60.0, 0.0, 75.0)), road_color, 1.8)
	_draw_region_boundaries()
	_draw_landmark_route()
	_draw_landmark_labels(rect)
	_draw_party_station_markers(rect)
	for node in get_tree().get_nodes_in_group("city_interactables"):
		if not is_instance_valid(node) or node.is_queued_for_deletion() or not node is Node3D:
			continue
		var point := _world_to_map(node.global_position)
		if not rect.has_point(point):
			continue
		if node.is_in_group("city_service_staff") or node.is_in_group("camp_staff"):
			_draw_staff_marker(point)
		elif node.has_method("get_job_data"):
			_draw_job_marker(point)
		else:
			_draw_building_marker(point)
	draw_circle(center, 6.0, Color(1.0, 0.28, 0.22))
	draw_line(center, center + Vector2.UP * 13.0, Color(1.0, 0.88, 0.7), 2.5)
	draw_string(ThemeDB.fallback_font, Vector2(9, 18), CityLanguage.translate("map_title"), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
	var region_label := CityLanguage.translate(_get_region_key(origin))
	draw_string(ThemeDB.fallback_font, Vector2(9, 36), region_label, HORIZONTAL_ALIGNMENT_LEFT, map_size.x - 18.0, 11, Color(0.95, 0.83, 0.55))
	_draw_compass_and_scale()
	_draw_map_legend()


func _draw_party_station_markers(map_rect: Rect2) -> void:
	# تظهر محطات الحفلات الموجودة فعليًا فقط، دون إضافة مواقع وهمية للخريطة.
	for station in get_tree().get_nodes_in_group("party_stations"):
		if not is_instance_valid(station) or station.is_queued_for_deletion() or not station is Node3D:
			continue
		var point := _world_to_map((station as Node3D).global_position)
		if not map_rect.has_point(point):
			continue
		draw_circle(point, 7.0, Color(0.95, 0.72, 0.28, 0.98))
		draw_circle(point, 4.5, Color(0.12, 0.09, 0.16, 0.98))
		draw_string(ThemeDB.fallback_font, point + Vector2(-4.0, 4.0), "♫", HORIZONTAL_ALIGNMENT_LEFT, 12.0, 10, Color(1.0, 0.88, 0.48))


func _draw_landmark_route() -> void:
	if not is_instance_valid(mission_manager) or not mission_manager.has_method("get_landmark_route_points"):
		return
	var route: PackedVector3Array = mission_manager.get_landmark_route_points()
	if route.size() < 2:
		return
	var points := PackedVector2Array()
	for world_point in route:
		var map_point := _world_to_map(world_point)
		if points.is_empty() or points[points.size() - 1].distance_to(map_point) > 1.0:
			points.append(map_point)
	if points.size() >= 2:
		draw_polyline(points, Color(0.22, 0.95, 0.82, 0.95), 3.0, true)
		draw_circle(points[points.size() - 1], 4.0, Color(1.0, 0.86, 0.42, 1.0))

func _draw_landmark_labels(map_rect: Rect2) -> void:
	# أسماء قصيرة وواضحة للمعالم القريبة فقط، مع منع تداخل بطاقات الأسماء.
	var placed_labels: Array[Rect2] = []
	var candidates: Array[Dictionary] = []
	for landmark in CITY_LANDMARKS:
		var world_position: Vector3 = landmark["position"]
		var point := _world_to_map(world_position)
		if map_rect.has_point(point):
			candidates.append({"key": str(landmark["key"]), "point": point, "distance": point.distance_to(map_size * 0.5)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["distance"]) < float(b["distance"]))
	var font := ThemeDB.fallback_font
	for candidate in candidates:
		var key: String = candidate["key"]
		var point: Vector2 = candidate["point"]
		draw_circle(point, 8.0 if key == selected_landmark_key else 5.0, Color(0.35, 0.95, 0.78, 0.95) if key == selected_landmark_key else Color(1.0, 0.83, 0.38, 0.98))
		draw_circle(point, 2.0, Color(0.08, 0.16, 0.17, 1.0))
		var label_text := CityLanguage.translate(key)
		var label_width := clampf(float(label_text.length()) * 5.0 + 10.0, 42.0, 78.0)
		var label_position := point + Vector2(7.0, -8.0)
		if label_position.x + label_width > map_size.x - 5.0:
			label_position.x = point.x - label_width - 7.0
		if label_position.y < 43.0:
			label_position.y = point.y + 13.0
		var label_rect := Rect2(label_position, Vector2(label_width, 15.0))
		if label_rect.position.x < 4.0 or label_rect.end.x > map_size.x - 4.0 or label_rect.end.y > map_size.y - 4.0:
			continue
		var overlaps := false
		for existing_rect in placed_labels:
			if label_rect.intersects(existing_rect):
				overlaps = true
				break
		if overlaps:
			continue
		placed_labels.append(label_rect)
		draw_rect(label_rect, Color(0.025, 0.055, 0.065, 0.88), true)
		draw_rect(label_rect, Color(0.75, 0.62, 0.34, 0.85), false, 1.0)
		draw_string(font, label_position + Vector2(4.0, 10.5), label_text, HORIZONTAL_ALIGNMENT_LEFT, label_width - 7.0, 8, Color(1.0, 0.93, 0.75))

func _draw_building_marker(point: Vector2) -> void:
	var color := Color(0.95, 0.72, 0.25)
	var diamond := PackedVector2Array([point + Vector2(0, -marker_radius), point + Vector2(marker_radius, 0), point + Vector2(0, marker_radius), point + Vector2(-marker_radius, 0)])
	draw_colored_polygon(diamond, color)

func _draw_job_marker(point: Vector2) -> void:
	var color := Color(0.35, 0.78, 1.0)
	draw_rect(Rect2(point - Vector2(marker_radius, marker_radius), Vector2(marker_radius * 2.0, marker_radius * 2.0)), color, true)

func _draw_staff_marker(point: Vector2) -> void:
	draw_circle(point, marker_radius, Color(0.45, 0.9, 0.55))
	draw_arc(point, marker_radius + 1.5, 0.0, TAU, 16, Color(0.08, 0.16, 0.12), 1.0)

func _draw_map_legend() -> void:
	var font := ThemeDB.fallback_font
	var font_size := 9
	var first_y := map_size.y - 48.0
	var row_gap := 11.0
	var text_color := Color(0.92, 0.9, 0.82)
	draw_colored_polygon(PackedVector2Array([Vector2(11, first_y - 4), Vector2(15, first_y), Vector2(11, first_y + 4), Vector2(7, first_y)]), Color(0.95, 0.72, 0.25))
	draw_string(font, Vector2(20, first_y + 3), CityLanguage.translate("map_buildings"), HORIZONTAL_ALIGNMENT_LEFT, map_size.x - 28.0, font_size, text_color)
	var job_y := first_y + row_gap
	draw_rect(Rect2(Vector2(7, job_y - 4), Vector2(8, 8)), Color(0.35, 0.78, 1.0), true)
	draw_string(font, Vector2(20, job_y + 3), CityLanguage.translate("map_jobs"), HORIZONTAL_ALIGNMENT_LEFT, map_size.x - 28.0, font_size, text_color)
	var staff_y := job_y + row_gap
	draw_circle(Vector2(11, staff_y), 4.0, Color(0.45, 0.9, 0.55))
	draw_string(font, Vector2(20, staff_y + 3), CityLanguage.translate("map_staff"), HORIZONTAL_ALIGNMENT_LEFT, map_size.x - 28.0, font_size, text_color)
	var party_y := staff_y + row_gap
	draw_circle(Vector2(11, party_y), 5.0, Color(0.95, 0.72, 0.28))
	draw_string(font, Vector2(20, party_y + 3), "♫ محطات الحفلات", HORIZONTAL_ALIGNMENT_LEFT, map_size.x - 28.0, font_size, text_color)

func _draw_compass_and_scale() -> void:
	var font := ThemeDB.fallback_font
	var compass_text := CityLanguage.translate("map_north")
	draw_string(font, Vector2(map_size.x - 25.0, 18.0), compass_text, HORIZONTAL_ALIGNMENT_RIGHT, 18.0, 9, Color(0.95, 0.83, 0.55))
	var bar_length := map_size.x * 0.42 * 25.0 / world_radius
	var bar_start := Vector2(map_size.x - bar_length - 12.0, 52.0)
	draw_line(bar_start, bar_start + Vector2(bar_length, 0.0), Color(0.95, 0.83, 0.55), 2.0)
	draw_line(bar_start + Vector2(0, -3), bar_start + Vector2(0, 3), Color(0.95, 0.83, 0.55), 1.0)
	draw_line(bar_start + Vector2(bar_length, -3), bar_start + Vector2(bar_length, 3), Color(0.95, 0.83, 0.55), 1.0)
	draw_string(font, bar_start + Vector2(-2, -5), "25 m", HORIZONTAL_ALIGNMENT_LEFT, 42.0, 8, Color(0.95, 0.83, 0.55))
