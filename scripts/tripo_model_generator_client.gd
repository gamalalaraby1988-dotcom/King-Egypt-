extends CanvasLayer
## Founder-only in-game client for the protected Tripo Edge Function.
## The Tripo API key remains server-side; only the current Supabase user session is sent.
signal generation_started(task_id: String)
signal generation_finished(glb_path: String, preview_path: String)
signal generation_failed(message: String)

const FUNCTION_URL := "https://lupmaktbymuaymhqsxxu.supabase.co/functions/v1/tripo-model-generator"
const API_BASE_SETTING := "founder/auth/api_base_url"
const PUBLISHABLE_KEY_SETTING := "founder/auth/publishable_key"
const TASK_CACHE_PATH := "user://tripo_royal_main_tent.cfg"
const GLB_PATH := "user://royal_main_tent.glb"
const PREVIEW_PATH := "user://royal_main_tent_preview.png"

var _request: HTTPRequest
var _download: HTTPRequest
var _preview_download: HTTPRequest
var _action := ""
var _task_id := ""
var _model_url := ""
var _preview_url := ""
var _button: Button
var _status: Label
var _poll_button: Button

func _ready() -> void:
	layer = 70
	_request = HTTPRequest.new()
	_request.timeout = 45.0
	add_child(_request)
	_request.request_completed.connect(_on_request_completed)
	_download = HTTPRequest.new()
	_download.timeout = 90.0
	add_child(_download)
	_download.request_completed.connect(_on_glb_downloaded)
	_preview_download = HTTPRequest.new()
	_preview_download.timeout = 45.0
	add_child(_preview_download)
	_preview_download.request_completed.connect(_on_preview_downloaded)
	_build_ui()
	_load_task()
	_refresh_visibility()

func _process(_delta: float) -> void:
	_refresh_visibility()

func _refresh_visibility() -> void:
	if not is_instance_valid(_button):
		return
	var founder_ok := is_instance_valid(FounderIdentityManager) and FounderIdentityManager.is_founder
	var session_ok := is_instance_valid(PlayerAccountAuthClient) and PlayerAccountAuthClient.has_active_session()
	_button.visible = founder_ok and session_ok
	_poll_button.visible = founder_ok and session_ok and not _task_id.is_empty()

func _build_ui() -> void:
	var panel := PanelContainer.new()
	panel.name = "TripoFounderPanel"
	panel.anchor_left = 0.0
	panel.anchor_top = 0.0
	panel.anchor_right = 0.0
	panel.anchor_bottom = 0.0
	panel.offset_left = 12.0
	panel.offset_top = 66.0
	panel.offset_right = 300.0
	panel.offset_bottom = 190.0
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.06, 0.94)
	style.border_color = Color(0.82, 0.65, 0.30, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 5)
	panel.add_child(column)
	var heading := Label.new()
	heading.text = "𓂀 أدوات المؤسس — Tripo"
	heading.add_theme_color_override("font_color", Color(0.92, 0.75, 0.40))
	column.add_child(heading)
	_button = Button.new()
	_button.text = "إنشاء الخيمة الملكية الرئيسية"
	_button.pressed.connect(_start_generation)
	column.add_child(_button)
	_poll_button = Button.new()
	_poll_button.text = "متابعة توليد الخيمة"
	_poll_button.pressed.connect(_check_status)
	_poll_button.visible = false
	column.add_child(_poll_button)
	_status = Label.new()
	_status.text = "تظهر هذه الأداة لحساب المؤسس الموثّق فقط."
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_color_override("font_color", Color(0.92, 0.84, 0.65))
	column.add_child(_status)

func _headers() -> PackedStringArray:
	var key := str(ProjectSettings.get_setting(PUBLISHABLE_KEY_SETTING, "")).strip_edges()
	return PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + key,
		"Authorization: Bearer " + PlayerAccountAuthClient.get_access_token()
	])

func _can_request() -> bool:
	if not is_instance_valid(FounderIdentityManager) or not FounderIdentityManager.is_founder:
		_status.text = "تم الرفض: هوية المؤسس غير موثّقة على هذا الجهاز."
		return false
	if not is_instance_valid(PlayerAccountAuthClient) or not PlayerAccountAuthClient.has_active_session():
		_status.text = "انتهت جلسة الحساب. سجّل الدخول مجددًا."
		return false
	if PlayerAccountAuthClient.get_user_id() != FounderIdentityManager.founder_subject_id:
		_status.text = "الحساب الحالي لا يطابق هوية المؤسس المعتمدة."
		return false
	var base := str(ProjectSettings.get_setting(API_BASE_SETTING, "")).strip_edges()
	var key := str(ProjectSettings.get_setting(PUBLISHABLE_KEY_SETTING, "")).strip_edges()
	if not base.begins_with("https://") or key.is_empty():
		_status.text = "إعدادات اتصال Supabase غير مكتملة."
		return false
	return true

func _start_generation() -> void:
	if _action != "":
		_status.text = "يوجد طلب قيد التنفيذ بالفعل."
		return
	if not _can_request():
		return
	if not _task_id.is_empty():
		_status.text = "توجد مهمة محفوظة. استخدم متابعة التوليد أولًا أو انتظر نتيجتها."
		return
	_action = "create"
	_status.text = "جارٍ إرسال طلب إنشاء الخيمة إلى Tripo..."
	var body := JSON.stringify({
		"action": "create",
		"asset_id": "royal_main_tent",
		"confirm_generation": true
	})
	var err := _request.request(FUNCTION_URL, _headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		_action = ""
		_status.text = "تعذر بدء الاتصال بخدمة توليد المجسمات."

func _check_status() -> void:
	if _action != "":
		_status.text = "انتظر انتهاء الطلب الحالي."
		return
	if not _can_request():
		return
	if _task_id.is_empty():
		_status.text = "لا توجد مهمة محفوظة لمتابعتها."
		return
	_action = "status"
	_status.text = "جارٍ الاستعلام عن حالة مهمة Tripo..."
	var body := JSON.stringify({"action": "status", "task_id": _task_id})
	var err := _request.request(FUNCTION_URL, _headers(), HTTPClient.METHOD_POST, body)
	if err != OK:
		_action = ""
		_status.text = "تعذر بدء الاستعلام عن حالة المهمة."

func _on_request_completed(result: int, response_code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	var action := _action
	_action = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		_status.text = "تعذر الاتصال بخدمة Tripo. تحقق من الشبكة ثم أعد المحاولة."
		generation_failed.emit("Network request failed.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		_status.text = "استجابة غير مفهومة من خدمة توليد المجسمات (HTTP %d)." % response_code
		generation_failed.emit("Invalid function response.")
		return
	var data: Dictionary = parsed
	if response_code < 200 or response_code >= 300:
		_status.text = "رفضت الخدمة الطلب (HTTP %d): %s" % [response_code, str(data.get("error", data.get("message", "خطأ غير معروف")))]
		generation_failed.emit(_status.text)
		return
	if action == "create":
		_task_id = str(data.get("task_id", ""))
		if _task_id.is_empty():
			_status.text = "لم تُرجع الخدمة رقم المهمة. لن نكرر طلب الإنشاء تلقائيًا."
			return
		_save_task()
		_status.text = "بدأت مهمة Tripo بنجاح. رقم المهمة محفوظ؛ اضغط متابعة التوليد بعد قليل."
		generation_started.emit(_task_id)
		_refresh_visibility()
	elif action == "status":
		var status_value := str(data.get("status", "")).to_lower()
		if status_value != "success":
			_status.text = "حالة المهمة الحالية: %s. اضغط متابعة التوليد لاحقًا." % (status_value if not status_value.is_empty() else "قيد المعالجة")
			return
		_model_url = str(data.get("model_url", ""))
		_preview_url = str(data.get("rendered_image_url", ""))
		if not _model_url.begins_with("https://"):
			_status.text = "اكتمل الطلب لكن رابط GLB غير صالح أو غير متاح."
			return
		_status.text = "اكتمل المجسم. جارٍ تنزيل ملف GLB الأصلي..."
		var err := _download.request(_model_url)
		if err != OK:
			_status.text = "تعذر بدء تنزيل GLB. رابط Tripo مؤقت؛ أعد فحص الحالة للحصول على رابط جديد."
			return

func _on_glb_downloaded(result: int, response_code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300 or body.size() < 16:
		_status.text = "فشل تنزيل ملف GLB. لم يتم حفظ ملف غير مكتمل."
		generation_failed.emit("GLB download failed.")
		return
	var file := FileAccess.open(GLB_PATH, FileAccess.WRITE)
	if file == null:
		_status.text = "تعذر حفظ ملف GLB على الجهاز."
		return
	file.store_buffer(body)
	file.close()
	_status.text = "تم تنزيل المجسم وحفظه على الجهاز. جارٍ حفظ صورة المعاينة الأصلية..."
	if _preview_url.begins_with("https://"):
		var err := _preview_download.request(_preview_url)
		if err == OK:
			return
	_status.text = "تم حفظ GLB. تعذر تنزيل صورة المعاينة تلقائيًا."
	generation_finished.emit(GLB_PATH, "")

func _on_preview_downloaded(result: int, response_code: int, _headers_in: PackedStringArray, body: PackedByteArray) -> void:
	var preview_path := ""
	if result == HTTPRequest.RESULT_SUCCESS and response_code >= 200 and response_code < 300 and body.size() > 16:
		var file := FileAccess.open(PREVIEW_PATH, FileAccess.WRITE)
		if file != null:
			file.store_buffer(body)
			file.close()
			preview_path = PREVIEW_PATH
	_status.text = "تم تنزيل ملف GLB وصورة المعاينة من مهمة Tripo نفسها." if not preview_path.is_empty() else "تم حفظ GLB؛ تعذر حفظ صورة المعاينة."
	generation_finished.emit(GLB_PATH, preview_path)

func _save_task() -> void:
	var config := ConfigFile.new()
	config.set_value("task", "task_id", _task_id)
	config.save(TASK_CACHE_PATH)

func _load_task() -> void:
	var config := ConfigFile.new()
	if config.load(TASK_CACHE_PATH) == OK:
		_task_id = str(config.get_value("task", "task_id", ""))
		if not _task_id.is_empty():
			_status.text = "توجد مهمة Tripo محفوظة. يمكنك متابعة حالتها دون إنشاء مهمة جديدة."

func clear_completed_task() -> void:
	_task_id = ""
	_model_url = ""
	_preview_url = ""
	var absolute_path := ProjectSettings.globalize_path(TASK_CACHE_PATH)
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	_refresh_visibility()
