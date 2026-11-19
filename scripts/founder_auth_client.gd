extends Node
## Supabase Auth email OTP client. Email verification alone never grants founder privileges.
signal request_finished(success: bool, message: String)
signal email_verified(user_id: String, email: String)
signal auth_session_received(access_token: String, refresh_token: String)

const API_BASE_SETTING := "founder/auth/api_base_url"
const PUBLISHABLE_KEY_SETTING := "founder/auth/publishable_key"
const OTP_PATH := "/auth/v1/otp"
const VERIFY_PATH := "/auth/v1/verify"

var _http: HTTPRequest
var _pending_action := ""
var _pending_email := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "FounderAuthHttpRequest"
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func is_configured() -> bool:
	var base := _api_base_url()
	return base.begins_with("https://") and not base.ends_with("/") and not _publishable_key().is_empty()

func request_email_code(email: String) -> bool:
	if not _can_start_request(email):
		return false
	_pending_email = email.strip_edges().to_lower()
	return _post(OTP_PATH, {"email": _pending_email, "create_user": true}, "request_code")

func verify_email_code(email: String, code: String) -> bool:
	if _pending_action != "":
		request_finished.emit(false, "هناك طلب تحقق قيد التنفيذ.")
		return false
	var normalized_code := code.strip_edges()
	if not _valid_email(email) or normalized_code.length() != 6 or not normalized_code.is_valid_int():
		request_finished.emit(false, "راجع البريد وأدخل رمز التحقق المكوّن من 6 أرقام.")
		return false
	if not is_configured():
		request_finished.emit(false, "إعدادات خدمة التحقق غير مكتملة.")
		return false
	_pending_email = email.strip_edges().to_lower()
	return _post(VERIFY_PATH, {"email": _pending_email, "token": normalized_code, "type": "email"}, "verify_code")

func _can_start_request(email: String) -> bool:
	if _pending_action != "":
		request_finished.emit(false, "هناك طلب تحقق قيد التنفيذ.")
		return false
	if not _valid_email(email):
		request_finished.emit(false, "أدخل بريدًا إلكترونيًا صحيحًا.")
		return false
	if not is_configured():
		request_finished.emit(false, "إعدادات خدمة التحقق غير مكتملة.")
		return false
	return true

func _api_base_url() -> String:
	return str(ProjectSettings.get_setting(API_BASE_SETTING, "")).strip_edges().trim_suffix("/")

func _publishable_key() -> String:
	return str(ProjectSettings.get_setting(PUBLISHABLE_KEY_SETTING, "")).strip_edges()

func _valid_email(email: String) -> bool:
	var normalized := email.strip_edges()
	var at_pos := normalized.find("@")
	var dot_pos := normalized.rfind(".")
	return at_pos > 0 and dot_pos > at_pos + 1 and dot_pos < normalized.length() - 1 and not normalized.contains(" ")

func _post(path: String, payload: Dictionary, action: String) -> bool:
	var headers := PackedStringArray(["Content-Type: application/json", "Accept: application/json", "apikey: " + _publishable_key()])
	var error := _http.request(_api_base_url() + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request_finished.emit(false, "تعذر بدء اتصال آمن بخدمة التحقق.")
		return false
	_pending_action = action
	return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _pending_action
	_pending_action = ""
	var parsed := JSON.new()
	if result != HTTPRequest.RESULT_SUCCESS:
		request_finished.emit(false, "فشل الاتصال بخدمة التحقق. حاول لاحقًا.")
		return
	if parsed.parse(body.get_string_from_utf8()) != OK or not (parsed.data is Dictionary):
		request_finished.emit(false, "استجابة غير صالحة من خدمة التحقق.")
		return
	var response: Dictionary = parsed.data
	if response_code < 200 or response_code >= 300:
		request_finished.emit(false, _safe_auth_error(response))
		return
	if action == "request_code":
		request_finished.emit(true, "إذا كان البريد صالحًا للإرسال، فسيصلك رمز التحقق.")
		return
	if action == "verify_code":
		var user_value: Variant = response.get("user", {})
		var access_token := str(response.get("access_token", ""))
		var refresh_token := str(response.get("refresh_token", ""))
		if not (user_value is Dictionary) or access_token.is_empty() or refresh_token.is_empty():
			request_finished.emit(false, "لم تُرجع خدمة المصادقة جلسة صالحة.")
			return
		var user: Dictionary = user_value
		var verified_email := str(user.get("email", "")).strip_edges().to_lower()
		var confirmed_at := str(user.get("email_confirmed_at", ""))
		var user_id := str(user.get("id", ""))
		if verified_email != _pending_email or confirmed_at.is_empty() or user_id.is_empty():
			request_finished.emit(false, "لم يثبت الخادم ملكية البريد المطلوب.")
			return
		email_verified.emit(user_id, verified_email)
		auth_session_received.emit(access_token, refresh_token)
		request_finished.emit(true, "تم التحقق من البريد بنجاح. صلاحيات المؤسس تحتاج اعتمادًا خادميًا منفصلًا.")

func _safe_auth_error(response: Dictionary) -> String:
	match str(response.get("code", "")):
		"over_email_send_rate_limit":
			return "تم تجاوز حد إرسال الرسائل مؤقتًا. حاول لاحقًا."
		"email_address_invalid":
			return "عنوان البريد الإلكتروني غير صالح."
		"otp_expired":
			return "انتهت صلاحية الرمز. اطلب رمزًا جديدًا."
		"otp_disabled":
			return "التحقق برمز البريد غير مفعّل حاليًا."
		_:
			return "تعذر إتمام التحقق. راجع الرمز وحاول مرة أخرى."
