extends CanvasLayer
## واجهة اختيار الشخصيات الجاهزة — معاينة فقط حتى ربط الأصول النهائية وخدمة الملف الشخصي.
## لا توجد خزانة أو أدوات تغيير ملابس/ألوان أو حفظ محلي لهوية الشخصية.

const PLACEHOLDER_AVATAR_SCENE := "res://scenes/characters/avatar_visual.tscn"
const CHARACTERS := [
	{"id":"eg_m_adam","name":"آدم","country":"مصر","flag":"🇪🇬","gender":"male","tier":"متاح مبدئيًا","status":"مجاني مقترح"},
	{"id":"eg_m_omar","name":"عمر","country":"مصر","flag":"🇪🇬","gender":"male","tier":"متاح مبدئيًا","status":"مجاني مقترح"},
	{"id":"it_m_leon","name":"ليون","country":"إيطاليا","flag":"🇮🇹","gender":"male","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"fr_m_alex","name":"أليكس","country":"فرنسا","flag":"🇫🇷","gender":"male","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"br_m_matheus","name":"ماتيوس","country":"البرازيل","flag":"🇧🇷","gender":"male","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"jp_m_ren","name":"رين","country":"اليابان","flag":"🇯🇵","gender":"male","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"us_m_lucas","name":"لوكاس","country":"الولايات المتحدة","flag":"🇺🇸","gender":"male","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"tr_m_amir","name":"أمير","country":"تركيا","flag":"🇹🇷","gender":"male","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"eg_f_layan","name":"ليان","country":"مصر","flag":"🇪🇬","gender":"female","tier":"متاح مبدئيًا","status":"مجاني مقترح"},
	{"id":"eg_f_nour","name":"نور","country":"مصر","flag":"🇪🇬","gender":"female","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"it_f_sofia","name":"صوفيا","country":"إيطاليا","flag":"🇮🇹","gender":"female","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"fr_f_emma","name":"إيما","country":"فرنسا","flag":"🇫🇷","gender":"female","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"br_f_isabella","name":"إيزابيلا","country":"البرازيل","flag":"🇧🇷","gender":"female","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"jp_f_aika","name":"آيكا","country":"اليابان","flag":"🇯🇵","gender":"female","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"us_f_olivia","name":"أوليفيا","country":"الولايات المتحدة","flag":"🇺🇸","gender":"female","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"},
	{"id":"tr_f_eileen","name":"إيلين","country":"تركيا","flag":"🇹🇷","gender":"female","tier":"متاح مبدئيًا","status":"التصنيف المالي غير معتمد"}
]

var selected_gender := "male"
var selected_id := "eg_m_adam"
var overlay: Control
var cards_box: GridContainer
var detail_name: Label
var detail_country: Label
var detail_status: Label
var preview_title: Label
var preview_viewport: SubViewport
var player: Node3D
var preview_character: Node3D
var preview_world: Node3D

func _ready() -> void:
	layer = 45
	_build_launcher()
	_build_screen()

func _build_launcher() -> void:
	var launcher := Button.new()
	launcher.name = "OpenCharacterSelection"
	launcher.text = "♛  الشخصيات"
	launcher.custom_minimum_size = Vector2(154, 48)
	launcher.position = Vector2(24, 104)
	launcher.add_theme_font_size_override("font_size", 17)
	launcher.add_theme_color_override("font_color", Color("#f5df9a"))
	launcher.add_theme_stylebox_override("normal", _style(Color("#17202b"), Color("#c49a45"), 2))
	launcher.add_theme_stylebox_override("hover", _style(Color("#283344"), Color("#f1ce75"), 2))
	launcher.pressed.connect(_open_screen)
	add_child(launcher)

func _build_screen() -> void:
	overlay = Control.new()
	overlay.name = "CharacterSelectionScreen"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.015, 0.02, 0.035, 0.94)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.name = "RoyalSelectionPanel"
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 18
	panel.offset_top = 18
	panel.offset_right = -18
	panel.offset_bottom = -18
	panel.add_theme_stylebox_override("panel", _style(Color("#101722"), Color("#c49a45"), 3))
	overlay.add_child(panel)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	panel.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)
	var heading := Label.new()
	heading.text = "𓂀  KING OF EGYPT CITY — الشخصيات 𓂀"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color("#e8c46b"))
	header.add_child(heading)
	var close := Button.new()
	close.text = "✕"
	close.custom_minimum_size = Vector2(48, 42)
	close.pressed.connect(func(): overlay.visible = false)
	header.add_child(close)

	var gender_row := HBoxContainer.new()
	gender_row.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(gender_row)
	var men := Button.new()
	men.text = "♂  الرجال"
	men.toggle_mode = true
	var gender_group := ButtonGroup.new()
	gender_group.allow_unpress = false
	men.button_group = gender_group
	men.button_pressed = true
	men.pressed.connect(func(): _set_gender("male"))
	gender_row.add_child(men)
	var women := Button.new()
	women.text = "♀  النساء"
	women.toggle_mode = true
	women.button_group = gender_group
	women.pressed.connect(func(): _set_gender("female"))
	gender_row.add_child(women)

	var body := HBoxContainer.new()
	body.name = "SelectionBody"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	layout.add_child(body)

	# القائمة على اليسار.
	var list_panel := PanelContainer.new()
	list_panel.name = "CharacterListPanel"
	list_panel.custom_minimum_size = Vector2(340, 0)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_stretch_ratio = 1.0
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _style(Color("#151e2b"), Color("#806b43"), 2))
	body.add_child(list_panel)
	var list_layout := VBoxContainer.new()
	list_layout.add_theme_constant_override("separation", 8)
	list_panel.add_child(list_layout)
	var list_heading := Label.new()
	list_heading.text = "الشخصيات الجاهزة"
	list_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_heading.add_theme_color_override("font_color", Color("#e8c46b"))
	list_layout.add_child(list_heading)
	var scroll := ScrollContainer.new()
	scroll.name = "CharacterCardsScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_layout.add_child(scroll)
	cards_box = GridContainer.new()
	cards_box.columns = 2
	cards_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards_box.add_theme_constant_override("h_separation", 8)
	cards_box.add_theme_constant_override("v_separation", 8)
	scroll.add_child(cards_box)

	# المعاينة والبيانات على اليمين.
	var preview_panel := PanelContainer.new()
	preview_panel.name = "SelectedCharacterPreviewPanel"
	preview_panel.custom_minimum_size = Vector2(360, 0)
	preview_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview_panel.size_flags_stretch_ratio = 1.15
	preview_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_panel.add_theme_stylebox_override("panel", _style(Color("#151e2b"), Color("#c49a45"), 2))
	body.add_child(preview_panel)
	var preview_column := VBoxContainer.new()
	preview_column.add_theme_constant_override("separation", 8)
	preview_panel.add_child(preview_column)
	preview_title = Label.new()
	preview_title.text = "معاينة الشخصية"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 22)
	preview_title.add_theme_color_override("font_color", Color("#e8c46b"))
	preview_column.add_child(preview_title)
	preview_viewport = SubViewport.new()
	preview_viewport.name = "CharacterPreviewViewport"
	preview_viewport.size = Vector2i(520, 620)
	preview_viewport.own_world_3d = true
	preview_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var viewport_container := SubViewportContainer.new()
	viewport_container.name = "SelectedCharacter3DPreview"
	viewport_container.stretch = true
	viewport_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	viewport_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport_container.add_child(preview_viewport)
	preview_column.add_child(viewport_container)
	_build_preview_world()
	detail_name = Label.new()
	detail_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_name.add_theme_font_size_override("font_size", 26)
	detail_name.add_theme_color_override("font_color", Color("#f1d17b"))
	preview_column.add_child(detail_name)
	detail_country = Label.new()
	detail_country.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_column.add_child(detail_country)
	var rarity := Label.new()
	rarity.text = "★  شخصية جاهزة — زي ثابت"
	rarity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity.add_theme_color_override("font_color", Color("#e8c46b"))
	preview_column.add_child(rarity)
	detail_status = Label.new()
	detail_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_column.add_child(detail_status)
	var note := Label.new()
	note.text = "المعاينة مؤقتة حتى تسليم نماذج الشخصيات النهائية وربط الحفظ الآمن بملف اللاعب على الخادم."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("#d4c9ae"))
	preview_column.add_child(note)
	var select_button := Button.new()
	select_button.name = "ConfirmCharacterSelection"
	select_button.text = "تأكيد الاختيار"
	select_button.disabled = true
	select_button.tooltip_text = "يتفعّل بعد تسليم النماذج النهائية وربط selected_character_id بخدمة الملف الشخصي."
	select_button.custom_minimum_size = Vector2(0, 52)
	preview_column.add_child(select_button)
	var close_bottom := Button.new()
	close_bottom.text = "إغلاق"
	close_bottom.pressed.connect(func(): overlay.visible = false)
	preview_column.add_child(close_bottom)

	_refresh_cards()
	_refresh_details()

func _build_preview_world() -> void:
	var world := Node3D.new()
	world.name = "PreviewWorld"
	preview_viewport.add_child(world)
	var environment_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#9da8bb")
	env.ambient_light_energy = 0.8
	environment_node.environment = env
	world.add_child(environment_node)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-28, -25, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var camera := Camera3D.new()
	camera.position = Vector3(0, 1.25, 4.8)
	camera.look_at(Vector3(0, 1.0, 0), Vector3.UP)
	camera.current = true
	world.add_child(camera)
	preview_world = world

func _load_preview_character(character: Dictionary) -> void:
	if is_instance_valid(preview_character):
		preview_character.queue_free()
		preview_character = null
	var character_id := str(character.id)
	var final_path := "res://assets/characters/%s/character.tscn" % character_id
	var scene_path := final_path if ResourceLoader.exists(final_path) else PLACEHOLDER_AVATAR_SCENE
	var packed := load(scene_path) as PackedScene
	if packed == null:
		push_warning("مشهد معاينة الشخصية غير متاح: " + scene_path)
		return
	preview_character = packed.instantiate() as Node3D
	if preview_character == null:
		push_warning("مشهد الشخصية يجب أن يكون Node3D: " + scene_path)
		return
	preview_character.name = "Preview_" + character_id
	preview_world.add_child(preview_character)

func _open_screen() -> void:
	overlay.visible = true
	_refresh_cards()
	_refresh_details()

func _set_gender(value: String) -> void:
	selected_gender = value
	var selected := _find_character(selected_id)
	if selected.is_empty() or str(selected.gender) != selected_gender:
		for character in CHARACTERS:
			if str(character.gender) == selected_gender:
				selected_id = str(character.id)
				break
	_refresh_cards()
	_refresh_details()

func _refresh_cards() -> void:
	for child in cards_box.get_children():
		child.queue_free()
	for character in CHARACTERS:
		if str(character.gender) != selected_gender:
			continue
		var card := Button.new()
		card.custom_minimum_size = Vector2(126, 88)
		card.text = "%s  %s\n%s" % [str(character.flag), str(character.name), str(character.country)]
		card.add_theme_font_size_override("font_size", 15)
		var active := str(character.id) == selected_id
		card.add_theme_stylebox_override("normal", _style(Color("#29334a") if active else Color("#1b2433"), Color("#e7bd5e") if active else Color("#78613a"), 2))
		card.add_theme_stylebox_override("hover", _style(Color("#38435b"), Color("#f2d68e"), 2))
		card.pressed.connect(_select_preview.bind(str(character.id)))
		cards_box.add_child(card)

func _select_preview(character_id: String) -> void:
	selected_id = character_id
	_refresh_cards()
	_refresh_details()

func _refresh_details() -> void:
	var character := _find_character(selected_id)
	if character.is_empty():
		return
	detail_name.text = str(character.name)
	detail_country.text = "%s  %s" % [str(character.flag), str(character.country)]
	detail_status.text = str(character.status)
	preview_title.text = "معاينة %s" % str(character.name)
	_load_preview_character(character)

func _find_character(character_id: String) -> Dictionary:
	for character in CHARACTERS:
		if str(character.id) == character_id:
			return character
	return {}

func _style(bg: Color, border: Color, border_width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(border_width)
	box.set_corner_radius_all(12)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box
