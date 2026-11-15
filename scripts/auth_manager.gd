extends Node
## Supabase email OTP client for the TEST project only.
## No service_role key is used. Session tokens remain memory-only until
## an Android Keystore-backed persistence layer is implemented and reviewed.

signal otp_sent(email: String)
signal authenticated(user_id: String, email: String)
signal authentication_failed(message: String)

const SUPABASE_URL := "https://unwrlvyjrtdwobcktetd.supabase.co"
const SUPABASE_PUBLISHABLE_KEY := "sb_publishable_BrWeMmhyOpL73Uca40Ug0Q_8Zgw55si"
const OTP_ENDPOINT := SUPABASE_URL + "/auth/v1/otp"
const VERIFY_ENDPOINT := SUPABASE_URL + "/auth/v1/verify"

var _http: HTTPRequest
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

func request_email_otp(email: String) -> bool:
	var normalized_email := email.strip_edges().to_lower()
	if not _is_valid_email(normalized_email):
		authentication_failed.emit("يرجى إدخال بريد إلكتروني صحيح.")
		return false
	if _http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED or not _pending_action.is_empty():
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

func is_authenticated() -> bool:
	return not _access_token.is_empty() and not _authenticated_user_id.is_empty()

func get_access_token() -> String:
	return _access_token

func get_authenticated_user_id() -> String:
	return _authenticated_user_id

func get_authenticated_email() -> String:
	return _authenticated_email

func clear_session() -> void:
	_access_token = ""
	_refresh_token = ""
	_authenticated_user_id = ""
	_authenticated_email = ""

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
	var response_text := body.get_string_from_utf8()
	_clear_pending()

	if result != HTTPRequest.RESULT_SUCCESS:
		authentication_failed.emit("تعذر الاتصال بخدمة تسجيل الدخول.")
		return

	var parsed: Variant = JSON.parse_string(response_text)
	if response_code < 200 or response_code >= 300:
		authentication_failed.emit(_safe_auth_error(parsed))
		return
	if not parsed is Dictionary:
		authentication_failed.emit("استجابة تسجيل الدخول غير صالحة.")
		return

	if action == "request_otp":
		otp_sent.emit(_pending_email)
		return

	if action == "verify_otp":
		var access := str(parsed.get("access_token", ""))
		var refresh := str(parsed.get("refresh_token", ""))
		var user_data: Variant = parsed.get("user", {})
		if access.is_empty() or refresh.is_empty() or not user_data is Dictionary:
			authentication_failed.emit("لم تكتمل جلسة تسجيل الدخول.")
			return
		var user_id := str(user_data.get("id", ""))
		var user_email := str(user_data.get("email", _pending_email))
		if user_id.is_empty():
			authentication_failed.emit("تعذر تأكيد هوية الحساب.")
			return
		_access_token = access
		_refresh_token = refresh
		_authenticated_user_id = user_id
		_authenticated_email = user_email
		authenticated.emit(user_id, user_email)

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
