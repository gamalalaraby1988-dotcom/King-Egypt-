extends Node
## HTTPS email verification client. The server, never the client, decides founder entitlement.

signal request_finished(success: bool, message: String)
signal entitlement_verified

const API_BASE_SETTING := "founder/auth/api_base_url"
const REQUEST_CODE_PATH := "/v1/founder/email/request-code"
const VERIFY_CODE_PATH := "/v1/founder/email/verify-code"

var _http: HTTPRequest
var _pending_action := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "FounderAuthHttpRequest"
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func is_configured() -> bool:
	var base := _api_base_url()
	return base.begins_with("https://") and not base.ends_with("/")

func request_email_code(email: String) -> bool:
	if _pending_action != "":
		request_finished.emit(false, "هناك طلب تحقق قيد التنفيذ.")
		return false
	if not _valid_email(email):
		request_finished.emit(false, "أدخل بريدًا إلكترونيًا صحيحًا.")
		return false
	if not is_configured():
		request_finished.emit(false, "خدمة التحقق غير مهيأة بعد.")
		return false
	return _post(REQUEST_CODE_PATH, {"email": email.strip_edges().to_lower()}, "request_code")

func verify_email_code(email: String, code: String) -> bool:
	if _pending_action != "":
		request_finished.emit(false, "هناك طلب تحقق قيد التنفيذ.")
		return false
	if not _valid_email(email) or code.strip_edges().length() < 4 or code.strip_edges().length() > 10:
		request_finished.emit(false, "راجع البريد ورمز التحقق.")
		return false
	if not is_configured():
		request_finished.emit(false, "خدمة التحقق غير مهيأة بعد.")
		return false
	return _post(VERIFY_CODE_PATH, {
		"email": email.strip_edges().to_lower(),
		"code": code.strip_edges()
	}, "verify_code")

func _api_base_url() -> String:
	return str(ProjectSettings.get_setting(API_BASE_SETTING, "")).strip_edges().trim_suffix("/")

func _valid_email(email: String) -> bool:
	var normalized := email.strip_edges()
	var at_pos := normalized.find("@")
	var dot_pos := normalized.rfind(".")
	return at_pos > 0 and dot_pos > at_pos + 1 and dot_pos < normalized.length() - 1 and not normalized.contains(" ")

func _post(path: String, payload: Dictionary, action: String) -> bool:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json"
	])
	var body := JSON.stringify(payload)
	var error := _http.request(_api_base_url() + path, headers, HTTPClient.METHOD_POST, body)
	if error != OK:
		request_finished.emit(false, "تعذر بدء اتصال آمن بخدمة التحقق.")
		return false
	_pending_action = action
	return true

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _pending_action
	_pending_action = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		request_finished.emit(false, "فشل الاتصال بخدمة التحقق. حاول لاحقًا.")
		return
	var parsed := JSON.new()
	var body_text := body.get_string_from_utf8()
	if parsed.parse(body_text) != OK or not (parsed.data is Dictionary):
		request_finished.emit(false, "استجابة غير صالحة من خدمة التحقق.")
		return
	var response: Dictionary = parsed.data
	if response_code < 200 or response_code >= 300:
		request_finished.emit(false, str(response.get("message", "تعذر إتمام التحقق.")))
		return
	if action == "request_code":
		# Server should return the same generic message for known/unknown addresses.
		request_finished.emit(true, str(response.get("message", "إذا كان البريد مؤهلًا، فستصلك تعليمات التحقق.")))
		return
	if action == "verify_code":
		var payload_value: Variant = response.get("entitlement_payload", "")
		var signature_value: Variant = response.get("signature", "")
		if not (payload_value is String and signature_value is String):
			request_finished.emit(false, "لم تُرجع الخدمة تذكرة مؤسس موقعة.")
			return
		if not FounderIdentityManager.accept_signed_entitlement(payload_value, signature_value):
			request_finished.emit(false, "رفض التحقق من تذكرة المؤسس. راجع إعداد المفتاح العام.")
			return
		entitlement_verified.emit()
		request_finished.emit(true, "تم التحقق من حساب المؤسس.")
