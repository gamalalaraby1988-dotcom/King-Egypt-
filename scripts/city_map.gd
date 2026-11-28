extends Control
## قائمة وجهات خفيفة بلا خريطة مصغرة؛ اختيار الوجهة يفعّل السهم والشعاع المحليين.

var player: Node3D
var mission_manager: Node
var destinations_button: Button
var destinations_panel: PanelContainer
var destinations_list: VBoxContainer
var destination_choice_buttons: Array[Button] = []
var selected_landmark_key := ""

const CITY_LANDMARKS := [
	{"key": "shop", "position": Vector3(0.0, 0.0, 6.4)},
	{"key": "restaurant", "position": Vector3(120.0, 0.0, -35.4)},
	{"key": "employment", "position": Vector3(60.0, 0.0, -35.4)},
	{"key": "delivery", "position": Vector3(60.0, 0.0, -33.0)},
	{"key": "city_guide", "position": Vector3(-48, 0, 6.75)},
	{"key": "maintenance", "position": Vector3(9, 0, 36)},
	{"key": "animal_camp", "position": Vector3(120, 0, 102)},
	{"key": "desert_camp", "position": Vector3(-130.0, 0.0, 70.0)},
	{"key": "pyramids_camp", "position": Vector3(-130.0, 0.0, 70.0)},
	{"key": "fuel_station", "position": Vector3(-150, 0, 57)},
	{"key": "marina_terminal", "position": Vector3(150, 0, 57)},
	{"key": "royal_yacht_club", "position": Vector3(150, 0, 87)},
	{"key": "desert_lodge", "position": Vector3(-150, 0, 112.50)},
	{"key": "mountain_temple", "position": Vector3(150, 0, 112.50)},
	{"key": "royal_ship", "position": Vector3(-45.0, 0.0, 216.0)},
	{"key": "beach_handball", "position": Vector3(180.0, 0.0, 195.0)}
]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_create_destinations_menu()
	CityLanguage.language_changed.connect(_refresh_language)
	get_viewport().size_changed.connect(_update_layout)
	_refresh_language()
	_update_layout()

func _exit_tree() -> void:
	if CityLanguage.language_changed.is_connected(_refresh_language):
		CityLanguage.language_changed.disconnect(_refresh_language)
	if get_viewport().size_changed.is_connected(_update_layout):
		get_viewport().size_changed.disconnect(_update_layout)

func _create_destinations_menu() -> void:
	destinations_button = Button.new()
	destinations_button.name = "NavigationDestinationsButton"
	destinations_button.text = CityLanguage.translate("map_destinations")
	destinations_button.focus_mode = Control.FOCUS_NONE
	destinations_button.mouse_filter = Control.MOUSE_FILTER_STOP
	destinations_button.pressed.connect(_toggle_destinations_menu)
	add_child(destinations_button)
	destinations_button.z_index = 30

	destinations_panel = PanelContainer.new()
	destinations_panel.name = "NavigationDestinationsPanel"
	destinations_panel.visible = false
	destinations_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.065, 0.97)
	panel_style.border_color = Color(0.82, 0.69, 0.39, 0.98)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(8)
	panel_style.content_margin_left = 8.0
	panel_style.content_margin_right = 8.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_bottom = 8.0
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
		choice.custom_minimum_size = Vector2(0.0, 36.0)
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
	add_child(destinations_panel)
	destinations_panel.z_index = 31

func _update_layout() -> void:
	var viewport_size := get_viewport_rect().size
	destinations_button.position = Vector2(viewport_size.x - 154.0, 14.0)
	destinations_button.size = Vector2(140.0, 38.0)
	destinations_panel.position = Vector2(viewport_size.x - 214.0, 58.0)
	destinations_panel.size = Vector2(200.0, minf(300.0, maxf(180.0, viewport_size.y * 0.62)))

func _refresh_language() -> void:
	if is_instance_valid(destinations_button):
		destinations_button.text = CityLanguage.translate("map_destinations")
	for index in range(mini(destination_choice_buttons.size(), CITY_LANDMARKS.size())):
		destination_choice_buttons[index].text = CityLanguage.translate(str(CITY_LANDMARKS[index]["key"]))

func _toggle_destinations_menu() -> void:
	if is_instance_valid(destinations_panel):
		destinations_panel.visible = not destinations_panel.visible

func _close_destinations_menu() -> void:
	if is_instance_valid(destinations_panel):
		destinations_panel.visible = false

func _on_destination_choice_pressed(index: int) -> void:
	if index < 0 or index >= CITY_LANDMARKS.size() or not is_instance_valid(mission_manager):
		return
	var landmark: Dictionary = CITY_LANDMARKS[index]
	var key := str(landmark["key"])
	var destination: Vector3 = landmark["position"]
	if mission_manager.has_method("navigate_to_landmark") and mission_manager.navigate_to_landmark(key, destination):
		selected_landmark_key = key
		_close_destinations_menu()
