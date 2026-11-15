extends Node
## واجهة الملف الشخصي وإعدادات اللعب الأساسية، تحفظ محليًا.

const SETTINGS_PATH := "user://kings_city_settings.cfg"
var mission_manager: Node
var player: Node3D
var panel: PanelContainer
var name_input: LineEdit
var name_change_status: Label
var volume_slider: HSlider
var quality_select: OptionButton
var language_select: OptionButton
var info_label: Label
var shadow_light: DirectionalLight3D
var root_control: Control

func _ready() -> void:
	_build_ui()
	if not AccountDataSession.session_ready.is_connected(_on_account_session_ready):
		AccountDataSession.session_ready.connect(_on_account_session_ready)
	if not AccountDataSession.session_invalidated.is_connected(_on_account_session_invalidated):
		AccountDataSession.session_invalidated.connect(_on_account_session_invalidated)
	_load_settings()
	if AccountDataSession.is_ready():
		_on_account_session_ready(AccountDataSession.get_user_id(), AccountDataSession.get_generation(), AccountDataSession.get_profile_path())
	else:
		_on_account_session_invalidated("", -1)
	_apply_settings()

func _exit_tree() -> void:
	if AccountDataSession.session_ready.is_connected(_on_account_session_ready):
		AccountDataSession.session_ready.disconnect(_on_account_session_ready)
	if AccountDataSession.session_invalidated.is_connected(_on_account_session_invalidated):
		AccountDataSession.session_invalidated.disconnect(_on_account_session_invalidated)

func _on_account_session_ready(user_id: String, generation: int, profile_path: String) -> void:
	if not AccountDataSession.is_session_current(user_id, generation) or profile_path.is_empty():
		return
	_load_profile_name(profile_path)

func _on_account_session_invalidated(_previous_user_id: String, _generation: int) -> void:
	if is_instance_valid(name_input):
		name_input.text = "لاعب جديد"
		name_input.editable = false
	if is_instance_valid(name_change_status):
		name_change_status.text = "سجّل الدخول لعرض اسم حسابك وتغييره."

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
	name_change_status = Label.new()
	name_change_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(name_change_status)

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
	# إعدادات الصوت والجودة واللغة إعدادات للجهاز، وليست بيانات لاعب.
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		language_select.select(0)
		if FileAccess.file_exists(SETTINGS_PATH):
			info_label.text = "تعذر قراءة إعدادات الجهاز؛ تم استخدام القيم الافتراضية."
		return
	var saved_volume: Variant = config.get_value("settings", "volume", 80)
	var volume_value := float(saved_volume) if saved_volume is int or saved_volume is float else 80.0
	volume_slider.value = clampf(volume_value, 0.0, 100.0) if is_finite(volume_value) else 80.0
	var saved_quality: Variant = config.get_value("settings", "quality", 0)
	var quality_value := int(saved_quality) if saved_quality is int or saved_quality is float else 0
	quality_select.select(clampi(quality_value, 0, 2))
	var saved_language_value: Variant = config.get_value("settings", "language", "auto")
	var saved_language := str(saved_language_value) if saved_language_value is String and ["auto", "ar", "en"].has(saved_language_value) else "auto"
	language_select.select({"auto": 0, "ar": 1, "en": 2}.get(saved_language, 0))
	CityLanguage.set_language(saved_language)

func _load_profile_name(profile_path: String) -> void:
	if not AccountDataSession.is_ready() or profile_path != AccountDataSession.get_profile_path():
		return
	var config := ConfigFile.new()
	var load_error := config.load(profile_path)
	if load_error != OK and FileAccess.file_exists(profile_path):
		name_input.editable = false
		name_change_status.text = "تعذر قراءة ملف الحساب؛ تم إيقاف تعديل الاسم لحماية البيانات."
		return
	var saved_name: Variant = config.get_value("profile", "player_name", "لاعب جديد")
	name_input.text = str(saved_name).strip_edges().substr(0, 24) if saved_name is String else "لاعب جديد"
	_update_name_change_status(config)

func _save_settings() -> void:
	# احفظ تفضيلات الجهاز في ملف منفصل عن بيانات الحساب والمحفظة.
	var settings := ConfigFile.new()
	var settings_error := settings.load(SETTINGS_PATH)
	if settings_error != OK and FileAccess.file_exists(SETTINGS_PATH):
		info_label.text = "تعذر قراءة إعدادات الجهاز؛ لم يتم استبدال الملف."
		return
	settings.set_value("settings", "volume", int(volume_slider.value))
	settings.set_value("settings", "quality", quality_select.selected)
	var language_modes := ["auto", "ar", "en"]
	var selected_language: String = language_modes[clampi(language_select.selected, 0, 2)]
	settings.set_value("settings", "language", selected_language)
	var settings_save_error := settings.save(SETTINGS_PATH)
	if settings_save_error != OK:
		info_label.text = "تعذر حفظ إعدادات الجهاز. رمز الخطأ: %s" % settings_save_error
		return

	var name_change_blocked := false
	if AccountDataSession.is_ready():
		var profile_path := AccountDataSession.get_profile_path()
		var profile := ConfigFile.new()
		var profile_error := profile.load(profile_path)
		if profile_error != OK and FileAccess.file_exists(profile_path):
			info_label.text = "تم حفظ إعدادات الجهاز، لكن تعذر قراءة ملف الحساب؛ لم يتم تعديل الاسم أو بيانات المحفظة."
			return
		var old_name_value: Variant = profile.get_value("profile", "player_name", "لاعب جديد")
		var old_name := str(old_name_value).strip_edges() if old_name_value is String else "لاعب جديد"
		var requested_name := name_input.text.strip_edges()
		if requested_name.is_empty():
			requested_name = old_name if not old_name.is_empty() else "لاعب"
		requested_name = requested_name.substr(0, 24)
		var name_changed := requested_name != old_name
		var today := Time.get_date_string_from_system()
		var last_change_value: Variant = profile.get_value("profile", "player_name_change_date", "")
		var last_change_date := str(last_change_value) if last_change_value is String else ""
		if name_changed and last_change_date == today:
			name_input.text = old_name
			name_change_blocked = true
			requested_name = old_name
			name_changed = false
		if name_changed:
			profile.set_value("profile", "player_name", requested_name)
			profile.set_value("profile", "player_name_change_date", today)
			if not AccountDataSession.is_session_current(AccountDataSession.get_user_id(), AccountDataSession.get_generation()):
				info_label.text = "تغير الحساب أثناء الحفظ؛ أُوقف تعديل الاسم."
				return
			var balances: Dictionary = WalletManager.get_balances()
			if not WalletManager.save_profile_update(profile, int(balances.get("money", 0)), int(balances.get("chips", 0))):
				info_label.text = "تعذر حفظ الاسم داخل ملف الحساب؛ لم يتم تغيير بيانات المحفظة."
				return
		_update_name_change_status(profile)
	else:
		name_input.editable = false
		name_change_status.text = "سجّل الدخول لحفظ اسم اللاعب الخاص بحسابك."

	CityLanguage.set_language(selected_language)
	_apply_settings()
	_refresh_info()
	if name_change_blocked:
		info_label.text += "\nيمكن تغيير اسم اللاعب مرة واحدة فقط في اليوم. حاول مرة أخرى غدًا؛ تم حفظ بقية الإعدادات دون تغيير الاسم."
	info_label.text += "\nتم حفظ إعدادات الجهاز محليًا."
	if not AccountDataSession.is_ready():
		info_label.text += "\nلم يتم حفظ اسم اللاعب لعدم وجود حساب نشط."

func _update_name_change_status(config: ConfigFile) -> void:
	if not is_instance_valid(name_change_status):
		return
	if not AccountDataSession.is_ready():
		name_input.editable = false
		name_change_status.text = "سجّل الدخول لعرض اسم حسابك وتغييره."
		return
	var last_change_value: Variant = config.get_value("profile", "player_name_change_date", "")
	var last_change_date := str(last_change_value) if last_change_value is String else ""
	var already_changed_today := last_change_date == Time.get_date_string_from_system()
	name_input.editable = not already_changed_today
	if already_changed_today:
		name_change_status.text = "تم استخدام تغيير الاسم اليوم؛ سيُفتح التغيير مجددًا غدًا."
	else:
		name_change_status.text = "يمكنك تغيير اسمك مرة واحدة يوميًا."
	name_change_status.text += "\nملاحظة: هذا قيد محلي مؤقت؛ الحماية النهائية تتطلب اعتماد التوقيت من الخادم."

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
	var balances: Dictionary = WalletManager.get_balances()
	var lines: Array[String] = [
		"المستوى: %d" % mission_manager.player_level,
		"الخبرة: %d" % mission_manager.xp,
		"المال: %d" % int(balances.get("money", mission_manager.money)),
		"الرقائق: %d" % int(balances.get("chips", mission_manager.chips)),
		"الجواهر: %d" % int(balances.get("gems", 0)),
		"",
		"آخر حركات المحفظة:"
	]
	for entry in WalletManager.get_recent_transactions(5):
		if str(entry.get("kind", "")) == "migration":
			lines.append("تم ترحيل الأرصدة القديمة دون تغيير.")
			continue
		var currency := str(entry.get("currency", ""))
		var currency_name: String = str({"money": "مال", "chips": "رقائق", "gems": "جواهر"}.get(currency, currency))
		var change := int(entry.get("balance_after", 0)) - int(entry.get("balance_before", 0))
		var sign: String = "+" if change >= 0 else ""
		lines.append("%s %s%d — %s" % [currency_name, sign, change, str(entry.get("reason", "عملية محفظة"))])
	if lines.size() == 7:
		lines.append("لا توجد حركات مسجلة بعد.")
	info_label.text = "\n".join(lines)
