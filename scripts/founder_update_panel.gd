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
var supervisor_id_input: LineEdit
var supervisor_player_option: OptionButton
var supervisor_role_option: OptionButton
var supervisors_list: VBoxContainer
var supervisor_status: Label
var supervisor_drafts: Array[Dictionary] = []

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

	_add_field_label(content, "إدارة المشرفين المساعدين")
	var supervisor_hint := Label.new()
	supervisor_hint.text = "اختر لاعبين تثق بهم كمشرفين. الصلاحيات الفعلية لا تُفعّل إلا بعد اعتمادها والتحقق منها على الخادم."
	supervisor_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(supervisor_hint)
	_add_field_label(content, "الاختيار من اللاعبين")
	supervisor_player_option = OptionButton.new()
	supervisor_player_option.add_item("قائمة اللاعبين ستظهر بعد ربط خدمة اللاعبين المتصلين")
	supervisor_player_option.disabled = true
	content.add_child(supervisor_player_option)
	var roster_hint := Label.new()
	roster_hint.text = "اختيار اللاعب من القائمة سيتاح بعد تجهيز واجهة آمنة لجلب اللاعبين المسجلين والمتصلين من الخادم."
	roster_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(roster_hint)
	_add_field_label(content, "أو الإضافة مباشرةً باستخدام رمز اللاعب")
	supervisor_id_input = LineEdit.new()
	supervisor_id_input.placeholder_text = "أدخل رمز اللاعب أو Player ID"
	content.add_child(supervisor_id_input)
	supervisor_role_option = OptionButton.new()
	supervisor_role_option.add_item("مشرف محادثة — إدارة البلاغات والمحادثة", 0)
	supervisor_role_option.add_item("مشرف فعاليات — متابعة الفعاليات", 1)
	supervisor_role_option.add_item("مشرف دعم — مساعدة اللاعبين", 2)
	content.add_child(supervisor_role_option)
	var add_supervisor_button := Button.new()
	add_supervisor_button.text = "إضافة إلى قائمة المشرفين المقترحين"
	add_supervisor_button.pressed.connect(_add_supervisor_draft)
	content.add_child(add_supervisor_button)
	supervisors_list = VBoxContainer.new()
	supervisors_list.add_theme_constant_override("separation", 4)
	content.add_child(supervisors_list)
	supervisor_status = Label.new()
	supervisor_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	supervisor_status.text = "لا توجد تعيينات محفوظة. هذه قائمة مقترحة محلية وليست صلاحيات مفعّلة."
	content.add_child(supervisor_status)

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
	config.set_value("draft", "supervisors", supervisor_drafts)
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
	supervisor_drafts = config.get_value("draft", "supervisors", [])
	_refresh_supervisors_list()
	status_label.text = "تم استرجاع مسودة محفوظة على هذا الجهاز. النشر ما زال غير متاح حتى ربط خدمة الإصدار الآمنة."

func _add_supervisor_draft() -> void:
	if not is_instance_valid(FounderIdentityManager) or not FounderIdentityManager.is_founder:
		supervisor_status.text = "تم رفض الإجراء: هذه الخاصية للمؤسس فقط."
		return
	var player_id := supervisor_id_input.text.strip_edges()
	if player_id.is_empty():
		supervisor_status.text = "أدخل رمز اللاعب أولًا."
		return
	for entry in supervisor_drafts:
		if str(entry.get("player_id", "")) == player_id:
			supervisor_status.text = "هذا اللاعب موجود بالفعل في القائمة."
			return
	var roles := ["مشرف محادثة", "مشرف فعاليات", "مشرف دعم"]
	var role := roles[supervisor_role_option.selected]
	supervisor_drafts.append({"player_id": player_id, "role": role})
	supervisor_id_input.clear()
	_refresh_supervisors_list()
	supervisor_status.text = "أُضيف اللاعب باستخدام الرمز إلى قائمة المشرفين المقترحين. احفظ المسودة للاحتفاظ بالقائمة على هذا الجهاز."

func _refresh_supervisors_list() -> void:
	if not is_instance_valid(supervisors_list):
		return
	for child in supervisors_list.get_children():
		child.queue_free()
	for index in range(supervisor_drafts.size()):
		var entry: Dictionary = supervisor_drafts[index]
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = "%s — %s" % [str(entry.get("player_id", "")), str(entry.get("role", ""))]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(label)
		var remove_button := Button.new()
		remove_button.text = "إزالة"
		remove_button.pressed.connect(_remove_supervisor_draft.bind(index))
		row.add_child(remove_button)
		supervisors_list.add_child(row)
	if supervisor_drafts.is_empty():
		supervisor_status.text = "لا توجد تعيينات محفوظة. هذه قائمة مقترحة محلية وليست صلاحيات مفعّلة."

func _remove_supervisor_draft(index: int) -> void:
	if index < 0 or index >= supervisor_drafts.size():
		return
	supervisor_drafts.remove_at(index)
	_refresh_supervisors_list()
	supervisor_status.text = "تمت إزالة اللاعب من القائمة المقترحة. احفظ المسودة لتثبيت التغيير محليًا."
