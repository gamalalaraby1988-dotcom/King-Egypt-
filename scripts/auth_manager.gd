extends Node
## Supabase email OTP client for the TEST project only.
## No service_role key is used. Session tokens remain memory-only until
## an Android Keystore-backed persistence layer is implemented and reviewed.

signal otp_sent(email: String)
signal authenticated(user_id: String, email: String)
signal session_refreshed()
signal test_player_account_ready(test_account_id: String, player_code: String, created: bool)
signal test_player_account_failed(message: String)
signal authentication_failed(message: String)

const SUPABASE_URL := "https://unwrlvyjrtdwobcktetd.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_BrWeMmhyOpL73Uca40Ug0Q_8Zgw55si"
const OTP_ENDPOINT := SUPABASE_URL + "/auth/v1/otp"
const VERIFY_ENDPOINT := SUPABASE_URL + "/auth/v1/verify"
const REFRESH_ENDPOINT := SUPABASE_URL + "/auth/v1/token?grant_type=refresh_token"
const ENSURE_TEST_PLAYER_ENDPOINT := SUPABASE_URL + "/rest/v1/rpc/ensure_my_test_player_account"

var _http: HTTPRequest
var _provision_http: HTTPRequest
var _provision_pending := false
var _test_account_id := ""
var _player_code := ""
var _refresh_timer: Timer
var _session_expires_at := 0
var _pending_action := ""
var _pending_email := ""
var _access_token := ""
var _refresh_token := ""
var _authenticated_user_id := ""
var _authenticated_email := ""

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.name = "SupabaseAuthHTTPRequest"
	_http.timeout = 20.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)
	_provision_http = HTTPRequest.new()
	_provision_http.name = "SupabaseTestPlayerProvisionHTTPRequest"
	_provision_http.timeout = 20.0
	add_child(_provision_http)
	_provision_http.request_completed.connect(_on_provision_request_completed)
	_refresh_timer = Timer.new()
	_refresh_timer.name = "AuthSessionRefreshTimer"
	_refresh_timer.one_shot = true
	add_child(_refresh_timer)
	_refresh_timer.timeout.connect(refresh_session)

func request_email_otp(email: String) -> bool:
	var normalized_email := email.strip_edges().to_lower()
	if not _is_valid_email(normalized_email):
		authentication_failed.emit("يرجى إدخال بريد إلكتروني صحيح.")
		return false
	if not _pending_action.is_empty():
		authentication_failed.emit("هناك طلب تسجيل دخول قيد التنفيذ.")
		return false

	_pending_action = "request_otp"
	_pending_email = normalized_email
	var payload := {
		"email": normalized_email,
		"create_user": false
	}
	var error := _http.request(
		OTP_ENDPOINT,
		_get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_clear_pending()
		authentication_failed.emit("تعذر بدء طلب تسجيل الدخول. حاول مرة أخرى.")
		return false
	return true

func verify_email_otp(email: String, otp: String) -> bool:
	var normalized_email := email.strip_edges().to_lower()
	var normalized_otp := otp.strip_edges()
	if not _is_valid_email(normalized_email) or not normalized_otp.is_valid_int() or normalized_otp.length() != 6:
		authentication_failed.emit("أدخل البريد ورمز التحقق المكوّن من 6 أرقام.")
		return false
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED or not _pending_action.is_empty():
		authentication_failed.emit("هناك طلب تسجيل دخول قيد التنفيذ.")
		return false

	_pending_action = "verify_otp"
	_pending_email = normalized_email
	var payload := {
		"email": normalized_email,
		"token": normalized_otp,
		"type": "email"
	}
	var error := _http.request(
		VERIFY_ENDPOINT,
		_get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_clear_pending()
		authentication_failed.emit("تعذر التحقق من الرمز. حاول مرة أخرى.")
		return false
	return true

func refresh_session() -> bool:
	if not is_authenticated() or _refresh_token.is_empty():
		authentication_failed.emit("لا توجد جلسة صالحة لتجديدها. سجّل الدخول مرة أخرى.")
		return false
	if not _pending_action.is_empty() or _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		authentication_failed.emit("هناك طلب تسجيل دخول قيد التنفيذ.")
		return false

	_pending_action = "refresh_session"
	_pending_email = _authenticated_email
	var payload := {"refresh_token": _refresh_token}
	var error := _http.request(
		REFRESH_ENDPOINT,
		_get_headers(),
		HTTPClient.METHOD_POST,
		JSON.stringify(payload)
	)
	if error != OK:
		_clear_pending()
		authentication_failed.emit("تعذر بدء تجديد الجلسة. حاول مرة أخرى.")
		return false
	return true

func ensure_my_test_player_account() -> bool:
	# Explicit call only; the server allowlist must authorize this Auth UID.
	if not is_authenticated():
		test_player_account_failed.emit("سجّل الدخول وتحقق من بريدك أولًا.")
		return false
	if not _test_account_id.is_empty():
		test_player_account_ready.emit(_test_account_id, _player_code, false)
		return true
	if _provision_pending or _provision_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		test_player_account_failed.emit("طلب تجهيز حساب اللاعب قيد التنفيذ.")
		return false
	_provision_pending = true
	var headers := _get_headers()
	headers.append("Authorization: Bearer " + _access_token)
	var error := _provision_http.request(ENSURE_TEST_PLAYER_ENDPOINT, headers, HTTPClient.METHOD_POST, "{}")
	if error != OK:
		_provision_pending = false
		test_player_account_failed.emit("تعذر بدء تجهيز حساب اللاعب. حاول مرة أخرى.")
		return false
	return true

func get_test_account_id() -> String:
	return _test_account_id

func get_player_code() -> String:
	return _player_code

func is_authenticated() -> bool:
	return not _access_token.is_empty() and not _authenticated_user_id.is_empty()

func _schedule_session_refresh(response_data: Dictionary) -> void:
	var expires_in := int(response_data.get("expires_in", 0))
	if expires_in <= 0:
		_session_expires_at = 0
		_refresh_timer.stop()
		return
	_session_expires_at = int(Time.get_unix_time_from_system()) + expires_in
	# Refresh one minute before expiry.
	_refresh_timer.start(float(maxi(1, expires_in - 60)))

func get_session_expires_at() -> int:
	return _session_expires_at

func get_access_token() -> String:
	return _access_token

func get_authenticated_user_id() -> String:
	return _authenticated_user_id

func get_authenticated_email() -> String:
	return _authenticated_email

func clear_session() -> void:
	# Prevent an in-flight OTP response from restoring a session after local sign-out.
	if not _pending_action.is_empty():
		_http.cancel_request()
		_clear_pending()
	_refresh_timer.stop()
	_session_expires_at = 0
	_access_token = ""
	_refresh_token = ""
	_authenticated_user_id = ""
	_authenticated_email = ""
	_test_account_id = ""
	_player_code = ""
	if is_instance_valid(_provision_http) and _provision_pending:
		_provision_http.cancel_request()
		_provision_pending = false

func _get_headers() -> PackedStringArray:
	return PackedStringArray([
		"apikey: " + SUPABASE_PUBLISHABLE_KEY,
		"Content-Type: application/json",
		"Accept: application/json"
	])

func _on_request_completed(
	result: int,
	response_code: int,
	_response_headers: PackedStringArray,
	body: PackedByteArray
) -> void:
	var action := _pending_action
	var request_email := _pending_email
	var response_text := body.get_string_from_utf8()
	_clear_pending()
	if action.is_empty():
		return

	if result != HTTPRequest.RESULT_SUCCESS:
		authentication_failed.emit("تعذر الاتصال بخدمة تسجيل الدخول.")
		return

	var parsed: Variant = JSON.parse_string(response_text)
	if response_code < 200 or response_code >= 300:
		if action == "refresh_session" and response_code in [400, 401]:
			clear_session()
			authentication_failed.emit(_safe_auth_error(parsed))
			return
	if response_code < 200 or response_code >= 300:
		authentication_failed.emit(_safe_auth_error(parsed))
		return
	if not parsed is Dictionary:
		authentication_failed.emit("استجابة تسجيل الدخول غير صالحة.")
		return

	if action == "request_otp":
		otp_sent.emit(request_email)
		return

	if action == "verify_otp":
		var access := str(parsed.get("access_token", ""))
		var refresh := str(parsed.get("refresh_token", ""))
		var user_data: Variant = parsed.get("user", {})
		if access.is_empty() or refresh.is_empty() or not user_data is Dictionary:
			authentication_failed.emit("لم تكتمل جلسة تسجيل الدخول.")
			return
		var user_id := str(user_data.get("id", ""))
		var user_email := str(user_data.get("email", request_email))
		if user_id.is_empty():
			authentication_failed.emit("تعذر تأكيد هوية الحساب.")
			return
		_test_account_id = ""
		_player_code = ""
		_access_token = access
		_refresh_token = refresh
		_authenticated_user_id = user_id
		_authenticated_email = user_email
		_schedule_session_refresh(parsed)
		authenticated.emit(user_id, user_email)
		return

	if action == "refresh_session":
		var refreshed_access := str(parsed.get("access_token", ""))
		var refreshed_token := str(parsed.get("refresh_token", ""))
		var refreshed_user: Variant = parsed.get("user", {})
		if refreshed_access.is_empty() or refreshed_token.is_empty() or not refreshed_user is Dictionary:
			authentication_failed.emit("استجابة تجديد الجلسة غير مكتملة.")
			return
		var refreshed_user_id := str(refreshed_user.get("id", ""))
		if refreshed_user_id.is_empty() or refreshed_user_id != _authenticated_user_id:
			clear_session()
			authentication_failed.emit("تعذر مطابقة هوية الحساب بعد تجديد الجلسة. سجّل الدخول مرة أخرى.")
			return
		_access_token = refreshed_access
		_refresh_token = refreshed_token
		_authenticated_email = str(refreshed_user.get("email", _authenticated_email))
		_schedule_session_refresh(parsed)
		session_refreshed.emit()

func _on_provision_request_completed(result: int, response_code: int, _response_headers: PackedStringArray, body: PackedByteArray) -> void:
	_provision_pending = false
	if not is_authenticated():
		return
	if result != HTTPRequest.RESULT_SUCCESS:
		test_player_account_failed.emit("تعذر الاتصال بخدمة تجهيز حساب اللاعب.")
		return
	var response_text := body.get_string_from_utf8()
	var parsed: Variant = JSON.parse_string(response_text)
	if response_code < 200 or response_code >= 300:
		if parsed is Dictionary and str(parsed.get("message", "")).contains("test_provisioning_not_enabled"):
			test_player_account_failed.emit("حساب الاختبار غير مفعّل للتجهيز بعد. لم يتم إنشاء أي حساب.")
		elif response_code == 401:
			test_player_account_failed.emit("انتهت جلسة الدخول. سجّل الدخول مجددًا.")
		else:
			test_player_account_failed.emit("رفض الخادم تجهيز حساب اللاعب. لم يتم إنشاء حساب.")
		return
	if not parsed is Array or parsed.is_empty() or not parsed[0] is Dictionary:
		test_player_account_failed.emit("استجابة تجهيز حساب اللاعب غير صالحة.")
		return
	var account_data: Dictionary = parsed[0]
	var account_id := str(account_data.get("test_account_id", ""))
	var code := str(account_data.get("player_code", ""))
	var was_created: bool = account_data.get("created", false) == true
	var code_pattern := RegEx.new()
	code_pattern.compile("^[A-Z0-9]{10}$")
	if account_id.is_empty() or code_pattern.search(code) == null:
		test_player_account_failed.emit("بيانات هوية اللاعب المستلمة غير مكتملة.")
		return
	_test_account_id = account_id
	_player_code = code
	test_player_account_ready.emit(_test_account_id, _player_code, was_created)

func _safe_auth_error(parsed: Variant) -> String:
	if parsed is Dictionary:
		var code := str(parsed.get("code", ""))
		if code == "over_email_send_rate_limit":
			return "انتظر قليلًا قبل طلب رمز جديد."
		if code == "otp_expired":
			return "انتهت صلاحية الرمز. اطلب رمزًا جديدًا."
		if code == "invalid_otp":
			return "رمز التحقق غير صحيح."
	return "تعذر تسجيل الدخول. تحقق من البريد والرمز ثم حاول مجددًا."

func _is_valid_email(value: String) -> bool:
	var at_index := value.find("@")
	return at_index > 0 and value.find(".", at_index) > at_index + 1 and not value.contains(" ")

func _clear_pending() -> void:
	_pending_action = ""
	_pending_email = ""
