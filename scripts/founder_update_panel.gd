extends CanvasLayer
## لوحة إعداد مسودة تحديث من داخل اللعبة. النشر الفعلي يظل مغلقًا حتى ربط خدمة خادمية موثوقة.

const DRAFT_PATH := "user://founder_update_draft.cfg"
const GOLD := Color(0.88, 0.70, 0.34)
const PANEL_BG := Color(0.035, 0.045, 0.06, 0.97)

var open_button: Button
var panel: PanelContainer
var version_input: LineEdit
var notes_input: TextEdit
var forced_toggle: CheckBox
var schedule_input: LineEdit
var status_label: Label
var publish_button: Button

func _ready() -> void:
	layer = 60
	_build_ui()
	_load_draft()

func _process(_delta: float) -> void:
	# لا نعتمد على اسم اللاعب أو بيانات محلية قابلة للتعديل كصلاحية.
	var verified_founder := is_instance_valid(FounderIdentityManager) and FounderIdentityManager.is_founder
	open_button.visible = verified_founder
	if not verified_founder:
		panel.visible = false

func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	open_button = Button.new()
	open_button.name = "FounderUpdateButton"
	open_button.text = "👑 إدارة التحديثات"
	open_button.position = Vector2(12, 12)
	open_button.custom_minimum_size = Vector2(178, 42)
	open_button.add_theme_color_override("font_color", GOLD)
	open_button.pressed.connect(_toggle_panel)
	root.add_child(open_button)

	panel = PanelContainer.new()
	panel.name = "FounderUpdatePanel"
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	var viewport_size := get_viewport().get_visible_rect().size
	var panel_width := minf(420.0, maxf(220.0, viewport_size.x - 16.0))
	var panel_height := minf(540.0, maxf(280.0, viewport_size.y - 16.0))
	panel.offset_left = -panel_width * 0.5
	panel.offset_right = panel_width * 0.5
	panel.offset_top = -panel_height * 0.5
	panel.offset_bottom = panel_height * 0.5
	panel.visible = false
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 9)
	scroll.add_child(content)

	var header := HBoxContainer.new()
	content.add_child(header)
	var title := Label.new()
	title.text = "𓂀 إدارة تحديثات KING OF EGYPT CITY"
	title.add_theme_color_override("font_color", GOLD)
	title.add_theme_font_size_override("font_size", 17)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.pressed.connect(func(): panel.visible = false)
	header.add_child(close)

	_add_field_label(content, "رقم الإصدار")
	version_input = LineEdit.new()
	version_input.placeholder_text = "مثال: 1.0.1"
	content.add_child(version_input)

	_add_field_label(content, "ملاحظات التحديث للاعبين")
	notes_input = TextEdit.new()
	notes_input.custom_minimum_size = Vector2(0, 105)
	notes_input.placeholder_text = "اكتب أهم التغييرات والتحسينات..."
	content.add_child(notes_input)

	forced_toggle = CheckBox.new()
	forced_toggle.text = "تحديث إجباري (يُطلب من اللاعب التحديث قبل المتابعة)"
	content.add_child(forced_toggle)

	_add_field_label(content, "موعد النشر (اختياري — ISO 8601)")
	schedule_input = LineEdit.new()
	schedule_input.placeholder_text = "2026-12-01T18:00:00Z"
	content.add_child(schedule_input)

	var save_button := Button.new()
	save_button.text = "حفظ مسودة التحديث على هذا الجهاز"
	save_button.pressed.connect(_save_draft)
	content.add_child(save_button)

	publish_button = Button.new()
	publish_button.text = "النشر غير متاح — بانتظار ربط خدمة الإصدار الآمنة"
	publish_button.disabled = true
	content.add_child(publish_button)

	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.text = "يمكنك تجهيز المسودة الآن. لن يتم نشرها أو إرسال إشعار للاعبين قبل ربط خدمة خادمية موثوقة والتحقق من صلاحية المؤسس على الخادم."
	status_label.add_theme_color_override("font_color", GOLD)
	content.add_child(status_label)

func _add_field_label(parent: VBoxContainer, caption: String) -> void:
	var label := Label.new()
	label.text = caption
	label.add_theme_color_override("font_color", GOLD)
	parent.add_child(label)

func _toggle_panel() -> void:
	panel.visible = not panel.visible

func _save_draft() -> void:
	if not is_instance_valid(FounderIdentityManager) or not FounderIdentityManager.is_founder:
		status_label.text = "تم رفض الحفظ: يجب التحقق من هوية المؤسس أولًا."
		return
	var version := version_input.text.strip_edges()
	if version.is_empty() or notes_input.text.strip_edges().is_empty():
		status_label.text = "أدخل رقم الإصدار وملاحظات التحديث قبل حفظ المسودة."
		return
	var config := ConfigFile.new()
	config.set_value("draft", "version", version)
	config.set_value("draft", "notes", notes_input.text.strip_edges())
	config.set_value("draft", "forced", forced_toggle.button_pressed)
	config.set_value("draft", "scheduled_at", schedule_input.text.strip_edges())
	config.set_value("draft", "saved_at_unix", int(Time.get_unix_time_from_system()))
	var error := config.save(DRAFT_PATH)
	if error == OK:
		status_label.text = "تم حفظ المسودة محليًا على هذا الجهاز. لم يتم رفعها أو نشرها للاعبين."
	else:
		status_label.text = "تعذر حفظ المسودة على الجهاز. رمز الخطأ: %s" % error_string(error)

func _load_draft() -> void:
	var config := ConfigFile.new()
	if config.load(DRAFT_PATH) != OK:
		version_input.text = str(ProjectSettings.get_setting("application/config/version", ""))
		return
	version_input.text = str(config.get_value("draft", "version", ""))
	notes_input.text = str(config.get_value("draft", "notes", ""))
	forced_toggle.button_pressed = bool(config.get_value("draft", "forced", false))
	schedule_input.text = str(config.get_value("draft", "scheduled_at", ""))
	status_label.text = "تم استرجاع مسودة محفوظة على هذا الجهاز. النشر ما زال غير متاح حتى ربط خدمة الإصدار الآمنة."
