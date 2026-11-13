extends Node
## المرحلة 21: واجهة خزانة ملابس مطورة وخفيفة تعتمد على أصول الشخصية الموجودة.

const SAVE_PATH := "user://kings_city_wardrobe.cfg"
const OUTFITS := [
	{"id":"default","name":"الإطلالة الافتراضية","group":"رجالي","rarity":"أساسية"},
	{"id":"men_formal","name":"بدلة رجالية رسمية","group":"رجالي","rarity":"أنيقة"},
	{"id":"women_formal","name":"طقم نسائي رسمي","group":"نسائي","rarity":"أنيقة"},
	{"id":"urban_casual","name":"إطلالة كاجوال","group":"رجالي","rarity":"مميزة"},
	{"id":"sport","name":"إطلالة رياضية","group":"رجالي","rarity":"رياضية"}
]
const HAIRSTYLES := [
	{"id":"short", "name":"شعر قصير"},
	{"id":"long", "name":"شعر طويل"},
	{"id":"curly", "name":"شعر مجعد"}
]

var player: Node3D
var mission_manager: Node
var panel: PanelContainer
var status_label: Label
var selected_label: Label
var rarity_label: Label
var owned_outfits: Array = ["default"]
var selected_outfit := "default"
var selected_hairstyle := "short"
var outfit_buttons: Dictionary = {}

func _ready() -> void:
	refresh_ownership()
	_load_outfit()
	_apply_outfit()
	_build_ui()

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.name = "WardrobeHUD"
	layer.layer = 8
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var open_button := Button.new()
	open_button.text = "خزانة الملابس  👔"
	open_button.position = Vector2(18, 244)
	open_button.size = Vector2(178, 50)
	open_button.pressed.connect(func():
		panel.visible = true
		_refresh_ui()
	)
	root.add_child(open_button)

	panel = PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 24
	panel.offset_top = 42
	panel.offset_right = -24
	panel.offset_bottom = -42
	panel.visible = false
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.055, 0.085, 0.22)
	panel_style.border_color = Color(0.72, 0.55, 0.25, 0.95)
	panel_style.set_border_width_all(2)
	panel_style.set_corner_radius_all(16)
	panel.add_theme_stylebox_override("panel", panel_style)
	root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var top := HBoxContainer.new()
	layout.add_child(top)
	var heading := Label.new()
	heading.text = "خزانة الملابس"
	heading.add_theme_font_size_override("font_size", 27)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(heading)
	var close := Button.new()
	close.text = "إغلاق  ✕"
	close.custom_minimum_size = Vector2(112, 42)
	close.pressed.connect(func(): panel.visible = false)
	top.add_child(close)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 16)
	layout.add_child(body)

	var left := PanelContainer.new()
	left.custom_minimum_size.x = 280
	body.add_child(left)
	var left_box := VBoxContainer.new()
	left.add_child(left_box)
	var list_title := Label.new()
	list_title.text = "الإطلالات"
	list_title.add_theme_font_size_override("font_size", 20)
	left_box.add_child(list_title)
	var list_note := Label.new()
	list_note.text = "اختر إطلالة لمعاينتها على شخصيتك"
	list_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left_box.add_child(list_note)
	for outfit in OUTFITS:
		var button := Button.new()
		button.text = str(outfit.name)
		button.custom_minimum_size.y = 48
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var outfit_id: String = outfit.id
		button.pressed.connect(func(): _select_outfit(outfit_id))
		left_box.add_child(button)
		outfit_buttons[outfit_id] = button
	left_box.add_spacer(false)

	# الوسط شفاف عمدًا ليبقى مجسم اللاعب ثلاثي الأبعاد ظاهرًا خلف واجهة الخزانة.
	var center := VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_theme_constant_override("separation", 14)
	body.add_child(center)
	var preview_title := Label.new()
	preview_title.text = "معاينة الشخصية"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 23)
	center.add_child(preview_title)
	var preview_hint := Label.new()
	preview_hint.text = "شخصيتك تظهر في منتصف الشاشة\nوالتغييرات تطبق مباشرة"
	preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(preview_hint)
	selected_label = Label.new()
	selected_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selected_label.add_theme_font_size_override("font_size", 19)
	center.add_child(selected_label)
	rarity_label = Label.new()
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rarity_label.add_theme_color_override("font_color", Color(0.92, 0.72, 0.32))
	center.add_child(rarity_label)

	var right := PanelContainer.new()
	right.custom_minimum_size.x = 250
	body.add_child(right)
	var right_box := VBoxContainer.new()
	right.add_child(right_box)
	var options_title := Label.new()
	options_title.text = "التخصيص"
	options_title.add_theme_font_size_override("font_size", 20)
	right_box.add_child(options_title)
	var hair_title := Label.new()
	hair_title.text = "تسريحة الشعر"
	right_box.add_child(hair_title)
	for hairstyle in HAIRSTYLES:
		var hair_button := Button.new()
		hair_button.text = str(hairstyle.name)
		hair_button.custom_minimum_size.y = 42
		var hair_id: String = hairstyle.id
		hair_button.pressed.connect(func(): _select_hairstyle(hair_id))
		right_box.add_child(hair_button)
	var separator := HSeparator.new()
	right_box.add_child(separator)
	var ownership_title := Label.new()
	ownership_title.text = "الملابس المملوكة"
	right_box.add_child(ownership_title)
	var owned_count := Label.new()
	owned_count.name = "OwnedCount"
	right_box.add_child(owned_count)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_box.add_child(status_label)
	_refresh_ui()

func _refresh_ui() -> void:
	if not is_instance_valid(panel):
		return
	for outfit in OUTFITS:
		var item_id: String = outfit.id
		if outfit_buttons.has(item_id):
			var button: Button = outfit_buttons[item_id]
			button.text = str(outfit.name) + ("  ✓" if owned_outfits.has(item_id) else "  🔒")
			button.disabled = not owned_outfits.has(item_id)
	if is_instance_valid(selected_label):
		selected_label.text = _outfit_name(selected_outfit)
	if is_instance_valid(rarity_label):
		rarity_label.text = "التصنيف: " + _outfit_rarity(selected_outfit)
	var count_label := panel.find_child("OwnedCount", true, false) as Label
	if count_label != null:
		count_label.text = "%d من %d إطلالات مملوكة" % [owned_outfits.size(), OUTFITS.size()]
	if is_instance_valid(status_label):
		status_label.text = "التسريحة: %s\nاختياراتك تحفظ على هذا الجهاز." % _hairstyle_name(selected_hairstyle)

func _select_outfit(outfit_id: String) -> void:
	if not owned_outfits.has(outfit_id):
		status_label.text = "هذه الإطلالة غير مملوكة. يمكنك شراؤها من المتجر."
		return
	if not _save_selection(outfit_id, selected_hairstyle):
		return
	selected_outfit = outfit_id
	_apply_outfit()
	_refresh_ui()
	status_label.text = "تم تطبيق الإطلالة وحفظها على هذا الجهاز."

func _select_hairstyle(hairstyle_id: String) -> void:
	if not ["short", "long", "curly"].has(hairstyle_id):
		status_label.text = "تسريحة الشعر غير متاحة."
		return
	if not _save_selection(selected_outfit, hairstyle_id):
		return
	selected_hairstyle = hairstyle_id
	_apply_outfit()
	_refresh_ui()
	status_label.text = "تم تحديث تسريحة الشعر وحفظ اختيارك."

func _save_selection(outfit_id: String, hairstyle_id: String) -> bool:
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		if is_instance_valid(status_label):
			status_label.text = "ملف الخزانة موجود لكنه غير قابل للقراءة؛ أُوقفت الكتابة لحماية الاختيارات السابقة."
		return false
	config.set_value("wardrobe", "outfit_id", outfit_id)
	config.set_value("wardrobe", "hairstyle_id", hairstyle_id)
	var result := config.save(SAVE_PATH)
	if result != OK:
		if is_instance_valid(status_label):
			status_label.text = "تعذر حفظ الاختيار على هذا الجهاز؛ لم يتم تطبيق التغيير."
		return false
	return true

func _load_outfit() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		selected_outfit = str(config.get_value("wardrobe", "outfit_id", "default"))
		selected_hairstyle = str(config.get_value("wardrobe", "hairstyle_id", "short"))
	if _find_outfit(selected_outfit).is_empty() or not owned_outfits.has(selected_outfit):
		selected_outfit = "default"
	if not ["short", "long", "curly"].has(selected_hairstyle):
		selected_hairstyle = "short"

func _apply_outfit() -> void:
	if not is_instance_valid(player):
		return
	var avatar := player.get_node_or_null("AvatarVisual")
	if avatar != null and avatar.has_method("apply_outfit"):
		avatar.apply_outfit(selected_outfit)
	if avatar != null and avatar.has_method("apply_hairstyle"):
		avatar.apply_hairstyle(selected_hairstyle)

func _find_outfit(outfit_id: String) -> Dictionary:
	for outfit in OUTFITS:
		if outfit.id == outfit_id:
			return outfit
	return {}

func _outfit_name(outfit_id: String) -> String:
	return str(_find_outfit(outfit_id).get("name", "الإطلالة الافتراضية"))

func _outfit_rarity(outfit_id: String) -> String:
	return str(_find_outfit(outfit_id).get("rarity", "أساسية"))

func _hairstyle_name(hairstyle_id: String) -> String:
	for hairstyle in HAIRSTYLES:
		if hairstyle.id == hairstyle_id:
			return str(hairstyle.name)
	return "شعر قصير"

func refresh_ownership() -> void:
	if is_instance_valid(mission_manager) and mission_manager.has_method("get_owned_outfits"):
		owned_outfits = mission_manager.get_owned_outfits()
	else:
		# توافق احتياطي مع مشاهد الاختبار القديمة التي لا تمرر مدير اللاعب.
		var config := ConfigFile.new()
		if config.load("user://kings_city_store.cfg") == OK:
			var saved = config.get_value("store", "owned_outfits", ["default"])
			owned_outfits = saved if saved is Array else ["default"]
		else:
			owned_outfits = ["default"]
	if not owned_outfits.has("default"):
		owned_outfits.append("default")
	if is_instance_valid(panel):
		_refresh_ui()
