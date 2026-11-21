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
const PKCE_TOKEN_PATH := "/auth/v1/token?grant_type=pkce"
const REFRESH_PATH := "/auth/v1/token?grant_type=refresh_token"
const MAGIC_LINK_REDIRECT_URI := "kingofegyptcity://auth-callback"
const PKCE_VERIFIER_ALIAS := "king_of_egypt_city.player.magic_link_verifier.v1"
const DEEP_LINK_PLUGIN_SINGLETON := "FounderSecureStorage"
const PROFILE_PATH := "/rest/v1/player_profiles"
const SECURE_STORAGE_SINGLETON := "FounderSecureStorage"
const REFRESH_TOKEN_ALIAS := "king_of_egypt_city.player.refresh_token.v1"

var _auth_http: HTTPRequest
var _profile_http: HTTPRequest
var _pending_action := ""
var _profile_action := ""
var _profile_request_access_token := ""
var _profile_request_user_id := ""
var _pending_email := ""
var _access_token := ""
var _refresh_token := ""
var _expires_at := 0
var _user_id := ""
var _email := ""
var _refresh_timer: Timer
var _restoring := false
var _restore_retry_pending := false
var _deep_link_poll_elapsed := 0.0
var _pending_code_verifier := ""

func _process(delta: float) -> void:
	_deep_link_poll_elapsed += delta
	if _deep_link_poll_elapsed < 0.4:
		return
	_deep_link_poll_elapsed = 0.0
	if _pending_action != "" or not Engine.has_singleton(DEEP_LINK_PLUGIN_SINGLETON):
		return
	var plugin: Object = Engine.get_singleton(DEEP_LINK_PLUGIN_SINGLETON)
	if not plugin.has_method("getPendingAuthLink") or not plugin.has_method("clearPendingAuthLink"):
		return
	var pending_link := str(plugin.call("getPendingAuthLink"))
	if pending_link.is_empty():
		return
	plugin.call("clearPendingAuthLink")
	_handle_magic_link_callback(pending_link)

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

func request_google_sign_in() -> bool:
	if _pending_action != "":
		request_finished.emit(false, "هناك طلب حساب قيد التنفيذ.")
		return false
	if not is_configured():
		request_finished.emit(false, "إعدادات خدمة الحسابات غير مكتملة.")
		return false
	if OS.get_name() == "Android" and not _android_deep_link_ready():
		request_finished.emit(false, "نسخة Android لا تحتوي على مكوّن استقبال رابط Google.")
		return false
	var verifier_bytes := Crypto.new().generate_random_bytes(32)
	if verifier_bytes.size() != 32:
		request_finished.emit(false, "تعذر إنشاء حماية جلسة الدخول.")
		return false
	_pending_code_verifier = _base64url(verifier_bytes)
	var hashing := HashingContext.new()
	if hashing.start(HashingContext.HASH_SHA256) != OK:
		_pending_code_verifier = ""
		request_finished.emit(false, "تعذر تجهيز حماية تسجيل الدخول.")
		return false
	hashing.update(_pending_code_verifier.to_utf8_buffer())
	var challenge := _base64url(hashing.finish())
	var storage := _secure_storage()
	if storage != null and storage.has_method("save_secret"):
		if not bool(storage.call("save_secret", PKCE_VERIFIER_ALIAS, _pending_code_verifier)):
			_pending_code_verifier = ""
			request_finished.emit(false, "تعذر حفظ حماية تسجيل الدخول على هذا الجهاز.")
			return false
	elif OS.get_name() == "Android":
		_pending_code_verifier = ""
		request_finished.emit(false, "التخزين الآمن في Android غير متاح؛ لم يتم فتح Google.")
		return false
	var redirect_query := "?provider=google&redirect_to=" + MAGIC_LINK_REDIRECT_URI.uri_encode()
	redirect_query += "&code_challenge=" + challenge.uri_encode()
	redirect_query += "&code_challenge_method=s256"
	var authorize_url := _api_base_url() + "/auth/v1/authorize" + redirect_query
	var open_error := OS.shell_open(authorize_url)
	if open_error != OK:
		_clear_pending_magic_link()
		request_finished.emit(false, "تعذر فتح صفحة تسجيل الدخول باستخدام Google.")
		return false
	request_finished.emit(true, "اختر حساب Google المرتبط بشخصيتك الأصلية، ثم عُد إلى اللعبة.")
	return true

func _android_deep_link_ready() -> bool:
	if not Engine.has_singleton(DEEP_LINK_PLUGIN_SINGLETON):
		return false
	var plugin: Object = Engine.get_singleton(DEEP_LINK_PLUGIN_SINGLETON)
	return plugin.has_method("getPendingAuthLink") and plugin.has_method("clearPendingAuthLink")

func _base64url(value: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(value).replace("+", "-").replace("/", "_").trim_suffix("=")

func _handle_magic_link_callback(link: String) -> void:
	if not link.begins_with(MAGIC_LINK_REDIRECT_URI):
		return
	var auth_code := _url_parameter(link, "code")
	if auth_code.is_empty():
		request_finished.emit(false, "لم يكتمل رد Google أو انتهت صلاحيته. أعد المحاولة.")
		return
	var storage := _secure_storage()
	if _pending_code_verifier.is_empty() and storage != null and storage.has_method("load_secret"):
		_pending_code_verifier = str(storage.call("load_secret", PKCE_VERIFIER_ALIAS))
	if _pending_code_verifier.is_empty():
		request_finished.emit(false, "تعذر استعادة حماية Google. ابدأ تسجيل الدخول من اللعبة مجددًا.")
		return
	if _pending_action != "":
		return
	_send_auth_request(PKCE_TOKEN_PATH, {
		"auth_code": auth_code,
		"code_verifier": _pending_code_verifier
	}, "verify_magic_link")

func _url_parameter(url: String, key: String) -> String:
	var query := url.get_slice("?", 1).get_slice("#", 0)
	if query.is_empty():
		query = url.get_slice("#", 1)
	for item in query.split("&", false):
		var parts := item.split("=", true, 1)
		if parts.size() == 2 and parts[0].uri_decode() == key:
			return parts[1].uri_decode()
	return ""

func _clear_pending_magic_link() -> void:
	var storage := _secure_storage()
	if storage != null and storage.has_method("delete_secret"):
		storage.call("delete_secret", PKCE_VERIFIER_ALIAS)
	_pending_code_verifier = ""
	_pending_email = ""

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
		"request_magic_link":
			request_finished.emit(true, "تم فتح تسجيل الدخول باستخدام Google. أكمل الاختيار ثم عُد إلى اللعبة.")
		"verify_magic_link":
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
	_clear_pending_magic_link()
	_user_id = user_id
	_email = verified_email
	_access_token = access
	_refresh_token = refresh
	_expires_at = int(Time.get_unix_time_from_system()) + expires
	_restore_retry_pending = false
	_restoring = false
	_persist_refresh_token()
	_schedule_refresh()
	session_access_token_changed.emit(_access_token)
	account_authenticated.emit(_user_id, _email)
	_fetch_player_profile()
	if was_restoring:
		request_finished.emit(true, "تم استعادة حساب اللاعب بأمان.")
	else:
		request_finished.emit(true, "تم تسجيل الدخول والتحقق من حساب Google.")

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
	if _refresh_token.is_empty():
		return
	if _pending_action != "":
		if is_instance_valid(_refresh_timer):
			_refresh_timer.start(5.0)
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
	_profile_request_access_token = _access_token
	_profile_request_user_id = _user_id

func _is_profile_request_current(request_user_id: String, request_access_token: String) -> bool:
	return has_active_session() and not request_user_id.is_empty() and not request_access_token.is_empty() and request_user_id == _user_id and request_access_token == _access_token

func _on_profile_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var action := _profile_action
	var request_user_id := _profile_request_user_id
	var request_access_token := _profile_request_access_token
	_profile_action = ""
	_profile_request_user_id = ""
	_profile_request_access_token = ""
	if action != "profile":
		return
	# A profile response is valid only for the exact account session that sent it.
	# If the account changed while the request was in flight, ignore it and load the
	# currently authenticated account after the old HTTPRequest has completed.
	if not _is_profile_request_current(request_user_id, request_access_token):
		if has_active_session():
			call_deferred("_fetch_player_profile")
		return
	if result != HTTPRequest.RESULT_SUCCESS or response_code < 200 or response_code >= 300:
		player_profile_failed.emit("تعذر تحميل ملف اللاعب. سيظل تسجيل الدخول صالحًا.")
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Array) or parsed.is_empty() or not (parsed[0] is Dictionary):
		player_profile_failed.emit("ملف اللاعب غير جاهز على الخادم.")
		return
	var profile: Dictionary = parsed[0]
	var player_code := str(profile.get("player_code", ""))
	var display_name := str(profile.get("display_name", "لاعب"))
	if player_code.length() != 10:
		player_profile_failed.emit("رمز اللاعب المستلم غير صالح.")
		return
	player_profile_ready.emit(request_user_id, player_code, display_name)

func _safe_error(response: Dictionary) -> String:
	match str(response.get("code", "")):
		"over_email_send_rate_limit":
			return "تم تجاوز حد إرسال الرموز مؤقتًا. حاول لاحقًا."
		"email_address_invalid":
			return "عنوان البريد الإلكتروني غير صالح."
		"otp_expired":
			return "انتهت صلاحية الرمز. اطلب رمزًا جديدًا."
		"otp_disabled":
			return "التحقق عبر البريد غير مفعّل حاليًا."
		"flow_state_expired", "bad_code_verifier":
			return "انتهت صلاحية جلسة Google أو تعذر التحقق منها. أعد المحاولة."
		_:
			return "تعذر تسجيل الدخول باستخدام Google. حاول مرة أخرى."
