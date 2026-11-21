extends Node
## Supabase Auth email OTP client. Email verification alone never grants founder privileges.
signal request_finished(success: bool, message: String)
signal email_verified(user_id: String, email: String)
signal auth_session_received(access_token: String, refresh_token: String)
signal auth_session_refreshed(access_token: String)
signal auth_session_restored(access_token: String)
signal auth_session_expired
signal founder_entitlement_received(payload: String, signature_base64: String)
signal founder_entitlement_failed(message: String)

const API_BASE_SETTING := "founder/auth/api_base_url"
const PUBLISHABLE_KEY_SETTING := "founder/auth/publishable_key"
const OTP_PATH := "/auth/v1/otp"
const VERIFY_PATH := "/auth/v1/verify"
const REFRESH_PATH := "/auth/v1/token?grant_type=refresh_token"
const SECURE_STORAGE_SINGLETON := "FounderSecureStorage"
const REFRESH_TOKEN_ALIAS := "king_of_egypt_city.founder.refresh_token.v1"
const ENTITLEMENT_PATH := "/functions/v1/founder-entitlement"

var _http: HTTPRequest
var _pending_action := ""
var _pending_email := ""
var _session_access_token := ""
var _session_refresh_token := ""
var _session_expires_at := 0
var _session_refresh_timer: Timer
var _restoring_session := false
var _restore_retry_pending := false

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "FounderAuthHttpRequest"
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_session_refresh_timer = Timer.new()
	_session_refresh_timer.name = "FounderAuthSessionRefreshTimer"
	_session_refresh_timer.one_shot = true
	add_child(_session_refresh_timer)
	_session_refresh_timer.timeout.connect(_refresh_auth_session)
	# Founder entitlement now uses the authenticated player session; no second Auth session is restored.

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
		if action == "refresh_session":
			if _restoring_session:
				_retry_restore_or_clear()
			else:
				_retry_or_expire_session()
		else:
			request_finished.emit(false, "فشل الاتصال بخدمة التحقق. حاول لاحقًا.")
		return
	if parsed.parse(body.get_string_from_utf8()) != OK or not (parsed.data is Dictionary):
		if action == "refresh_session":
			_retry_or_expire_session()
		else:
			request_finished.emit(false, "استجابة غير صالحة من خدمة التحقق.")
		return
	var response: Dictionary = parsed.data
	if response_code < 200 or response_code >= 300:
		if action == "refresh_session":
			_handle_refresh_failure(response_code, response)
		else:
			request_finished.emit(false, _safe_auth_error(response))
		return
	if action == "refresh_session":
		_handle_refresh_success(response)
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
		var expires_in := int(response.get("expires_in", 3600))
		if expires_in <= 0:
			request_finished.emit(false, "مدة جلسة المصادقة التي أعادها الخادم غير صالحة.")
			return
		_store_auth_session(access_token, refresh_token, expires_in)
		email_verified.emit(user_id, verified_email)
		auth_session_received.emit(access_token, refresh_token)
		request_finished.emit(true, "تم التحقق من البريد. جارٍ طلب اعتماد هوية المؤسس من الخادم...")
		_request_founder_entitlement(access_token)
		return
	if action == "founder_entitlement":
		var payload := str(response.get("payload", ""))
		var signature := str(response.get("signature", ""))
		if payload.is_empty() or signature.is_empty():
			founder_entitlement_failed.emit("لم يُرجع الخادم تذكرة مؤسس صالحة.")
			return
		founder_entitlement_received.emit(payload, signature)
		return

func _request_founder_entitlement(access_token: String) -> void:
	if _pending_action != "":
		founder_entitlement_failed.emit("تعذر بدء طلب اعتماد المؤسس.")
		return
	var endpoint := _api_base_url() + ENTITLEMENT_PATH
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + _publishable_key(),
		"Authorization: Bearer " + access_token
	])
	var error := _http.request(endpoint, headers, HTTPClient.METHOD_POST, "{}")
	if error != OK:
		founder_entitlement_failed.emit("تعذر الاتصال بخدمة اعتماد المؤسس.")
		return
	_pending_action = "founder_entitlement"


func request_founder_entitlement_with_access_token(access_token: String) -> bool:
	if access_token.strip_edges().is_empty():
		founder_entitlement_failed.emit("سجّل الدخول إلى حساب اللاعب أولًا.")
		return false
	if not is_configured():
		founder_entitlement_failed.emit("إعدادات خدمة اعتماد المؤسس غير مكتملة.")
		return false
	if _pending_action != "":
		founder_entitlement_failed.emit("هناك طلب اعتماد آخر قيد التنفيذ.")
		return false
	_request_founder_entitlement(access_token)
	return _pending_action == "founder_entitlement"

func has_active_auth_session() -> bool:
	return not _session_access_token.is_empty() and Time.get_unix_time_from_system() < _session_expires_at

func get_current_access_token() -> String:
	if not has_active_auth_session():
		return ""
	return _session_access_token

func clear_auth_session() -> void:
	_expire_auth_session()

func request_founder_entitlement_for_active_session() -> bool:
	if not has_active_auth_session():
		founder_entitlement_failed.emit("لا توجد جلسة مصادقة نشطة لاعتماد المؤسس.")
		return false
	if _pending_action != "":
		return false
	_request_founder_entitlement(_session_access_token)
	return _pending_action == "founder_entitlement"

func _store_auth_session(access_token: String, refresh_token: String, expires_in: int) -> void:
	_session_access_token = access_token
	_session_refresh_token = refresh_token
	_session_expires_at = int(Time.get_unix_time_from_system()) + expires_in
	_persist_refresh_token_securely(refresh_token)
	_schedule_session_refresh()

func _secure_storage_available() -> bool:
	if not Engine.has_singleton(SECURE_STORAGE_SINGLETON):
		return false
	var storage: Object = Engine.get_singleton(SECURE_STORAGE_SINGLETON)
	return storage.has_method("is_available") and bool(storage.call("is_available"))

func _persist_refresh_token_securely(refresh_token: String) -> void:
	if not _secure_storage_available():
		return
	var storage: Object = Engine.get_singleton(SECURE_STORAGE_SINGLETON)
	if not storage.has_method("save_secret"):
		return
	if not bool(storage.call("save_secret", REFRESH_TOKEN_ALIAS, refresh_token)):
		if storage.has_method("delete_secret"):
			storage.call("delete_secret", REFRESH_TOKEN_ALIAS)
		push_warning("تعذر حفظ جلسة المؤسس في مخزن Android الآمن؛ ستظل الجلسة الحالية مؤقتة.")

func _restore_persisted_session() -> void:
	if not _secure_storage_available():
		return
	var storage: Object = Engine.get_singleton(SECURE_STORAGE_SINGLETON)
	if not storage.has_method("load_secret"):
		return
	var saved_token := str(storage.call("load_secret", REFRESH_TOKEN_ALIAS))
	if saved_token.is_empty():
		return
	_session_refresh_token = saved_token
	_request_session_refresh(true)

func _delete_persisted_refresh_token() -> void:
	if not _secure_storage_available():
		return
	var storage: Object = Engine.get_singleton(SECURE_STORAGE_SINGLETON)
	if storage.has_method("delete_secret"):
		storage.call("delete_secret", REFRESH_TOKEN_ALIAS)

func _schedule_session_refresh() -> void:
	if not is_instance_valid(_session_refresh_timer) or _session_refresh_token.is_empty():
		return
	var remaining := float(_session_expires_at) - Time.get_unix_time_from_system()
	if remaining <= 0.0:
		_expire_auth_session()
		return
	var delay := remaining * 0.8
	if remaining > 20.0:
		delay = minf(delay, remaining - 10.0)
	else:
		delay = remaining * 0.5
	_session_refresh_timer.start(maxf(1.0, delay))

func _refresh_auth_session() -> void:
	_request_session_refresh(_restore_retry_pending)

func _request_session_refresh(restoring: bool) -> void:
	if _session_refresh_token.is_empty():
		return
	if not restoring and Time.get_unix_time_from_system() >= _session_expires_at:
		_expire_auth_session()
		return
	if _pending_action != "":
		_session_refresh_timer.start(5.0)
		return
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + _publishable_key()
	])
	var payload := {"refresh_token": _session_refresh_token}
	var error := _http.request(_api_base_url() + REFRESH_PATH, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		if restoring:
			_retry_restore_or_clear()
		else:
			_retry_or_expire_session()
		return
	_restoring_session = restoring
	_pending_action = "refresh_session"

func _handle_refresh_success(response: Dictionary) -> void:
	var was_restoring := _restoring_session
	_restoring_session = false
	_restore_retry_pending = false
	var access_token := str(response.get("access_token", ""))
	var refresh_token := str(response.get("refresh_token", ""))
	var expires_in := int(response.get("expires_in", 3600))
	if access_token.is_empty() or refresh_token.is_empty() or expires_in <= 0:
		_retry_or_expire_session()
		return
	_store_auth_session(access_token, refresh_token, expires_in)
	auth_session_refreshed.emit(access_token)
	if was_restoring:
		auth_session_restored.emit(access_token)

func _handle_refresh_failure(response_code: int, response: Dictionary) -> void:
	var was_restoring := _restoring_session
	_restoring_session = false
	var error_code := str(response.get("code", response.get("error", ""))).to_lower()
	if response_code == 400 and error_code in ["invalid_grant", "refresh_token_not_found", "refresh_token_already_used", "invalid_refresh_token"]:
		_expire_auth_session()
		return
	if was_restoring:
		_retry_restore_or_clear()
	else:
		_retry_or_expire_session()

func _retry_or_expire_session() -> void:
	if _session_refresh_token.is_empty():
		return
	var remaining := float(_session_expires_at) - Time.get_unix_time_from_system()
	if remaining <= 5.0:
		_expire_auth_session()
	else:
		_session_refresh_timer.start(minf(15.0, remaining - 2.0))

func _retry_restore_or_clear() -> void:
	if _session_refresh_token.is_empty():
		return
	# الشبكة غير متاحة؛ احتفظ بالرمز الآمن وحاول مجددًا عند توفر الاتصال.
	_restore_retry_pending = true
	_session_refresh_timer.start(15.0)

func _expire_auth_session() -> void:
	_restore_retry_pending = false
	_restoring_session = false
	_delete_persisted_refresh_token()
	if is_instance_valid(_session_refresh_timer):
		_session_refresh_timer.stop()
	_session_access_token = ""
	_session_refresh_token = ""
	_session_expires_at = 0
	auth_session_expired.emit()

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
