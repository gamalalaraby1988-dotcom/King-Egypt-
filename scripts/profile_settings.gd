extends Node
## واجهة الملف الشخصي وإعدادات اللعب الأساسية، تحفظ محليًا.

const SAVE_PATH := "user://kings_city_profile.cfg"
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
	_load_settings()
	SupabaseTestClient.auth_changed.connect(_on_test_auth_changed)
	_apply_settings()

func _on_test_auth_changed(_is_authenticated: bool, _user_id: String) -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK and FileAccess.file_exists(SAVE_PATH):
		name_input.editable = false
		name_change_status.text = "تعذر قراءة ملف اللاعب؛ تغيير الاسم موقوف لحماية البيانات."
		return
	_update_name_change_status(config)

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
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		name_input.text = "لاعب جديد"
		language_select.select(0)
		if FileAccess.file_exists(SAVE_PATH):
			name_input.editable = false
			name_change_status.text = "تعذر قراءة بيانات الاسم؛ لا يمكن التحقق من حق التغيير اليومي بأمان."
		else:
			_update_name_change_status(config)
		return
	var saved_name: Variant = config.get_value("profile", "player_name", "لاعب جديد")
	name_input.text = str(saved_name).strip_edges().substr(0, 24) if saved_name is String else "لاعب جديد"
	_update_name_change_status(config)
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

func _save_settings() -> void:
	var config := ConfigFile.new()
	var load_error := config.load(SAVE_PATH)
	if load_error != OK and FileAccess.file_exists(SAVE_PATH):
		info_label.text = "ملف اللاعب موجود لكنه غير قابل للقراءة؛ أُوقفت كتابة الإعدادات لحماية الرصيد والبيانات."
		return
	var old_name_value: Variant = config.get_value("profile", "player_name", "لاعب جديد")
	var old_name := str(old_name_value).strip_edges() if old_name_value is String else "لاعب جديد"
	var requested_name := name_input.text.strip_edges()
	if requested_name.is_empty():
		requested_name = old_name if not old_name.is_empty() else "لاعب"
	requested_name = requested_name.substr(0, 24)
	var name_changed := requested_name != old_name
	var name_change_blocked := false
	var server_next_name_change_at := ""
	var name_change_failure_message := ""
	if name_changed:
		if not SupabaseTestClient.is_authenticated():
			name_input.text = old_name
			requested_name = old_name
			name_changed = false
			name_change_blocked = true
			name_change_status.text = "تغيير الاسم متاح بعد تسجيل الدخول بحساب الاختبار؛ لا نعتمد ساعة الجهاز لتطبيق الحد اليومي."
		else:
			name_change_status.text = "جارٍ التحقق من حد تغيير الاسم على الخادم..."
			var server_result: Dictionary = await SupabaseTestClient.change_test_display_name(requested_name)
			if not bool(server_result.get("ok", false)):
				name_input.text = old_name
				requested_name = old_name
				name_changed = false
				name_change_blocked = true
				name_change_failure_message = str(server_result.get("message", "رفض الخادم تغيير الاسم."))
				server_next_name_change_at = str(server_result.get("next_change_at", ""))
				name_change_status.text = name_change_failure_message
				if not server_next_name_change_at.is_empty():
					name_change_status.text += " موعد السماح التالي حسب الخادم: %s" % server_next_name_change_at
			else:
				requested_name = str(server_result.get("display_name", requested_name))
				name_input.text = requested_name
				server_next_name_change_at = str(server_result.get("next_change_at", ""))
				name_change_status.text = "تم تغيير الاسم من الخادم. موعد السماح التالي: %s" % (server_next_name_change_at if not server_next_name_change_at.is_empty() else "يُحدده الخادم")
	config.set_value("profile", "player_name", requested_name)
	config.set_value("settings", "volume", int(volume_slider.value))
	config.set_value("settings", "quality", quality_select.selected)
	var language_modes := ["auto", "ar", "en"]
	var selected_language: String = language_modes[clampi(language_select.selected, 0, 2)]
	config.set_value("settings", "language", selected_language)
	if not WalletManager.save_profile_metadata(config):
		info_label.text = "تعذر حفظ الإعدادات؛ لم يتم اعتماد التغييرات لحماية ملف اللاعب."
		return
	CityLanguage.set_language(selected_language)
	_apply_settings()
	_refresh_info()
	if name_change_blocked:
		info_label.text += "\nتعذر اعتماد الاسم الجديد: %s تم حفظ بقية الإعدادات دون تغيير الاسم." % name_change_failure_message
	info_label.text += "\nتم حفظ الإعدادات محليًا."
	_update_name_change_status(config)
	if not server_next_name_change_at.is_empty():
		name_change_status.text += "\nموعد السماح التالي حسب الخادم: %s" % server_next_name_change_at

func _update_name_change_status(_config: ConfigFile) -> void:
	if not is_instance_valid(name_change_status):
		return
	if SupabaseTestClient.is_authenticated():
		name_input.editable = true
		name_change_status.text = "تغيير الاسم يتم التحقق منه على الخادم مرة واحدة يوميًا."
	else:
		name_input.editable = false
		name_change_status.text = "تغيير الاسم موقوف حتى تسجيل الدخول بحساب الاختبار؛ لا يُستخدم تاريخ الجهاز كحماية."

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
	var wallet_available := WalletManager.initialized and not WalletManager.integrity_blocked and not balances.is_empty()
	var lines: Array[String] = [
		"المستوى: %d" % mission_manager.player_level,
		"الخبرة: %d" % mission_manager.xp
	]
	if wallet_available:
		lines.append("المال: %d" % int(balances.get("money", 0)))
		lines.append("الرقائق: %d" % int(balances.get("chips", 0)))
		lines.append("الجواهر: %d" % int(balances.get("gems", 0)))
		lines.append("")
		lines.append("آخر حركات المحفظة:")
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
	else:
		lines.append("المال: موقوف للمراجعة")
		lines.append("الرقائق: موقوفة للمراجعة")
		lines.append("الجواهر: موقوفة للمراجعة")
		lines.append("")
		lines.append("سجل المحفظة موقوف حتى مراجعة سلامة ملف الحفظ.")
	info_label.text = "\n".join(lines)
