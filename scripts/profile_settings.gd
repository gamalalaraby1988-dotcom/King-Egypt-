extends Node
## واجهة الملف الشخصي وإعدادات اللعب الأساسية، تحفظ محليًا.

const SAVE_PATH := "user://kings_city_profile.cfg"
var mission_manager: Node
var player: Node3D
var panel: PanelContainer
var name_input: LineEdit
var volume_slider: HSlider
var quality_select: OptionButton
var language_select: OptionButton
var info_label: Label
var shadow_light: DirectionalLight3D
var root_control: Control

func _ready() -> void:
	_build_ui()
	_load_settings()
	_apply_settings()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ProfileSettingsHUD"
	add_child(layer)
	root_control = Control.new()
	root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root_control)

	var open_button := Button.new()
	open_button.text = "الملف الشخصي ⚙"
	open_button.position = Vector2(18, 188)
	open_button.size = Vector2(160, 48)
	open_button.pressed.connect(func(): _refresh_info(); panel.visible = true)
	root_control.add_child(open_button)

	panel = PanelContainer.new()
	panel.visible = false
	root_control.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	scroll.add_child(content)

	var heading := Label.new()
	heading.text = "الملف الشخصي والإعدادات"
	heading.add_theme_font_size_override("font_size", 22)
	content.add_child(heading)

	var name_label := Label.new()
	name_label.text = "اسم اللاعب"
	content.add_child(name_label)
	name_input = LineEdit.new()
	name_input.placeholder_text = "اكتب اسم اللاعب"
	name_input.max_length = 24
	content.add_child(name_input)

	var volume_label := Label.new()
	volume_label.text = "مستوى الصوت"
	content.add_child(volume_label)
	volume_slider = HSlider.new()
	volume_slider.min_value = 0
	volume_slider.max_value = 100
	volume_slider.step = 5
	volume_slider.value = 80
	content.add_child(volume_slider)

	var quality_label := Label.new()
	quality_label.text = "جودة الرسوم"
	content.add_child(quality_label)
	quality_select = OptionButton.new()
	quality_select.add_item("منخفضة — أداء أفضل", 0)
	quality_select.add_item("متوسطة", 1)
	quality_select.add_item("مرتفعة", 2)
	content.add_child(quality_select)

	var language_label := Label.new()
	language_label.text = "لغة اللافتات والإرشادات"
	content.add_child(language_label)
	language_select = OptionButton.new()
	language_select.add_item("تلقائي حسب لغة الهاتف", 0)
	language_select.add_item("العربية", 1)
	language_select.add_item("English", 2)
	content.add_child(language_select)

	info_label = Label.new()
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(info_label)

	var save_button := Button.new()
	save_button.text = "حفظ الإعدادات"
	save_button.pressed.connect(_save_settings)
	content.add_child(save_button)

	var close_button := Button.new()
	close_button.text = "إغلاق"
	close_button.pressed.connect(func(): panel.visible = false)
	content.add_child(close_button)
	get_viewport().size_changed.connect(_update_layout)
	_update_layout()

func _update_layout() -> void:
	if not is_instance_valid(root_control) or not is_instance_valid(panel):
		return
	var view := get_viewport().get_visible_rect().size
	var panel_size := Vector2(minf(520.0, maxf(160.0, view.x - 28.0)), minf(490.0, maxf(180.0, view.y - 28.0)))
	panel.size = panel_size
	panel.position = (view - panel_size) * 0.5

func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		name_input.text = "لاعب جديد"
		language_select.select(0)
		return
	name_input.text = str(config.get_value("profile", "player_name", "لاعب جديد"))
	volume_slider.value = float(config.get_value("settings", "volume", 80))
	quality_select.select(int(config.get_value("settings", "quality", 0)))
	var saved_language := str(config.get_value("settings", "language", "auto"))
	language_select.select({"auto": 0, "ar": 1, "en": 2}.get(saved_language, 0))
	CityLanguage.set_language(saved_language)

func _save_settings() -> void:
	var config := ConfigFile.new()
	config.load(SAVE_PATH)
	config.set_value("profile", "player_name", name_input.text.strip_edges() if not name_input.text.strip_edges().is_empty() else "لاعب")
	config.set_value("settings", "volume", int(volume_slider.value))
	config.set_value("settings", "quality", quality_select.selected)
	var language_modes := ["auto", "ar", "en"]
	var selected_language: String = language_modes[clampi(language_select.selected, 0, 2)]
	config.set_value("settings", "language", selected_language)
	var error := config.save(SAVE_PATH)
	CityLanguage.set_language(selected_language)
	_apply_settings()
	_refresh_info()
	info_label.text += "\nتم حفظ الإعدادات محليًا." if error == OK else "\nتعذر حفظ الإعدادات."

func _apply_settings() -> void:
	var master := AudioServer.get_bus_index("Master")
	if master >= 0:
		AudioServer.set_bus_volume_linear(master, max(0.001, volume_slider.value / 100.0))
	var quality := quality_select.selected
	var lights := get_tree().get_nodes_in_group("quality_shadow_light")
	for light in lights:
		if light is DirectionalLight3D:
			light.shadow_enabled = quality >= 1

func _refresh_info() -> void:
	if not is_instance_valid(mission_manager):
		info_label.text = "بيانات اللاعب غير متاحة."
		return
	info_label.text = "المستوى: %d\nالخبرة: %d\nالمال: %d\nالرقائق: %d" % [
		mission_manager.player_level, mission_manager.xp,
		mission_manager.money, mission_manager.chips
	]
