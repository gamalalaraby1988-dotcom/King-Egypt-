extends Node
## General player email-OTP authentication. Separate from FounderAuthClient and its identity.
signal request_finished(success: bool, message: String)
signal account_authenticated(user_id: String, email: String)
signal session_access_token_changed(access_token: String)
signal session_expired
signal player_profile_ready(user_id: String, player_code: String, display_name: String)
signal player_profile_failed(message: String)

const API_BASE_SETTING := "founder/auth/api_base_url"
const PUBLISHABLE_KEY_SETTING := "founder/auth/publishable_key"
const OTP_PATH := "/auth/v1/otp"
const VERIFY_PATH := "/auth/v1/verify"
const REFRESH_PATH := "/auth/v1/token?grant_type=refresh_token"
const USER_PATH := "/auth/v1/user"
const PROFILE_PATH := "/rest/v1/player_profiles"
const SECURE_STORAGE_SINGLETON := "FounderSecureStorage"
const REFRESH_TOKEN_ALIAS := "king_of_egypt_city.player.refresh_token.v1"

var _auth_http: HTTPRequest
var _profile_http: HTTPRequest
var _pending_action := ""
var _profile_action := ""
var _pending_email := ""
var _access_token := ""
var _refresh_token := ""
var _expires_at := 0
var _user_id := ""
var _email := ""
var _refresh_timer: Timer
var _restoring := false
var _restore_retry_pending := false

func _ready() -> void:
	_auth_http = HTTPRequest.new()
	_auth_http.name = "PlayerAccountAuthHTTPRequest"
	_auth_http.timeout = 20.0
	add_child(_auth_http)
	_auth_http.request_completed.connect(_on_auth_request_completed)

	_profile_http = HTTPRequest.new()
	_profile_http.name = "PlayerAccountProfileHTTPRequest"
	_profile_http.timeout = 20.0
	add_child(_profile_http)
	_profile_http.request_completed.connect(_on_profile_request_completed)

	_refresh_timer = Timer.new()
	_refresh_timer.name = "PlayerAccountRefreshTimer"
	_refresh_timer.one_shot = true
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(_refresh_session)
	call_deferred("_restore_session")

func is_configured() -> bool:
	var base := _api_base_url()
	return base.begins_with("https://") and not _publishable_key().is_empty()

func has_active_session() -> bool:
	return not _access_token.is_empty() and Time.get_unix_time_from_system() < _expires_at

func get_access_token() -> String:
	return _access_token if has_active_session() else ""

func get_user_id() -> String:
	return _user_id

func get_email() -> String:
	return _email

func request_email_code(email: String) -> bool:
	var normalized := email.strip_edges().to_lower()
	if _pending_action != "":
		request_finished.emit(false, "هناك طلب حساب قيد التنفيذ.")
		return false
	if not _valid_email(normalized) or not is_configured():
		request_finished.emit(false, "أدخل بريدًا صحيحًا وتأكد من إعداد خدمة الحسابات.")
		return false
	_pending_email = normalized
	return _send_auth_request(OTP_PATH, {"email": normalized, "create_user": true}, "request_code")

func verify_email_code(email: String, code: String) -> bool:
	var normalized_email := email.strip_edges().to_lower()
	var normalized_code := code.strip_edges()
	if _pending_action != "":
		request_finished.emit(false, "هناك طلب حساب قيد التنفيذ.")
		return false
	if not _valid_email(normalized_email) or normalized_code.length() != 6 or not normalized_code.is_valid_int() or not is_configured():
		request_finished.emit(false, "راجع البريد وأدخل رمز التحقق المكوّن من 6 أرقام.")
		return false
	_pending_email = normalized_email
	return _send_auth_request(VERIFY_PATH, {
		"email": normalized_email,
		"token": normalized_code,
		"type": "email"
	}, "verify_code")

func _api_base_url() -> String:
	return str(ProjectSettings.get_setting(API_BASE_SETTING, "")).strip_edges().trim_suffix("/")

func _publishable_key() -> String:
	return str(ProjectSettings.get_setting(PUBLISHABLE_KEY_SETTING, "")).strip_edges()

func _valid_email(value: String) -> bool:
	var at_pos := value.find("@")
	var dot_pos := value.rfind(".")
	return at_pos > 0 and dot_pos > at_pos + 1 and dot_pos < value.length() - 1 and not value.contains(" ")

func _send_auth_request(path: String, payload: Dictionary, action: String) -> bool:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + _publishable_key()
	])
	var error := _auth_http.request(_api_base_url() + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request_finished.emit(false, "تعذر بدء الاتصال بخدمة الحسابات.")
		return false
	_pending_action = action
	return true

func _on_auth_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _pending_action
	_pending_action = ""
	var parsed := JSON.new()
	if result != HTTPRequest.RESULT_SUCCESS:
		if action == "refresh":
			_retry_refresh()
		else:
			request_finished.emit(false, "تعذر الاتصال بخدمة الحسابات. حاول لاحقًا.")
		return
	if parsed.parse(body.get_string_from_utf8()) != OK or not (parsed.data is Dictionary):
		if action == "refresh":
			_retry_refresh()
		else:
			request_finished.emit(false, "استجابة غير صالحة من خدمة الحسابات.")
		return
	var response: Dictionary = parsed.data
	if response_code < 200 or response_code >= 300:
		if action == "refresh":
			_handle_refresh_error(response_code, response)
		else:
			request_finished.emit(false, _safe_error(response))
		return
	match action:
		"request_code":
			request_finished.emit(true, "إذا كان البريد صالحًا للإرسال، فسيصلك رمز التحقق.")
		"verify_code":
			_accept_session_response(response, false)
		"refresh":
			_accept_session_response(response, _restoring)
		_:
			request_finished.emit(false, "حالة طلب غير معروفة.")

func _accept_session_response(response: Dictionary, was_restoring: bool) -> void:
	var user_value: Variant = response.get("user", {})
	var access := str(response.get("access_token", ""))
	var refresh := str(response.get("refresh_token", ""))
	var expires := int(response.get("expires_in", 3600))
	if not (user_value is Dictionary) or access.is_empty() or refresh.is_empty() or expires <= 0:
		request_finished.emit(false, "لم تُرجع خدمة الحسابات جلسة صالحة.")
		return
	var user: Dictionary = user_value
	var user_id := str(user.get("id", ""))
	var verified_email := str(user.get("email", "")).strip_edges().to_lower()
	var confirmed_at := str(user.get("email_confirmed_at", ""))
	if user_id.is_empty() or verified_email.is_empty() or confirmed_at.is_empty():
		request_finished.emit(false, "لم يثبت الخادم ملكية البريد الإلكتروني.")
		return
	_user_id = user_id
	_email = verified_email
	_access_token = access
	_refresh_token = refresh
	_expires_at = int(Time.get_unix_time_from_system()) + expires
	_restore_retry_pending = false
	_persist_refresh_token()
	_schedule_refresh()
	session_access_token_changed.emit(_access_token)
	account_authenticated.emit(_user_id, _email)
	_fetch_player_profile()
	if was_restoring:
		request_finished.emit(true, "تم استعادة حساب اللاعب بأمان.")
	else:
		request_finished.emit(true, "تم تسجيل الدخول والتحقق من حساب اللاعب.")

func _secure_storage() -> Object:
	if not Engine.has_singleton(SECURE_STORAGE_SINGLETON):
		return null
	var storage: Object = Engine.get_singleton(SECURE_STORAGE_SINGLETON)
	if not storage.has_method("is_available") or not bool(storage.call("is_available")):
		return null
	return storage

func _persist_refresh_token() -> void:
	var storage := _secure_storage()
	if storage == null or not storage.has_method("save_secret"):
		push_warning("مخزن Android الآمن غير متاح؛ جلسة اللاعب الحالية مؤقتة.")
		return
	if not bool(storage.call("save_secret", REFRESH_TOKEN_ALIAS, _refresh_token)):
		if storage.has_method("delete_secret"):
			storage.call("delete_secret", REFRESH_TOKEN_ALIAS)
		push_warning("تعذر حفظ جلسة اللاعب في مخزن Android الآمن.")

func _restore_session() -> void:
	var storage := _secure_storage()
	if storage == null or not storage.has_method("load_secret"):
		return
	var saved := str(storage.call("load_secret", REFRESH_TOKEN_ALIAS))
	if saved.is_empty():
		return
	_refresh_token = saved
	_restoring = true
	_request_refresh()

func _request_refresh() -> void:
	if _refresh_token.is_empty() or _pending_action != "":
		return
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Accept: application/json",
		"apikey: " + _publishable_key()
	])
	var error := _auth_http.request(_api_base_url() + REFRESH_PATH, headers, HTTPClient.METHOD_POST, JSON.stringify({"refresh_token": _refresh_token}))
	if error != OK:
		_retry_refresh()
		return
	_pending_action = "refresh"

func _refresh_session() -> void:
	_request_refresh()

func _schedule_refresh() -> void:
	if not is_instance_valid(_refresh_timer) or _refresh_token.is_empty():
		return
	var remaining := float(_expires_at) - Time.get_unix_time_from_system()
	if remaining <= 0.0:
		_expire_session()
		return
	_refresh_timer.start(maxf(1.0, minf(remaining * 0.8, remaining - 5.0)))

func _retry_refresh() -> void:
	if _refresh_token.is_empty():
		return
	_restore_retry_pending = true
	if is_instance_valid(_refresh_timer):
		_refresh_timer.start(15.0)

func _handle_refresh_error(response_code: int, response: Dictionary) -> void:
	var error_code := str(response.get("code", response.get("error", ""))).to_lower()
	if response_code == 400 and error_code in ["invalid_grant", "refresh_token_not_found", "refresh_token_already_used", "invalid_refresh_token"]:
		_expire_session()
	else:
		_retry_refresh()

func _expire_session() -> void:
	var storage := _secure_storage()
	if storage != null and storage.has_method("delete_secret"):
		storage.call("delete_secret", REFRESH_TOKEN_ALIAS)
	if is_instance_valid(_refresh_timer):
		_refresh_timer.stop()
	_access_token = ""
	_refresh_token = ""
	_expires_at = 0
	_user_id = ""
	_email = ""
	_restoring = false
	_restore_retry_pending = false
	session_expired.emit()

func _fetch_player_profile() -> void:
	if not has_active_session() or _profile_action != "":
		return
	var headers := PackedStringArray([
		"Accept: application/json",
		"apikey: " + _publishable_key(),
		"Authorization: Bearer " + _access_token
	])
	var url := _api_base_url() + PROFILE_PATH + "?select=player_code,display_name&user_id=eq." + _user_id
	var error := _profile_http.request(url, headers, HTTPClient.METHOD_GET)
	if error != OK:
		player_profile_failed.emit("تعذر تحميل ملف اللاعب الآن.")
		return
	_profile_action = "profile"

func _on_profile_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _profile_action
	_profile_action = ""
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		player_profile_failed.emit("تعذر تحميل ملف اللاعب. سيظل تسجيل الدخول صالحًا.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if action != "profile" or not (parsed is Array) or parsed.is_empty() or not (parsed[0] is Dictionary):
		player_profile_failed.emit("ملف اللاعب غير جاهز على الخادم.")
		return
	var profile: Dictionary = parsed[0]
	var player_code := str(profile.get("player_code", ""))
	var display_name := str(profile.get("display_name", "لاعب"))
	if player_code.length() != 10:
		player_profile_failed.emit("رمز اللاعب المستلم غير صالح.")
		return
	player_profile_ready.emit(_user_id, player_code, display_name)

func _safe_error(response: Dictionary) -> String:
	match str(response.get("code", "")):
		"over_email_send_rate_limit":
			return "تم تجاوز حد إرسال الرموز مؤقتًا. حاول لاحقًا."
		"email_address_invalid":
			return "عنوان البريد الإلكتروني غير صالح."
		"otp_expired":
			return "انتهت صلاحية الرمز. اطلب رمزًا جديدًا."
		"otp_disabled":
			return "التحقق برمز البريد غير مفعّل حاليًا."
		_:
			return "تعذر تسجيل الدخول. راجع الرمز وحاول مرة أخرى."
