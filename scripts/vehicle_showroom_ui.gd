extends CanvasLayer
## معرض المركبات الأولي: يعرض الكتالوج المعتمد دون منح ملكية أو تفعيل شراء.
const VEHICLES := [
	{"id":"city_one","name":"CITY ONE","tier":"اقتصادية","kind":"سيارة"},
	{"id":"elegance_s","name":"ELEGANCE S","tier":"اقتصادية","kind":"سيارة"},
	{"id":"flash_gt","name":"FLASH GT","tier":"متوسطة","kind":"سيارة"},
	{"id":"urban_x","name":"URBAN X","tier":"متوسطة","kind":"سيارة"},
	{"id":"titan_suv","name":"TITAN SUV","tier":"فوق متوسطة","kind":"سيارة"},
	{"id":"desert_4x4","name":"DESERT 4X4","tier":"فوق متوسطة","kind":"سيارة"},
	{"id":"royal_sedan","name":"ROYAL SEDAN","tier":"راقية","kind":"سيارة"},
	{"id":"velocity","name":"VELOCITY","tier":"راقية","kind":"سيارة"},
	{"id":"imperial_suv","name":"IMPERIAL SUV","tier":"فاخرة","kind":"سيارة"},
	{"id":"royal_gt","name":"ROYAL GT","tier":"فاخرة","kind":"سيارة"},
	{"id":"phantom_gt","name":"PHANTOM GT","tier":"سوبر رياضية","kind":"سيارة"},
	{"id":"eagle_x","name":"EAGLE X","tier":"هايبركار","kind":"سيارة"},
	{"id":"pharaoh_elite","name":"PHARAOH ELITE","tier":"ليموزين ملكية","kind":"سيارة"},
	{"id":"horus_2030","name":"HORUS 2030","tier":"رياضية فرعونية فاخرة","kind":"سيارة"},
	{"id":"pharaonic_scooter","name":"HORUS Scooter","tier":"سكوتر كهربائي واقف","kind":"سكوتر"}
]

var showroom_panel: PanelContainer
var selected_label: Label
var detail_label: Label
var _selected_id := "horus_2030"
var open_button: Button

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_SIZE_CHANGED or what == NOTIFICATION_RESIZED:
		_call_deferred("_update_responsive_layout")

func _ready() -> void:
	layer = 21
	_build_ui()

func _build_ui() -> void:
	open_button = Button.new()
	open_button.name = "OpenVehicleShowroom"
	open_button.text = "معرض المركبات 𓂀"
	open_button.custom_minimum_size = Vector2(190, 54)
	open_button.position = Vector2(24, 92)
	open_button.pressed.connect(_toggle_showroom)
	add_child(open_button)

	showroom_panel = PanelContainer.new()
	showroom_panel.name = "VehicleShowroomPanel"
	showroom_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	showroom_panel.offset_left = 12
	showroom_panel.offset_top = 12
	showroom_panel.offset_right = -12
	showroom_panel.offset_bottom = -12
	showroom_panel.visible = false
	add_child(showroom_panel)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 12)
	showroom_panel.add_child(root)

	var heading := Label.new()
	heading.text = "𓂀  معرض مركبات KING OF EGYPT CITY  𓂀"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color(0.91, 0.73, 0.38))
	root.add_child(heading)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 0)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(scroll)

	var cards := VBoxContainer.new()
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("separation", 6)
	scroll.add_child(cards)

	for item in VEHICLES:
		var card := Button.new()
		card.text = "%02d  |  %s  |  %s" % [VEHICLES.find(item) + 1, item.name, item.tier]
		card.custom_minimum_size = Vector2(0, 48)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.pressed.connect(_select_preview.bind(item.id))
		cards.add_child(card)

	var preview := PanelContainer.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(preview)

	var preview_content := VBoxContainer.new()
	preview_content.alignment = BoxContainer.ALIGNMENT_CENTER
	preview_content.add_theme_constant_override("separation", 16)
	preview.add_child(preview_content)

	var emblem := Label.new()
	emblem.text = "𓃭"
	emblem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	emblem.add_theme_font_size_override("font_size", 92)
	emblem.add_theme_color_override("font_color", Color(0.86, 0.67, 0.30))
	preview_content.add_child(emblem)

	selected_label = Label.new()
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	selected_label.add_theme_font_size_override("font_size", 24)
	selected_label.add_theme_color_override("font_color", Color(0.94, 0.80, 0.48))
	preview_content.add_child(selected_label)

	detail_label = Label.new()
	detail_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_label.add_theme_font_size_override("font_size", 16)
	preview_content.add_child(detail_label)

	var close_button := Button.new()
	close_button.text = "إغلاق المعرض"
	close_button.custom_minimum_size = Vector2(0, 46)
	close_button.pressed.connect(_toggle_showroom)
	root.add_child(close_button)

	_select_preview(_selected_id)
	_update_responsive_layout()

func _select_preview(vehicle_id: String) -> void:
	for item in VEHICLES:
		if item.id == vehicle_id:
			_selected_id = vehicle_id
			selected_label.text = item.name
			detail_label.text = "الفئة: %s\nالنوع: %s\n\nالمعاينة ثلاثية الأبعاد والأصل النهائي قيد التجهيز.\nلا يوجد شراء أو تفعيل ملكية من هذه الشاشة." % [item.tier, item.kind]
			return

func _toggle_showroom() -> void:
	if is_instance_valid(showroom_panel):
		showroom_panel.visible = not showroom_panel.visible

func _update_responsive_layout() -> void:
	if not is_instance_valid(showroom_panel):
		return
	var viewport := get_viewport().get_visible_rect().size
	var compact := viewport.x < 760.0 or viewport.y < 560.0
	showroom_panel.offset_left = 8.0 if compact else 20.0
	showroom_panel.offset_top = 8.0 if compact else 20.0
	showroom_panel.offset_right = -8.0 if compact else -20.0
	showroom_panel.offset_bottom = -8.0 if compact else -20.0
	if compact:
		showroom_panel.get_child(0).add_theme_constant_override("separation", 6)
	else:
		showroom_panel.get_child(0).add_theme_constant_override("separation", 12)
	if is_instance_valid(open_button):
		open_button.custom_minimum_size = Vector2(170 if compact else 190, 48 if compact else 54)
