extends Node
## Founder entitlement transport only. It never creates or restores an Auth session.
signal founder_entitlement_received(payload: String, signature_base64: String)
signal founder_entitlement_failed(message: String)

const API_BASE_SETTING := "founder/auth/api_base_url"
const PUBLISHABLE_KEY_SETTING := "founder/auth/publishable_key"
const ENTITLEMENT_PATH := "/functions/v1/founder-entitlement"

var _http: HTTPRequest
var _request_pending := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "FounderEntitlementHTTPRequest"
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func is_configured() -> bool:
	var base := _api_base_url()
	return base.begins_with("https://") and not _publishable_key().is_empty()

func request_founder_entitlement_with_access_token(access_token: String) -> bool:
	if access_token.strip_edges().is_empty():
		founder_entitlement_failed.emit("سجّل الدخول إلى حساب اللاعب أولًا.")
		return false
	if not is_configured():
		founder_entitlement_failed.emit("إعدادات خدمة اعتماد المؤسس غير مكتملة.")
		return false
	if _request_pending:
		founder_entitlement_failed.emit("هناك طلب اعتماد آخر قيد التنفيذ.")
		return false

	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + _publishable_key(),
		"Authorization: Bearer " + access_token
	])
	var error := _http.request(_api_base_url() + ENTITLEMENT_PATH, headers, HTTPClient.METHOD_POST, "{}")
	if error != OK:
		founder_entitlement_failed.emit("تعذر بدء الاتصال بخدمة اعتماد المؤسس.")
		return false
	_request_pending = true
	return true

func _api_base_url() -> String:
	var setting := "founder/auth/test_api_base_url" if OS.has_feature("TEST") else API_BASE_SETTING
	return str(ProjectSettings.get_setting(setting, "")).strip_edges().trim_suffix("/")

func _publishable_key() -> String:
	var setting := "founder/auth/test_publishable_key" if OS.has_feature("TEST") else PUBLISHABLE_KEY_SETTING
	return str(ProjectSettings.get_setting(setting, "")).strip_edges()

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_request_pending = false
	if result != HTTPRequest.RESULT_SUCCESS:
		founder_entitlement_failed.emit("تعذر الاتصال بخدمة اعتماد المؤسس.")
		return
	var parsed := JSON.new()
	if parsed.parse(body.get_string_from_utf8()) != OK or not (parsed.data is Dictionary):
		founder_entitlement_failed.emit("استجابة غير صالحة من خدمة اعتماد المؤسس.")
		return
	var response: Dictionary = parsed.data
	if response_code < 200 or response_code >= 300:
		founder_entitlement_failed.emit("لم يعتمد الخادم صلاحية المؤسس لهذا الحساب.")
		return
	var payload := str(response.get("payload", ""))
	var signature := str(response.get("signature", ""))
	if payload.is_empty() or signature.is_empty():
		founder_entitlement_failed.emit("لم يُرجع الخادم تذكرة مؤسس صالحة.")
		return
	founder_entitlement_received.emit(payload, signature)
